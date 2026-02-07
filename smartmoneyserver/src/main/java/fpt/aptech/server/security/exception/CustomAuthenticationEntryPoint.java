package fpt.aptech.server.security.exception;

import com.fasterxml.jackson.databind.ObjectMapper;
import fpt.aptech.server.dto.response.ApiResponse;
import jakarta.servlet.ServletException;
import jakarta.servlet.http.HttpServletRequest;
import jakarta.servlet.http.HttpServletResponse;
import lombok.RequiredArgsConstructor;
import org.springframework.http.MediaType;
import org.springframework.security.core.AuthenticationException;
import org.springframework.security.web.AuthenticationEntryPoint;
import org.springframework.stereotype.Component;

import java.io.IOException;

@Component
@RequiredArgsConstructor // Dùng để tự động tạo constructor cho final field
public class CustomAuthenticationEntryPoint implements AuthenticationEntryPoint {

    // Inject bean ObjectMapper đã được Spring cấu hình sẵn
    private final ObjectMapper objectMapper;

    @Override
    public void commence(HttpServletRequest request, HttpServletResponse response, AuthenticationException authException) throws IOException, ServletException {
        response.setStatus(HttpServletResponse.SC_UNAUTHORIZED); // 401
        response.setContentType(MediaType.APPLICATION_JSON_VALUE);
        response.setCharacterEncoding("UTF-8");

        ApiResponse<Void> apiResponse = ApiResponse.error("Vui lòng đăng nhập để tiếp tục (401 Unauthorized)");

        // Dùng objectMapper đã được inject, không cần new nữa
        response.getWriter().write(objectMapper.writeValueAsString(apiResponse));
    }
}