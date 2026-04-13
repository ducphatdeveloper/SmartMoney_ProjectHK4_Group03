package fpt.aptech.server.service.planned;

import fpt.aptech.server.dto.planned.PlannedTransactionRequest;
import fpt.aptech.server.dto.planned.PlannedTransactionResponse;
import fpt.aptech.server.dto.transaction.report.TransactionTotalDTO;
import fpt.aptech.server.dto.transaction.view.BillTransactionListResponse;
import fpt.aptech.server.dto.transaction.view.DailyTransactionGroup;
import fpt.aptech.server.dto.transaction.view.TransactionResponse;
import fpt.aptech.server.entity.*;
import fpt.aptech.server.enums.category.SystemCategory;
import fpt.aptech.server.enums.transaction.TransactionSourceType;
import fpt.aptech.server.mapper.planned.PlannedTransactionMapper;
import fpt.aptech.server.mapper.transaction.TransactionMapper;
import fpt.aptech.server.repos.*;
import fpt.aptech.server.service.debt.DebtCalculationService;
import fpt.aptech.server.enums.notification.NotificationType;
import fpt.aptech.server.service.notification.NotificationContent;
import fpt.aptech.server.service.notification.NotificationMessages;
import fpt.aptech.server.service.notification.NotificationService;
import fpt.aptech.server.utils.date.DateUtils;
import fpt.aptech.server.utils.plannedtransaction.RepeatDayBitmask;
import lombok.RequiredArgsConstructor;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

import java.math.BigDecimal;
import java.time.DayOfWeek;
import java.time.LocalDate;
import java.time.LocalDateTime;
import java.util.List;
import java.util.Objects;
import java.util.Set;
import java.util.stream.Collectors;

@Service
@RequiredArgsConstructor
public class PlannedTransactionServiceImpl implements PlannedTransactionService {

    private final PlannedTransactionRepository plannedRepo;
    private final AccountRepository            accountRepo;
    private final WalletRepository             walletRepo;
    private final CategoryRepository           categoryRepo;
    private final DebtRepository               debtRepo;
    private final TransactionRepository        transactionRepo;
    private final PlannedTransactionMapper     mapper;
    private final NotificationService          notificationService; // Inject để gửi thông báo debtFullyPaid
    private final DebtCalculationService       debtCalculationService;
    private final TransactionMapper            transactionMapper; // Inject TransactionMapper

    // ── DEBT category IDs cần có debt_id ────────────────────────────────────
    private static final Set<Integer> DEBT_CATEGORY_IDS = Set.of(
            SystemCategory.DEBT_LENDING.getId(),    // 19 Cho vay
            SystemCategory.DEBT_BORROWING.getId(),  // 20 Đi vay
            SystemCategory.DEBT_COLLECTION.getId(), // 21 Thu nợ
            SystemCategory.DEBT_REPAYMENT.getId()   // 22 Trả nợ
    );

    // ════════════════════════════════════════════════════════════════════════
    // 1. RECURRING (plan_type = 2) — Giao dịch định kỳ tự động
    // ════════════════════════════════════════════════════════════════════════

    /**
     * [1.1] Lấy danh sách Recurring theo trạng thái active.
     */
    @Override
    @Transactional(readOnly = true)
    public List<PlannedTransactionResponse> getRecurring(Integer userId, Boolean active) {
        return mapper.toDtoList(
                plannedRepo.findByAccount_IdAndPlanTypeAndActiveOrderByCreatedAtDesc(
                        userId, 2, active));
    }

    /**
     * [1.2] Lấy chi tiết một Recurring theo ID + kiểm tra quyền.
     */
    @Override
    @Transactional(readOnly = true)
    public PlannedTransactionResponse getRecurringById(Integer id, Integer userId) {
        return mapper.toDto(getOwnedPlanned(id, userId));
    }

    /**
     * [1.3] Tạo Recurring mới (plan_type=2).
     */
    @Override
    @Transactional
    public PlannedTransactionResponse createRecurring(PlannedTransactionRequest req, Integer userId) {
        return mapper.toDto(plannedRepo.save(buildPlanned(req, userId, 2)));
    }

    /**
     * [1.4] Cập nhật Recurring — chỉ update bảng tPlannedTransactions,
     * KHÔNG thay đổi các Transaction đã tạo trước đó.
     */
    @Override
    @Transactional
    public PlannedTransactionResponse updateRecurring(Integer id,
                                                      PlannedTransactionRequest req,
                                                      Integer userId) {
        PlannedTransaction planned = getOwnedPlanned(id, userId);
        updatePlannedFields(planned, req, userId);
        return mapper.toDto(plannedRepo.save(planned));
    }

    /**
     * [1.5] Xóa mềm Recurring — giữ lại Transaction nhưng cắt liên kết (set planned_id=NULL).
     * SourceType vẫn là PLANNED (5) để tracking lịch sử.
     */
    @Override
    @Transactional
    public void deleteRecurring(Integer id, Integer userId) {
        PlannedTransaction planned = getOwnedPlanned(id, userId);
        // Cắt liên kết transaction (set planned_id=NULL) thay vì xóa
        transactionRepo.clearPlannedTransactionLink(id, userId);
        // Soft delete planned
        planned.setDeleted(true);
        planned.setDeletedAt(java.time.LocalDateTime.now());
        plannedRepo.save(planned);
    }

