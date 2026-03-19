package fpt.aptech.server.service.planned;

import fpt.aptech.server.dto.planned.PlannedTransactionRequest;
import fpt.aptech.server.dto.planned.PlannedTransactionResponse;
import fpt.aptech.server.entity.*;
import fpt.aptech.server.enums.category.SystemCategory;
import fpt.aptech.server.enums.notification.NotificationType;
import fpt.aptech.server.enums.transaction.TransactionSourceType;
import fpt.aptech.server.mapper.planned.PlannedTransactionMapper;
import fpt.aptech.server.repos.*;
import fpt.aptech.server.service.debt.DebtCalculationService;
import fpt.aptech.server.service.notification.NotificationContent;
import fpt.aptech.server.service.notification.NotificationMessages;
import fpt.aptech.server.service.notification.NotificationService;
import lombok.RequiredArgsConstructor;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

import java.math.BigDecimal;
import java.time.DayOfWeek;
import java.time.LocalDate;
import java.time.LocalDateTime;
import java.util.List;
import java.util.Set;

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
    private final DebtCalculationService debtCalculationService;

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
     * [1.5] Xóa Recurring — các Transaction đã tạo ra KHÔNG bị xóa.
     */
    @Override
    @Transactional
    public void deleteRecurring(Integer id, Integer userId) {
        plannedRepo.delete(getOwnedPlanned(id, userId));
    }

    /**
     * [1.6] Toggle active của Recurring.
     * Không cho kích hoạt lại nếu Debt liên kết đã finished.
     */
    @Override
    @Transactional
    public PlannedTransactionResponse toggleRecurring(Integer id, Integer userId) {
        PlannedTransaction planned = getOwnedPlanned(id, userId);

        // Không cho reactivate nếu khoản nợ đã trả xong
        if (!planned.getActive()
                && planned.getDebt() != null
                && Boolean.TRUE.equals(planned.getDebt().getFinished())) {
            throw new IllegalStateException(
                    "Khoản nợ đã thanh toán xong, không thể kích hoạt lại");
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
     * [2.5] Xóa Bill — các Transaction đã tạo ra KHÔNG bị xóa.
     */
    @Override
    @Transactional
    public void deleteBill(Integer id, Integer userId) {
        plannedRepo.delete(getOwnedPlanned(id, userId));
    }

    /**
     * [2.6] User bấm "Trả tiền" → Tạo Transaction từ Bill.
     * Bước 1 — Validate: chỉ Bill (plan_type=1) mới cần duyệt tay.
     * Bước 2 — Tạo Transaction + cập nhật số dư ví + recalculate debt.
     * Bước 3 — Cập nhật last_executed_at + next_due_date.
     * Bước 4 — Kiểm tra hết hạn → active=false.
     */
    @Override
    @Transactional
    public PlannedTransactionResponse payBill(Integer id, Integer userId) {
        PlannedTransaction planned = getOwnedPlanned(id, userId);

        // Bước 1: Validate loại
        if (planned.getPlanType() != 1) {
            throw new IllegalArgumentException("Chỉ hóa đơn mới cần duyệt tay");
        }

        // Bước 2: Tạo Transaction
        createTransactionFromPlanned(planned);

        // Bước 3: Cập nhật lịch
        LocalDate today   = LocalDate.now();
        LocalDate nextDue = calculateNextDueDate(planned, today);
        planned.setLastExecutedAt(today);
        planned.setNextDueDate(nextDue);

        // Bước 4: Kiểm tra hết hạn
        if (planned.getEndDate() != null && nextDue.isAfter(planned.getEndDate())) {
            planned.setActive(false);
        }

        return mapper.toDto(plannedRepo.save(planned));
    }

    /**
     * [2.7] Toggle active của Bill (đánh dấu hoàn tất / chưa hoàn tất).
     */
    @Override
    @Transactional
    public PlannedTransactionResponse toggleBill(Integer id, Integer userId) {
        PlannedTransaction planned = getOwnedPlanned(id, userId);
        planned.setActive(!planned.getActive());
        return mapper.toDto(plannedRepo.save(planned));
    }

    // ════════════════════════════════════════════════════════════════════════
    // 3. HELPER DÙNG CHUNG
    // ════════════════════════════════════════════════════════════════════════

    /**
     * [3.1] Tìm PlannedTransaction và kiểm tra quyền sở hữu.
     */
    private PlannedTransaction getOwnedPlanned(Integer id, Integer userId) {
        return plannedRepo.findByIdAndAccount_Id(id, userId)
                .orElseThrow(() -> new IllegalArgumentException(
                        "Không tìm thấy giao dịch định kỳ"));
    }

    /**
     * [3.2] Xây dựng PlannedTransaction mới từ Request.
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

        // Bước 1.4: Validate Debt (chỉ khi category là nợ/vay)
        Debt debt = null;
        if (DEBT_CATEGORY_IDS.contains(req.categoryId()) && req.debtId() != null) {
            debt = debtRepo.findById(req.debtId())
                    .orElseThrow(() -> new IllegalArgumentException("Khoản nợ không tồn tại"));
            if (!debt.getAccount().getId().equals(userId)) {
                throw new SecurityException("Không có quyền sử dụng khoản nợ này");
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
     * [3.3] Cập nhật các trường của PlannedTransaction khi edit.
     * KHÔNG đụng đến các Transaction đã tạo trước đó.
     */
    private void updatePlannedFields(PlannedTransaction planned,
                                     PlannedTransactionRequest req,
                                     Integer userId) {
        // Validate Wallet
        Wallet wallet = walletRepo.findById(req.walletId())
                .orElseThrow(() -> new IllegalArgumentException("Ví không tồn tại"));
        if (!wallet.getAccount().getId().equals(userId)) {
            throw new SecurityException("Không có quyền sử dụng ví này");
        }

        // Validate Category
        Category category = categoryRepo.findById(req.categoryId())
                .orElseThrow(() -> new IllegalArgumentException("Danh mục không tồn tại"));

        planned.setWallet(wallet);
        planned.setCategory(category);
        planned.setAmount(req.amount());
        planned.setNote(req.note());
        planned.setRepeatType(req.repeatType());
        planned.setRepeatInterval(req.repeatInterval() != null ? req.repeatInterval() : 1);
        planned.setRepeatOnDayVal(req.repeatOnDayVal());
        planned.setBeginDate(req.beginDate());
        planned.setEndDate(calculateEndDate(req));

        // FIX: Reset next_due_date nếu beginDate đổi sang tương lai
        // → Tránh Scheduler fire ngay hôm nay dù user muốn bắt đầu sau
        if (req.beginDate().isAfter(LocalDate.now())) {
            planned.setNextDueDate(req.beginDate());
        }
    }

    // ════════════════════════════════════════════════════════════════════════
    // 4. TÍNH TOÁN LỊCH LẶP
    // ════════════════════════════════════════════════════════════════════════

    /**
     * [4.1] Tính endDate từ endDateOption.
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
     * [4.2] Tính endDate khi user chọn "Lặp X lần".
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
     * [4.3] Tính next_due_date sau khi Scheduler chạy xong 1 kỳ.
     * Được gọi bởi: Scheduler (processRecurring, processBill) và payBill().
     */
    public LocalDate calculateNextDueDate(PlannedTransaction p, LocalDate from) {
        int interval = p.getRepeatInterval() != null ? p.getRepeatInterval() : 1;

        return switch (p.getRepeatType()) {
            case 1 -> from.plusDays(interval);
            case 2 -> calculateNextWeekDay(p.getRepeatOnDayVal(), from, interval);
            case 3 -> from.plusMonths(interval);
            case 4 -> from.plusYears(interval);
            default -> from.plusMonths(1); // Fallback an toàn
        };
    }

    /**
     * [4.4] Tính ngày kế tiếp trong tuần theo bitmask, hỗ trợ intervalWeeks > 1.
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

        // Map DayOfWeek Java (MON=1..SUN=7) → bitmask project (CN=1, T2=2, T3=4, T4=8, T5=16, T6=32, T7=64)
        int[] javaToMask = {0, 2, 4, 8, 16, 32, 64, 1}; // index 0 unused

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
    // 5. TẠO TRANSACTION + CẬP NHẬT SỐ DƯ + RECALCULATE DEBT
    // ════════════════════════════════════════════════════════════════════════

    /**
     * [5.1] Tạo Transaction từ PlannedTransaction.
     * Được gọi bởi:
     *   - PlannedTransactionScheduler.processRecurring() — tự động hàng ngày
     *   - payBill() — user bấm "Trả tiền"
     *
     * Bước 1 — Tạo và lưu Transaction.
     * Bước 2 — Cập nhật số dư ví (wallet.balance).
     * Bước 3 — Recalculate debt nếu planned có liên kết debt.
     */
    public void createTransactionFromPlanned(PlannedTransaction planned) {
        boolean isIncome = Boolean.TRUE.equals(planned.getCategory().getCtgType());

        // Bước 1: Tạo Transaction
        Transaction transaction = Transaction.builder()
                .account(planned.getAccount())
                .wallet(planned.getWallet())
                .category(planned.getCategory())
                .debt(planned.getDebt())
                .amount(planned.getAmount())
                .note(planned.getNote() != null
                        ? planned.getNote()
                        : planned.getCategory().getCtgName())
                .transDate(LocalDateTime.now())
                .reportable(true)
                .sourceType(TransactionSourceType.PLANNED.getValue())
                .build();
        transactionRepo.save(transaction);

        // Bước 2: Cập nhật số dư ví
        Wallet wallet = planned.getWallet();
        wallet.setBalance(isIncome
                ? wallet.getBalance().add(planned.getAmount())
                : wallet.getBalance().subtract(planned.getAmount()));
        walletRepo.save(wallet);

        // Bước 3: Recalculate debt nếu có
        if (planned.getDebt() != null) {
            debtCalculationService.recalculateDebt(
                    planned.getDebt().getId(),
                    planned.getAccount()
            );
        }
    }

    /**
     * [5.2] Tính lại trạng thái khoản nợ sau mỗi transaction định kỳ.
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