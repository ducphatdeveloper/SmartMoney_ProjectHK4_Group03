package fpt.aptech.server.dto.request;

import jakarta.validation.constraints.*;
import lombok.Data;

@Data
public class RegisterRequest {
    // Thêm bọc ngoặc và dấu hỏi chấm ở cuối để cho phép để trống
    @Pattern(regexp = "^0\\d{9,10}$", message = "Số điện thoại phải bắt đầu bằng 0 và có 10 hoặc 11 chữ số"
    )
    private String accPhone;


    @Email(message = "Email không hợp lệ")
    private String accEmail;

    @NotBlank(message = "Mật khẩu không được để trống")
    @Size(min = 6, max = 50, message = "Mật khẩu phải từ 6-50 ký tự")
    private String password;

    @NotBlank(message = "Xác nhận mật khẩu không được để trống")
    private String confirmPassword;

    // Custom validation: Phải có ít nhất phone HOẶC email
    @AssertTrue(message = "Phải cung cấp ít nhất số điện thoại hoặc email")
    public boolean isValidIdentity() {
        return (accPhone != null && !accPhone.isBlank()) ||
                (accEmail != null && !accEmail.isBlank());
    }

    // Custom validation: Password phải trùng confirmPassword
    @AssertTrue(message = "Mật khẩu xác nhận không khớp")
    public boolean isPasswordMatching() {
        if (password == null) return false;
        return password.equals(confirmPassword);
    }
}