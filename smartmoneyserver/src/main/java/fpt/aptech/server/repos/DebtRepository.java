package fpt.aptech.server.repos;

import fpt.aptech.server.entity.Debt;
import org.springframework.data.jpa.repository.JpaRepository;
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
}