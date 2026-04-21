package fpt.aptech.server.service.ai;

import fpt.aptech.server.entity.AIConversation;
import fpt.aptech.server.entity.Account;
import fpt.aptech.server.entity.Receipt;
import fpt.aptech.server.repos.AIConversationRepository;
import fpt.aptech.server.repos.ReceiptRepository;
import jakarta.persistence.EntityManager;
import lombok.RequiredArgsConstructor;
import lombok.extern.slf4j.Slf4j;
import org.springframework.stereotype.Component;
import org.springframework.transaction.annotation.Transactional;

/**
 * [1] ReceiptDbService — Service xử lý DB cho Receipt với @Transactional riêng
 * Tách riêng để tránh Connection Pool Starvation khi AI chạy lâu
 */
@Slf4j
@Component
@RequiredArgsConstructor
public class ReceiptDbService {

    private final AIConversationRepository aiRepo;
    private final ReceiptRepository receiptRepo;
    private final EntityManager entityManager;

    /**
     * [1.1] Tạo bản ghi Receipt ban đầu với trạng thái pending (Transactional riêng)
     * Bước 1: Upload ảnh Cloudinary
     * Bước 2: Lưu AIConversation
     * Bước 3: Lưu Receipt với native query
     */
    @Transactional
    public Receipt createInitialReceipt(Account account, String imageUrl) {
        // Lưu AIConversation
        AIConversation userMsg = AIConversation.builder()
                .account(account)
                .messageContent("Tôi muốn phân tích hóa đơn này.")
                .senderType(false)
                .intent(null)
                .attachmentType(1) // Image
                .attachmentUrl(imageUrl)
                .build();
        aiRepo.save(userMsg);

        // Lưu Receipt entity bằng native query để tránh optimistic locking
        entityManager.createNativeQuery("""
                INSERT INTO tReceipts (id, acc_id, image_url, raw_ocr_text, processed_data, receipt_status, created_at)
                VALUES (?, ?, ?, NULL, '{}', 'pending', GETDATE())
                """)
                .setParameter(1, userMsg.getId())
                .setParameter(2, account.getId())
                .setParameter(3, imageUrl)
                .executeUpdate();

        return receiptRepo.findById(userMsg.getId()).orElse(null);
    }

    /**
     * [1.2] Cập nhật kết quả OCR thành công (Transactional riêng)
     */
    @Transactional
    public Receipt updateReceiptSuccess(Integer receiptId, String rawOcrText, String processedData) {
        Receipt receipt = receiptRepo.findById(receiptId).orElse(null);
        if (receipt != null) {
            receipt.setRawOcrText(rawOcrText);
            receipt.setReceiptStatus("processed");
            receipt.setProcessedData(processedData);
            receiptRepo.save(receipt);
        }
        return receipt;
    }

    /**
     * [1.3] Cập nhật lỗi OCR (Transactional riêng)
     */
    @Transactional
    public Receipt updateReceiptError(Integer receiptId, String errorMessage) {
        Receipt receipt = receiptRepo.findById(receiptId).orElse(null);
        if (receipt != null) {
            receipt.setReceiptStatus("error");
            receipt.setProcessedData("{}");
            receipt.setRawOcrText(errorMessage);
            receiptRepo.save(receipt);
        }
        return receipt;
    }
}