    /**
     * [1.6] Toggle active của Recurring.
     * Không cho kích hoạt lại nếu:
     *   - Debt liên kết đã finished (đã trả xong)
     *   - endDate đã qua (hết hạn)
     */
    @Override
    @Transactional
    public PlannedTransactionResponse toggleRecurring(Integer id, Integer userId) {
        PlannedTransaction planned = getOwnedPlanned(id, userId);

        // Không cho reactivate nếu khoản nợ đã trả xong
        if (!planned.getActive()
                && planned.getDebt() != null
                && Boolean.TRUE.equals(planned.getDebt().getFinished())) {
            throw new IllegalArgumentException(
                    "Khoản nợ đã thanh toán xong, không thể kích hoạt lại giao dịch định kỳ này.");
        }

        // Không cho reactivate nếu giao dịch định kỳ đã hết hạn (endDate đã qua)
        if (!planned.getActive()
                && planned.getEndDate() != null
                && planned.getEndDate().isBefore(LocalDate.now())) {
            throw new IllegalArgumentException(String.format(
                    "Giao dịch định kỳ đã hết hạn từ ngày %s. Vui lòng tạo mới nếu muốn tiếp tục.",
                    DateUtils.formatDisplayDate(planned.getEndDate())));
        }

        planned.setActive(!planned.getActive());
        return mapper.toDto(plannedRepo.save(planned));
    }

    // ════════════════════════════════════════════════════════════════════════
    // 2. BILLS (plan_type = 1) — Hóa đơn duyệt tay
    // ════════════════════════════════════════════════════════════════════════

    /**
     * [2.1] Lấy danh sách Bills theo trạng thái active.
     */
    @Override
    @Transactional(readOnly = true)
    public List<PlannedTransactionResponse> getBills(Integer userId, Boolean active) {
        return mapper.toDtoList(
                plannedRepo.findByAccount_IdAndPlanTypeAndActiveOrderByCreatedAtDesc(
                        userId, 1, active));
    }

    /**
     * [2.2] Lấy chi tiết một Bill theo ID + kiểm tra quyền.
     */
    @Override
    @Transactional(readOnly = true)
    public PlannedTransactionResponse getBillById(Integer id, Integer userId) {
        return mapper.toDto(getOwnedPlanned(id, userId));
    }

    /**
     * [2.3] Tạo Bill mới (plan_type=1).
     */
    @Override
    @Transactional
    public PlannedTransactionResponse createBill(PlannedTransactionRequest req, Integer userId) {
        return mapper.toDto(plannedRepo.save(buildPlanned(req, userId, 1)));
    }

    /**
     * [2.4] Cập nhật Bill — chỉ update bảng tPlannedTransactions.
     */
    @Override
    @Transactional
    public PlannedTransactionResponse updateBill(Integer id,
                                                 PlannedTransactionRequest req,
                                                 Integer userId) {
        PlannedTransaction planned = getOwnedPlanned(id, userId);
        updatePlannedFields(planned, req, userId);
        return mapper.toDto(plannedRepo.save(planned));
    }

    /**
     * [2.5] Xóa mềm Bill — giữ lại Transaction nhưng cắt liên kết (set planned_id=NULL).
     * SourceType vẫn là PLANNED (5) để tracking lịch sử.
     */
    @Override
    @Transactional
    public void deleteBill(Integer id, Integer userId) {
        PlannedTransaction planned = getOwnedPlanned(id, userId);
        // Cắt liên kết transaction (set planned_id=NULL) thay vì xóa
        transactionRepo.clearPlannedTransactionLink(id, userId);
        // Soft delete planned
        planned.setDeleted(true);
        planned.setDeletedAt(java.time.LocalDateTime.now());
        plannedRepo.save(planned);
    }

