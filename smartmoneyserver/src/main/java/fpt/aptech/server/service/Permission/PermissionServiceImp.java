package fpt.aptech.server.service.Permission;

import fpt.aptech.server.entity.Permission;
import fpt.aptech.server.repos.PermissionRepository;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.stereotype.Service;

import java.util.List;

@Service
public class PermissionServiceImp implements PermissionService {

    @Autowired
    private PermissionRepository permissionRepository;

    @Override
    public List<Permission> getAllPermissions() {
        return permissionRepository.findAll();
    }

    @Override
    public List<Permission> getPermissionsByGroup(String group) {
        return permissionRepository.findByModuleGroup(group);
    }
}
