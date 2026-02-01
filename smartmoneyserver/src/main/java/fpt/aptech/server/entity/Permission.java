package fpt.aptech.server.entity;

import jakarta.persistence.*;
import lombok.*;

/**
 * Bảng quyền hệ thống (master data).
 * Định nghĩa các quyền chi tiết trong hệ thống.
 */
@Entity
@Table(name = "tPermissions")
@Getter
@Setter
@NoArgsConstructor
@AllArgsConstructor
@Builder
public class Permission {

    @Id
    @GeneratedValue(strategy = GenerationType.IDENTITY)
    private Integer id;

    // Mã quyền, dùng để kiểm tra trong code (VD: "CREATE_BUDGET")
    @Column(name = "per_code", unique = true, nullable = false, length = 50)
    private String perCode;

    // Tên quyền, dùng để hiển thị trên UI
    @Column(name = "per_name", unique = true, nullable = false, length = 100)
    private String perName;

    // Nhóm module mà quyền này thuộc về (VD: "USER_CORE", "ADMIN_CORE")
    @Column(name = "module_group", nullable = false, length = 50)
    private String moduleGroup;
}