package fpt.aptech.server.repos;

import fpt.aptech.server.entity.Transaction;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.stereotype.Repository;

import java.util.List;

@Repository
public interface TransactionRepository extends JpaRepository<Transaction, Long> {

    // =================================================================================
    // CÁC HÀM LẤY DỮ LIỆU (VIEW)
    // =================================================================================

    /// [VIEW] Lấy danh sách giao dịch của một người dùng (không bao gồm các giao dịch đã xóa).
    /// SELECT ... FROM tTransactions WHERE acc_id = ? AND deleted = false ORDER BY trans_date DESC
    List<Transaction> findByAccountIdAndDeletedFalseOrderByTransDateDesc(Integer accountId);


    // =================================================================================
    // CÁC HÀM KIỂM TRA (VALIDATE) TRƯỚC KHI XÓA CÁC ENTITY LIÊN QUAN
    // =================================================================================

    /// [VALIDATE-DELETE] Kiểm tra xem một danh mục đã được sử dụng trong giao dịch nào chưa.
    boolean existsByCategoryIdAndDeletedFalse(Integer categoryId);

    /// [VALIDATE-DELETE] Kiểm tra xem một ví đã được sử dụng trong giao dịch nào chưa.
    boolean existsByWalletIdAndDeletedFalse(Integer walletId);

}
