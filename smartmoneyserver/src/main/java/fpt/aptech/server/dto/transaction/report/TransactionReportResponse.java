package fpt.aptech.server.dto.transaction.report;

import lombok.Builder;

import java.math.BigDecimal;

/**
 * DTO trả về dữ liệu tổng quan cho màn hình "Báo cáo" (Tab Báo cáo).
 * Bao gồm:
 * 1. Phần Header: Tổng quan tài chính (Vào/Ra/Ròng) + Số dư đầu/cuối kỳ.
 * 2. Phần Thống kê: Nhóm Nợ/Vay/Khác (trả về số tiền để hiển thị ở footer).
 */
@Builder
public record TransactionReportResponse(
    // --- Số dư ---
    BigDecimal openingBalance, // Số dư đầu kỳ
    BigDecimal closingBalance, // Số dư cuối kỳ

    // --- Tổng quan trong kỳ ---
    BigDecimal totalIncome,  // Tổng tiền thu vào
    BigDecimal totalExpense, // Tổng tiền chi ra
    BigDecimal netIncome,    // Thu nhập ròng (Thu - Chi)

    // --- 3. Nhóm Nợ/Vay/Khác (Phần Footer - Click để xem chi tiết) ---
    // Trả về số tiền để hiển thị theo nhóm chuyên biệt (dùng cho footer trên UI)
    // debtAmount: Tổng tiền của tất cả giao dịch thuộc category "Đi vay" (DEBT_BORROWING = 20)
    BigDecimal debtAmount,
    // loanAmount: Tổng tiền của tất cả giao dịch thuộc category "Cho vay" (DEBT_LENDING = 19)
    BigDecimal loanAmount,
    // otherAmount: Số tiền còn lại = tổng(Thu nợ DEBT_COLLECTION = 21) - tổng(Trả nợ DEBT_REPAYMENT = 22)
    // Ví dụ: Thu nợ 22.222 - Trả nợ 11.111 => otherAmount = 11.111
    BigDecimal otherAmount
)
{}
