package fpt.aptech.server.api;

import fpt.aptech.server.entity.Permission;
import fpt.aptech.server.service.Permission.PermissionService;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.http.ResponseEntity;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.PathVariable;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RestController;

import java.util.List;

@RestController
@RequestMapping("/api/permissions")
public class PermissionController {

    @Autowired
    private PermissionService permissionService;

    // Lấy tất cả các quyền có trong hệ thống
    @GetMapping
    public ResponseEntity<List<Permission>> getAll() {
        return ResponseEntity.ok(permissionService.getAllPermissions());
    }

    // Lấy quyền theo nhóm module (ví dụ: 'DASHBOARD', 'USER_MANAGEMENT')
    @GetMapping("/group/{groupName}")
    public ResponseEntity<List<Permission>> getByGroup(@PathVariable String groupName) {
        return ResponseEntity.ok(permissionService.getPermissionsByGroup(groupName));
    }
}