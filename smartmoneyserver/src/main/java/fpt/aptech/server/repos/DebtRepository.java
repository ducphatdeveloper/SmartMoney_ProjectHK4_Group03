package fpt.aptech.server.repos;

import fpt.aptech.server.entity.Debt;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.data.jpa.repository.Modifying;
import org.springframework.data.jpa.repository.Query;
import org.springframework.data.repository.query.Param;
import org.springframework.stereotype.Repository;

import java.util.List;
import java.util.Optional;

@Repository
public interface DebtRepository extends JpaRepository<Debt, Integer> {

    /// [VIEW] Lấy tất cả khoản nợ theo loại (cả chưa xong lẫn đã xong)
    /// Dùng cho Tab CẦN TRẢ (debtType=false) và Tab CẦN THU (debtType=true)
    /// Flutter tự chia 2 header: "CHƯA TRẢ" / "ĐÃ TRẢ HẾT" dựa theo field finished
    List<Debt> findAllByAccount_IdAndDebtTypeOrderByCreatedAtDesc(
            Integer accountId, Boolean debtType);

    /// [VALIDATE] Kiểm tra debt có thuộc về user không (dùng trong getOwnedDebt)
    Optional<Debt> findByIdAndAccount_Id(Integer id, Integer accountId);

    // [FIX] Xóa Debt bằng JPQL DELETE trực tiếp (không qua entity lifecycle).
    // Dùng thay cho debtRepository.delete(debt) trong DebtCalculationServiceImpl.recalculateDebt()
    // để tránh TransientObjectException: khi dùng delete(entity), Hibernate đánh dấu entity là REMOVED
    // → các entity khác (Transaction) vẫn giữ reference → flush sẽ báo lỗi.
    // JPQL DELETE không thay đổi trạng thái entity trong 1L cache → an toàn hơn.
    @Modifying
    @Query("DELETE FROM Debt d WHERE d.id = :id")
    void deleteByDebtId(@Param("id") Integer id);
}