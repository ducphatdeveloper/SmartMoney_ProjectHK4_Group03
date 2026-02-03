package fpt.aptech.server.entity;

import jakarta.persistence.*;
import lombok.*;
import org.hibernate.annotations.CreationTimestamp;

import java.time.LocalDateTime;

/**
 * Bảng hóa đơn được quét bằng OCR.
 * Có quan hệ 1-1 với tAIConversations.
 */
@Entity
@Table(name = "tReceipts")
@Getter
@Setter
@NoArgsConstructor
@AllArgsConstructor
@Builder
public class Receipt {

    // Khóa chính của bảng này cũng là khóa ngoại trỏ tới tAIConversations.
    @Id
    private Integer id;

    // Quan hệ 1-1: Một hóa đơn tương ứng với một tin nhắn AI.
    // @MapsId chỉ định rằng giá trị của 'id' phía trên được lấy từ quan hệ này.
    @OneToOne(fetch = FetchType.LAZY)
    @MapsId
    @JoinColumn(name = "id")
    private AIConversation aiConversation;

    @ManyToOne(fetch = FetchType.LAZY)
    @JoinColumn(name = "acc_id", nullable = false)
    private Account account;

    @Column(name = "image_url", nullable = false, length = 500)
    private String imageUrl;

    // Text thô trả về từ dịch vụ OCR.
    @Lob
    @Column(name = "raw_ocr_text")
    private String rawOcrText;

    // Dữ liệu đã được xử lý và chuẩn hóa (dưới dạng JSON).
    @Lob
    @Column(name = "processed_data")
    @Builder.Default
    private String processedData = "{}";

    // Trạng thái xử lý: "pending" | "processed" | "error"
    @Column(name = "receipt_status", nullable = false, length = 20)
    @Builder.Default
    private String receiptStatus = "pending";

    @CreationTimestamp
    @Column(name = "created_at", nullable = false, updatable = false)
    private LocalDateTime createdAt;
}