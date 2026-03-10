package fpt.aptech.server.config;

import com.google.auth.oauth2.GoogleCredentials;
import com.google.firebase.FirebaseApp;
import com.google.firebase.FirebaseOptions;
import lombok.extern.slf4j.Slf4j;
import org.springframework.context.annotation.Configuration;
import org.springframework.core.io.ClassPathResource;

import javax.annotation.PostConstruct;
import java.io.IOException;
import java.io.InputStream;

// @Configuration: Đánh dấu đây là class cấu hình, Spring Boot tự load khi khởi động.
@Configuration
// @Slf4j: Tạo biến `log` để ghi log ra console.
@Slf4j
public class FirebaseConfig {

    /**
     * Khởi tạo Firebase Admin SDK khi server start.
     * @PostConstruct: Chạy method này SAU KHI Spring Boot tạo xong Bean này.
     */
    @PostConstruct
    public void initFirebase() {
        // Chỉ khởi tạo nếu chưa có FirebaseApp nào đang chạy (tránh khởi tạo 2 lần)
        if (FirebaseApp.getApps().isEmpty()) {
            try {
                // Bước 1: Đọc file serviceAccountKey.json từ thư mục resources
                InputStream serviceAccount =
                        new ClassPathResource("serviceAccountKey.json").getInputStream();

                // Bước 2: Tạo cấu hình Firebase từ file key
                FirebaseOptions options = FirebaseOptions.builder()
                        .setCredentials(GoogleCredentials.fromStream(serviceAccount))
                        .build();

                // Bước 3: Khởi tạo FirebaseApp với cấu hình trên
                FirebaseApp.initializeApp(options);

                log.info("✅ Firebase Admin SDK đã khởi tạo thành công!");

            } catch (IOException e) {
                // Nếu không tìm thấy file key → log lỗi rõ ràng
                log.error("❌ Không thể khởi tạo Firebase: {}", e.getMessage());
                throw new RuntimeException("Khởi tạo Firebase thất bại!", e);
            }
        }
    }
}