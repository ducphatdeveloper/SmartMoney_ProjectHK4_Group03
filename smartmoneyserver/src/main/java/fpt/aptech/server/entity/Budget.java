package fpt.aptech.server.entity;

import jakarta.persistence.*;
import lombok.*;

import java.math.BigDecimal;
import java.time.LocalDate;
import java.util.Set;

/**
 * Bảng ngân sách chi tiêu.
 * Thiết lập giới hạn chi tiêu cho một hoặc nhiều danh mục trong một khoảng thời gian.
 */
@Entity
@Table(name = "tBudgets")
@Getter
@Setter
@NoArgsConstructor
@AllArgsConstructor
@Builder
public class Budget {

    @Id
    @GeneratedValue(strategy = GenerationType.IDENTITY)
    private Integer id;

    @ManyToOne(fetch = FetchType.LAZY)
    @JoinColumn(name = "acc_id", nullable = false)
    private Account account;

    // Ngân sách áp dụng cho ví nào. NULL nếu áp dụng cho tất cả các ví.
    @ManyToOne(fetch = FetchType.LAZY)
    @JoinColumn(name = "wallet_id")
    private Wallet wallet;

    // Số tiền giới hạn của ngân sách.
    @Column(name = "amount", nullable = false, precision = 18, scale = 2)
    private BigDecimal amount;

    @Column(name = "begin_date", nullable = false)
    private LocalDate beginDate = LocalDate.now();

    @Column(name = "end_date", nullable = false)
    private LocalDate endDate;

    // true: áp dụng cho tất cả danh mục chi. false: áp dụng cho danh sách `categories`.
    @Column(name = "all_categories")
    private Boolean allCategories = false;

    // true: tự động gia hạn ngân sách cho chu kỳ tiếp theo.
    @Column(name = "repeating")
    private Boolean repeating = false;

    // Danh sách các danh mục được áp dụng ngân sách này.
    @ManyToMany(fetch = FetchType.LAZY)
    @JoinTable(
            name = "tBudgetCategories",
            joinColumns = @JoinColumn(name = "budget_id"),
            inverseJoinColumns = @JoinColumn(name = "ctg_id")
    )
    private Set<Category> categories;
}