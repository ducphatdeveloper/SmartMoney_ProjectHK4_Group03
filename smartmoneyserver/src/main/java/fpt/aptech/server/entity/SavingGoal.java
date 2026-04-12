package fpt.aptech.server.entity;

import jakarta.persistence.*;
import lombok.*;
import org.hibernate.annotations.SQLRestriction;

import java.math.BigDecimal;
import java.time.LocalDate;
import java.time.LocalDateTime;

/**
 * Bảng mục tiêu tiết kiệm.
 * VD: "Mua iPhone 15", "Quỹ khẩn cấp".
 */
@Entity
@Table(name = "tSavingGoals")
@SQLRestriction("deleted = 0")
@Getter
@Setter
@NoArgsConstructor
@AllArgsConstructor
@Builder
public class SavingGoal {

    @Id
    @GeneratedValue(strategy = GenerationType.IDENTITY)
    private Integer id;

    @ManyToOne(fetch = FetchType.LAZY)
    @JoinColumn(name = "acc_id", nullable = false)
    private Account account;

    @ManyToOne(fetch = FetchType.LAZY)
    @JoinColumn(name = "currency", referencedColumnName = "currency_code", nullable = false)
    private Currency currency;

    @Column(name = "goal_name", nullable = false, length = 200)
    private String goalName;

    // Số tiền mục tiêu cần đạt.
    @Column(name = "target_amount", nullable = false, precision = 18, scale = 2)
    private BigDecimal targetAmount;

    // Số tiền đã tiết kiệm được.
    @Column(name = "current_amount", precision = 18, scale = 2)
    @Builder.Default
    private BigDecimal currentAmount = BigDecimal.ZERO;

    @Column(name = "goal_image_url", length = 2048)
    private String goalImageUrl;

    @Column(name = "begin_date")
    @Builder.Default
    private LocalDate beginDate = LocalDate.now();

    @Column(name = "end_date", nullable = false)
    private LocalDate endDate;

    // 1: Active | 2: Completed | 3: Cancelled (tạm dừng/kết thúc sớm) | 4: Overdue
    @Column(name = "goal_status", nullable = false)
    @Builder.Default
    private Integer goalStatus = 1;

    @Column(name = "notified", nullable = false)
    @Builder.Default
    private Boolean notified = true;

    @Column(name = "reportable", nullable = false)
    @Builder.Default
    private Boolean reportable = true;

    // true nếu mục tiêu đã kết thúc (hoàn thành, hủy, hoặc quá hạn).
    @Column(name = "finished")
    @Builder.Default
    private Boolean finished = false;

    // ── SOFT DELETE ──────────────────────────────────────────────────────
    @Column(name = "deleted", nullable = false)
    @Builder.Default
    private Boolean deleted = false;

    @Column(name = "deleted_at")
    private LocalDateTime deletedAt;
}