    /**
     * [2.6] User bấm "Trả tiền" → Tạo Transaction từ Bill.
     * Tích hợp logic kiểm tra trạng thái V2.
     */
    @Override
    @Transactional
    public PlannedTransactionResponse payBill(Integer id, Integer userId) {
        // --- Bước 1: Lấy thông tin và validate quyền ---
        PlannedTransaction planned = getOwnedPlanned(id, userId);
        LocalDate today = LocalDate.now();

        // --- Bước 2: Validate loại, chỉ cho phép Bill ---
        if (planned.getPlanType() != 1) {
            throw new IllegalArgumentException("Chỉ hóa đơn (Bill) mới có thể được trả qua phương thức này.");
        }

        // --- Bước 3: Validate trạng thái (Logic V3) ---
        // 3.1. Kiểm tra Hết Hạn (EXPIRED)
        if (planned.getEndDate() != null && planned.getEndDate().isBefore(today)) {
            throw new IllegalArgumentException("Hóa đơn đã hết hạn. Vui lòng sửa lại ngày kết thúc nếu muốn tiếp tục.");
        }

        // 3.2. Kiểm tra Đã Đến Hạn thanh toán chưa
        // Chỉ cho phép thanh toán khi ngày hiện tại >= ngày đến hạn tiếp theo
        if (planned.getNextDueDate() != null && today.isBefore(planned.getNextDueDate())) {
            throw new IllegalArgumentException(String.format(
                "Chưa tới hạn thanh toán. Hóa đơn này có thể thanh toán vào ngày %s. " +
                "Vui lòng quay lại vào ngày đến hạn để thanh toán.",
                DateUtils.formatDisplayDate(planned.getNextDueDate())
            ));
        }

        // 3.3. Kiểm tra Đã Trả (PAID) cho kỳ hiện tại
        // cycleDate là ngày đại diện cho kỳ cần thanh toán
        LocalDate cycleDate = planned.getNextDueDate() != null ? planned.getNextDueDate() : today;
        LocalDateTime startOfCycle = cycleDate.atStartOfDay();
        LocalDateTime endOfCycle = cycleDate.atTime(23, 59, 59);

        if (transactionRepo.existsByPlannedTransactionIdAndAccountIdAndTransDateBetween(
                planned.getId(), userId, startOfCycle, endOfCycle)) {
            throw new IllegalArgumentException("Hóa đơn đã được thanh toán cho kỳ này.");
        }

        // 3.4. [FIX-DEBT-PRECHECK] Kiểm tra khoản nợ liên kết đã hoàn thành TRƯỚC KHI tạo GD
        // Reload debt từ DB để đảm bảo lấy trạng thái mới nhất (tránh Hibernate cache)
        // [IMPORTANT] KHÔNG thêm plannedRepo.save() ở đây: throw sẽ rollback mọi thứ trong @Transactional
        // Việc deactivate bill được thực hiện bởi: recalculateDebt() → deactivateAllByDebtId()
        if (planned.getDebt() != null) {
            Debt linkedDebt = debtRepo.findById(planned.getDebt().getId()).orElse(null);
            if (linkedDebt != null && Boolean.TRUE.equals(linkedDebt.getFinished())) {
                throw new IllegalArgumentException(
                    "Khoản nợ liên kết đã được thanh toán xong. Hóa đơn không còn hiệu lực.");
            }
        }

        // --- Bước 4: Tạo Transaction ---
        // Nếu tất cả validate đều qua, tiến hành tạo giao dịch
        createTransactionFromPlanned(planned);

        // --- Bước 5: Kiểm tra nợ liên kết — nếu đã hoàn thành → deactivate bill ---
        // [FIX-AUTODEACTIVATE] Nếu hóa đơn liên kết debt và debt vừa được kết thúc
        // (do recalculateDebt() gọi ở Bước 4) → tự động deactivate bill này
        // Lý do: Khi trả đủ hoặc vượt số tiền nợ → hóa đơn không cần tạo transaction lần nữa
        if (planned.getDebt() != null) {
            // Reload debt từ DB để kiểm tra trạng thái mới nhất (vừa được update)
            Debt updatedDebt = debtRepo.findById(planned.getDebt().getId()).orElse(null);
            if (updatedDebt != null && Boolean.TRUE.equals(updatedDebt.getFinished())) {
                planned.setActive(false);
            }
        }

        // --- Bước 6: Cập nhật lịch trình cho kỳ tiếp theo ---
        // [FIX-CATCHUP] Giống Scheduler: vòng lặp tiến nextDueDate đến tương lai
        // BUG CŨ: chỉ tiến 1 kỳ → nếu trả trễ, nextDueDate mới vẫn < today
        //   VD: nextDueDate=01/03, trả ngày 14/04 → nextDue=01/04 < 14/04 → vẫn "quá hạn" ngay!
        // FIX: vòng lặp catch-up cho đến khi nextDueDate > today
        LocalDate nextDue = calculateNextDueDate(planned, planned.getNextDueDate());
        int safety = 0;
        while (!nextDue.isAfter(today) && safety++ < 1000) {
            nextDue = calculateNextDueDate(planned, nextDue);
        }
        planned.setLastExecutedAt(today);
        planned.setNextDueDate(nextDue);

        // [FIX-ENDDATE] Nếu nextDue vượt endDate → deactivate bill (giống Scheduler Bước 10)
        if (planned.getEndDate() != null && nextDue.isAfter(planned.getEndDate())) {
            planned.setActive(false);
        }

        // --- Bước 7: Gửi thông báo xác nhận thanh toán thành công ---
        String label = planned.getNote() != null ? planned.getNote() : planned.getCategory().getCtgName();
        // Truyền nextDueDate = null nếu bill đã bị deactivate (debt xong hoặc hết hạn)
        LocalDate nextDueForMsg = Boolean.TRUE.equals(planned.getActive()) ? nextDue : null;
        NotificationContent billPaidMsg = NotificationMessages.billPaid(label, planned.getAmount(), nextDueForMsg);
        notificationService.createNotification(
                planned.getAccount(),
                billPaidMsg.title(), billPaidMsg.content(),
                NotificationType.REMINDER,
                Long.valueOf(planned.getId()),
                null
        );

        // --- Bước 8: Lưu và trả về DTO mới nhất ---
        // Mapper sẽ tự động tính lại displayStatus và các label khác
        return mapper.toDto(plannedRepo.save(planned));
    }


