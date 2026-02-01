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
        configuration.setAllowedOrigins(Arrays.asList(
                "http://localhost:3000",      // React Dev
                "http://localhost:5173",      // Vite Dev
                "capacitor://localhost",      // Cho Mobile (nếu cần)
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