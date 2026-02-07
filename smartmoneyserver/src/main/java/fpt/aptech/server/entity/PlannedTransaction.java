package fpt.aptech.server.entity;

import jakarta.persistence.*;
import lombok.*;
import org.hibernate.annotations.CreationTimestamp;

import java.math.BigDecimal;
import java.time.LocalDate;
import java.time.LocalDateTime;

/**
 * Bảng giao dịch định kỳ và hóa đơn.
 * Dùng để tự động tạo giao dịch hoặc nhắc nhở người dùng.
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

    @ManyToOne(fetch = FetchType.LAZY)
    @JoinColumn(name = "currency_code", referencedColumnName = "currency_code", nullable = false)
    private Currency currency;

    @Column(name = "note", length = 500)
    private String note;

    @Column(name = "amount", nullable = false, precision = 18, scale = 2)
    private BigDecimal amount;

    // 1: Bill (cần duyệt), 2: Recurring (tự động)
    @Column(name = "plan_type", nullable = false)
    private Integer planType;

    // Loại giao dịch sẽ được tạo ra.
    @Column(name = "trans_type", nullable = false)
    private Integer transType;

    // 0: Không lặp, 1: Ngày, 2: Tuần, 3: Tháng, 4: Năm
    @Column(name = "repeat_type", nullable = false)
    private Integer repeatType;

    // Khoảng cách lặp (VD: mỗi 2 tuần)
    @Column(name = "repeat_interval", nullable = false)
    @Builder.Default
    private Integer repeatInterval = 1;

    // Giá trị ngày lặp (VD: bitmask cho ngày trong tuần)
    @Column(name = "repeat_on_day_val")
    private Integer repeatOnDayVal;

    @Column(name = "begin_date", nullable = false)
    private LocalDate beginDate;

    // Ngày đến hạn tiếp theo, dùng cho worker quét.
    @Column(name = "next_due_date", nullable = false)
    private LocalDate nextDueDate;

    // Ngày thực thi gần nhất để tránh lặp lại.
    @Column(name = "last_executed_at")
    private LocalDate lastExecutedAt;

    // NULL nếu lặp lại vô hạn.
    @Column(name = "end_date")
    private LocalDate endDate;

    // true: đang chạy, false: tạm dừng.
    @Column(name = "active", nullable = false)
    @Builder.Default
    private Boolean active = true;

    @CreationTimestamp
    @Column(name = "created_at", nullable = false, updatable = false)
    private LocalDateTime createdAt;
}