package fpt.aptech.server.dto.ai;

import com.fasterxml.jackson.annotation.JsonCreator;
import com.fasterxml.jackson.annotation.JsonProperty;
import jakarta.validation.constraints.NotBlank;
import jakarta.validation.constraints.NotNull;
import lombok.Builder;

import java.util.Map;

/**
 * [1] AiExecuteRequest — DTO nhận yêu cầu thực thi hành động từ Flutter.
 */
@Builder
public record AiExecuteRequest(
        // Bước 1: Validate loại hành động
        @NotBlank(message = "Action type cannot be empty")
        @JsonProperty("actionType")
        String actionType,          // Loại hành động (VD: create_transaction)

        // Bước 2: Validate tham số hành động
        @NotNull(message = "Action parameters cannot be empty")
        @JsonProperty("params")
        Map<String, Object> params  // Dữ liệu truyền vào cho hành động
) {
    @JsonCreator
    public static AiExecuteRequest create(
            @JsonProperty("actionType") String actionType,
            @JsonProperty("params") Map<String, Object> params) {
        return new AiExecuteRequest(actionType, params);
    }
}
