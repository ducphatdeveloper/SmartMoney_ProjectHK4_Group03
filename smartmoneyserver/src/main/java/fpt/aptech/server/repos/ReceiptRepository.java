package fpt.aptech.server.repos;

import fpt.aptech.server.entity.Receipt;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.data.jpa.repository.Query;
import org.springframework.data.repository.query.Param;
import org.springframework.stereotype.Repository;

import java.util.List;
import java.util.Optional;

@Repository
public interface ReceiptRepository extends JpaRepository<Receipt, Integer> {

    // ─────────────────────────────────────────────
    // [4.1] Lấy danh sách hóa đơn của user theo trạng thái
    // Dùng cho: hiển thị lịch sử hóa đơn đã quét
    // ─────────────────────────────────────────────
    @Query("""
        SELECT r FROM Receipt r
        WHERE r.account.id = :accId
        AND (:status IS NULL OR r.receiptStatus = :status)
        ORDER BY r.createdAt DESC
        """)
    List<Receipt> findByAccountIdAndStatus(
            @Param("accId") Integer accId,
            @Param("status") String status
    );
}