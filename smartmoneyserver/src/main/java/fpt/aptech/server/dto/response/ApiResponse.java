package fpt.aptech.server.dto.response;

import lombok.AllArgsConstructor;
import lombok.Builder;
import lombok.Data;
import lombok.NoArgsConstructor;

import java.time.LocalDateTime;

/**
 * Lớp cấu trúc phản hồi API dùng chung cho toàn hệ thống.
 * Giúp thống nhất dữ liệu trả về giữa Backend và Frontend (React).
 */
@Data
@NoArgsConstructor
@AllArgsConstructor
@Builder
public class ApiResponse<T> {

    // Trạng thái thành công (true) hoặc thất bại (false)
    private Boolean success;

    // Thông báo phản hồi (ví dụ: "Đăng ký thành công", "Mật khẩu không khớp")
    private String message;

    // Dữ liệu trả về (có thể là một Object, một List, hoặc Map các lỗi validate)
    private T data;

    // Thời điểm phản hồi được tạo
    private LocalDateTime timestamp;

    /**
     * Phản hồi thành công CÓ kèm theo dữ liệu.
     * Thường dùng cho các hàm Get hoặc Post trả về thông tin đối tượng.
     */
    public static <T> ApiResponse<T> success(T data, String message) {
        return ApiResponse.<T>builder()
                .success(true)
                .message(message)
                .data(data)
                .timestamp(LocalDateTime.now())
                .build();
    }

    /**
     * Phản hồi thành công NHƯNG KHÔNG kèm dữ liệu.
     * Thường dùng cho các thao tác như Xóa hoặc Cập nhật đơn giản.
     */
    public static <T> ApiResponse<T> success(String message) {
        return ApiResponse.<T>builder()
                .success(true)
                .message(message)
                .timestamp(LocalDateTime.now())
                .build();
    }

    /**
     * Phản hồi lỗi chỉ kèm theo thông báo.
     * Thường dùng cho các lỗi hệ thống, lỗi 404, 403.
     */
    public static <T> ApiResponse<T> error(String message) {
        return ApiResponse.<T>builder()
                .success(false)
                .message(message)
                .timestamp(LocalDateTime.now())
                .build();
    }

    /**
     * Phản hồi lỗi CÓ kèm theo dữ liệu chi tiết.
     * ĐẶC BIỆT QUAN TRỌNG: Dùng để trả về danh sách lỗi validate từ DTO (@Valid).
     * Field 'data' lúc này thường là một Map<String, String> chứa (tên_trường : thông_báo_lỗi).
     */
    public static <T> ApiResponse<T> error(String message, T data) {
        return ApiResponse.<T>builder()
                .success(false)
                .message(message)
                .data(data)
                .timestamp(LocalDateTime.now())
                .build();
    }
}