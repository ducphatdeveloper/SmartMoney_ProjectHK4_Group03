package fpt.aptech.server.entity;

import jakarta.persistence.*;
import lombok.AllArgsConstructor;
import lombok.Builder;
import lombok.Data;
import lombok.NoArgsConstructor;

import java.math.BigDecimal;

@Entity
@Table(name = "tWallets")
@Data
@NoArgsConstructor
@AllArgsConstructor
@Builder
public class Wallet {

    @Id
    @GeneratedValue(strategy = GenerationType.IDENTITY)
    private Integer id;

    @ManyToOne
    @JoinColumn(name = "acc_id", nullable = false)
    private Account account;

    @ManyToOne
    @JoinColumn(name = "currency", nullable = false)
    private Currency currency;

    @Column(name = "wallet_name", nullable = false, length = 100)
    private String walletName;

    @Column(name = "balance", precision = 18, scale = 2)
    private BigDecimal balance = BigDecimal.ZERO;

    @Column(name = "notified", nullable = false)
    private Boolean notified = true;

    @Column(name = "reportable", nullable = false)
    private Boolean reportable = true;

    @Column(name = "goal_image_url", length = 2048)
    private String goalImageUrl;
}