package fpt.aptech.server.repos;

import fpt.aptech.server.entity.AIConversation;
import org.springframework.data.domain.Page;
import org.springframework.data.domain.Pageable;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.data.jpa.repository.Modifying;
import org.springframework.data.jpa.repository.Query;
import org.springframework.data.repository.query.Param;
import org.springframework.stereotype.Repository;

import java.util.List;

@Repository
public interface AIConversationRepository extends JpaRepository<AIConversation, Integer> {
    // ─────────────────────────────────────────────
    // [3.1] Lấy lịch sử chat của user, sắp xếp mới nhất trước
    // Dùng cho: load chat history khi mở màn hình AI
    // ─────────────────────────────────────────────
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
}