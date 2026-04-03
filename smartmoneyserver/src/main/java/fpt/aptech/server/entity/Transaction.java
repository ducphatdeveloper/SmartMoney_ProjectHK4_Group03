package fpt.aptech.server.entity;

import jakarta.persistence.*;
import lombok.*;
import org.hibernate.annotations.CreationTimestamp;
import org.hibernate.annotations.SQLRestriction;

import java.math.BigDecimal;
import java.time.LocalDateTime;

/**
 * Bảng giao dịch (trung tâm của hệ thống).
 * Ghi lại mọi hoạt động thu, chi, chuyển tiền...
 */
@Entity
@Table(name = "tTransactions")
@SQLRestriction("deleted = 0")
@Getter
@Setter
@NoArgsConstructor
@AllArgsConstructor
@Builder
public class Transaction {

    @Id
    @GeneratedValue(strategy = GenerationType.IDENTITY)
    private Long id;

    @ManyToOne(fetch = FetchType.LAZY)
    @JoinColumn(name = "acc_id", nullable = false)
    private Account account;

    @ManyToOne(fetch = FetchType.LAZY)
    @JoinColumn(name = "ctg_id")
    private Category category;

    @ManyToOne(fetch = FetchType.LAZY)
    @JoinColumn(name = "wallet_id")
    private Wallet wallet;

    @ManyToOne(fetch = FetchType.LAZY)
    @JoinColumn(name = "event_id")
    private Event event;

    @ManyToOne(fetch = FetchType.LAZY)
    @JoinColumn(name = "debt_id")
    private Debt debt;

    @ManyToOne(fetch = FetchType.LAZY)
    @JoinColumn(name = "goal_id")
    private SavingGoal savingGoal;

    @ManyToOne(fetch = FetchType.LAZY)
    @JoinColumn(name = "ai_chat_id")
    private AIConversation aiConversation;

    // ✅ THÊM: Link giao dịch về PlannedTransaction gốc (nullable)
    // Chỉ có giá trị khi source_type = 5 (PLANNED)
    // Flutter dùng để: "Xem danh sách giao dịch thuộc hóa đơn này"
    @ManyToOne(fetch = FetchType.LAZY)
    @JoinColumn(name = "planned_id")
    private PlannedTransaction plannedTransaction;

    @Column(name = "amount", nullable = false, precision = 18, scale = 2)
    private BigDecimal amount;

    @Column(name = "with_person", length = 100)
    private String withPerson;

    @Column(name = "note", length = 500)
    private String note;

    @Column(name = "reportable", nullable = false)
    @Builder.Default
    private Boolean reportable = true;

    // Nguồn tạo giao dịch: 1: manual, 2: chat, 3: voice, 4: receipt, 5: planned
    @Column(name = "source_type", nullable = false)
    @Builder.Default
    private Integer sourceType = 1;

    // Ngày giao dịch thực tế.
    @Column(name = "trans_date", nullable = false)
    @Builder.Default
    private LocalDateTime transDate = LocalDateTime.now();

    @CreationTimestamp
    @Column(name = "created_at", nullable = false, updatable = false)
    private LocalDateTime createdAt;

    // ── SOFT DELETE ──────────────────────────────────────────────────────
    @Column(name = "deleted", nullable = false)
    @Builder.Default
    private Boolean deleted = false;

    @Column(name = "deleted_at")
    private LocalDateTime deletedAt;
}