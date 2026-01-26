package fpt.aptech.server.repos;

import fpt.aptech.server.entity.Permission;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.stereotype.Repository;

import java.util.List;

@Repository
public interface PermissionRepository extends JpaRepository<Permission, Integer> {
    // Tìm các quyền theo nhóm module (VD: hiển thị tất cả quyền thuộc nhóm 'REPORT')
    List<Permission> findByModuleGroup(String moduleGroup);
}
