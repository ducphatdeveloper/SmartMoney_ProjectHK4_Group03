package fpt.aptech.server.dto;

import lombok.AllArgsConstructor;
import lombok.Builder;
import lombok.Data;
import lombok.NoArgsConstructor;

import java.util.Set;

@Data
@Builder
@NoArgsConstructor
@AllArgsConstructor
public class UserInfoDTO {
    private Integer id;
    private String email;
    private String phone;
    private String avatarUrl;

    // Thông tin phân quyền
    private Integer roleId;          // ID của vai trò
    private String roleName;         // Ví dụ: "Quản trị viên", "Người dùng"
    private String roleCode;         // Ví dụ: "ROLE_ADMIN", "ROLE_USER"
    private Set<String> permissions;  // Danh sách các perCode: (VD: "USER_STANDARD_MANAGE", "ADMIN_SYSTEM_ALL")

    // Thông tin cấu hình hệ thống của người dùng
    private String currencyCode;     // Ví dụ: "VND", "USD"
    private Boolean isLocked;        // Trạng thái tài khoản
}