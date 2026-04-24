package fpt.aptech.server.scheduler.event;

import fpt.aptech.server.dto.transaction.report.TransactionTotalDTO;
import fpt.aptech.server.entity.Event;
import fpt.aptech.server.enums.notification.NotificationType;
import fpt.aptech.server.repos.EventRepository;
import fpt.aptech.server.repos.TransactionRepository;
import fpt.aptech.server.service.notification.NotificationContent;
import fpt.aptech.server.service.notification.NotificationMessages;
import fpt.aptech.server.service.notification.NotificationService;
import lombok.RequiredArgsConstructor;
import lombok.extern.slf4j.Slf4j;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.context.annotation.Lazy;
import org.springframework.scheduling.annotation.Scheduled;
import org.springframework.stereotype.Component;
import org.springframework.transaction.annotation.Propagation;
import org.springframework.transaction.annotation.Transactional;

import java.math.BigDecimal;
import java.time.LocalDate;
import java.util.List;

/**
 * Scheduler quản lý thông báo sự kiện.
 *
 * ─── LỊCH CHẠY (CRON) ──────────────────────────────────────────────────
 *   JOB 1 — remindUpcomingEvents():  8:00 AM mỗi ngày → Nhắc sự kiện sắp tới (còn 7 ngày)
 *   JOB 2 — autoCompleteEvents():    1:00 AM mỗi ngày → Auto-complete sự kiện quá hạn
 * ────────────────────────────────────────────────────────────────────────
 * Lý do phân khung giờ:
 *   - 1h sáng: Xử lý nền (auto-complete) khi hệ thống ít tải
 *   - 8h sáng: Nhắc nhở sự kiện khi user mở app buổi sáng
 *
 * Thông báo được tạo ra (tất cả gọi từ NotificationMessages):
 *
 *   1. eventReminder()       → "Sự kiện sắp tới 📅" — còn 7 ngày nữa (JOB 1)
 *      Content: "Sự kiện sắp tới 📅: Sự kiện 'Sinh nhật bạn thân' sẽ diễn ra sau 7 ngày (10/05/2026). Hãy chuẩn bị quà tặng 500.000 ₫."
 *
 *   2. eventAutoCompleted()  → "Sự kiện đã kết thúc tự động ✅" — scheduler auto-complete (JOB 2)
 *      Content: "Sự kiện đã kết thúc tự động ✅: Sự kiện 'Sinh nhật bạn thân' đã kết thúc. Tổng chi tiêu: 450.000 ₫ (đã chi 450.000 ₫ / dự kiến 500.000 ₫)."
 *
 * ⚠️ PHÂN BIỆT VỚI EventServiceImpl:
 *   - eventCompleted() (trong EventServiceImpl) → user bấm thủ công hoàn thành → Title="Sự kiện đã kết thúc ✅"
 *   - eventAutoCompleted() (trong Scheduler)    → hệ thống tự auto-complete  → Title="Sự kiện đã kết thúc tự động ✅"
 *   Scheduler chỉ auto-complete event chưa có finished=true. ServiceImpl chỉ gọi khi user thao tác thủ công.
 *   Không trùng nhau vì Scheduler query findOverdueUnfinishedEvents(finished=false).
 *
 * Bảo mật: Mỗi thông báo gắn event.getAccount() → chỉ chủ sở hữu sự kiện nhận được.
 * NotificationType: EVENTS (7), related_id = event.id
 */
@Slf4j
@Component
@RequiredArgsConstructor
public class EventScheduler {

    // Self-injection để dùng @Transactional(REQUIRES_NEW) cho từng event riêng biệt
    @Autowired
    @Lazy
    private EventScheduler self;

    private final EventRepository eventRepository;
    private final TransactionRepository transactionRepository;
    private final NotificationService notificationService;

    // Nhắc trước khi sự kiện kết thúc bao nhiêu ngày
    private static final int REMIND_DAYS = 7;

    // ══════════════════════════════════════════════════════════════════════
    // JOB 1 — Nhắc sự kiện sắp tới (8:00 AM mỗi ngày)
    // Lý do 8h sáng: Nhắc nhở khi user mở app buổi sáng,
    // cùng khung giờ với BudgetScheduler.checkBudgets(), DebtScheduler.checkDebtReminders(),
    // SavingGoalScheduler.remindNearDeadlineGoals().
    // ══════════════════════════════════════════════════════════════════════

