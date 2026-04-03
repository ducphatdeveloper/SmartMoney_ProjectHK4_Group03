package fpt.aptech.server.service.event;

import fpt.aptech.server.dto.event.EventCreateRequest;
import fpt.aptech.server.dto.event.EventResponse;
import fpt.aptech.server.dto.event.EventUpdateRequest;
import fpt.aptech.server.dto.transaction.report.TransactionTotalDTO;
import fpt.aptech.server.dto.transaction.view.DailyTransactionGroup;
import fpt.aptech.server.dto.transaction.view.TransactionResponse;
import fpt.aptech.server.entity.*;
import fpt.aptech.server.entity.Currency;
import fpt.aptech.server.enums.notification.NotificationType;
import fpt.aptech.server.mapper.event.EventMapper;
import fpt.aptech.server.mapper.transaction.TransactionMapper;
import fpt.aptech.server.repos.*;
import fpt.aptech.server.service.notification.NotificationContent;
import fpt.aptech.server.service.notification.NotificationMessages;
import fpt.aptech.server.service.notification.NotificationService;
import fpt.aptech.server.utils.date.DateUtils;
import lombok.RequiredArgsConstructor;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

import java.math.BigDecimal;
import java.time.LocalDate;
import java.util.*;
import java.util.stream.Collectors;

@Service
@RequiredArgsConstructor
public class EventServiceImpl implements EventService {

    private final EventRepository       eventRepository;
    private final TransactionRepository transactionRepository;
    private final AccountRepository     accountRepository;
    private final CurrencyRepository    currencyRepository;
    private final EventMapper           eventMapper;
    private final TransactionMapper     transactionMapper;
    private final NotificationService   notificationService; // Inject để gửi thông báo hoàn thành sự kiện

    // =================================================================================
    // 1. LẤY DANH SÁCH & CHI TIẾT (READ)
    // =================================================================================

    /**
     * [1.1] Lấy danh sách sự kiện theo trạng thái finished (true/false).
     * Kèm theo tổng thu/chi của từng sự kiện.
     */
    @Override
    @Transactional(readOnly = true)
    public List<EventResponse> getEvents(Integer accId, Boolean isFinished) {
        return eventRepository.findAllByAccountIdAndFinished(accId, isFinished)
                .stream()
                .map(this::mapToResponseWithTotals)
                .collect(Collectors.toList());
    }

    /**
     * [1.2] Lấy chi tiết một sự kiện theo ID + kiểm tra quyền sở hữu.
     */
    @Override
    @Transactional(readOnly = true)
    public EventResponse getEvent(Integer eventId, Integer accId) {
        return mapToResponseWithTotals(getOwnedEvent(eventId, accId));
    }

    /**
     * [1.3] Lấy danh sách giao dịch thuộc sự kiện (flat list).
     */
    @Override
    @Transactional(readOnly = true)
    public List<TransactionResponse> getEventTransactions(Integer eventId, Integer accId) {
        getOwnedEvent(eventId, accId); // Kiểm tra quyền
        return transactionMapper.toDtoList(
                transactionRepository.findAllByEventId(eventId));
    }

    /**
     * [1.4] Lấy danh sách giao dịch thuộc sự kiện, đã gom nhóm theo ngày.
     * Dùng cho màn hình chi tiết sự kiện — hiển thị theo timeline.
     */
    @Override
    @Transactional(readOnly = true)
    public List<DailyTransactionGroup> getEventTransactionsGrouped(Integer eventId, Integer accId) {
        getOwnedEvent(eventId, accId); // Kiểm tra quyền
        List<Transaction> transactions = transactionRepository.findAllByEventId(eventId);

        // Gom nhóm theo ngày
        Map<LocalDate, List<Transaction>> groupedByDate = transactions.stream()
                .collect(Collectors.groupingBy(t -> t.getTransDate().toLocalDate()));

        return groupedByDate.entrySet().stream()
                .map(entry -> {
                    LocalDate date = entry.getKey();
                    List<Transaction> transInDay = entry.getValue();

                    // Tính thu/chi ròng của ngày đó
                    BigDecimal netAmount = transInDay.stream()
                            .map(t -> Boolean.TRUE.equals(t.getCategory().getCtgType())
                                    ? t.getAmount()
                                    : t.getAmount().negate())
                            .reduce(BigDecimal.ZERO, BigDecimal::add);

                    return DailyTransactionGroup.builder()
                            .date(date)
                            .displayDateLabel(DateUtils.formatDisplayDate(date))
                            .netAmount(netAmount)
                            .transactions(transactionMapper.toDtoList(transInDay))
                            .build();
                })
                .sorted(Comparator.comparing(DailyTransactionGroup::date).reversed())
                .collect(Collectors.toList());
    }

    // =================================================================================
    // 2. TẠO & CẬP NHẬT (CREATE / UPDATE)
    // =================================================================================

