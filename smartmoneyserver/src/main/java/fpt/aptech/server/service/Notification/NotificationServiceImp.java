package fpt.aptech.server.service.Notification;

import fpt.aptech.server.entity.Notification;
import fpt.aptech.server.repos.NotificationRepository;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.stereotype.Service;

import java.util.List;

@Service
public class NotificationServiceImp implements NotificationService {
    @Autowired
    private NotificationRepository notificationRepository;

    @Override
    public List<Notification> getMyNotifications(Integer accId) {
        return notificationRepository.findAllByAccount_IdOrderByScheduledTimeDesc(accId);
    }

    @Override
    public void markAsSent(Integer notificationId) {
        notificationRepository.findById(notificationId).ifPresent(n -> {
            n.setNotifySent(true);
            notificationRepository.save(n);
        });
    }
}
