package fpt.aptech.server.config;

import fpt.aptech.server.filter.JwtAuthenticationFilter;
import fpt.aptech.server.security.exception.CustomAccessDeniedHandler;
import fpt.aptech.server.security.exception.CustomAuthenticationEntryPoint;
import lombok.RequiredArgsConstructor;
import org.springframework.context.annotation.Bean;
import org.springframework.context.annotation.Configuration;
import org.springframework.security.authentication.AuthenticationProvider;
import org.springframework.security.config.annotation.method.configuration.EnableMethodSecurity;
import org.springframework.security.config.annotation.web.builders.HttpSecurity;
import org.springframework.security.config.annotation.web.configuration.EnableWebSecurity;
import org.springframework.security.config.annotation.web.configurers.AbstractHttpConfigurer;
import org.springframework.security.config.http.SessionCreationPolicy;
import org.springframework.security.web.SecurityFilterChain;
import org.springframework.security.web.authentication.UsernamePasswordAuthenticationFilter;
import org.springframework.web.cors.CorsConfigurationSource;

@Configuration
@EnableWebSecurity
@EnableMethodSecurity
@RequiredArgsConstructor
public class SecurityConfig {

    // Các thành phần này được Spring tự động tiêm (inject) từ ApplicationConfig và WebConfig
    private final JwtAuthenticationFilter jwtAuthenticationFilter;
    private final CorsConfigurationSource corsConfigurationSource;
    private final AuthenticationProvider authenticationProvider;

    // Inject 2 bộ xử lý lỗi tùy chỉnh
    private final CustomAccessDeniedHandler accessDeniedHandler;
    private final CustomAuthenticationEntryPoint authenticationEntryPoint;

    @Bean
    public SecurityFilterChain securityFilterChain(HttpSecurity http) throws Exception {
        http
                // 1. Vô hiệu hóa CSRF vì chúng ta dùng JWT (Stateless)
                .csrf(AbstractHttpConfigurer::disable)

                // 2. Cấu hình CORS từ WebConfig
                .cors(cors -> cors.configurationSource(corsConfigurationSource))

                // 3. Phân quyền truy cập các Endpoint
                .authorizeHttpRequests(auth -> auth
                        // Public API
                        .requestMatchers("/api/auth/**", "/api/test/**", "/error").permitAll()

                        // Admin API -> Yêu cầu quyền ADMIN_SYSTEM_ALL (trong bảng tPermissions)
                        .requestMatchers("/api/admin/**").hasAuthority("ADMIN_SYSTEM_ALL")

                        // User API -> Yêu cầu quyền USER_STANDARD_MANAGE (trong bảng tPermissions)
                        .requestMatchers("/api/user/**").hasAuthority("USER_STANDARD_MANAGE")

                        // =================================================================
                        // CÔNG TẮC TEST: Bỏ comment dòng dưới để mở tất cả API (Không cần Token)
                        //.requestMatchers("/api/**").permitAll()
                        // =================================================================

                        // Các API còn lại -> Chỉ cần ĐÃ ĐĂNG NHẬP là được vào
                        // (Quyền cụ thể ADMIN hay USER sẽ do @PreAuthorize ở Controller check)
                        .anyRequest().authenticated()
                )

                // 4. Cấu hình xử lý lỗi (Exception Handling) - MỚI THÊM
                .exceptionHandling(exception -> exception
                        .accessDeniedHandler(accessDeniedHandler)           // Xử lý 403
                        .authenticationEntryPoint(authenticationEntryPoint) // Xử lý 401
                )

                // 5. Cấu hình Session là Stateless (không lưu session trên server)
                .sessionManagement(session -> session
                        .sessionCreationPolicy(SessionCreationPolicy.STATELESS)
                )

                // 6. Thiết lập Provider xác thực đã được định nghĩa ở ApplicationConfig
                .authenticationProvider(authenticationProvider)

                // 7. Thêm Filter kiểm tra JWT trước Filter xác thực mặc định
                .addFilterBefore(jwtAuthenticationFilter, UsernamePasswordAuthenticationFilter.class);

        return http.build();
    }
}