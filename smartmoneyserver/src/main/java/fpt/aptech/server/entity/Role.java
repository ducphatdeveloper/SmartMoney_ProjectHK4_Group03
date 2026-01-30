package fpt.aptech.server.entity;

import jakarta.persistence.*;
import lombok.AllArgsConstructor;
import lombok.Builder;
import lombok.Getter;
import lombok.NoArgsConstructor;
import lombok.Setter;

import java.util.Set;

/**
 * Bảng vai trò người dùng (master data).
 * Xác định các vai trò như "ROLE_ADMIN", "ROLE_USER".
 */
@Entity
@Table(name = "tRoles")
@Getter
@Setter
@NoArgsConstructor
@AllArgsConstructor
@Builder
public class Role {

    @Id
    @GeneratedValue(strategy = GenerationType.IDENTITY)
    private Integer id;

    // Mã vai trò, dùng trong code (VD: "ROLE_USER")
    @Column(name = "role_code", unique = true, nullable = false, length = 50)
    private String roleCode;

    // Tên vai trò, dùng để hiển thị (VD: "Người dùng tiêu chuẩn")
    @Column(name = "role_name", unique = true, nullable = false, length = 100)
    private String roleName;

    // Danh sách các quyền thuộc về vai trò này.
    // EAGER fetch được dùng để Spring Security tải quyền ngay khi xác thực.
    @ManyToMany(fetch = FetchType.EAGER)
    @JoinTable(
            name = "tRolePermissions",
            joinColumns = @JoinColumn(name = "role_id"),
            inverseJoinColumns = @JoinColumn(name = "per_id")
    )
    private Set<Permission> permissions;
}