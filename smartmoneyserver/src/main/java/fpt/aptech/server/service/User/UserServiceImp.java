package fpt.aptech.server.service.User;

import fpt.aptech.server.dto.AccountDto;
import fpt.aptech.server.entity.Account;
import fpt.aptech.server.repos.AccountRepository;
import lombok.RequiredArgsConstructor;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

@Service
@RequiredArgsConstructor
public class UserServiceImp implements UserService {

    private final AccountRepository accountRepository;

    @Override
    @Transactional(readOnly = true)
    public AccountDto getProfile(String email) {
        Account account = accountRepository.findByAccEmail(email)
                .orElseThrow(() -> new RuntimeException("User not found"));
        return new AccountDto(account);
    }
}