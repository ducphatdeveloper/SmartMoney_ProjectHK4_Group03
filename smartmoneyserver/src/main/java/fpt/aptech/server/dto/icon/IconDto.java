package fpt.aptech.server.dto.icon;

/**
 * DTO (Data Transfer Object) cho thông tin của một icon.
 *
 * @param fileName Tên file đầy đủ (ví dụ: "icon_food.png"), dùng để lưu vào database.
 * @param url      URL đầy đủ (https) của icon, dùng để Flutter hiển thị.
 */
public record IconDto(
        String fileName,
        String url
) {
}
