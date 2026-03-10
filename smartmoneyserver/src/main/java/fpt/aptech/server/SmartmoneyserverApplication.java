package fpt.aptech.server;

import org.springframework.boot.SpringApplication;
import org.springframework.boot.autoconfigure.SpringBootApplication;
import org.springframework.scheduling.annotation.EnableScheduling;

@SpringBootApplication
@EnableScheduling // Kích hoạt tính năng lập lịch (Scheduler)
public class SmartmoneyserverApplication {

    public static void main(String[] args) {
        SpringApplication.run(SmartmoneyserverApplication.class, args);
    }

}