    /**
     * [2.7] Toggle active của Bill (đánh dấu hoàn tất / chưa hoàn tất).
     * Không cho reactivate nếu:
     *   - Khoản nợ liên kết đã finished (đã trả xong)
     *   - endDate đã qua (hết hạn)
     */
    @Override
    @Transactional
    public PlannedTransactionResponse toggleBill(Integer id, Integer userId) {
        PlannedTransaction planned = getOwnedPlanned(id, userId);

        // Không cho reactivate nếu khoản nợ đã trả xong
        if (!planned.getActive()
                && planned.getDebt() != null
                && Boolean.TRUE.equals(planned.getDebt().getFinished())) {
            throw new IllegalArgumentException(
                    "Khoản nợ đã thanh toán xong, không thể kích hoạt lại hóa đơn này.");
        }

        // Không cho reactivate nếu hóa đơn đã hết hạn (endDate đã qua)
        if (!planned.getActive()
                && planned.getEndDate() != null
                && planned.getEndDate().isBefore(LocalDate.now())) {
            throw new IllegalArgumentException(String.format(
                    "Hóa đơn đã hết hạn từ ngày %s. Vui lòng tạo mới nếu muốn tiếp tục.",
                    DateUtils.formatDisplayDate(planned.getEndDate())));
        }

        planned.setActive(!planned.getActive());
        return mapper.toDto(plannedRepo.save(planned));
    }

    // ════════════════════════════════════════════════════════════════════════
    // 3. XEM GIAO DỊCH LIÊN QUAN
    // ════════════════════════════════════════════════════════════════════════

    /**
     * [3.1] Lấy danh sách giao dịch của Hóa đơn kèm header tóm tắt.
     * ⚠️ CHỈ BILLS (plan_type=1) — Recurring tự động, không cần màn này.
     *
     * Trả về 2 phần:
     *   - summary: tổng thu (totalIncome) + tổng chi (totalExpense) → Frontend tự tính "Còn lại"
     *   - groupedTransactions: danh sách giao dịch gom theo ngày (DailyTransactionGroup)
     *
     * Performance: CHỈ 1 QUERY duy nhất → tính totalIncome/totalExpense bằng Java stream
     * (Hóa đơn có ít giao dịch, ~12-50/năm → Java stream nhanh hơn 2 queries DB)
     */
    @Override
    @Transactional(readOnly = true)
    public BillTransactionListResponse getBillTransactions(Integer billId, Integer userId) {
        // Bước 1: Validate Bill tồn tại, thuộc user, và đúng plan_type=1
        PlannedTransaction bill = getOwnedPlanned(billId, userId);
        if (bill.getPlanType() != 1) {
            throw new IllegalArgumentException("Chỉ hóa đơn mới có danh sách giao dịch");
        }

        // Bước 2: Lấy toàn bộ giao dịch của Bill (1 query duy nhất, sắp xếp mới nhất lên đầu)
        List<Transaction> transactions = transactionRepo
                .findAllByPlannedTransactionIdAndAccountIdOrderByTransDateDesc(billId, userId);

        // Bước 3: Tính tổng thu/chi từ list đã fetch — không cần query thêm
        // ctgType=true → Thu nhập | ctgType=false → Chi tiêu
        BigDecimal totalIncome = transactions.stream()
                .filter(t -> Boolean.TRUE.equals(t.getCategory().getCtgType()))
                .map(Transaction::getAmount)
                .reduce(BigDecimal.ZERO, BigDecimal::add);
        BigDecimal totalExpense = transactions.stream()
                .filter(t -> Boolean.FALSE.equals(t.getCategory().getCtgType()))
                .map(Transaction::getAmount)
                .reduce(BigDecimal.ZERO, BigDecimal::add);

        // Bước 4: Gom giao dịch theo ngày → mỗi ngày là 1 DailyTransactionGroup
        List<DailyTransactionGroup> grouped = transactions.stream()
                .collect(Collectors.groupingBy(t -> t.getTransDate().toLocalDate()))
                .entrySet().stream()
                .map(e -> {
                    // netAmount của ngày = tổng thu - tổng chi trong ngày đó
                    BigDecimal net = e.getValue().stream()
                            .map(t -> Boolean.TRUE.equals(t.getCategory().getCtgType())
                                    ? t.getAmount()          // Thu → cộng
                                    : t.getAmount().negate()) // Chi → trừ
                            .reduce(BigDecimal.ZERO, BigDecimal::add);
                    return DailyTransactionGroup.builder()
                            .date(e.getKey())
                            .displayDateLabel(DateUtils.formatDisplayDate(e.getKey())) // VD: "Hôm nay", "Hôm qua"
                            .netAmount(net)
                            .transactions(transactionMapper.toDtoList(e.getValue()))
                            .build();
                })
                .sorted(java.util.Comparator.comparing(DailyTransactionGroup::date).reversed()) // Mới nhất lên đầu
                .collect(Collectors.toList());

        // Bước 5: Build response trả về 2 form (header + body)
        return BillTransactionListResponse.builder()
                .totalCount(transactions.size())                          // Tổng số GD ("5 Kết quả")
                .summary(new TransactionTotalDTO(totalIncome, totalExpense)) // Form 1: Header
                .groupedTransactions(grouped)                              // Form 2: Body gom theo ngày
                .build();
    }

    // ════════════════════════════════════════════════════════════════════════
    // 4. HELPER DÙNG CHUNG
    // ════════════════════════════════════════════════════════════════════════

    /**
     * [4.1] Tìm PlannedTransaction và kiểm tra quyền sở hữu.
     */
    private PlannedTransaction getOwnedPlanned(Integer id, Integer userId) {
        return plannedRepo.findByIdAndAccount_Id(id, userId)
                .orElseThrow(() -> new IllegalArgumentException(
                        "Không tìm thấy giao dịch định kỳ"));
    }

