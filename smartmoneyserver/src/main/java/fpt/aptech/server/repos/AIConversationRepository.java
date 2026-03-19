package fpt.aptech.server.repos;

import fpt.aptech.server.entity.AIConversation;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.data.jpa.repository.Query;
import org.springframework.data.repository.query.Param;
import org.springframework.stereotype.Repository;

import java.util.List;

@Repository
public interface AIConversationRepository extends JpaRepository<AIConversation, Integer> {

    /**
     * Lấy N tin nhắn gần nhất của user để làm context cho Gemini.
     * Sắp xếp DESC để lấy mới nhất, sau đó đảo ngược thứ tự ở Service.
     */
    @Query("SELECT c FROM AIConversation c WHERE c.account.id = :accId ORDER BY c.createdAt DESC LIMIT :limit")
    List<AIConversation> findRecentByAccountId(
            @Param("accId") Integer accId,
            @Param("limit") int limit);

    /**
     * Lấy toàn bộ lịch sử chat của user (phân trang ở Controller).
     */
    List<AIConversation> findByAccount_IdOrderByCreatedAtDesc(Integer accId);
}