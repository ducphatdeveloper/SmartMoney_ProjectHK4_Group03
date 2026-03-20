package fpt.aptech.server.config;

import org.springframework.context.annotation.Bean;
import org.springframework.context.annotation.Configuration;
import org.springframework.web.cors.CorsConfiguration;
import org.springframework.web.cors.CorsConfigurationSource;
import org.springframework.web.cors.UrlBasedCorsConfigurationSource;
import org.springframework.web.servlet.config.annotation.ResourceHandlerRegistry;
import org.springframework.web.servlet.config.annotation.WebMvcConfigurer;

import java.util.Arrays;
import java.util.Collections;

@Configuration
public class WebConfig implements WebMvcConfigurer {

    @Override
    public void addResourceHandlers(ResourceHandlerRegistry registry) {
        registry.addResourceHandler("/images/**")
                .addResourceLocations("file:uploads/images/");
    }

    /**
     * 2. Cấu hình CORS chi tiết dưới dạng Bean
     * Cấu hình này sẽ được tiêm (inject) vào SecurityConfig để kiểm soát truy cập từ Frontend
     */
    @Bean
    public CorsConfigurationSource corsConfigurationSource() {
        CorsConfiguration configuration = new CorsConfiguration();

        // Cho phép các nguồn (Origins) truy cập - Bạn có thể thêm URL Production vào đây
        // SỬ DỤNG setAllowedOriginPatterns thay vì setAllowedOrigins
        configuration.setAllowedOriginPatterns(Arrays.asList(
                "http://localhost:[*]",       // Cho Flutter Web
                "http://127.0.0.1:[*]",      // Cho Flutter Web (dự phòng)

                // CHO ANDROID EMULATOR (MÁY ẢO)
                "http://10.0.2.2:[*]",       // Mặc định của Android Studio Emulator
                "http://10.0.3.2:[*]",       // Mặc định của Genymotion (nếu dùng)

                // CHO ANDROID REAL DEVICE (MÁY THẬT) & MẠNG TRƯỜNG/NHÀ
                "http://192.168.[*]:[*]",    // Dải IP Lớp C (Nhà/Cafe)
                "http://172.[*]:[*]",        // Dải IP Lớp B (Trường học/Công ty)
                "http://10.[*]:[*]",         // Dải IP Lớp A (Mạng nội bộ lớn)

                "capacitor://localhost",
                "ionic://localhost"
        ));

        // Cho phép các phương thức HTTP
        configuration.setAllowedMethods(Arrays.asList(
                "GET", "POST", "PUT", "DELETE", "PATCH", "OPTIONS"
        ));

        // Cho phép các Headers cần thiết cho JWT và Request
        configuration.setAllowedHeaders(Arrays.asList(
                "Authorization",
                "Content-Type",
                "X-Requested-With",
                "Accept",
                "Origin"
        ));

        // Tiết lộ Header Authorization để Frontend (React) có thể đọc được Token
        configuration.setExposedHeaders(Collections.singletonList("Authorization"));

        // Cho phép gửi Credentials (Cookies, Auth Headers)
        configuration.setAllowCredentials(true);

        // Thời gian cache cấu hình CORS (1 giờ)
        configuration.setMaxAge(3600L);

        UrlBasedCorsConfigurationSource source = new UrlBasedCorsConfigurationSource();
        source.registerCorsConfiguration("/**", configuration);
        return source;
    }
}