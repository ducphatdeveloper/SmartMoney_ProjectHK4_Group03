package fpt.aptech.server.entity;

import jakarta.persistence.*;
import lombok.AllArgsConstructor;
import lombok.Builder;
import lombok.Getter;
import lombok.NoArgsConstructor;
import lombok.Setter;

import java.math.BigDecimal;

/**
 * Bảng ví tiền.
 * VD: "Tiền mặt", "Vietcombank", "Momo".
 */
@Entity
@Table(name = "tWallets")
@Getter
@Setter
@NoArgsConstructor
@AllArgsConstructor
@Builder
public class Wallet {

    @Id
    @GeneratedValue(strategy = GenerationType.IDENTITY)
    private Integer id;

    // Tài khoản sở hữu ví.
    @ManyToOne(fetch = FetchType.LAZY)
    @JoinColumn(name = "acc_id", nullable = false)
    private Account account;

    // Loại tiền tệ của ví.
    @ManyToOne(fetch = FetchType.LAZY)
    @JoinColumn(name = "currency", referencedColumnName = "currency_code", nullable = false)
    private Currency currency;

    // Tên ví (VD: "Tiền mặt")
    @Column(name = "wallet_name", nullable = false, length = 100)
    private String walletName;

    // Số dư hiện tại.
    @Column(name = "balance", precision = 18, scale = 2)
    private BigDecimal balance = BigDecimal.ZERO;

    // Bật/tắt thông báo cho ví này.
    @Column(name = "notified", nullable = false)
    private Boolean notified = true;

    // Có tính vào báo cáo tổng quan hay không.
    @Column(name = "reportable", nullable = false)
    private Boolean reportable = true;

    // Hình ảnh của ví (nếu có).
    @Column(name = "goal_image_url", length = 2048)
    private String goalImageUrl;
}