    /**
     * [2.1] Tạo sự kiện mới.
     * Bước 1 — Validate tài khoản và tiền tệ.
     * Bước 2 — Tạo và lưu Event.
     */
    @Override
    @Transactional
    public EventResponse createEvent(EventCreateRequest request, Integer accId) {
        // Bước 1: Validate
        Account account = accountRepository.findById(accId)
                .orElseThrow(() -> new IllegalArgumentException("Tài khoản không tồn tại."));
        Currency currency = currencyRepository.findById(request.currencyCode())
                .orElseThrow(() -> new IllegalArgumentException("Loại tiền tệ không tồn tại."));

        // Bước 2: Tạo Event
        Event event = eventMapper.fromCreateRequest(request);
        event.setAccount(account);
        event.setCurrency(currency);
        event.setFinished(false); // Mặc định là chưa hoàn thành

        return mapToResponseWithTotals(eventRepository.save(event));
    }

    /**
     * [2.2] Cập nhật thông tin sự kiện (tên, ngày, ngân sách...).
     */
    @Override
    @Transactional
    public EventResponse updateEvent(Integer eventId, EventUpdateRequest request, Integer accId) {
        Event event = getOwnedEvent(eventId, accId);

        Currency currency = currencyRepository.findById(request.currencyCode())
                .orElseThrow(() -> new IllegalArgumentException("Loại tiền tệ không tồn tại."));

        eventMapper.updateFromUpdateRequest(request, event);
        event.setCurrency(currency);

        return mapToResponseWithTotals(eventRepository.save(event));
    }

    /**
     * [2.3] Toggle trạng thái finished của sự kiện.
     * Dùng cho nút "Đánh dấu hoàn tất" / "Đánh dấu chưa hoàn tất".
     * → Khi chuyển sang finished=true: gửi thông báo hoàn thành kèm tổng chi tiêu.
     */
    @Override
    @Transactional
    public EventResponse updateEventStatus(Integer eventId, Integer accId) {
        Event event = getOwnedEvent(eventId, accId);
        boolean wasFinished = Boolean.TRUE.equals(event.getFinished());

        // Toggle trạng thái
        event.setFinished(!wasFinished);
        Event updated = eventRepository.save(event);

        // Nếu vừa chuyển từ false → true (vừa hoàn thành)
        if (!wasFinished && Boolean.TRUE.equals(updated.getFinished())) {
            // Tính tổng chi tiêu của sự kiện để đưa vào thông báo
            TransactionTotalDTO totals = transactionRepository.getTotalsByEventId(eventId);
            BigDecimal totalSpent = totals.totalExpense();

            NotificationContent msg = NotificationMessages.eventCompleted(
                    event.getEventName(), totalSpent);
            notificationService.createNotification(
                    event.getAccount(),
                    msg.title(), msg.content(),
                    NotificationType.EVENTS,
                    Long.valueOf(eventId),
                    null
            );
        }

        return mapToResponseWithTotals(updated);
    }

    // =================================================================================
    // 3. XÓA (DELETE)
    // =================================================================================

    /**
     * [3.1] Xóa mềm sự kiện.
     * Chỉ xóa mềm chính sự kiện — KHÔNG cascade xóa mềm giao dịch.
     * Giao dịch thuộc sự kiện được giữ lại (set event_id = null để cắt liên kết).
     *
     * Nguyên tắc thiết kế:
     *   - Chỉ Wallet / SavingGoal (nguồn tiền) mới cascade xóa mềm Transaction.
     *   - Event / Debt / Planned khi bị xóa chỉ xóa mềm chính nó + cắt FK liên kết.
     *   - Hoàn tiền (nếu cần) được xử lý ở TransactionServiceImpl.deleteTransaction().
     */
    @Override
    @Transactional
    public void deleteEvent(Integer eventId, Integer accId) {
        Event event = getOwnedEvent(eventId, accId);

        // Cắt liên kết: set event_id = null trên các giao dịch (KHÔNG xóa mềm transaction)
        transactionRepository.setEventIdToNullByEventId(eventId);

        // Soft delete sự kiện
        event.setDeleted(true);
        event.setDeletedAt(java.time.LocalDateTime.now());
        eventRepository.save(event);
    }

    // =================================================================================
    // 4. PRIVATE HELPERS
    // =================================================================================

    /**
     * [4.1] Tìm sự kiện và kiểm tra quyền sở hữu.
     * Ném SecurityException nếu không phải của user này.
     */
    private Event getOwnedEvent(Integer eventId, Integer accId) {
        Event event = eventRepository.findById(eventId)
                .orElseThrow(() -> new IllegalArgumentException(
                        "Sự kiện không tồn tại với ID: " + eventId));

        if (!event.getAccount().getId().equals(accId)) {
            throw new SecurityException("Bạn không có quyền truy cập sự kiện này.");
        }
        return event;
    }

    /**
     * [4.2] Map Event → EventResponse, kèm tổng thu/chi tính từ DB.
     */
    private EventResponse mapToResponseWithTotals(Event event) {
        // Tính tổng thu và tổng chi từ tất cả giao dịch thuộc sự kiện
        TransactionTotalDTO totals = transactionRepository.getTotalsByEventId(event.getId());

        BigDecimal totalIncome  = totals.totalIncome();
        BigDecimal totalExpense = totals.totalExpense();
        BigDecimal netAmount    = totalIncome.subtract(totalExpense);

        return eventMapper.toResponse(event).toBuilder()
                .totalIncome(totalIncome)
                .totalExpense(totalExpense)
                .netAmount(netAmount)
                .build();
    }
}