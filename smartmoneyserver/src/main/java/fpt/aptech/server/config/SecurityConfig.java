package fpt.aptech.server.config;

import fpt.aptech.server.filter.JwtAuthenticationFilter;
import org.springframework.context.annotation.Bean;
import org.springframework.context.annotation.Configuration;
import org.springframework.security.authentication.AuthenticationManager;
import org.springframework.security.config.annotation.authentication.configuration.AuthenticationConfiguration;
import org.springframework.security.config.annotation.method.configuration.EnableMethodSecurity;
import org.springframework.security.config.annotation.web.builders.HttpSecurity;
import org.springframework.security.config.annotation.web.configuration.EnableWebSecurity;
import org.springframework.security.config.annotation.web.configurers.AbstractHttpConfigurer;
import org.springframework.security.crypto.bcrypt.BCryptPasswordEncoder;
import org.springframework.security.web.SecurityFilterChain;
import org.springframework.security.web.authentication.UsernamePasswordAuthenticationFilter;
import org.springframework.web.cors.CorsConfiguration;

import java.util.Arrays;
import java.util.List;

@Configuration
@EnableWebSecurity
@EnableMethodSecurity // <--- THÊM DÒNG NÀY: Để sài được @PreAuthorize trên Controller
public class SecurityConfig {

    // Inject bộ lọc JWT (do bạn Nam viết) để xử lý token
    private final JwtAuthenticationFilter jwtAuthenticationFilter;
    public SecurityConfig(JwtAuthenticationFilter jwtAuthenticationFilter) {
        this.jwtAuthenticationFilter = jwtAuthenticationFilter;
    }

    // Bean mã hóa mật khẩu. Dùng BCrypt là chuẩn ngành rồi.
    @Bean
    public BCryptPasswordEncoder passwordEncoder() {
        return new BCryptPasswordEncoder();
    }

    // Bean quản lý xác thực (Dùng để gọi hàm login trong AuthController)
    @Bean
    public AuthenticationManager authenticationManager(AuthenticationConfiguration configuration) throws Exception {
        return configuration.getAuthenticationManager();
    }

    // --- CẤU HÌNH CHÍNH CỦA BẢO MẬT (Cái này quan trọng nhất) ---
    @Bean
    SecurityFilterChain securityFilterChain(HttpSecurity http) throws Exception {
        http
            // 1. Tắt CSRF: Vì mình làm API (Stateless) cho Mobile/React nên không cần cái này.
            // Nếu làm Web MVC truyền thống (JSP/Thymeleaf) thì mới cần bật.
            .csrf(AbstractHttpConfigurer::disable)

            // 2. Phân quyền truy cập (Ai được vào đâu)
            .authorizeHttpRequests((authorize) -> authorize
                // Cho phép vào tự do các link này (Login, Register, và API Categories để test)
                // Sau này hoàn thiện thì xóa bớt "/api/**" đi nhé.
                .requestMatchers("/api/auth/**", "/api/categories/**", "/api/**").permitAll()
                
                // Còn lại tất cả các link khác bắt buộc phải có Token mới được vào
                .anyRequest().authenticated()
            )

            // 3. Chèn bộ lọc JWT vào trước bộ lọc đăng nhập mặc định
            // Để nó kiểm tra Token trong Header trước khi xử lý tiếp.
            .addFilterBefore(jwtAuthenticationFilter, UsernamePasswordAuthenticationFilter.class)

            // 4. Cấu hình CORS (Quan trọng cho Frontend Web/Mobile)
            // Giúp trình duyệt không chặn khi Flutter Web/React gọi API từ cổng khác (VD: 55907 gọi sang 9999).
            .cors(cors -> cors.configurationSource(request -> {
                CorsConfiguration configuration = new CorsConfiguration();
                configuration.setAllowedOrigins(List.of("*")); // Cho phép mọi nguồn gọi vào
                configuration.setAllowedMethods(Arrays.asList("GET", "POST", "PUT", "DELETE", "OPTIONS")); // Cho phép mọi hành động
                configuration.setAllowedHeaders(List.of("*")); // Cho phép mọi header
                return configuration;
            }));
            
        return http.build();
    }
}