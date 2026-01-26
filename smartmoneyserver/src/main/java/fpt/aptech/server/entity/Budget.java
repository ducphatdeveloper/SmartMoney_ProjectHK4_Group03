package fpt.aptech.server.entity;

import jakarta.persistence.*;
import lombok.AllArgsConstructor;
import lombok.Builder;
import lombok.Data;
import lombok.NoArgsConstructor;

import java.math.BigDecimal;
import java.time.LocalDate;
import java.util.Set;

@Entity
@Table(name = "tBudgets")
@Data
@NoArgsConstructor
@AllArgsConstructor
@Builder
public class Budget {

    @Id
    @GeneratedValue(strategy = GenerationType.IDENTITY)
    private Integer id;

    @ManyToOne
    @JoinColumn(name = "acc_id", nullable = false)
    private Account account;

    @ManyToOne
    @JoinColumn(name = "wallet_id")
    private Wallet wallet;

    @Column(name = "amount", nullable = false, precision = 18, scale = 2)
    private BigDecimal amount;

    @Column(name = "begin_date", nullable = false)
    private LocalDate beginDate = LocalDate.now();

    @Column(name = "end_date", nullable = false)
    private LocalDate endDate;

    @Column(name = "all_categories")
    private Boolean allCategories = false;

    @Column(name = "repeating")
    private Boolean repeating = false;

    @ManyToMany
    @JoinTable(
            name = "tBudgetCategories",
            joinColumns = @JoinColumn(name = "budget_id"),
            inverseJoinColumns = @JoinColumn(name = "ctg_id")
    )
    private Set<Category> categories;
}