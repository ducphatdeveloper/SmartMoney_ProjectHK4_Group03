package fpt.aptech.server.service.User;

import fpt.aptech.server.dto.AccountDto;
import org.springframework.web.multipart.MultipartFile;

public interface UserService {
    AccountDto getProfile(String email);

    String updateAvatar(Integer accId, MultipartFile file);
}