    /**
     * [4.2] Xây dựng PlannedTransaction mới từ Request.
     * Bước 1 — Validate Account, Wallet, Category, Debt.
     * Bước 2 — Tính endDate từ endDateOption.
     * Bước 3 — Build Entity.
     */
    private PlannedTransaction buildPlanned(PlannedTransactionRequest req,
                                            Integer userId, Integer planType) {
        // Bước 1.1: Validate Account
        Account account = accountRepo.findById(userId)
                .orElseThrow(() -> new IllegalArgumentException("Tài khoản không tồn tại"));

        // Bước 1.2: Validate Wallet
        Wallet wallet = walletRepo.findById(req.walletId())
                .orElseThrow(() -> new IllegalArgumentException("Ví không tồn tại"));
        if (!wallet.getAccount().getId().equals(userId)) {
            throw new SecurityException("Không có quyền sử dụng ví này");
        }

        // Bước 1.3: Validate Category
        Category category = categoryRepo.findById(req.categoryId())
                .orElseThrow(() -> new IllegalArgumentException("Danh mục không tồn tại"));
        if (category.getAccount() != null
                && !category.getAccount().getId().equals(userId)) {
            throw new SecurityException("Không có quyền sử dụng danh mục này");
        }

        // Bước 1.4: Validate category Nợ/Vay cho PlannedTransaction
        // [FIX-BLOCK-DEBT-ORIGIN] Chặn tạo planned với Cho vay (19) / Đi vay (20)
        // Lý do: 2 category này dùng để KHỞI TẠO khoản nợ trong module Debt (tạo tDebts mới),
        // PlannedTransaction chỉ dùng Thu nợ (21) / Trả nợ (22) để trả/thu nợ đã có
        if (req.categoryId() == SystemCategory.DEBT_LENDING.getId()
                || req.categoryId() == SystemCategory.DEBT_BORROWING.getId()) {
            throw new IllegalArgumentException(
                    "Không thể tạo giao dịch định kỳ/hóa đơn với danh mục Cho vay hoặc Đi vay. " +
                    "Vui lòng sử dụng danh mục Thu nợ hoặc Trả nợ.");
        }

        // Bước 1.5: Validate Debt cho Thu nợ (21) / Trả nợ (22)
        // Bắt buộc chọn debt_id + debt_type phải phù hợp với category
        Debt debt = null;
        if (req.categoryId() == SystemCategory.DEBT_COLLECTION.getId()
                || req.categoryId() == SystemCategory.DEBT_REPAYMENT.getId()) {
            // 1.5a: Bắt buộc chọn khoản nợ liên kết
            if (req.debtId() == null) {
                throw new IllegalArgumentException(
                        "Vui lòng chọn khoản nợ liên kết cho danh mục Thu nợ / Trả nợ.");
            }
            debt = debtRepo.findById(req.debtId())
                    .orElseThrow(() -> new IllegalArgumentException("Khoản nợ không tồn tại"));
            if (!debt.getAccount().getId().equals(userId)) {
                throw new SecurityException("Không có quyền sử dụng khoản nợ này");
            }
            // 1.5b: Validate debt_type phù hợp:
            //   Thu nợ (21) → debt phải là "Cần Thu" (debtType=true/1, tức Cho vay)
            //   Trả nợ (22) → debt phải là "Cần Trả" (debtType=false/0, tức Đi vay)
            boolean requireDebtType = req.categoryId() == SystemCategory.DEBT_COLLECTION.getId();
            if (!debt.getDebtType().equals(requireDebtType)) {
                throw new IllegalArgumentException(requireDebtType
                        ? "Danh mục Thu nợ chỉ được liên kết với khoản nợ loại 'Cần Thu' (Cho vay)."
                        : "Danh mục Trả nợ chỉ được liên kết với khoản nợ loại 'Cần Trả' (Đi vay).");
            }
            // 1.5c: Chặn liên kết debt đã trả xong
            if (Boolean.TRUE.equals(debt.getFinished())) {
                throw new IllegalArgumentException(
                        "Khoản nợ đã thanh toán xong, không thể tạo giao dịch định kỳ/hóa đơn liên kết.");
            }
        }

        // Bước 2: Tính endDate
        LocalDate endDate    = calculateEndDate(req);
        LocalDate nextDueDate = req.beginDate(); // Lần đầu chạy = begin_date

        // Bước 3: Build
        return PlannedTransaction.builder()
                .account(account)
                .wallet(wallet)
                .category(category)
                .debt(debt)
                .note(req.note())
                .amount(req.amount())
                .planType(planType)
                .repeatType(req.repeatType())
                .repeatInterval(req.repeatInterval() != null ? req.repeatInterval() : 1)
                .repeatOnDayVal(req.repeatOnDayVal())
                .beginDate(req.beginDate())
                .nextDueDate(nextDueDate)
                .endDate(endDate)
                .active(true)
                .build();
    }

