package fpt.aptech.server.entity;

import jakarta.persistence.*;
import lombok.AllArgsConstructor;
import lombok.Builder;
import lombok.Data;
import lombok.NoArgsConstructor;
import org.hibernate.annotations.CreationTimestamp;

import java.time.LocalDateTime;

@Entity
@Table(name = "tNotifications")
@Data
@NoArgsConstructor
@AllArgsConstructor
@Builder
public class Notification {

    @Id
    @GeneratedValue(strategy = GenerationType.IDENTITY)
    private Integer id;

    @ManyToOne
    @JoinColumn(name = "acc_id", nullable = false)
    private Account account;

    @Column(name = "notify_type", nullable = false)
    private Integer notifyType; // 1: TRANSACTION | 2: SAVING | 3: BUDGET | 4: SYSTEM | 5: CHAT_AI | 6: WALLETS | 7: EVENTS | 8: DEBT_LOAN | 9: REMINDER

    @Column(name = "related_id")
    private Long relatedId;

    @Column(name = "title", length = 100)
    private String title;

    @Column(name = "content", nullable = false, length = 500)
    private String content;

    @Column(name = "scheduled_time")
    private LocalDateTime scheduledTime = LocalDateTime.now();

    @Column(name = "notify_sent")
    private Boolean notifySent = false;

    @Column(name = "notify_read")
    private Boolean notifyRead = false;

    @CreationTimestamp
    @Column(name = "created_at", updatable = false)
    private LocalDateTime createdAt;
}