    /**
     * Quét sự kiện chưa kết thúc có endDate = today + 7 ngày.
     * Chỉ nhắc đúng mốc 7 ngày để tránh nhắc lặp mỗi ngày.
     */
    @Scheduled(cron = "0 0 8 * * ?") // 8:00 AM mỗi ngày
    public void remindUpcomingEvents() {
        LocalDate today = LocalDate.now();
        LocalDate targetDate = today.plusDays(REMIND_DAYS); // Mốc: today + 7 ngày

        log.info("[EventScheduler] Kiểm tra sự kiện sắp tới (endDate = {})...", targetDate);

        // Bước 1: Tìm tất cả sự kiện chưa kết thúc có endDate = today + 7
        List<Event> upcomingEvents = eventRepository.findActiveEventsByEndDate(targetDate);

        // Bước 2: Nếu không có → log và return
        if (upcomingEvents.isEmpty()) {
            log.info("[EventScheduler] Không có sự kiện nào cần nhắc.");
            return;
        }

        // Bước 3: Gửi thông báo cho từng sự kiện
        int count = 0;
        for (Event event : upcomingEvents) {
            try {
                self.notifyUpcomingEvent(event, REMIND_DAYS, targetDate); // self-injection cho @Transactional
                count++;
            } catch (Exception e) {
                log.error("[EventScheduler] Lỗi nhắc sự kiện id={}: {}", event.getId(), e.getMessage());
            }
        }

        log.info("[EventScheduler] Đã nhắc {} sự kiện sắp tới.", count);
    }

    /**
     * Gửi thông báo nhắc sự kiện sắp tới cho 1 sự kiện.
     *
     * → NotificationMessages.eventReminder()
     *   Thông báo tạo ra: Title="Sự kiện sắp tới 📅"
     *   Content="\"Sinh nhật 25 tuổi\" còn 7 ngày nữa (19/04/2026). Đừng quên lên kế hoạch!"
     *   (Nếu event có budget: thêm "Ngân sách dự kiến: 2.000.000 ₫.")
     *
     * Bảo mật: Dùng event.getAccount() → chỉ chủ sở hữu nhận được.
     */
    @Transactional(propagation = Propagation.REQUIRES_NEW)
    public void notifyUpcomingEvent(Event event, int daysLeft, LocalDate eventDate) {
        // Bước 1: Tạo nội dung thông báo (budget = null vì Event không có trường budget)
        NotificationContent msg = NotificationMessages.eventReminder(
                event.getEventName(), daysLeft, eventDate, null); // null = không hiển thị ngân sách

        // Bước 2: Gửi thông báo — gắn event.getAccount() để đảm bảo đúng người nhận
        notificationService.createNotification(
                event.getAccount(),                      // Bảo mật: chỉ chủ sự kiện nhận
                msg.title(), msg.content(),
                NotificationType.EVENTS,                 // type = 7 (EVENTS)
                Long.valueOf(event.getId()),              // related_id = event.id (để Flutter navigate)
                null                                      // scheduledTime = null → gửi ngay
        );

        log.info("[EventScheduler] Đã nhắc sự kiện id={} '{}' còn {} ngày.",
                event.getId(), event.getEventName(), daysLeft);
    }

    // ══════════════════════════════════════════════════════════════════════
    // JOB 2 — Tự động hoàn tất sự kiện quá hạn (1:00 AM mỗi ngày)
    // Lý do 1h sáng: Xử lý nền khi hệ thống ít tải,
    // cùng khung giờ với BudgetScheduler.renewRecurringBudgets(),
    // SavingGoalScheduler.checkOverdueGoals(), PlannedTransactionScheduler.processDailyPlanned().
    //
    // ⚠️ KHÔNG trùng với EventServiceImpl.updateEventStatus():
    //   - Scheduler: query event có finished=false VÀ endDate < today → auto-complete
    //   - ServiceImpl: user bấm thủ công → gọi eventCompleted() (khác method)
    // ══════════════════════════════════════════════════════════════════════

