package fpt.aptech.server.service.Permission;

import fpt.aptech.server.entity.Permission;

import java.util.List;


public interface PermissionService {
    List<Permission> getAllPermissions();
    List<Permission> getPermissionsByGroup(String group);
}
