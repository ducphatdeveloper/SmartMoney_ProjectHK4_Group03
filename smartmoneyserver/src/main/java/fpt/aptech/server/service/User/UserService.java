package fpt.aptech.server.service.User;

import fpt.aptech.server.dto.AccountDto;

public interface UserService {
    AccountDto getProfile(String email);
}