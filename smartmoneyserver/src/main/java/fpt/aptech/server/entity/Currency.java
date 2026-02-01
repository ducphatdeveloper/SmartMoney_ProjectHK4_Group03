package fpt.aptech.server.entity;

import jakarta.persistence.Column;
import jakarta.persistence.Entity;
import jakarta.persistence.Id;
import jakarta.persistence.Table;
import lombok.*;

/**
 * Bảng tiền tệ (master data).
 * Lưu thông tin các loại tiền tệ được hệ thống hỗ trợ.
 */
@Entity
@Table(name = "tCurrencies")
@Getter
@Setter
@NoArgsConstructor
@AllArgsConstructor
@Builder
public class Currency {

    // Mã tiền tệ (VD: "VND", "USD"). Khóa chính.
    @Id
    @Column(name = "currency_code", length = 10)
    private String currencyCode;

    // Tên đầy đủ (VD: "Việt Nam Đồng")
    @Column(name = "currency_name", unique = true, nullable = false, length = 100)
    private String currencyName;

    // Ký hiệu (VD: "₫", "$")
    @Column(name = "symbol", nullable = false, length = 10)
    private String symbol;

    // URL cờ quốc gia
    @Column(name = "flag_url", unique = true, nullable = false, length = 500)
    private String flagUrl;
}