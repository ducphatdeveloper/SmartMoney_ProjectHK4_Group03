import React, { useEffect, useState, useCallback } from 'react';
import { useNavigate } from 'react-router-dom';
import { transactionApi } from '../server/api';

// --- TRANSLATIONS DICTIONARY (Đồng bộ với Dashboard) ---
const translations = {
    vi: {
        history: "Lịch sử giao dịch",
        back: "Quay lại",
        income: "Thu nhập",
        expense: "Chi tiêu",
        total: "Tổng cộng",
        noTransactions: "Không có giao dịch nào trong khoảng thời gian này",
        loading: "Đang tải dữ liệu...",
        today: "Hôm nay",
        yesterday: "Hôm qua",
        thisWeek: "Tuần này",
        lastWeek: "Tuần trước",
        thisMonth: "Tháng này",
        lastMonth: "Tháng trước",
        thisQuarter: "Quý này",
        thisYear: "Năm nay",
        all: "Tất cả",
        searchPlaceholder: "Tìm kiếm giao dịch...",
    },
    en: {
        history: "Transaction History",
        back: "Back",
        income: "Income",
        expense: "Expense",
        total: "Total",
        noTransactions: "No transactions found for this period",
        loading: "Loading data...",
        today: "Today",
        yesterday: "Yesterday",
        thisWeek: "This Week",
        lastWeek: "Last Week",
        thisMonth: "This Month",
        lastMonth: "Last Month",
        thisQuarter: "This Quarter",
        thisYear: "This Year",
        all: "All",
        searchPlaceholder: "Search transactions...",
    }
};

