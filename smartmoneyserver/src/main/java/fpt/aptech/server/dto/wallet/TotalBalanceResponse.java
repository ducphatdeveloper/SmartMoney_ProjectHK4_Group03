    package fpt.aptech.server.dto.wallet;

    import lombok.Builder;

    import java.math.BigDecimal;

    @Builder
    public record TotalBalanceResponse(
        BigDecimal totalBalance
    ) {}
