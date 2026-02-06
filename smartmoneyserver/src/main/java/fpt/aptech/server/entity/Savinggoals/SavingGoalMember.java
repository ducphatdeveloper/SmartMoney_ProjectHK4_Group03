package fpt.aptech.server.entity.Savinggoals;

import fpt.aptech.server.entity.Account;
import jakarta.persistence.*;
import lombok.*;

@Entity
@Table(name = "tSavingGoalMembers", uniqueConstraints = @UniqueConstraint(columnNames = {"saving_goal_id", "acc_id"}))
@Getter
@Setter
@NoArgsConstructor
@AllArgsConstructor
@Builder
public class SavingGoalMember {

    @Id
    @GeneratedValue(strategy = GenerationType.IDENTITY)
    private Integer id;

    @ManyToOne(fetch = FetchType.LAZY)
    @JoinColumn(name = "saving_goal_id", nullable = false)
    private SavingGoal savingGoal;

    @ManyToOne(fetch = FetchType.LAZY)
    @JoinColumn(name = "acc_id", nullable = false)
    private Account account;

    /**
     * OWNER | CO_OWNER | MEMBER
     */
    @Column(nullable = false, length = 20)
    private String role;
}
