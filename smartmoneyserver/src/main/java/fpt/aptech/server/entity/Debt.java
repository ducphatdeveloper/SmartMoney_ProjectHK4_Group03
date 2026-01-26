package fpt.aptech.server.entity;

import jakarta.persistence.*;
import lombok.AllArgsConstructor;
import lombok.Builder;
import lombok.Data;
import lombok.NoArgsConstructor;
import org.hibernate.annotations.CreationTimestamp;

import java.math.BigDecimal;
import java.time.LocalDateTime;

@Entity
@Table(name = "tDebts")
@Data
@NoArgsConstructor
@AllArgsConstructor
@Builder
public class Debt {

    @Id
    @GeneratedValue(strategy = GenerationType.IDENTITY)
    private Integer id;

    @ManyToOne
    @JoinColumn(name = "acc_id", nullable = false)
    private Account account;

    @Column(name = "debt_type", nullable = false)
    private Boolean debtType; // false: Cần Trả (Đi vay) | true: Cần Thu (Cho vay)

    @Column(name = "total_amount", nullable = false, precision = 18, scale = 2)
    private BigDecimal totalAmount;

    @Column(name = "remain_amount", nullable = false, precision = 18, scale = 2)
    private BigDecimal remainAmount;

    @Column(name = "due_date")
    private LocalDateTime dueDate;

    @Column(name = "note", length = 500)
    private String note;

    @Column(name = "finished", nullable = false)
    private Boolean finished = false;

    @CreationTimestamp
    @Column(name = "created_at", updatable = false)
    private LocalDateTime createdAt;
}