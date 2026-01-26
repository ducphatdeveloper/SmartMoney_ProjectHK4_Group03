package fpt.aptech.server.entity;

import jakarta.persistence.*;
import lombok.AllArgsConstructor;
import lombok.Builder;
import lombok.Data;
import lombok.NoArgsConstructor;
import org.hibernate.annotations.CreationTimestamp;

import java.time.LocalDateTime;

@Entity
@Table(name = "tReceipts")
@Data
@NoArgsConstructor
@AllArgsConstructor
@Builder
public class Receipt {

    @Id
    private Integer id; // Same as AIConversation ID (1-1 relationship)

    @OneToOne
    @MapsId
    @JoinColumn(name = "id")
    private AIConversation aiConversation;

    @ManyToOne
    @JoinColumn(name = "acc_id", nullable = false)
    private Account account;

    @Column(name = "image_url", nullable = false, length = 500)
    private String imageUrl;

    @Column(name = "raw_ocr_text", columnDefinition = "NVARCHAR(MAX)")
    private String rawOcrText;

    @Column(name = "processed_data", columnDefinition = "NVARCHAR(MAX)")
    private String processedData = "{}";

    @Column(name = "receipt_status", nullable = false, length = 20)
    private String receiptStatus = "pending"; // pending | processed | error

    @CreationTimestamp
    @Column(name = "created_at", nullable = false, updatable = false)
    private LocalDateTime createdAt;
}