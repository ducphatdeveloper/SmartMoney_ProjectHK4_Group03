package fpt.aptech.server.entity;

import jakarta.persistence.*;
import lombok.AllArgsConstructor;
import lombok.Builder;
import lombok.Data;
import lombok.NoArgsConstructor;
import org.hibernate.annotations.CreationTimestamp;

import java.time.LocalDateTime;

@Entity
@Table(name = "tAIConversations")
@Data
@NoArgsConstructor
@AllArgsConstructor
@Builder
public class AIConversation {

    @Id
    @GeneratedValue(strategy = GenerationType.IDENTITY)
    private Integer id;

    @ManyToOne
    @JoinColumn(name = "acc_id", nullable = false)
    private Account account;

    @Column(name = "message_content", nullable = false, columnDefinition = "NVARCHAR(MAX)")
    private String messageContent;

    @Column(name = "sender_type", nullable = false)
    private Boolean senderType; // false: User nhắn | true: AI phản hồi

    @Column(name = "intent")
    private Integer intent; // 1: add_transaction | 2: report_query | 3: set_budget | 4: general_chat | 5: remind_task

    @Column(name = "attachment_url", length = 500)
    private String attachmentUrl;

    @Column(name = "attachment_type")
    private Integer attachmentType; // 1: image | 2: voice | NULL: chat text

    @CreationTimestamp
    @Column(name = "created_at", nullable = false, updatable = false)
    private LocalDateTime createdAt;
}