package fpt.aptech.server.repos;

import fpt.aptech.server.entity.Event;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.stereotype.Repository;

import java.util.List;

@Repository
public interface EventRepository extends JpaRepository<Event, Integer> {
    /**
     * Tìm tất cả sự kiện của một user dựa trên trạng thái 'finished'.
     * Dùng cho 2 tab "Đang diễn ra" và "Đã kết thúc".
     * @param accountId ID của user.
     * @param isFinished Trạng thái hoàn thành (true hoặc false).
     * @return Danh sách các sự kiện.
     */
    List<Event> findAllByAccountIdAndFinished(Integer accountId, Boolean isFinished);
}
