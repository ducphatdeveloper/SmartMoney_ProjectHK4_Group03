package fpt.aptech.server.service;

import org.springframework.stereotype.Service;

import java.time.LocalDateTime;
import java.util.Map;
import java.util.concurrent.ConcurrentHashMap;

@Service
public class UserActivityService {
    // Map lưu trữ: Key = Username, Value = Last Active Time
    private final Map<String, LocalDateTime> activeUsersMap = new ConcurrentHashMap<>();

    public void logActivity(String username) {
        activeUsersMap.put(username, LocalDateTime.now());
    }

    public long countOnlineUsers(int minutesInactivity) {
        LocalDateTime limit = LocalDateTime.now().minusMinutes(minutesInactivity);
        
        // Loại bỏ những user đã không hoạt động quá thời gian quy định
        activeUsersMap.entrySet().removeIf(entry -> entry.getValue().isBefore(limit));
        
        return activeUsersMap.size();
    }
}