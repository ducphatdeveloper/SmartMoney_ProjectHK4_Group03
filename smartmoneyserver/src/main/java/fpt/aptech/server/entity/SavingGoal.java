package fpt.aptech.server.entity;

import jakarta.persistence.*;
import lombok.AllArgsConstructor;
import lombok.Builder;
import lombok.Data;
import lombok.NoArgsConstructor;

import java.math.BigDecimal;
import java.time.LocalDate;

@Entity
@Table(name = "tSavingGoals")
@Data
@NoArgsConstructor
@AllArgsConstructor
@Builder
public class SavingGoal {

    @Id
    @GeneratedValue(strategy = GenerationType.IDENTITY)
    private Integer id;

    @ManyToOne
    @JoinColumn(name = "acc_id", nullable = false)
    private Account account;

    @ManyToOne
    @JoinColumn(name = "currency", nullable = false)
    private Currency currency;

    @Column(name = "goal_name", nullable = false, length = 200)
    private String goalName;

    @Column(name = "target_amount", nullable = false, precision = 18, scale = 2)
    private BigDecimal targetAmount;

    @Column(name = "current_amount", precision = 18, scale = 2)
    private BigDecimal currentAmount = BigDecimal.ZERO;

    @Column(name = "goal_image_url", length = 2048)
    private String goalImageUrl;

    @Column(name = "begin_date")
    private LocalDate beginDate = LocalDate.now();

    @Column(name = "end_date", nullable = false)
    private LocalDate endDate;

    @Column(name = "goal_status", nullable = false)
    private Integer goalStatus = 1; // 1: Active | 2: Completed | 3: Cancelled

    @Column(name = "notified", nullable = false)
    private Boolean notified = true;

    @Column(name = "reportable", nullable = false)
    private Boolean reportable = true;

    @Column(name = "finished")
    private Boolean finished = false;
}