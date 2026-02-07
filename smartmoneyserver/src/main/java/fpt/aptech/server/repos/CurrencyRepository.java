package fpt.aptech.server.repos;

import fpt.aptech.server.entity.Currency;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.stereotype.Repository;

import java.util.Optional;

@Repository
public interface CurrencyRepository extends JpaRepository<Currency,String> {
    /**
     * Tìm kiếm tiền tệ dựa trên mã (Currency Code).
     * Mặc dù findById đã làm được việc này, nhưng định nghĩa rõ ràng giúp code dễ đọc hơn.
     */
    Optional<Currency> findByCurrencyCode(String currencyCode);

    /**
     * Kiểm tra xem một mã tiền tệ đã tồn tại trong hệ thống chưa.
     */
    boolean existsByCurrencyCode(String currencyCode);

    // Nếu entity Currency có thêm trường status (trạng thái),
    // bạn có thể thêm: List<Currency> findByActiveTrue();
}
