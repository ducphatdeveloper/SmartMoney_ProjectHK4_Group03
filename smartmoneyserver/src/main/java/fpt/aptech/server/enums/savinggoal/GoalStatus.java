package fpt.aptech.server.enums.savinggoal;

import lombok.Getter;

/**
 * Định nghĩa trạng thái của một mục tiêu tiết kiệm.
 * Dùng cho tSavingGoals.goal_status
 */
@Getter
public enum GoalStatus {
    ACTIVE(1),          // Đang hoạt động, trong thời gian tiết kiệm
    COMPLETED(2),       // Đã hoàn thành (đủ tiền)
    CANCELLED(3),       // Người dùng chủ động hủy
    OVERDUE(4);         // Đã quá hạn nhưng chưa đủ tiền

    private final int value;

    GoalStatus(int value) {
        this.value = value;
    }
}