    /**
     * Quét sự kiện đã quá hạn (endDate < today AND finished=false).
     * Tự động đánh dấu hoàn thành + gửi thông báo kèm tổng chi tiêu.
     */
    @Scheduled(cron = "0 0 1 * * ?") // 1:00 AM mỗi ngày
    public void autoCompleteEvents() {
        LocalDate today = LocalDate.now();

        log.info("[EventScheduler] Kiểm tra sự kiện quá hạn cần auto-complete...");

        // Bước 1: Tìm sự kiện quá hạn chưa hoàn tất (endDate < today AND finished=false)
        List<Event> overdueEvents = eventRepository.findOverdueUnfinishedEvents(today);

        // Bước 2: Nếu không có → log và return
        if (overdueEvents.isEmpty()) {
            log.info("[EventScheduler] Không có sự kiện quá hạn.");
            return;
        }

        // Bước 3: Auto-complete từng sự kiện trong transaction riêng biệt
        int count = 0;
        for (Event event : overdueEvents) {
            try {
                self.autoCompleteEvent(event); // self-injection cho @Transactional(REQUIRES_NEW)
                count++;
            } catch (Exception e) {
                log.error("[EventScheduler] Lỗi auto-complete sự kiện id={}: {}", event.getId(), e.getMessage());
            }
        }

        log.info("[EventScheduler] Đã auto-complete {} sự kiện quá hạn.", count);
    }

    /**
     * Tự động hoàn tất 1 sự kiện quá hạn + gửi thông báo.
     *
     * → NotificationMessages.eventAutoCompleted()
     *   Thông báo tạo ra: Title="Sự kiện đã kết thúc tự động ✅"
     *   Content="Sự kiện \"Du lịch Đà Lạt\" đã hết hạn vào 10/04/2026 và được tự động kết thúc. Tổng chi tiêu: 8.500.000 ₫."
     *
     * ⚠️ Khác với eventCompleted() (user bấm thủ công):
     *   - eventAutoCompleted(): Title="Sự kiện đã kết thúc tự động ✅" — ghi rõ "tự động" + hiển thị endDate
     *   - eventCompleted():     Title="Sự kiện đã kết thúc ✅" — không ghi "tự động"
     *
     * Bảo mật: Dùng event.getAccount() → chỉ chủ sở hữu nhận được.
     */
    @Transactional(propagation = Propagation.REQUIRES_NEW)
    public void autoCompleteEvent(Event event) {
        // Bước 1: Đánh dấu sự kiện đã hoàn thành (finished = true)
        event.setFinished(true);
        eventRepository.save(event);

        // Bước 2: Tính tổng chi tiêu của sự kiện (từ các transaction liên kết)
        TransactionTotalDTO totals = transactionRepository.getTotalsByEventId(event.getId());
        BigDecimal totalSpent = totals.totalExpense(); // Tổng chi tiêu (chỉ lấy expense)

        // Bước 3: Tạo nội dung thông báo auto-complete — NotificationMessages.eventAutoCompleted()
        //   → Title="Sự kiện đã kết thúc tự động ✅"
        //   → Content="Sự kiện \"Du lịch Đà Lạt\" đã hết hạn vào 10/04/2026 và được tự động kết thúc. Tổng chi tiêu: 8.500.000 ₫."
        NotificationContent msg = NotificationMessages.eventAutoCompleted(
                event.getEventName(), event.getEndDate(), totalSpent);

        // Bước 4: Gửi thông báo — gắn event.getAccount() để đảm bảo đúng người nhận
        notificationService.createNotification(
                event.getAccount(),                      // Bảo mật: chỉ chủ sự kiện nhận
                msg.title(), msg.content(),
                NotificationType.EVENTS,                 // type = 7 (EVENTS)
                Long.valueOf(event.getId()),              // related_id = event.id (để Flutter navigate)
                null                                      // scheduledTime = null → gửi ngay
        );

        log.info("[EventScheduler] Auto-complete sự kiện id={} '{}', tổng chi: {}",
                event.getId(), event.getEventName(), totalSpent);
    }
}

