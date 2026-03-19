package fpt.aptech.server.service.notification;

/**
 * Carrier đơn giản chứa title + content đã được format sẵn.
 * Được trả về bởi NotificationMessages để truyền vào NotificationService.createNotification()
 */
public record NotificationContent(String title, String content) {}