package fpt.aptech.server.dto.ai;

import jakarta.validation.constraints.NotBlank;
import jakarta.validation.constraints.NotNull;
import lombok.Builder;

import java.util.Map;

/**
 * DTO nhận yêu cầu xác nhận hành động từ client (sau khi AI gợi ý).
 *
 * 1. actionType — Loại hành động: "create_transaction" (bắt buộc)
 * 2. params     — Tham số giao dịch: categoryId, walletId, amount, note, sourceType, aiChatId, ... (bắt buộc)
 */
@Builder
public record AiExecuteRequest(

    @NotBlank(message = "Loại hành động không được để trống.")
    String actionType,

    @NotNull(message = "Tham số không được để trống.")
    Map<String, Object> params

) {}

