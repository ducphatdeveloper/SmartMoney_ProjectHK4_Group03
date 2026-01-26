package fpt.aptech.server.dto;

import lombok.Data;

import java.util.Set;

@Data
public class UserInfoDTO {
    private Integer id;
    private String email;
    private String phone;
    private String avatarUrl;
    private String roleName;       // Tên vai trò: ADMIN, USER...
    private Set<String> permissions; // Danh sách các mã quyền (per_code)
}