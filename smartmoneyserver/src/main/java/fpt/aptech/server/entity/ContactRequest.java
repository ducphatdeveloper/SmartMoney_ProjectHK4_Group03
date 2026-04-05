package fpt.aptech.server.entity;

import fpt.aptech.server.enums.contact.ContactRequestPriority;
import fpt.aptech.server.enums.contact.ContactRequestStatus;
import fpt.aptech.server.enums.contact.ContactRequestType;
import jakarta.persistence.*;
import lombok.*;
import org.hibernate.annotations.CreationTimestamp;
import org.hibernate.annotations.UpdateTimestamp;

import java.time.LocalDateTime;

/**
 * Bảng yêu cầu hỗ trợ / liên hệ từ người dùng.
 * Hỗ trợ flow: PENDING → PROCESSING → APPROVED | REJECTED
 * Dùng cho: khóa/mở khóa tài khoản, báo lỗi, giao dịch bất thường, khôi phục dữ liệu...
 * acc_id nullable → hỗ trợ cả guest (user chưa login hoặc bị khóa gửi form public).
 */
@Entity
@Table(name = "tContactRequests")
@Getter
@Setter
@NoArgsConstructor
@AllArgsConstructor
@Builder
public class ContactRequest {

    @Id
    @GeneratedValue(strategy = GenerationType.IDENTITY)
    private Integer id;

    // Tài khoản gửi yêu cầu (FK → tAccounts, nullable cho guest/tài khoản bị khóa)
    @ManyToOne(fetch = FetchType.LAZY, optional = true)
    @JoinColumn(name = "acc_id", nullable = true)
    private Account account;

    // Admin duyệt cuối (FK → tAccounts, nullable)
    @ManyToOne(fetch = FetchType.LAZY)
    @JoinColumn(name = "resolved_by")
    private Account resolvedBy;

    // Loại yêu cầu: ACCOUNT_LOCK | ACCOUNT_UNLOCK | FORGOT_PASSWORD | EMERGENCY |
    //               BUG_REPORT | SUSPICIOUS_TX | DATA_RECOVERY | DATA_LOSS | GENERAL
    @Enumerated(EnumType.STRING)
    @Column(name = "request_type", nullable = false, length = 30)
    private ContactRequestType requestType;

    // Mức độ ưu tiên: URGENT | HIGH | NORMAL
    @Enumerated(EnumType.STRING)
    @Column(name = "request_priority", nullable = false, length = 10)
    @Builder.Default
    private ContactRequestPriority requestPriority = ContactRequestPriority.NORMAL;

    // Tiêu đề ngắn gọn do user nhập
    @Column(name = "title", nullable = false, length = 200)
    private String title;

    // Mô tả chi tiết vấn đề
    @Column(name = "request_description", length = 2000)
    private String requestDescription;

    // Họ tên người gửi — backend tự gán từ tAccounts nếu đã login, user có thể sửa lại; guest bắt buộc nhập
    @Column(name = "fullname", nullable = false, length = 60)
    private String fullname;

    // SĐT liên hệ — phải có phone HOẶC email (validate ở backend)
    @Column(name = "contact_phone", length = 20)
    private String contactPhone;

    // Email liên hệ — phải có phone HOẶC email (validate ở backend)
    @Column(name = "contact_email", length = 100)
    private String contactEmail;

    // Trạng thái xử lý: PENDING → PROCESSING → APPROVED | REJECTED
    @Enumerated(EnumType.STRING)
    @Column(name = "request_status", nullable = false, length = 20)
    @Builder.Default
    private ContactRequestStatus requestStatus = ContactRequestStatus.PENDING;

    // Thời điểm Admin nhận xử lý (chuyển sang PROCESSING)
    @Column(name = "processed_at")
    private LocalDateTime processedAt;

    // Thời điểm admin duyệt (chuyển sang APPROVED/REJECTED)
    @Column(name = "resolved_at")
    private LocalDateTime resolvedAt;

    // Ghi chú nội bộ của Admin
    @Column(name = "admin_note", length = 1000)
    private String adminNote;

    @CreationTimestamp
    @Column(name = "created_at", nullable = false, updatable = false)
    private LocalDateTime createdAt;

    @UpdateTimestamp
    @Column(name = "updated_at")
    private LocalDateTime updatedAt;
}
