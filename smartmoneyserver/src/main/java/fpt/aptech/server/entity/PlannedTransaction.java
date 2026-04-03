package fpt.aptech.server.entity;

import jakarta.persistence.*;
import lombok.*;
import org.hibernate.annotations.CreationTimestamp;

import java.math.BigDecimal;
import java.time.LocalDate;
import java.time.LocalDateTime;

/**
 * Bảng giao dịch định kỳ / hóa đơn.
 * plan_type=1: Bill (hóa đơn, số tiền thay đổi, user duyệt tay)
 * plan_type=2: Recurring (định kỳ cố định, Scheduler tự tạo Transaction)
 */
@Entity
@Table(name = "tPlannedTransactions")
@Getter
@Setter
@NoArgsConstructor
@AllArgsConstructor
@Builder
public class PlannedTransaction {

    @Id
    @GeneratedValue(strategy = GenerationType.IDENTITY)
    private Integer id;

    @ManyToOne(fetch = FetchType.LAZY)
    @JoinColumn(name = "acc_id", nullable = false)
    private Account account;

    @ManyToOne(fetch = FetchType.LAZY)
    @JoinColumn(name = "wallet_id", nullable = false)
    private Wallet wallet;

    @ManyToOne(fetch = FetchType.LAZY)
    @JoinColumn(name = "ctg_id", nullable = false)
    private Category category;

    // NULL nếu không liên quan đến nợ
    // Chỉ điền khi ctg là: Cho vay(19), Đi vay(20), Thu nợ(21), Trả nợ(22)
    // ⚠️ EAGER load để tránh LazyInitializationException trong toggle/view operations
    @ManyToOne(fetch = FetchType.EAGER)
    @JoinColumn(name = "debt_id")
    private Debt debt;

    @Column(name = "note", length = 500)
    private String note;

    @Column(name = "amount", nullable = false, precision = 18, scale = 2)
    private BigDecimal amount;

    // 1: Bill (duyệt tay) | 2: Recurring (tự động)
    @Column(name = "plan_type", nullable = false)
    private Integer planType;

    // 0: Không lặp | 1: Ngày | 2: Tuần | 3: Tháng | 4: Năm
    @Column(name = "repeat_type", nullable = false)
    private Integer repeatType;

    // Mỗi bao nhiêu ngày/tuần/tháng/năm
    @Column(name = "repeat_interval", nullable = false)
    @Builder.Default
    private Integer repeatInterval = 1;

    // Bitmask ngày trong tuần (repeat_type=2): CN=1,T2=2,T3=4,T4=8,T5=16,T6=32,T7=64
    @Column(name = "repeat_on_day_val")
    private Integer repeatOnDayVal;

    @Column(name = "begin_date", nullable = false)
    private LocalDate beginDate;

    // Scheduler quét cột này để biết khi nào cần xử lý
    @Column(name = "next_due_date", nullable = false)
    private LocalDate nextDueDate;

    // Ngày thực hiện gần nhất (tránh duyệt trùng kỳ)
    @Column(name = "last_executed_at")
    private LocalDate lastExecutedAt;

    // NULL = lặp mãi mãi
    @Column(name = "end_date")
    private LocalDate endDate;

    // 1: Đang áp dụng | 0: Đã kết thúc
    @Column(name = "active", nullable = false)
    @Builder.Default
    private Boolean active = true;

    @CreationTimestamp
    @Column(name = "created_at", nullable = false, updatable = false)
    private LocalDateTime createdAt;
}