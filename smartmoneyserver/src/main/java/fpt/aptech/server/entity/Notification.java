package fpt.aptech.server.entity;

import jakarta.persistence.*;
import lombok.*;
import org.hibernate.annotations.CreationTimestamp;

import java.time.LocalDateTime;

/**
 * Bảng thông báo.
 * Gửi các thông báo về giao dịch, ngân sách, nhắc nhở... đến người dùng.
 */
@Entity
@Table(name = "tNotifications")
@Getter
@Setter
@NoArgsConstructor
@AllArgsConstructor
@Builder
public class Notification {

    @Id
    @GeneratedValue(strategy = GenerationType.IDENTITY)
    private Integer id;

    @ManyToOne(fetch = FetchType.LAZY)
    @JoinColumn(name = "acc_id", nullable = false)
    private Account account;

    // Loại thông báo, xem chú thích trong file SQL để biết chi tiết.
    @Column(name = "notify_type", nullable = false)
    private Integer notifyType;

    // ID của đối tượng liên quan (VD: ID của transaction, budget...).
    @Column(name = "related_id")
    private Long relatedId;

    @Column(name = "title", length = 100)
    private String title;

    @Column(name = "content", nullable = false, length = 500)
    private String content;

    // Thời gian dự kiến gửi thông báo.
    @Column(name = "scheduled_time")
    private LocalDateTime scheduledTime = LocalDateTime.now();

    // Trạng thái đã gửi push notification.
    @Column(name = "notify_sent")
    private Boolean notifySent = false;

    // Trạng thái người dùng đã đọc.
    @Column(name = "notify_read")
    private Boolean notifyRead = false;

    @CreationTimestamp
    @Column(name = "created_at", updatable = false)
    private LocalDateTime createdAt;
}