package fpt.aptech.server.repos.Currency;

import fpt.aptech.server.entity.Currency;
import org.springframework.data.jpa.repository.JpaRepository;

public interface CurrencyRepository extends JpaRepository<Currency, String> {}
