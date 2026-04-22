package fpt.aptech.server.repos;

import fpt.aptech.server.entity.AIConversation;
import fpt.aptech.server.entity.Account;
import org.springframework.data.domain.Page;
import org.springframework.data.domain.Pageable;
import org.springframework.data.jpa.repository.EntityGraph;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.data.jpa.repository.Modifying;
import org.springframework.data.jpa.repository.Query;
import org.springframework.data.repository.query.Param;
import org.springframework.stereotype.Repository;

import java.util.List;
import java.util.Optional;

@Repository
public interface AIConversationRepository extends JpaRepository<AIConversation, Integer> {
    
    // ─────────────────────────────────────────────
    // [3.1] Lấy lịch sử chat của user, sắp xếp mới nhất trước
    // Dùng cho: load chat history khi mở màn hình AI
    // ─────────────────────────────────────────────
    // Dùng @EntityGraph thay vì LEFT JOIN FETCH vì:
    // - LEFT JOIN FETCH với Pageable sẽ gây in-memory pagination (Hibernate fetch toàn bộ rồi mới phân trang ở memory)
    // - EntityGraph thực hiện eager fetch ở database level, tránh N+1 query mà vẫn giữ pagination hiệu quả
    @EntityGraph(attributePaths = {"receipt"})
    @Query("""
        SELECT c FROM AIConversation c
        WHERE c.account.id = :accId
        ORDER BY c.createdAt DESC
        """)
    Page<AIConversation> findByAccountIdOrderByCreatedAtDesc(
            @Param("accId") Integer accId,
            Pageable pageable
    );

    // ─────────────────────────────────────────────
    // [3.2] Lấy N tin nhắn gần nhất để làm context cho AI
    // Dùng cho: build conversation history khi gọi AI
    // ─────────────────────────────────────────────
    // Dùng @EntityGraph thay vì LEFT JOIN FETCH vì:
    // - LEFT JOIN FETCH với Pageable sẽ gây in-memory pagination (Hibernate fetch toàn bộ rồi mới phân trang ở memory)
    // - EntityGraph thực hiện eager fetch ở database level, tránh N+1 query mà vẫn giữ pagination hiệu quả
    @EntityGraph(attributePaths = {"receipt"})
    @Query("""
        SELECT c FROM AIConversation c
        WHERE c.account.id = :accId
        ORDER BY c.createdAt DESC
        """)
    List<AIConversation> findRecentByAccountId(
            @Param("accId") Integer accId,
            Pageable pageable
    );

    // ─────────────────────────────────────────────
    // [3.3] Xóa toàn bộ lịch sử chat của user
    // Dùng cho: nút "Xóa lịch sử chat" trong UI
    // @Modifying cần kèm @Transactional ở Service
    // ─────────────────────────────────────────────
    @Modifying
    @Query("DELETE FROM AIConversation c WHERE c.account.id = :accId")
    int deleteAllByAccountId(@Param("accId") Integer accId);

    // Bổ sung các phương thức theo gợi ý của AI module local:

    // [DÙNG CHO MẶC ĐỊNH] Lấy 5 tin nhắn gần nhất (tất cả intent) để build context cho AI
    // LEFT JOIN FETCH receipt để tránh N+1 query tReceipts (OneToOne mappedBy không lazy được)
    // Giảm từ 10 → 5 để tối ưu cho máy local (Dell M4800), đủ context cho AI mà không quá nặng
    @Query("SELECT c FROM AIConversation c LEFT JOIN FETCH c.receipt WHERE c.account.id = :accountId ORDER BY c.createdAt DESC LIMIT 5")
    List<AIConversation> findTop10ByAccountIdOrderByCreatedAtDesc(@Param("accountId") Integer accountId);

    // [DÙNG CHO REMINDER] Lấy 1 tin nhắn AI gần nhất (senderType = true) để kiểm tra action chờ confirm
    // LEFT JOIN FETCH receipt để tránh N+1 query tReceipts
    @Query("SELECT c FROM AIConversation c LEFT JOIN FETCH c.receipt WHERE c.account.id = :accountId AND c.senderType = :senderType ORDER BY c.createdAt DESC LIMIT 1")
    List<AIConversation> findTop1ByAccountIdAndSenderTypeOrderByCreatedAtDesc(
            @Param("accountId") Integer accountId,
            @Param("senderType") Boolean senderType
    );

    // [DÙNG CHO FALLBACK CATEGORY/NOTE] Lấy 5 tin nhắn user gần nhất (senderType = false)
    // LEFT JOIN FETCH receipt để tránh N+1 query tReceipts
    @Query("SELECT c FROM AIConversation c LEFT JOIN FETCH c.receipt WHERE c.account.id = :accountId AND c.senderType = :senderType ORDER BY c.createdAt DESC LIMIT 5")
    List<AIConversation> findTop5ByAccountIdAndSenderTypeOrderByCreatedAtDesc(
            @Param("accountId") Integer accountId,
            @Param("senderType") Boolean senderType
    );

    // [DÙNG CHO TƯ VẤN] Lấy 3 tin nhắn gần nhất theo intent cụ thể
    // LEFT JOIN FETCH receipt để tránh N+1 query tReceipts
    // Dùng 3 tin nhắn để đủ context cho tư vấn mà không quá nặng cho máy local (Dell M4800)
    @Query("SELECT c FROM AIConversation c LEFT JOIN FETCH c.receipt WHERE c.account.id = :accountId AND c.intent = :intent ORDER BY c.createdAt DESC LIMIT 3")
    List<AIConversation> findTop10ByAccountIdAndIntentOrderByCreatedAtDesc(
            @Param("accountId") Integer accountId,
            @Param("intent") Integer intent
    );

    // Lấy tất cả conversation của account (không phân trang, dùng khi xóa lịch sử)
    List<AIConversation> findByAccountId(Integer accountId);

    // Lấy conversation theo ID và accountId (đảm bảo bảo mật - chỉ trả về conversation của đúng user)
    Optional<AIConversation> findByIdAndAccountId(Integer conversationId, Integer accountId);

    // Xóa toàn bộ lịch sử chat của account
    @Modifying
    void deleteByAccount(Account account);
}
