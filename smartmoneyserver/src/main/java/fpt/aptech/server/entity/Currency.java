package fpt.aptech.server.entity;

import jakarta.persistence.Column;
import jakarta.persistence.Entity;
import jakarta.persistence.Id;
import jakarta.persistence.Table;
import lombok.AllArgsConstructor;
import lombok.Builder;
import lombok.Data;
import lombok.NoArgsConstructor;

@Entity
@Table(name = "tCurrencies")
@Data
@NoArgsConstructor
@AllArgsConstructor
@Builder
public class Currency {

    @Id
    @Column(name = "currency_code", length = 10)
    private String currencyCode;

    @Column(name = "currency_name", unique = true, nullable = false, length = 100)
    private String currencyName;

    @Column(name = "symbol", nullable = false, length = 10)
    private String symbol;

    @Column(name = "flag_url", unique = true, nullable = false, length = 500)
    private String flagUrl;
}