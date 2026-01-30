package fpt.aptech.server.entity;

import jakarta.persistence.*;
import lombok.AllArgsConstructor;
import lombok.Builder;
import lombok.Getter;
import lombok.NoArgsConstructor;
import lombok.Setter;
import org.hibernate.annotations.CreationTimestamp;

import java.math.BigDecimal;
import java.time.LocalDateTime;

/**
 * Bảng sổ nợ.
 * Ghi lại các khoản cho vay và đi vay.
 */
@Entity
@Table(name = "tDebts")
@Getter
@Setter
@NoArgsConstructor
@AllArgsConstructor
@Builder
public class Debt {

    @Id
    @GeneratedValue(strategy = GenerationType.IDENTITY)
    private Integer id;

    @ManyToOne(fetch = FetchType.LAZY)
    @JoinColumn(name = "acc_id", nullable = false)
    private Account account;

    // Loại nợ: false (0) = Cần Trả (Đi vay), true (1) = Cần Thu (Cho vay).
    @Column(name = "debt_type", nullable = false)
    private Boolean debtType;

    // Tổng số tiền ban đầu.
    @Column(name = "total_amount", nullable = false, precision = 18, scale = 2)
    private BigDecimal totalAmount;

    // Số tiền còn lại phải trả/thu.
    @Column(name = "remain_amount", nullable = false, precision = 18, scale = 2)
    private BigDecimal remainAmount;

    // Ngày hẹn trả.
    @Column(name = "due_date")
    private LocalDateTime dueDate;

    @Column(name = "note", length = 500)
    private String note;

    // Trạng thái hoàn thành.
    @Column(name = "finished", nullable = false)
    private Boolean finished = false;

    @CreationTimestamp
    @Column(name = "created_at", updatable = false)
    private LocalDateTime createdAt;
}