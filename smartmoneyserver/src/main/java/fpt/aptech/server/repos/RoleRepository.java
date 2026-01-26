package fpt.aptech.server.repos;

import fpt.aptech.server.entity.Role;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.stereotype.Repository;

import java.util.Optional;

@Repository
public interface RoleRepository extends JpaRepository<Role, Integer> {
    // Tìm kiếm Role theo mã (VD: ROLE_ADMIN, ROLE_USER)
    Optional<Role> findByRoleCode(String roleCode);
}