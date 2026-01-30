package fpt.aptech.server.entity;

import jakarta.persistence.*;
import lombok.AllArgsConstructor;
import lombok.Builder;
import lombok.Getter;
import lombok.NoArgsConstructor;
import lombok.Setter;
import org.hibernate.annotations.CreationTimestamp;

import java.time.LocalDateTime;

/**
 * Bảng lịch sử chat với AI.
 * Lưu lại mọi tương tác giữa người dùng và trợ lý AI.
 */
@Entity
@Table(name = "tAIConversations")
@Getter
@Setter
@NoArgsConstructor
@AllArgsConstructor
@Builder
public class AIConversation {

    @Id
    @GeneratedValue(strategy = GenerationType.IDENTITY)
    private Integer id;

    @ManyToOne(fetch = FetchType.LAZY)
    @JoinColumn(name = "acc_id", nullable = false)
    private Account account;

    // Nội dung tin nhắn. @Lob chỉ định đây là một đối tượng lớn.
    @Lob
    @Column(name = "message_content", nullable = false)
    private String messageContent;

    // Người gửi: false (0) = User, true (1) = AI.
    @Column(name = "sender_type", nullable = false)
    private Boolean senderType;

    // Ý định của tin nhắn: 1:add_trans, 2:report, 3:budget, 4:chat, 5:remind
    @Column(name = "intent")
    private Integer intent;

    // URL file đính kèm (ảnh hóa đơn, ghi âm).
    @Column(name = "attachment_url", length = 500)
    private String attachmentUrl;

    // Loại file đính kèm: 1: image, 2: voice.
    @Column(name = "attachment_type")
    private Integer attachmentType;

    @CreationTimestamp
    @Column(name = "created_at", nullable = false, updatable = false)
    private LocalDateTime createdAt;
}