    /**
     * [4.3] Cập nhật các trường của PlannedTransaction khi edit.
     * KHÔNG đụng đến các Transaction đã tạo trước đó.
     *
     * Logic nextDueDate:
     *   - beginDate đổi, = hôm nay, đã có GD hôm nay → nextDueDate = kỳ sau (tránh duplicate)
     *   - beginDate đổi, = hôm nay, chưa có GD hôm nay → nextDueDate = hôm nay (Scheduler tạo ngay)
     *   - beginDate đổi, > hôm nay → nextDueDate = beginDate
     *   - beginDate giữ, repeat params đổi → tính lại từ beginDate, tiến >= hôm nay
     *   - Cả hai giữ nguyên → nextDueDate không đổi
     */
    private void updatePlannedFields(PlannedTransaction planned,
                                     PlannedTransactionRequest req,
                                     Integer userId) {
        // ── Bước 1: Detect thay đổi trước khi overwrite ──────────────────
        LocalDate oldBeginDate = planned.getBeginDate();
        boolean beginDateChanged = !oldBeginDate.equals(req.beginDate());
        boolean repeatParamsChanged =
                !Objects.equals(planned.getRepeatType(),     req.repeatType())      ||
                        !Objects.equals(planned.getRepeatInterval(), req.repeatInterval())  ||
                        !Objects.equals(planned.getRepeatOnDayVal(), req.repeatOnDayVal());

        if (beginDateChanged && req.beginDate().isBefore(LocalDate.now())) {
            throw new IllegalArgumentException(
                    "Không thể sửa thời gian bắt đầu sang ngày trong quá khứ. " +
                            "Vui lòng chọn một ngày từ hôm nay trở đi.");
        }

        // ── Bước 2: Validate Wallet, Category, Debt ──────────────────────
        Wallet wallet = walletRepo.findById(req.walletId())
                .orElseThrow(() -> new IllegalArgumentException("Ví không tồn tại"));
        if (!wallet.getAccount().getId().equals(userId))
            throw new SecurityException("Không có quyền sử dụng ví này");

        // [FIX-DEBT-WALLET-LOCK] Kiểm tra: nếu giao dịch định kỳ thuộc vay nợ (category 19/20/21/22)
        // → không được phép đổi ví (vì các transaction liên kết debt đã ghi trong ví cũ)
        if (DEBT_CATEGORY_IDS.contains(req.categoryId())) {
            if (!req.walletId().equals(planned.getWallet().getId())) {
                throw new IllegalArgumentException(
                        "Không thể đổi ví cho giao dịch định kỳ/hóa đơn thuộc vay nợ. " +
                        "Ví đã được xác định bởi các giao dịch nợ trước đó.");
            }
        }

        Category category = categoryRepo.findById(req.categoryId())
                .orElseThrow(() -> new IllegalArgumentException("Danh mục không tồn tại"));
        if (category.getAccount() != null && !category.getAccount().getId().equals(userId))
            throw new SecurityException("Không có quyền sử dụng danh mục này");

        // [FIX-BLOCK-DEBT-ORIGIN] Chặn đổi sang category Cho vay (19) / Đi vay (20) khi update
        if (req.categoryId() == SystemCategory.DEBT_LENDING.getId()
                || req.categoryId() == SystemCategory.DEBT_BORROWING.getId()) {
            throw new IllegalArgumentException(
                    "Không thể sử dụng danh mục Cho vay hoặc Đi vay cho giao dịch định kỳ/hóa đơn. " +
                    "Vui lòng sử dụng danh mục Thu nợ hoặc Trả nợ.");
        }

        // Validate Debt cho Thu nợ (21) / Trả nợ (22)
        Debt debt = null;
        if (req.categoryId() == SystemCategory.DEBT_COLLECTION.getId()
                || req.categoryId() == SystemCategory.DEBT_REPAYMENT.getId()) {
            if (req.debtId() == null) {
                throw new IllegalArgumentException(
                        "Vui lòng chọn khoản nợ liên kết cho danh mục Thu nợ / Trả nợ.");
            }
            debt = debtRepo.findById(req.debtId())
                    .orElseThrow(() -> new IllegalArgumentException("Khoản nợ không tồn tại"));
            if (!debt.getAccount().getId().equals(userId))
                throw new SecurityException("Không có quyền sử dụng khoản nợ này");
            // Validate debt_type phù hợp với category
            boolean requireDebtType = req.categoryId() == SystemCategory.DEBT_COLLECTION.getId();
            if (!debt.getDebtType().equals(requireDebtType)) {
                throw new IllegalArgumentException(requireDebtType
                        ? "Danh mục Thu nợ chỉ được liên kết với khoản nợ loại 'Cần Thu' (Cho vay)."
                        : "Danh mục Trả nợ chỉ được liên kết với khoản nợ loại 'Cần Trả' (Đi vay).");
            }
            if (Boolean.TRUE.equals(debt.getFinished())) {
                throw new IllegalArgumentException(
                        "Khoản nợ đã thanh toán xong, không thể liên kết.");
            }
        }

        // ── Bước 3: Overwrite các field ──────────────────────────────────
        planned.setWallet(wallet);
        planned.setCategory(category);
        planned.setDebt(debt);
        planned.setAmount(req.amount());
        planned.setNote(req.note());
        planned.setRepeatType(req.repeatType());
        planned.setRepeatInterval(req.repeatInterval() != null ? req.repeatInterval() : 1);
        planned.setRepeatOnDayVal(req.repeatOnDayVal());
        planned.setBeginDate(req.beginDate());
        planned.setEndDate(calculateEndDate(req));

        // ── Bước 4: Tính lại nextDueDate (nếu cần) ───────────────────────
        LocalDate today = LocalDate.now();

        if (beginDateChanged) {
            LocalDate newBeginDate = req.beginDate();
            if (newBeginDate.equals(today)) {
                // beginDate = hôm nay → check duplicate GD hôm nay
                boolean hasTransactionToday = transactionRepo
                        .existsByPlannedTransactionIdAndAccountIdAndTransDateBetween(
                                planned.getId(), userId,
                                today.atStartOfDay(), today.atTime(23, 59, 59));
                planned.setNextDueDate(hasTransactionToday
                        ? calculateNextDueDate(planned, today) // đã có GD → nhảy kỳ sau
                        : today);                              // chưa có  → Scheduler chạy ngay
            } else {
                planned.setNextDueDate(newBeginDate); // beginDate > hôm nay → giữ nguyên beginDate
            }

        } else if (repeatParamsChanged && planned.getNextDueDate() != null) {
            // Lịch lặp đổi, beginDate giữ → tính lại từ beginDate rồi tiến >= hôm nay
            LocalDate nd = calculateNextDueDate(planned, planned.getBeginDate());
            int safety = 0;
            while (nd.isBefore(today) && safety++ < 1000)
                nd = calculateNextDueDate(planned, nd);
            planned.setNextDueDate(nd);
        }
        // Cả hai không đổi → giữ nguyên nextDueDate hiện tại

        // ── Bước 5: Fallback safety — đẩy nextDueDate lên >= hôm nay ────
        // Bắt edge case: Case B set nextDueDate = beginDate nhưng beginDate vừa pass today
        // (hiếm nhưng có thể xảy ra nếu request gửi trễ ngay sát nửa đêm)
        LocalDate currentNext = planned.getNextDueDate();
        if (currentNext != null && currentNext.isBefore(today)) {
            LocalDate nd = currentNext;
            int safety = 0;
            while (nd.isBefore(today) && safety++ < 1000)
                nd = calculateNextDueDate(planned, nd);
            planned.setNextDueDate(nd);
        }
    }

