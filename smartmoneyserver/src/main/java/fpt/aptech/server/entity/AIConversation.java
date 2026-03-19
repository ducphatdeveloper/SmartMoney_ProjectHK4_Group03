package fpt.aptech.server.entity;

import jakarta.persistence.*;
import lombok.*;
import org.hibernate.annotations.CreationTimestamp;

import java.time.LocalDateTime;

/**
 * Entity ánh xạ bảng tAIConversations.
 *
 * Lưu từng tin nhắn riêng lẻ (cả user lẫn AI).
 * Quan hệ:
 *   - N-1 với tAccounts
 *   - 1-1 với tReceipts (nếu có ảnh hóa đơn)
 *   - 1-N với tTransactions (ai_chat_id)
 *
 * sender_type: 0=User, 1=AI
 * intent:      1=add_transaction | 2=report_query | 3=set_budget
 *              4=general_chat   | 5=remind_task  | NULL=đang xử lý ảnh
 * attachment_type: 1=image | 2=voice | NULL=text
 *
 * DB Constraint:
 *   - Có ảnh  (attachment_type=1) → attachment_url NOT NULL
 *   - Giọng nói (attachment_type=2) → attachment_url NULL (không lưu file)
 *   - Text      (attachment_type=NULL) → cả 2 NULL
 */
@Entity
@Table(name = "tAIConversations")
@Getter
@Setter
@NoArgsConstructor
@AllArgsConstructor
@Builder
public class AIConversation {

    // =================================================================================
    // PRIMARY KEY
    // =================================================================================

    @Id
    @GeneratedValue(strategy = GenerationType.IDENTITY)
    private Integer id;

    // =================================================================================
    // FOREIGN KEYS
    // =================================================================================

    @ManyToOne(fetch = FetchType.LAZY)
    @JoinColumn(name = "acc_id", nullable = false)
    private Account account;

    // =================================================================================
    // DATA COLUMNS
    // =================================================================================

    @Column(name = "message_content", nullable = false, columnDefinition = "NVARCHAR(MAX)")
    private String messageContent;

    // 0 = User nhắn | 1 = AI phản hồi
    @Column(name = "sender_type", nullable = false)
    private Boolean senderType;

    // 1=add_transaction | 2=report_query | 3=set_budget | 4=general_chat | 5=remind_task
    @Column(name = "intent")
    private Integer intent;

    // URL file đính kèm (chỉ có khi attachment_type=1 - image)
    @Column(name = "attachment_url", length = 500)
    private String attachmentUrl;

    // 1=image | 2=voice | NULL=text
    @Column(name = "attachment_type")
    private Integer attachmentType;


    @CreationTimestamp //Tự động sinh ngày giờ hiện tại.
    @Column(name = "created_at", nullable = false)
    private LocalDateTime createdAt;

    // =================================================================================
    // RELATIONSHIPS
    // =================================================================================

    // 1-1 với Receipt (chỉ tồn tại khi có ảnh hóa đơn)
    @OneToOne(mappedBy = "conversation", cascade = CascadeType.ALL, fetch = FetchType.LAZY)
    private Receipt receipt;
}