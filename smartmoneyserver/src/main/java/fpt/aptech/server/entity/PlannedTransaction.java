package fpt.aptech.server.entity;

import jakarta.persistence.*;
import lombok.AllArgsConstructor;
import lombok.Builder;
import lombok.Data;
import lombok.NoArgsConstructor;
import org.hibernate.annotations.CreationTimestamp;

import java.math.BigDecimal;
import java.time.LocalDate;
import java.time.LocalDateTime;

@Entity
@Table(name = "tPlannedTransactions")
@Data
@NoArgsConstructor
@AllArgsConstructor
@Builder
public class PlannedTransaction {

    @Id
    @GeneratedValue(strategy = GenerationType.IDENTITY)
    private Integer id;

    @ManyToOne
    @JoinColumn(name = "acc_id", nullable = false)
    private Account account;

    @ManyToOne
    @JoinColumn(name = "wallet_id", nullable = false)
    private Wallet wallet;

    @ManyToOne
    @JoinColumn(name = "ctg_id", nullable = false)
    private Category category;

    @ManyToOne
    @JoinColumn(name = "currency_code", nullable = false)
    private Currency currency;

    @Column(name = "note", length = 500)
    private String note;

    @Column(name = "amount", nullable = false, precision = 18, scale = 2)
    private BigDecimal amount;

    @Column(name = "plan_type", nullable = false)
    private Integer planType; // 1: Bill | 2: Recurring

    @Column(name = "trans_type", nullable = false)
    private Integer transType; // 1: Chi | 2: Thu | 3: Cho vay | 4: Đi vay | 5: Thu nợ | 6: Trả nợ

    @Column(name = "repeat_type", nullable = false)
    private Integer repeatType; // 0: Không lặp | 1: Ngày | 2: Tuần | 3: Tháng | 4: Năm

    @Column(name = "repeat_interval", nullable = false)
    private Integer repeatInterval = 1;

    @Column(name = "repeat_on_day_val")
    private Integer repeatOnDayVal;

    @Column(name = "begin_date", nullable = false)
    private LocalDate beginDate;

    @Column(name = "next_due_date", nullable = false)
    private LocalDate nextDueDate;

    @Column(name = "last_executed_at")
    private LocalDate lastExecutedAt;

    @Column(name = "end_date")
    private LocalDate endDate;

    @Column(name = "active", nullable = false)
    private Boolean active = true;

    @CreationTimestamp
    @Column(name = "created_at", nullable = false, updatable = false)
    private LocalDateTime createdAt;
}