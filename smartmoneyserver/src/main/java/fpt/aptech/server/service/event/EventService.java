package fpt.aptech.server.service.event;

import fpt.aptech.server.dto.event.EventCreateRequest;
import fpt.aptech.server.dto.event.EventResponse;
import fpt.aptech.server.dto.event.EventUpdateRequest;
import fpt.aptech.server.dto.transaction.view.DailyTransactionGroup;
import fpt.aptech.server.dto.transaction.view.TransactionResponse;

import java.util.List;

public interface EventService {

    /**
     * Lấy danh sách sự kiện của một user.
     * @param accId ID của user.
     * @param isFinished Lọc theo trạng thái (true: đã kết thúc, false: đang diễn ra).
     * @return Danh sách các sự kiện kèm theo tổng thu/chi.
     */
    List<EventResponse> getEvents(Integer accId, Boolean isFinished);

    /**
     * Lấy chi tiết một sự kiện.
     * @param eventId ID của sự kiện.
     * @param accId ID của user để kiểm tra quyền.
     * @return Chi tiết sự kiện.
     */
    EventResponse getEvent(Integer eventId, Integer accId);

    /**
     * Lấy danh sách các giao dịch thuộc về một sự kiện.
     * @param eventId ID của sự kiện.
     * @param accId ID của user để kiểm tra quyền.
     * @return Danh sách các giao dịch (DTO).
     */
    List<TransactionResponse> getEventTransactions(Integer eventId, Integer accId);

    /**
     * Tạo một sự kiện mới.
     * @param request DTO chứa thông tin sự kiện.
     * @param accId ID của user tạo sự kiện.
     * @return Sự kiện đã được tạo.
     */
    EventResponse createEvent(EventCreateRequest request, Integer accId);

    /**
     * Cập nhật thông tin một sự kiện.
     * @param eventId ID của sự kiện cần cập nhật.
     * @param request DTO chứa thông tin mới.
     * @param accId ID của user để kiểm tra quyền.
     * @return Sự kiện đã được cập nhật.
     */
    EventResponse updateEvent(Integer eventId, EventUpdateRequest request, Integer accId);

    /**
     * Cập nhật trạng thái 'finished' của một sự kiện.
     * Dùng cho nút "Đánh dấu hoàn tất" / "Đánh dấu chưa hoàn tất".
     * @param eventId ID của sự kiện.
     * @param accId ID của user để kiểm tra quyền.
     * @return Sự kiện đã được cập nhật trạng thái.
     */
    EventResponse updateEventStatus(Integer eventId, Integer accId);

    /**
     * Xóa mềm một sự kiện.
     * Giao dịch thuộc sự kiện được GIỮ LẠI (set event_id = null), KHÔNG xóa mềm.
     * Chỉ Wallet / SavingGoal (nguồn tiền) mới cascade xóa mềm giao dịch.
     *
     * @param eventId ID của sự kiện cần xóa.
     * @param accId ID của user để kiểm tra quyền.
     */
    void deleteEvent(Integer eventId, Integer accId);

    /**
     * Lấy danh sách các giao dịch thuộc về một sự kiện, đã được nhóm theo ngày.
     * @param eventId ID của sự kiện.
     * @param accId ID của user để kiểm tra quyền.
     * @return Danh sách các nhóm giao dịch theo ngày.
     */
    List<DailyTransactionGroup> getEventTransactionsGrouped(Integer eventId, Integer accId);
}
