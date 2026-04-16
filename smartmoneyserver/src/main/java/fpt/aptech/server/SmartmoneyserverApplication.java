package fpt.aptech.server;

import org.springframework.boot.SpringApplication;
import org.springframework.boot.autoconfigure.SpringBootApplication;
import org.springframework.cache.annotation.EnableCaching;
import org.springframework.scheduling.annotation.EnableAsync; // Import EnableAsync
import org.springframework.scheduling.annotation.EnableScheduling;

@SpringBootApplication
@EnableScheduling // Kích hoạt tính năng lập lịch (Scheduler)
@EnableCaching    // Kích hoạt tính năng Cache của Spring
@EnableAsync      // Kích hoạt tính năng xử lý bất đồng bộ (@Async)
public class SmartmoneyserverApplication {

    public static void main(String[] args) {
        SpringApplication.run(SmartmoneyserverApplication.class, args);
    }

}