const TransactionHistory = () => {
    const navigate = useNavigate();
    const [groups, setGroups] = useState([]); // DailyTransactionGroup
    const [summary, setSummary] = useState({ income: 0, expense: 0 });
    const [loading, setLoading] = useState(true);
    const [filterRange, setFilterRange] = useState('THIS_MONTH');
    const [lang] = useState(localStorage.getItem('adminLang') || 'vi');

    // Helper: Dịch thuật
    const t = (key) => translations[lang][key] || key;

    // Helper: Parse Date (Xử lý chuỗi hoặc mảng Jackson)
    const parseDate = (dateValue) => {
        if (!dateValue) return null;
        if (Array.isArray(dateValue)) {
            const [y, m, d, h = 0, min = 0, s = 0] = dateValue;
            return new Date(y, m - 1, d, h, min, s);
        }
        const date = new Date(dateValue);
        return isNaN(date.getTime()) ? null : date;
    };

    const formatCurrency = (amount) => {
        return new Intl.NumberFormat('vi-VN', { style: 'currency', currency: 'VND' }).format(amount || 0);
    };

    const fetchHistory = useCallback(async () => {
        setLoading(true);
        try {
            const params = { range: filterRange };
            const [journalRes, summaryRes] = await Promise.all([
                transactionApi.getJournal(params),
                transactionApi.getSummary(params)
            ]);

            if (journalRes.data.success) {
                setGroups(journalRes.data.data || []);
            }
            if (summaryRes.data.success) {
                const s = summaryRes.data.data;
                setSummary({
                    income: s.totalIncome || 0,
                    expense: s.totalExpense || 0
                });
            }
        } catch (error) {
            console.error("Lỗi khi tải lịch sử giao dịch:", error);
        } finally {
            setLoading(false);
        }
    }, [filterRange]);

    useEffect(() => {
        fetchHistory();
    }, [fetchHistory]);

    // Render từng icon dựa trên loại danh mục (giả định hoặc map từ backend)
    const getCategoryIcon = (categoryName) => {
        const name = (categoryName || "").toLowerCase();
        if (name.includes("ăn") || name.includes("food")) return { icon: "bi-egg-fried", color: "#f39c12" };
        if (name.includes("xăng") || name.includes("xe") || name.includes("transport")) return { icon: "bi-car-front", color: "#3498db" };
        if (name.includes("mua") || name.includes("shop")) return { icon: "bi-bag-check", color: "#e67e22" };
        if (name.includes("lương") || name.includes("salary")) return { icon: "bi-cash-stack", color: "#27ae60" };
        if (name.includes("quà") || name.includes("gift")) return { icon: "bi-gift", color: "#9b59b6" };
        return { icon: "bi-tags", color: "#95a5a6" };
    };

    return (
        <div className="min-vh-100 bg-light">
            {/* Header */}
            <div className="bg-white shadow-sm sticky-top">
                <div className="container py-3 d-flex align-items-center">
                    <button className="btn btn-link text-dark p-0 me-3" onClick={() => navigate(-1)}>
                        <i className="bi bi-arrow-left fs-4"></i>
                    </button>
                    <h5 className="mb-0 fw-bold">{t('history')}</h5>
                </div>
                
                {/* Quick Summary in Header */}
                <div className="container pb-3">
                    <div className="row g-2">
                        <div className="col-6">
                            <div className="bg-success-subtle p-2 rounded text-center">
                                <small className="text-success text-uppercase fw-bold extra-small" style={{fontSize: '0.65rem'}}>{t('income')}</small>
                                <div className="text-success fw-bold small">{formatCurrency(summary.income)}</div>
                            </div>
                        </div>
                        <div className="col-6">
                            <div className="bg-danger-subtle p-2 rounded text-center">
                                <small className="text-danger text-uppercase fw-bold extra-small" style={{fontSize: '0.65rem'}}>{t('expense')}</small>
                                <div className="text-danger fw-bold small">{formatCurrency(summary.expense)}</div>
                            </div>
                        </div>
                    </div>
                </div>
            </div>

            <div className="container py-4">
                {/* Filter Bar */}
                <div className="card border-0 shadow-sm rounded-4 mb-4">
                    <div className="card-body p-2">
                        <select 
                            className="form-select border-0 bg-transparent fw-bold text-primary"
                            value={filterRange}
                            onChange={(e) => setFilterRange(e.target.value)}
                        >
                            <option value="THIS_DAY">{t('today')}</option>
                            <option value="YESTERDAY">{t('yesterday')}</option>
                            <option value="THIS_WEEK">{t('thisWeek')}</option>
                            <option value="LAST_WEEK">{t('lastWeek')}</option>
                            <option value="THIS_MONTH">{t('thisMonth')}</option>
                            <option value="LAST_MONTH">{t('lastMonth')}</option>
                            <option value="THIS_QUARTER">{t('thisQuarter')}</option>
                            <option value="THIS_YEAR">{t('thisYear')}</option>
                        </select>
                    </div>
                </div>

                {/* Transactions List Grouped by Date */}
                {loading ? (
                    <div className="text-center py-5">
                        <div className="spinner-border text-primary" role="status"></div>
                        <p className="mt-2 text-muted">{t('loading')}</p>
                    </div>
                ) : groups.length === 0 ? (
                    <div className="text-center py-5">
                        <i className="bi bi-calendar-x display-4 text-muted opacity-25"></i>
                        <p className="mt-3 text-muted">{t('noTransactions')}</p>
                    </div>
                ) : (
                    groups.map((group, gIdx) => {
                        const dateObj = parseDate(group.date);
                        const isIncomeDay = (group.totalIncome || 0) > (group.totalExpense || 0);

                        return (
                            <div key={gIdx} className="card border-0 shadow-sm rounded-4 mb-4 overflow-hidden">
                                {/* Date Header */}
                                <div className="card-header bg-white border-bottom py-3 px-4 d-flex justify-content-between align-items-center">
                                    <div className="d-flex align-items-center">
                                        <div className="display-6 fw-bold me-3 text-dark">
                                            {dateObj ? dateObj.getDate() : '??'}
                                        </div>
                                        <div>
                                            <div className="fw-bold small text-dark">
                                                {dateObj ? dateObj.toLocaleDateString(lang === 'vi' ? 'vi-VN' : 'en-US', { weekday: 'long' }) : '---'}
                                            </div>
                                            <div className="text-muted extra-small">
                                                {dateObj ? dateObj.toLocaleDateString(lang === 'vi' ? 'vi-VN' : 'en-US', { month: 'long', year: 'numeric' }) : '---'}
                                            </div>
                                        </div>
                                    </div>
                                    <div className="text-end">
                                        <div className={`fw-bold ${isIncomeDay ? 'text-success' : 'text-dark'}`}>
                                            {formatCurrency((group.totalIncome || 0) - (group.totalExpense || 0))}
                                        </div>
                                    </div>
                                </div>

                                {/* Transactions in this day */}
                                <ul className="list-group list-group-flush">
                                    {group.transactions && group.transactions.map((transaction, tIdx) => {
                                        const meta = getCategoryIcon(transaction.categoryName || transaction.category);
                                        const isIncome = transaction.type === 'INCOME';
                                        
                                        return (
                                            <li key={tIdx} className="list-group-item border-0 px-4 py-3 d-flex align-items-center hover-bg-light cursor-pointer" 
                                                onClick={() => navigate(`/transactions/${transaction.id}`)}>
                                                <div 
                                                    className="rounded-circle p-2 me-3 d-flex align-items-center justify-content-center" 
                                                    style={{ backgroundColor: meta.color, width: '45px', height: '45px' }}
                                                >
                                                    <i className={`bi ${meta.icon} text-white fs-5`}></i>
                                                </div>
                                                <div className="flex-grow-1">
                                                    <h6 className="mb-0 fw-bold text-dark">{transaction.categoryName || transaction.category}</h6>
                                                    {transaction.note && (
                                                        <div className="text-muted small text-truncate" style={{maxWidth: '200px'}}>
                                                            {transaction.note}
                                                        </div>
                                                    )}
                                                    <div className="text-muted extra-small d-md-none">
                                                        {transaction.walletName || 'Ví chính'}
                                                    </div>
                                                </div>
                                                <div className="text-end">
                                                    <div className={`fw-bold ${isIncome ? 'text-success' : 'text-danger'}`}>
                                                        {isIncome ? '+ ' : '- '}{formatCurrency(transaction.amount)}
                                                    </div>
                                                    <div className="text-muted extra-small d-none d-md-block">
                                                        {transaction.walletName || 'Ví chính'}
                                                    </div>
                                                </div>
                                            </li>
                                        );
                                    })}
                                </ul>
                            </div>
                        );
                    })
                )}
            </div>
            
            {/* Floating Action Button (Optional - Thêm nhanh giao dịch) */}
            <button 
                className="btn btn-primary rounded-circle shadow-lg position-fixed" 
                style={{ bottom: '30px', right: '30px', width: '60px', height: '60px', zIndex: 1000 }}
                onClick={() => navigate('/transactions/create')}
            >
                <i className="bi bi-plus-lg fs-3"></i>
            </button>

            <style dangerouslySetInnerHTML={{ __html: `
                .extra-small { font-size: 0.75rem; }
                .hover-bg-light:hover { background-color: #f8f9fa; transition: 0.2s; }
                .cursor-pointer { cursor: pointer; }
                .bg-success-subtle { background-color: #e8f5e9; }
                .bg-danger-subtle { background-color: #ffebee; }
            `}} />
        </div>
    );
};

export default TransactionHistory;