    // ════════════════════════════════════════════════════════════════════════
    // 5. TÍNH TOÁN LỊCH LẶP
    // ════════════════════════════════════════════════════════════════════════

    // [5.0] Helper: Tính nextDueDate từ một ngày cho trước (dùng cho logic update & Scheduler)
    public LocalDate calculateNextDueDate(PlannedTransaction p, LocalDate from) {
        int interval = p.getRepeatInterval() != null ? p.getRepeatInterval() : 1;

        return switch (p.getRepeatType()) {
            case 1 -> from.plusDays(interval);
            case 2 -> calculateNextWeekDay(p.getRepeatOnDayVal(), from, interval);
            case 3 -> from.plusMonths(interval);
            case 4 -> from.plusYears(interval);
            default -> from.plusMonths(1);
        };
    }

    /**
     * [5.1] Tính endDate từ endDateOption.
     * - FOREVER    → null (lặp mãi mãi)
     * - UNTIL_DATE → endDateValue (ngày cụ thể)
     * - COUNT      → tính từ beginDate + interval * (count - 1)
     */
    private LocalDate calculateEndDate(PlannedTransactionRequest req) {
        return switch (req.endDateOption()) {
            case "FOREVER"    -> null;
            case "UNTIL_DATE" -> req.endDateValue();
            case "COUNT"      -> calculateEndDateByCount(req);
            default           -> throw new IllegalArgumentException(
                    "endDateOption không hợp lệ: " + req.endDateOption());
        };
    }

    /**
     * [5.2] Tính endDate khi user chọn "Lặp X lần".
     *
     * Dùng (count - 1) vì begin_date đã tính là lần chạy thứ 1.
     * Ví dụ: count=3, daily, start=14/03
     *   → endDate = 14 + (3-1)*1 = 16/03
     *   → Scheduler chạy: 14, 15, 16 → nextDue=17 > 16 → active=false ✅
     */
    private LocalDate calculateEndDateByCount(PlannedTransactionRequest req) {
        int count    = req.repeatCount()    != null ? req.repeatCount()    : 1;
        int interval = req.repeatInterval() != null ? req.repeatInterval() : 1;
        int remaining = Math.max(count - 1, 0); // begin_date tính là lần 1 rồi
        LocalDate start = req.beginDate();

        return switch (req.repeatType()) {
            case 1 -> start.plusDays((long)   interval * remaining);
            case 2 -> start.plusWeeks((long)  interval * remaining);
            case 3 -> start.plusMonths((long) interval * remaining);
            case 4 -> start.plusYears((long)  interval * remaining);
            default -> throw new IllegalArgumentException(
                    "repeatType không hợp lệ: " + req.repeatType());
        };
    }

