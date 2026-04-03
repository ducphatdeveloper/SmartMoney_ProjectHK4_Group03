package fpt.aptech.server.entity;

import jakarta.persistence.*;
import lombok.*;
import org.hibernate.annotations.SQLRestriction;

import java.time.LocalDate;
import java.time.LocalDateTime;

/**
 * Bảng sự kiện.
 * Dùng để nhóm các giao dịch vào một sự kiện cụ thể (VD: "Du lịch Đà Lạt").
 */
@Entity
@Table(name = "tEvents")
@SQLRestriction("deleted = 0")
@Getter
@Setter
@NoArgsConstructor
@AllArgsConstructor
@Builder
public class Event {

    @Id
    @GeneratedValue(strategy = GenerationType.IDENTITY)
    private Integer id;

    @ManyToOne(fetch = FetchType.LAZY)
    @JoinColumn(name = "acc_id", nullable = false)
    private Account account;

    @ManyToOne(fetch = FetchType.LAZY)
    @JoinColumn(name = "currency", referencedColumnName = "currency_code", nullable = false)
    private Currency currency;

    @Column(name = "event_name", nullable = false, length = 200)
    private String eventName;

    @Column(name = "event_icon_url", length = 2048)
    @Builder.Default
    private String eventIconUrl = "icon_event_default.svg";

    @Column(name = "begin_date")
    @Builder.Default
    private LocalDate beginDate = LocalDate.now();

    @Column(name = "end_date", nullable = false)
    private LocalDate endDate;

    @Column(name = "finished")
    @Builder.Default
    private Boolean finished = false;

    // ── SOFT DELETE ──────────────────────────────────────────────────────
    @Column(name = "deleted", nullable = false)
    @Builder.Default
    private Boolean deleted = false;

    @Column(name = "deleted_at")
    private LocalDateTime deletedAt;
}