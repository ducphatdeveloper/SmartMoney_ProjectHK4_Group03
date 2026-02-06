package fpt.aptech.server.dto.savinggoals.request;

import jakarta.validation.constraints.NotBlank;
import jakarta.validation.constraints.NotNull;
import lombok.Getter;
import lombok.Setter;

@Getter
@Setter
public class AddSavingMemberRequest {

    @NotNull
    private Integer accId;

    /**
     * CO_OWNER | MEMBER
     */
    @NotBlank
    private String role;
}