    /**
     * [5.3] Tính ngày kế tiếp trong tuần theo bitmask, hỗ trợ intervalWeeks > 1.
     *
     * Logic:
     *   Bước 1 — Tìm ngày hợp lệ còn lại trong TUẦN HIỆN TẠI.
     *   Bước 2 — Nếu không còn → nhảy sang đầu tuần (intervalWeeks) tuần sau.
     *
     * Ví dụ: mỗi 2 tuần, bitmask = T2+T4, from = 18/03 (Wed)
     *   → Không còn ngày hợp lệ tuần này (T2 và T4 đã qua)
     *   → Nhảy sang Mon 30/03 (2 tuần sau) → tìm T2=30/03 ✅
     */
    private LocalDate calculateNextWeekDay(Integer bitmask, LocalDate from, int intervalWeeks) {
        if (bitmask == null || bitmask == 0) return from.plusWeeks(intervalWeeks);

        // ✅ Dùng RepeatDayBitmask util thay vì inline magic numbers
        // Map DayOfWeek Java (MON=1..SUN=7) → bitmask project
        int[] javaToMask = {0,
                RepeatDayBitmask.MONDAY, RepeatDayBitmask.TUESDAY,
                RepeatDayBitmask.WEDNESDAY, RepeatDayBitmask.THURSDAY,
                RepeatDayBitmask.FRIDAY, RepeatDayBitmask.SATURDAY,
                RepeatDayBitmask.SUNDAY};

        // Bước 1: Tìm ngày hợp lệ còn lại trong tuần hiện tại (tối đa 6 ngày)
        for (int offset = 1; offset <= 6; offset++) {
            LocalDate candidate = from.plusDays(offset);
            if (candidate.getDayOfWeek() == DayOfWeek.MONDAY && offset > 1) break; // Đã sang tuần mới
            int mask = javaToMask[candidate.getDayOfWeek().getValue()];
            if ((bitmask & mask) != 0) return candidate;
        }

        // Bước 2: Không còn ngày nào tuần này → nhảy sang đầu tuần của intervalWeeks tuần sau
        LocalDate startOfNextCycle = from.plusWeeks(intervalWeeks).with(DayOfWeek.MONDAY);
        for (int offset = 0; offset < 7; offset++) {
            LocalDate candidate = startOfNextCycle.plusDays(offset);
            int mask = javaToMask[candidate.getDayOfWeek().getValue()];
            if ((bitmask & mask) != 0) return candidate;
        }

        return from.plusWeeks(intervalWeeks); // Fallback
    }

    // ════════════════════════════════════════════════════════════════════════
    // 6. TẠO TRANSACTION + CẬP NHẬT SỐ DƯ + RECALCULATE DEBT
    // ════════════════════════════════════════════════════════════════════════

    /**
     * [6.1] Tạo Transaction từ PlannedTransaction.
     * Được gọi bởi:
     *   - PlannedTransactionScheduler.processRecurring() — tự động hàng ngày
     *   - payBill() — user bấm "Trả tiền"
     *
     * Bước 1 — Tạo và lưu Transaction.
     * Bước 2 — Cập nhật số dư ví (wallet.balance).
     * Bước 3 — Recalculate debt nếu planned có liên kết debt.
     */
    public void createTransactionFromPlanned(PlannedTransaction planned) {
        boolean isIncome = Boolean.TRUE.equals(planned.getCategory().getCtgType()); // true=Thu, false=Chi

        // Bước 1: Kiểm tra số dư ví TRƯỚC khi tạo transaction (tránh lưu rồi rollback)
        // Chỉ áp dụng cho CHI tiêu (isIncome=false) — Thu nhập không cần check
        // Caller (Scheduler / payBill) sẽ xử lý exception này theo cách riêng:
        //   - Scheduler:  pre-check tại Bước 4 trong processRecurring() → sẽ không tới đây nếu balance không đủ
        //   - payBill():  exception propagate lên → Spring rollback → frontend nhận 400 Bad Request
        Wallet wallet = planned.getWallet();
        if (!isIncome && wallet.getBalance().compareTo(planned.getAmount()) < 0) {
            throw new IllegalArgumentException(
                    "Ví '" + wallet.getWalletName() + "' hiện có "
                    + wallet.getBalance().toPlainString()
                    + " không đủ để thực hiện giao dịch "
                    + planned.getAmount().toPlainString());
        }

        // Bước 2: Tạo và lưu Transaction (số dư đã được kiểm tra ở Bước 1)
        Transaction transaction = Transaction.builder()
                .account(planned.getAccount())
                .wallet(planned.getWallet())
                .category(planned.getCategory())
                .debt(planned.getDebt())
                .plannedTransaction(planned) // Link FK planned_id để tracking nguồn gốc
                .amount(planned.getAmount())
                .note(planned.getNote() != null
                        ? planned.getNote()
                        : planned.getCategory().getCtgName())
                .transDate(LocalDateTime.now())
                .reportable(true)
                .sourceType(TransactionSourceType.PLANNED.getValue()) // sourceType=5 (PLANNED)
                .build();
        transactionRepo.save(transaction);

        // Bước 3: Cập nhật số dư ví
        // Thu (isIncome=true)  → cộng vào balance
        // Chi (isIncome=false) → trừ ra khỏi balance (đã kiểm tra >= 0 ở Bước 1)
        wallet.setBalance(isIncome
                ? wallet.getBalance().add(planned.getAmount())
                : wallet.getBalance().subtract(planned.getAmount()));
        walletRepo.save(wallet);

        // Bước 4: Recalculate debt nếu planned có liên kết khoản nợ
        // (cập nhật remainAmount, finished flag trong tDebts)
        if (planned.getDebt() != null) {
            debtCalculationService.recalculateDebt(
                    planned.getDebt().getId(),
                    planned.getAccount()
            );
        }
    }

    /**
     * [6.2] Tính lại trạng thái khoản nợ sau mỗi transaction định kỳ.
     *
     * Bước 1 — Tính totalAmount từ Cho vay + Đi vay.
     * Bước 2 — Tính paidAmount từ Thu nợ + Trả nợ.
     * Bước 3 — Cập nhật total, remain.
     * Bước 4 — Nếu remainAmount <= 0 → finished=true,
     *           deactivate tất cả planned liên kết,
     *           gửi thông báo debtFullyPaid.
     */
    // ĐÃ TÁCH tính nợ sang file DebtCalculationServiceImpl
}
