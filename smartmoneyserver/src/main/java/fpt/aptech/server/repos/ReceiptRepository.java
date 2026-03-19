package fpt.aptech.server.repos;

import fpt.aptech.server.entity.Receipt;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.stereotype.Repository;

import java.util.List;
import java.util.Optional;

@Repository
public interface ReceiptRepository extends JpaRepository<Receipt, Integer> {

    /**
     * Lấy danh sách hóa đơn của user theo trạng thái.
     * pending | processed | error
     */
    List<Receipt> findByAccount_IdAndReceiptStatusOrderByCreatedAtDesc(
            Integer accId, String receiptStatus);

    /**
     * Lấy hóa đơn theo conversation ID + kiểm tra quyền sở hữu.
     */
    Optional<Receipt> findByIdAndAccount_Id(Integer id, Integer accId);
}