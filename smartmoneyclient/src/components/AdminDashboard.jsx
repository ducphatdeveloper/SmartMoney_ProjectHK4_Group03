import React, { useEffect, useState, useCallback, useRef, useMemo } from 'react';
import { useNavigate, useLocation } from 'react-router-dom';
import { adminApi, authApi, notificationApi, utilApi } from '../server/api';
import { Chart as ChartJS, CategoryScale, LinearScale, PointElement, LineElement, BarElement, Title, Tooltip, Legend, ArcElement } from 'chart.js';
import { Bar, Doughnut } from 'react-chartjs-2';

ChartJS.register(CategoryScale, LinearScale, PointElement, LineElement, BarElement, Title, Tooltip, Legend, ArcElement);

const translations = {
    vi: {
        dashboard: "Tổng quan", users: "Người dùng", contactRequests: "Yêu cầu hỗ trợ", totalUsers: "Tổng Người dùng", onlineUsers: "Người dùng trực tuyến",
        transactions: "Giao dịch hệ thống", flowAnalysis: "Phân tích dòng tiền", categoryDetail: "Phân bổ danh mục (%)", ratioInExp: "Tỷ lệ Thu - Chi (%)",
        abnormalTrans: "Giao dịch bất thường", scanNow: "Gửi thông báo ({count})", scanning: "Đang quét...", detected: "Phát hiện: {count} người dùng",
        noAbnormal: "Không có ai vượt ngưỡng", autoLogout: "Thu hồi phiên quá hạn", loggingOut: "Đang xử lý...", searchPlaceholder: "Tìm kiếm user...",
        status: "Trạng thái", online: "Trực tuyến", offline: "Ngoại tuyến", phone: "SĐT", id: "ID", items: "{count} mục", connection: "Kết nối",
        active: "Hoạt động", locked: "Đã khóa", actions: "Thao tác", logout: "Đăng xuất", sysNotify: "Thông báo hệ thống", userDetails: "Chi tiết người dùng",
        userInsights: "Phân tích tài chính cá nhân", userTransHistory: "Lịch sử giao dịch chi tiết", viewAll: "Xem tất cả", noTrans: "Chưa có giao dịch nào",
        noNotify: "Không có thông báo mới", confirmLock: "Khóa tài khoản?", confirmUnlock: "Mở khóa tài khoản?", 
        confirmDescLock: "Hành động này sẽ ngăn chặn người dùng truy cập hệ thống.", confirmDescUnlock: "Hành động này sẽ cho phép người dùng truy cập lại.",
        confirm: "Xác nhận", cancel: "Hủy", week: "Tuần", month: "Tháng", year: "Năm", income: "Thu nhập", expense: "Chi tiêu",
        page: "Trang {current} / {total}", notifySuccess: "Thao tác thành công.", notifyError: "Lỗi hệ thống.", 
        autoLogoutSuccess: "Đã thu hồi các phiên đăng nhập ngoại tuyến quá hạn.", sessionExpired: "Phiên đăng nhập hết hạn.", accountLocked: "Tài khoản bị khóa.",
        requestType: "Loại yêu cầu", priority: "Độ ưu tiên", sender: "Người gửi", resolve: "Xử lý", approve: "Chấp nhận", reject: "Từ chối", takeRequest: "Tiếp nhận",
        adminNote: "Ghi chú của Admin", notePlaceholder: "Nhập phản hồi hoặc ghi chú xử lý...", viewRequest: "Chi tiết yêu cầu", history: "Lịch sử",
        PENDING: "Chờ xử lý", PROCESSING: "Đang xử lý", APPROVED: "Đã duyệt", REJECTED: "Đã từ chối", URGENT: "KHẨN CẤP", HIGH: "Cao", NORMAL: "Thường",
        SUSPICIOUS_TX: "Giao dịch bất thường", EMERGENCY: "Khẩn cấp", ACCOUNT_LOCK: "Khóa tài khoản", ACCOUNT_UNLOCK: "Mở khóa tài khoản", DATA_LOSS: "Mất dữ liệu",
        FORGOT_PASSWORD: "Quên mật khẩu", BUG_REPORT: "Báo lỗi", DATA_RECOVERY: "Khôi phục dữ liệu", GENERAL: "Góp ý / Câu hỏi",
        filterTrans: "Lọc giao dịch", allTrans: "Tất cả giao dịch", deletedTrans: "Giao dịch đã xóa", activeTrans: "Giao dịch hiện tại", markAllRead: "Đọc hết",
        transactionType: "Loại giao dịch", allTypes: "Tất cả loại", incomeType: "Thu nhập", expenseType: "Chi tiêu", prevPage: "Trước", nextPage: "Sau",
        deletedStatus: "Trạng thái xóa", ACTIVE: "Đang hoạt động", DELETED: "Đã xóa", ALL: "Tất cả trạng thái",
        day: "Ngày", quarter: "Quý", future: "Tương lai", loading: "Đang tải...", createdAt: "Ngày gửi",
        netFlow: "Dòng tiền thuần", totalVolume: "Tổng khối lượng", weight: "Tỷ trọng", today: "Hôm nay"
    },
    en: {
        dashboard: "Dashboard", users: "Users", contactRequests: "Support Requests", totalUsers: "Total Users", onlineUsers: "Online Users",
        transactions: "System Transactions", flowAnalysis: "Cash Flow Analysis", categoryDetail: "Category Breakdown (%)", ratioInExp: "Income - Expense Ratio (%)",
        abnormalTrans: "Abnormal Activities", scanNow: "Notify Users ({count})", scanning: "Scanning...", detected: "Detected: {count} users",
        noAbnormal: "No abnormal activities", autoLogout: "Revoke Overdue Sessions", loggingOut: "Processing...", searchPlaceholder: "Search users...",
        status: "Status", online: "Online", offline: "Offline", phone: "Phone", id: "ID", items: "{count} items", connection: "Connection",
        active: "Active", locked: "Locked", actions: "Actions", logout: "Logout", sysNotify: "System Notifications", userDetails: "User Details",
        userInsights: "Personal Financial Insights", userTransHistory: "Detailed Transaction History", viewAll: "View All", noTrans: "No transactions found",
        noNotify: "No new notifications", confirmLock: "Lock Account?", confirmUnlock: "Unlock Account?", 
        confirmDescLock: "This action will prevent the user from accessing the system.", confirmDescUnlock: "This action will allow the user to access the system again.",
        confirm: "Confirm", cancel: "Cancel", week: "Week", month: "Month", year: "Year", income: "Income", expense: "Expense",
        page: "Page {current} of {total}", notifySuccess: "Action successful.", notifyError: "System error.", 
        autoLogoutSuccess: "Overdue offline sessions revoked successfully.", sessionExpired: "Session expired.", accountLocked: "Account has been locked.",
        requestType: "Request Type", priority: "Priority", sender: "Sender", resolve: "Resolve", approve: "Approve", reject: "Reject", takeRequest: "Process",
        adminNote: "Admin Note", notePlaceholder: "Enter feedback or processing notes...", viewRequest: "Request Details", history: "History",
        PENDING: "Pending", PROCESSING: "Processing", APPROVED: "Approved", REJECTED: "Rejected", URGENT: "URGENT", HIGH: "High", NORMAL: "Normal",
        SUSPICIOUS_TX: "Suspicious Transaction", EMERGENCY: "Emergency", ACCOUNT_LOCK: "Account Lock", ACCOUNT_UNLOCK: "Account Unlock", DATA_LOSS: "Data Loss",
        FORGOT_PASSWORD: "Forgot Password", BUG_REPORT: "Bug Report", DATA_RECOVERY: "Data Recovery", GENERAL: "General / Feedback",
        filterTrans: "Filter Transactions", allTrans: "All Transactions", deletedTrans: "Deleted Transactions", activeTrans: "Current Transactions",
        markAllRead: "Mark all as read", transactionType: "Transaction Type", allTypes: "All Types", incomeType: "Income", expenseType: "Expense",
        prevPage: "Prev", nextPage: "Next", deletedStatus: "Deleted Status", ACTIVE: "Active", DELETED: "Deleted", ALL: "All Status",
        day: "Day", quarter: "Quarter", future: "Future", loading: "Loading...", createdAt: "Created At",
        netFlow: "Net Cash Flow", totalVolume: "Total Volume", weight: "Weight", today: "Today"
    }
};

const AdminDashboard = () => {
    const navigate = useNavigate();
    const location = useLocation();
    const rangeScrollRef = useRef(null);

    // --- STATE ---
    const [activeTab, setActiveTab] = useState('overview'); 
    const [lang, setLang] = useState(localStorage.getItem('adminLang') || 'vi');
    const [stats, setStats] = useState({ totalUsers: 0, totalTransactions: 0, activeDevices: 0 });
    const [users, setUsers] = useState([]);
    const [transactionStats, setTransactionStats] = useState(null);
    const [notifications, setNotifications] = useState([]);
    const [isSyncing, setIsSyncing] = useState(false);
    const [abnormalUsers, setAbnormalUsers] = useState([]);
    const [contactRequests, setContactRequests] = useState([]);
    const [filterStatus, setFilterStatus] = useState('');
    const [filterType, setFilterType] = useState('');
    const [filterPriority, setFilterPriority] = useState('');
    const [resolveModal, setResolveModal] = useState({ show: false, request: null, adminNote: '', loading: false });
    const [highlightRequestId, setHighlightRequestId] = useState(null);
    const [searchTerm, setSearchTerm] = useState('');
    const [filterLocked, setFilterLocked] = useState('');
    const [filterOnline, setFilterOnline] = useState('');
    const [page, setPage] = useState(0);
    const [totalPages, setTotalPages] = useState(0);
    const [rangeMode, setRangeMode] = useState('DAILY'); 
    const [dateRanges, setDateRanges] = useState([]);
    const [selectedRange, setSelectedRange] = useState(null);
    const [loadingRanges, setLoadingRanges] = useState(false);
    const [loading, setLoading] = useState(false);
    const [notifying, setNotifying] = useState(false);
    const [autoLoggingOut, setAutoLoggingOut] = useState(false);
    const [loadingAbnormal, setLoadingAbnormal] = useState(false);
    const [showNotifications, setShowNotifications] = useState(false);
    const [confirmModal, setConfirmModal] = useState({ show: false, userId: null, isLocked: false });
    const [detailModal, setDetailModal] = useState({ 
        show: false, user: null, insights: null, transactions: [], 
        deletedStatus: 'ACTIVE', userTransCurrentPage: 0, userTransTotalPages: 0, userTransFilterType: '', 
    });
    const [loadingDetail, setLoadingDetail] = useState(false);
    const [viewingAllTrans, setViewingAllTrans] = useState(false);

    // --- TRANSLATION HELPER ---
    const t = useCallback((key, params = {}) => {
        let text = translations[lang][key] || key;
        Object.keys(params).forEach(p => { text = text.replace(`{${p}}`, params[p]); });
        return text;
    }, [lang]);

    const toggleLang = (l) => { setLang(l); localStorage.setItem('adminLang', l); };

    // --- HELPER FUNCTIONS ---
    const formatDate = useCallback((d) => d ? new Date(d).toLocaleString(lang === 'vi' ? 'vi-VN' : 'en-US', {
        year: 'numeric', month: '2-digit', day: '2-digit', hour: '2-digit', minute: '2-digit'
    }) : '', [lang]);

    const formatCurrency = useCallback((val) => {
        return new Intl.NumberFormat(lang === 'vi' ? 'vi-VN' : 'en-US').format(val) + (lang === 'vi' ? ' đ' : ' VND');
    }, [lang]);

    const wrapLabel = useCallback((label, maxLength = 18) => {
        if (!label) return '';
        return label.length <= maxLength ? label : label.substring(0, maxLength) + '...';
    }, []);

    const scrollRanges = (direction) => {
        if (rangeScrollRef.current) {
            const scrollAmount = 300;
            rangeScrollRef.current.scrollBy({ left: direction === 'left' ? -scrollAmount : scrollAmount, behavior: 'smooth' });
        }
    };

    // --- API CALLS ---
    const handleLogout = useCallback(async (reason = '') => {
        try { await authApi.logout('web-browser'); } catch (err) { console.error(err); } finally {
            const langCache = localStorage.getItem('adminLang'); localStorage.clear();
            if (langCache) localStorage.setItem('adminLang', langCache);
            if (reason) alert(reason); navigate('/login');
        }
    }, [navigate]);

    const fetchOnlineCount = useCallback(async () => {
        try {
            const onlineRes = await adminApi.getOnlineUsers();
            if (onlineRes.data && onlineRes.data.success) {
                const newCount = onlineRes.data.data;
                setStats(prev => ({ ...prev, activeDevices: newCount }));
            }
        } catch (err) { console.error("Heartbeat error:", err); }
    }, []);

    const fetchStats = useCallback(async (isBackground = false) => {
        try {
            if (!isBackground) setIsSyncing(true);
            const res = await adminApi.getStats();
            const data = res.data.success ? res.data.data : res.data;
            if (data) setStats(prev => ({ ...data, activeDevices: prev.activeDevices }));
            await fetchOnlineCount();
        } catch (err) { console.error(err); }
        finally { if (!isBackground) setTimeout(() => setIsSyncing(false), 1000); }
    }, [fetchOnlineCount]);

    const fetchTransactionStats = useCallback(async (range) => {
        if (!range) return;
        try {
            const params = { startDate: range.startDate, endDate: range.endDate };
            const res = await adminApi.getSystemTransactionStats(params);
            if (res.data && res.data.success) { setTransactionStats(res.data.data); }
        } catch (err) { console.error(err); }
    }, []);

    const fetchDateRanges = useCallback(async (mode) => {
        setLoadingRanges(true);
        try {
            const res = await utilApi.getDateRanges(mode);
            if (res.data.success) {
                const ranges = res.data.data;
                setDateRanges(ranges);
                const currentRange = ranges.find(r => r.type === 'CURRENT') || ranges[ranges.length - 1];
                setSelectedRange(currentRange);
                if (currentRange) fetchTransactionStats(currentRange);
            }
        } catch (err) { console.error("Fetch ranges error:", err); } finally { setLoadingRanges(false); }
    }, [fetchTransactionStats]);

    const handleModeChange = useCallback((mode) => {
        if (mode !== rangeMode) {
            setRangeMode(mode);
        }
    }, [rangeMode]);

    const handleRangeChange = useCallback((range) => {
        setSelectedRange(range);
        fetchTransactionStats(range);
    }, [fetchTransactionStats]);

    const fetchAbnormalUsers = useCallback(async (isBackground = false) => {
        if (!isBackground) setLoadingAbnormal(true);
        try {
            // Sử dụng ngưỡng số 5.000.000
            const res = await adminApi.getAbnormalUsers(5000000);
            if (res.data && res.data.success) { setAbnormalUsers(res.data.data || []); }
        } catch (err) { console.error("Lỗi lấy danh sách bất thường:", err); } finally { if (!isBackground) setLoadingAbnormal(false); }
    }, []);

    const fetchContactRequests = useCallback(async (isBackground = false) => {
        if (!isBackground) setLoading(true);
        try {
            const res = await adminApi.getAllContactRequests({ status: filterStatus, type: filterType, priority: filterPriority });
            if (res.data.success) { setContactRequests(res.data.data || []); }
        } catch (err) { console.error("Fetch contact requests error:", err); } finally { if (!isBackground) setLoading(false); }
    }, [filterStatus, filterType, filterPriority]);

    const fetchNotifications = useCallback(async () => {
        try {
            // Sử dụng endpoint chuẩn cho Admin lấy thông báo hệ thống (notifyType=4)
            const res = await notificationApi.getAdminSystemNotifications();
            const data = res.data.success ? res.data.data : res.data; 
            setNotifications(data || []);
        } catch (err) { console.error(err); }
    }, []);

    const handleNotificationClick = async (n) => {
        try {
            await notificationApi.markAsRead(n.id); 
            fetchNotifications();
            if (n.notifyType === 4 || n.type === 4) {
                setHighlightRequestId(n.relatedId); 
                setActiveTab('contacts'); 
                setShowNotifications(false);
                navigate('/admin/contact-requests');
            }
        } catch (err) { console.error("Error marking notification as read:", err); }
    };

    const handleMarkAllAsRead = async () => {
        try {
            await notificationApi.markAllAsRead(); 
            fetchNotifications();
        } catch (err) { console.error("Error marking all read:", err); }
    };

    const fetchUsers = useCallback(async (isBackground = false) => {
        if (!isBackground) setLoading(true);
        try {
            const params = { page, size: 8 };
            if (searchTerm?.trim()) params.search = searchTerm.trim();
            if (filterLocked === 'true' || filterLocked === 'false') { params.locked = filterLocked === 'true'; }
            if (filterOnline === 'true') params.onlineStatus = 'ONLINE';
            if (filterOnline === 'false') params.onlineStatus = 'OFFLINE';
            const res = await adminApi.getUsers(params);
            const apiData = res.data.success ? res.data.data : res.data;
            if (apiData) {
                setUsers(apiData.content || []);
                setTotalPages(apiData.totalPages || 0);
            }
        } catch (err) { console.error("Fetch users error:", err); setUsers([]); } 
        finally { if (!isBackground) setLoading(false); }
    }, [page, searchTerm, filterLocked, filterOnline]);

    const fetchUserTransactions = useCallback(async (userId, pageNum, deletedStatus, transactionType) => {
        setLoadingDetail(true);
        try {
            const params = { page: pageNum, size: 5, deletedStatus, type: transactionType || '' };
            const transRes = await adminApi.getUserTransactions(userId, params);
            if (transRes.data.success) {
                setDetailModal(prev => ({
                    ...prev, transactions: transRes.data.data.content || [],
                    userTransCurrentPage: transRes.data.data.number,
                    userTransTotalPages: transRes.data.data.totalPages,
                }));
            }
        } catch (err) {
            console.error("Error fetching user transactions:", err);
            setDetailModal(prev => ({ ...prev, transactions: [], userTransCurrentPage: 0, userTransTotalPages: 0 }));
        } finally { setLoadingDetail(false); }
    }, []);

    const handleViewDetails = useCallback(async (user) => {
        const userId = Number(user.id); setLoadingDetail(true);
        setDetailModal(prev => ({ 
            ...prev, show: true, user, insights: null, transactions: [], deletedStatus: 'ACTIVE',
            userTransCurrentPage: 0, userTransTotalPages: 0, userTransFilterType: '', 
        }));
        try {
            const insightsRes = await adminApi.getUserFinancialInsights(userId);
            setDetailModal(prev => ({ ...prev, insights: insightsRes.data.success ? insightsRes.data.data : null, }));
            await fetchUserTransactions(userId, 0, 'ACTIVE', '');
        } catch (err) { console.error("Error fetching user details:", err); }
    }, [fetchUserTransactions]);

    const handleGoToUser = useCallback((userEmail) => {
        setActiveTab('users');
        setSearchTerm(userEmail);
        setFilterLocked('');
        setFilterOnline('');
        setPage(0);
    }, []);

    const handleResolveRequest = async (status) => {
        const { request, adminNote } = resolveModal; if (!request) return;
        setResolveModal(prev => ({ ...prev, loading: true }));
        try {
            const res = await adminApi.resolveContactRequest(request.id, { requestStatus: status, adminNote: adminNote });
            if (res.data.success) {
                alert(t('notifySuccess'));
                setResolveModal({ show: false, request: null, adminNote: '', loading: false });
                fetchContactRequests(); fetchStats(); 
            }
        } catch (err) { alert(t('notifyError')); } finally { setResolveModal(prev => ({ ...prev, loading: false })); }
    };

    const handleCardClick = useCallback((type) => {
        setActiveTab('users');
        if (type === 'TOTAL') { setSearchTerm(''); setFilterOnline(''); setFilterLocked(''); } 
        else if (type === 'ONLINE') { setSearchTerm(''); setFilterOnline('true'); setFilterLocked(''); }
        setPage(0);
    }, []);

    const handleUserTransPageChange = (newPage) => {
        setDetailModal(prev => {
            if (prev.user) { fetchUserTransactions(prev.user.id, newPage, prev.deletedStatus, prev.userTransFilterType); }
            return { ...prev, userTransCurrentPage: newPage };
        });
    };

    const handleUserTransFilterTypeChange = (e) => {
        const newFilterType = e.target.value;
        setDetailModal(prev => {
            if (prev.user) { fetchUserTransactions(prev.user.id, 0, prev.deletedStatus, newFilterType); }
            return { ...prev, userTransFilterType: newFilterType, userTransCurrentPage: 0 };
        });
    };

    const handleViewAllTransactions = async () => {
        if (!detailModal.user?.id) return; setViewingAllTrans(true);
        try {
            const params = { deletedStatus: detailModal.deletedStatus, type: detailModal.userTransFilterType };
            const res = await adminApi.getAllUserTransactions(Number(detailModal.user.id), params);
            if (res.data.success) { setDetailModal(prev => ({ ...prev, transactions: res.data.data })); }
        } catch (err) { console.error("Error fetching all transactions:", err); } finally { setViewingAllTrans(false); }
    };

    const handleAutoLogoutTrigger = async () => {
        setAutoLoggingOut(true);
        try {
            const res = await adminApi.handleAutoLogout();
            if (res.data.success) { alert(t('autoLogoutSuccess')); fetchStats(); }
        } catch (err) { console.error("Lỗi Auto Logout:", err); } finally { setAutoLoggingOut(false); }
    };

    const handleNotifyAbnormal = async () => {
        setNotifying(true);
        try { await adminApi.notifyAbnormalTransactions(5000000); alert(t('notifySuccess')); } 
        catch (err) { alert(t('notifyError')); } finally { setNotifying(false); }
    };

    // --- CHART DATA PREP (REWRITTEN BASED ON BACKEND JAVA LOGIC) ---
    const chartStats = useMemo(() => {
        if (!transactionStats) return { totalVolume: 0, incomePerc: 0, expensePerc: 0, netFlowPerc: 0, sortedBreakdown: [] };

        const breakdown = transactionStats.breakdown || [];
        const totalVolume = transactionStats.totalVolume || breakdown.reduce((acc, item) => acc + item.amount, 0);
        
        const totalIncome = breakdown.filter(i => i.type === 'INCOME').reduce((acc, i) => acc + i.amount, 0);
        const totalExpense = breakdown.filter(i => i.type === 'EXPENSE').reduce((acc, i) => acc + i.amount, 0);
        const netFlow = totalIncome - totalExpense;

        const incomePerc = totalVolume > 0 ? ((totalIncome / totalVolume) * 100).toFixed(1) : 0;
        const expensePerc = totalVolume > 0 ? ((totalExpense / totalVolume) * 100).toFixed(1) : 0;
        const netFlowPerc = totalVolume > 0 ? ((netFlow / totalVolume) * 100).toFixed(1) : 0;

        const sortedBreakdown = [...breakdown].sort((a, b) => {
            if (a.type !== b.type) return a.type === 'INCOME' ? -1 : 1;
            return b.percentage - a.percentage; 
        });

        return {
            totalVolume, incomePerc, expensePerc, netFlowPerc,
            totalIncome, totalExpense, netFlow, sortedBreakdown 
        };
    }, [transactionStats]);

    const dynamicChartHeight = useMemo(() => Math.max(400, chartStats.sortedBreakdown.length * 55), [chartStats]);

    const barChartData = useMemo(() => ({
        labels: chartStats.sortedBreakdown.map(item => wrapLabel(`${item.type === 'INCOME' ? '↑' : '↓'} ${item.categoryName}`)),
        datasets: [{ 
            label: t('weight'), 
            data: chartStats.sortedBreakdown.map(item => item.percentage), 
            backgroundColor: chartStats.sortedBreakdown.map(item => item.type === 'INCOME' ? 'rgba(16, 185, 129, 0.8)' : 'rgba(244, 63, 94, 0.8)'), 
            borderRadius: 6, barPercentage: 0.7 
        }]
    }), [chartStats, wrapLabel, t]);

    const doughnutData = useMemo(() => ({ 
        labels: [`${t('income')} (%)`, `${t('expense')} (%)`], 
        datasets: [{ data: [chartStats.incomePerc, chartStats.expensePerc], backgroundColor: ['#10b981', '#f43f5e'], cutout: '75%', borderRadius: 5 }] 
    }), [chartStats, t]);

    // --- EFFECTS ---
    useEffect(() => {
        const storedUser = JSON.parse(localStorage.getItem('user'));
        const token = localStorage.getItem('accessToken');
        const authorizedRoles = ["Quản trị viên", "ROLE_ADMIN", "ADMIN_SYSTEM_ALL"];
        if (!token || !storedUser || !authorizedRoles.includes(storedUser.roleName)) { navigate('/login'); return; }
        fetchStats();
        fetchNotifications();
    }, [navigate, fetchStats, fetchNotifications]);

    useEffect(() => {
        if (activeTab === 'overview') fetchDateRanges(rangeMode);
    }, [rangeMode, fetchDateRanges, activeTab]);

    useEffect(() => {
        const delayDebounceFn = setTimeout(() => {
            if (activeTab === 'users') fetchUsers(false); if (activeTab === 'contacts') fetchContactRequests(false);
        }, 500); return () => clearTimeout(delayDebounceFn);
    }, [fetchUsers, fetchContactRequests, activeTab, filterStatus, filterType, filterPriority]);

    useEffect(() => {
        const delayDebounceFn = setTimeout(() => { if (activeTab === 'overview') fetchAbnormalUsers(false); }, 600);
        return () => clearTimeout(delayDebounceFn);
    }, [fetchAbnormalUsers, activeTab]);

    useEffect(() => {
        const path = location.pathname; if (path.includes('/admin/contact-requests')) { setActiveTab('contacts'); }
    }, [location]);

    // Effect to scroll to the selected range smoothly
    useEffect(() => {
        if (!loadingRanges && selectedRange && dateRanges.length > 0 && rangeScrollRef.current) {
            const timer = setTimeout(() => {
                const activeItem = rangeScrollRef.current.querySelector('.range-item-active');
                if (activeItem) {
                    activeItem.scrollIntoView({ behavior: 'smooth', inline: 'center', block: 'nearest' });
                }
            }, 150);
            return () => clearTimeout(timer);
        }
    }, [selectedRange, dateRanges, loadingRanges]);

    // --- RENDER COMPONENTS ---
    const Sidebar = () => (
        <div className="d-flex flex-column flex-shrink-0 p-3 text-white bg-dark" style={{ width: '260px', height: '100vh', position: 'sticky', top: 0 }}>
            <div className="d-flex align-items-center mb-3 mb-md-0 me-md-auto text-white text-decoration-none px-2"><i className="bi bi-wallet2 fs-4 me-2 text-info"></i><span className="fs-5 fw-bold">Smart Money</span></div><hr />
            <ul className="nav nav-pills flex-column mb-auto">
                <li className="nav-item mb-1"><button onClick={() => setActiveTab('overview')} className={`nav-link w-100 text-start text-white ${activeTab === 'overview' ? 'active bg-primary shadow' : ''}`}><i className="bi bi-speedometer2 me-2"></i> {t('dashboard')}</button></li>
                <li className="nav-item mb-1"><button onClick={() => setActiveTab('users')} className={`nav-link w-100 text-start text-white ${activeTab === 'users' ? 'active bg-primary shadow' : ''}`}><i className="bi bi-people me-2"></i> {t('users')}</button></li>
                <li className="nav-item mb-1"><button onClick={() => setActiveTab('contacts')} className={`nav-link w-100 text-start text-white ${activeTab === 'contacts' ? 'active bg-primary shadow' : ''}`}><i className="bi bi-chat-dots me-2"></i> {t('contactRequests')}</button></li>
            </ul><hr />
            <div className="mt-auto px-2"><button className="btn btn-outline-light btn-sm w-100 d-flex align-items-center justify-content-center gap-2 py-2" onClick={handleAutoLogoutTrigger} disabled={autoLoggingOut}>{autoLoggingOut ? <span className="spinner-border spinner-border-sm"></span> : <i className="bi bi-shield-check"></i>}<span className="extra-small fw-bold text-uppercase" style={{fontSize: '0.65rem'}}>{t('autoLogout')}</span></button></div>
        </div>
    );

    const Topbar = () => {
        const unreadCount = notifications.filter(n => !n.notifyRead).length;
        return (
            <nav className="navbar navbar-expand-lg navbar-light bg-white border-bottom shadow-sm px-4 py-2 sticky-top" style={{zIndex: 1000}}>
                <div className="d-flex w-100 justify-content-between align-items-center">
                    <h5 className="mb-0 fw-bold text-dark">{t(activeTab === 'overview' ? 'dashboard' : activeTab === 'users' ? 'users' : 'contactRequests')}</h5>
                    <div className="d-flex align-items-center">
                        <div className="btn-group btn-group-sm me-4 shadow-sm border rounded"><button onClick={() => toggleLang('vi')} className={`btn ${lang === 'vi' ? 'btn-primary' : 'btn-light'}`}>VN</button><button onClick={() => toggleLang('en')} className={`btn ${lang === 'en' ? 'btn-primary' : 'btn-light'}`}>EN</button></div>
                         <div className="position-relative me-4">
                            <button className="btn btn-light rounded-circle position-relative shadow-sm" onClick={() => setShowNotifications(!showNotifications)}><i className="bi bi-bell"></i>{unreadCount > 0 && <span className="position-absolute top-0 start-100 translate-middle badge rounded-pill bg-danger animate-pulse" style={{fontSize: '0.6rem'}}>{unreadCount}</span>}</button>
                            {showNotifications && (
                                <div className="position-absolute end-0 mt-3 bg-white shadow-lg rounded-4 border overflow-hidden" style={{ width: '350px' }}>
                                    <div className="p-3 border-bottom fw-bold bg-light d-flex justify-content-between align-items-center"><span>{t('sysNotify')}</span><button className="btn btn-sm btn-link text-decoration-none p-0 small" onClick={handleMarkAllAsRead}>{t('markAllRead')}</button></div>
                                    <div className="custom-scrollbar" style={{ maxHeight: '400px', overflowY: 'auto' }}>
                                        {notifications.length === 0 ? <p className="text-center text-muted m-4 small">{t('noNotify')}</p> : 
                                            notifications.map((n, i) => (
                                                <div key={i} onClick={() => handleNotificationClick(n)} className={`p-3 border-bottom small hover-bg-light cursor-pointer transition-all ${!n.notifyRead ? 'bg-primary-subtle border-start border-4 border-primary' : ''}`}>
                                                    <div className="d-flex justify-content-between mb-1"><span className={`fw-bold ${n.title?.includes('URGENT') ? 'text-danger' : 'text-primary'}`}>{n.title}</span><span className="extra-small text-muted">{formatDate(n.createdAt)}</span></div><div className="text-dark opacity-75">{n.content || n.message}</div>
                                                </div>
                                            ))
                                        }
                                    </div>
                                </div>
                            )}
                        </div>
                        <button onClick={() => handleLogout()} className="btn btn-danger btn-sm px-3 shadow-sm d-flex align-items-center gap-2 rounded-pill"><i className="bi bi-box-arrow-right"></i> {t('logout')}</button>
                    </div>
                </div>
            </nav>
        );
    };

    const OverviewTab = () => (
        <div className="container-fluid py-4 px-lg-4">
            <style>{`
                .card-hover-up { transition: all 0.3s ease; } .card-hover-up:hover { transform: translateY(-4px); box-shadow: 0 20px 25px -5px rgb(0 0 0 / 0.1) !important; }
                .live-dot { width: 10px; height: 10px; background: #10b981; border-radius: 50%; display: inline-block; margin-right: 10px; animation: pulse-dot 2s infinite; }
                @keyframes pulse-dot { 0% { box-shadow: 0 0 0 0 rgba(16, 185, 129, 0.7); } 70% { box-shadow: 0 0 0 8px rgba(16, 185, 129, 0); } 100% { box-shadow: 0 0 0 0 rgba(16, 185, 129, 0); } }
                .range-scroll-wrapper { position: relative; display: flex; align-items: center; border-top: 1px solid #edf2f7; padding-top: 15px; }
                .range-scroll-container { display: flex; overflow-x: auto; gap: 10px; padding: 5px; scrollbar-width: none; -ms-overflow-style: none; scroll-behavior: smooth; min-height: 55px; }
                .range-scroll-container::-webkit-scrollbar { display: none; }
                .range-item { flex: 0 0 auto; padding: 10px 24px; border-radius: 12px; background: #f8fafc; border: 1px solid #e2e8f0; cursor: pointer; transition: all 0.3s; font-size: 0.85rem; font-weight: 600; color: #64748b; }
                .range-item:hover { border-color: #3b82f6; color: #3b82f6; background: #eff6ff; }
                .range-item-active { background: #3b82f6 !important; border-color: #3b82f6 !important; color: white !important; box-shadow: 0 4px 12px rgba(59, 130, 246, 0.3); }
                .scroll-btn { width: 32px; height: 32px; border-radius: 50%; background: white; border: 1px solid #e2e8f0; display: flex; align-items: center; justify-content: center; cursor: pointer; z-index: 10; box-shadow: 0 2px 4px rgba(0,0,0,0.05); }
                .scroll-btn:hover { background: #f8fafc; color: #3b82f6; border-color: #3b82f6; }
            `}</style>
            
            <div className="row g-4 mb-5">
                {[
                    { label: t('totalUsers'), value: stats.totalUsers, icon: 'bi-people', color: '#6366f1', bg: '#eef2ff', key: 'TOTAL' },
                    { label: t('onlineUsers'), value: stats.activeDevices, icon: 'bi-broadcast', color: '#10b981', bg: '#ecfdf5', isLive: true, key: 'ONLINE' },
                    { label: t('transactions'), value: stats.totalTransactions, icon: 'bi-activity', color: '#0ea5e9', bg: '#f0f9ff' }
                ].map((item, idx) => (
                    <div className="col-xl-4 col-md-6" key={idx}>
                        <div className="card shadow-sm border-0 rounded-4 card-hover-up h-100 cursor-pointer" onClick={() => item.key && handleCardClick(item.key)}><div className="card-body p-4"><div className="d-flex justify-content-between align-items-start mb-3"><div className="rounded-4 d-flex align-items-center justify-content-center shadow-sm" style={{ width: '52px', height: '52px', background: item.bg }}><i className={`bi ${item.icon} fs-4`} style={{ color: item.color }}></i></div>{item.isLive && <div className="d-flex align-items-center gap-2"><span className="live-dot"></span><span className="text-success small fw-bold">LIVE</span></div>}</div><p className="text-secondary mb-1 fw-bold text-uppercase small">{item.label}</p><h2 className="mb-0 fw-bold">{(item.value || 0).toLocaleString()}</h2></div></div>
                    </div>
                ))}
            </div>

             <div className="row g-4">
                <div className="col-lg-8">
                    <div className="card shadow-sm border-0 rounded-4 h-100 overflow-hidden">
                        <div className="card-header bg-white border-0 pt-4 px-4 d-flex flex-column gap-3">
                            <div className="d-flex justify-content-between align-items-center">
                                <h5 className="mb-0 fw-bold">{t('flowAnalysis')} {selectedRange ? `- ${selectedRange.label}` : ''}</h5>
                                <div className="btn-group btn-group-sm p-1 bg-light rounded-pill">
                                    {[{m: 'DAILY', l: t('day')}, {m: 'WEEKLY', l: t('week')}, {m: 'MONTHLY', l: t('month')}, {m: 'QUARTERLY', l: t('quarter')}, {m: 'YEARLY', l: t('year')}].map(item => (
                                        <button key={item.m} className={`btn border-0 px-3 rounded-pill transition-all ${rangeMode === item.m ? 'btn-white shadow-sm fw-bold text-primary' : 'text-muted'}`} onClick={() => handleModeChange(item.m)}>{item.l}</button>
                                    ))}
                                </div>
                            </div>
                            
                            <div className="range-scroll-wrapper">
                                <button className="scroll-btn me-2" onClick={() => scrollRanges('left')}><i className="bi bi-chevron-left"></i></button>
                                <div className="range-scroll-container" ref={rangeScrollRef} style={{ opacity: loadingRanges ? 0.6 : 1 }}>
                                    {dateRanges.map((range) => (
                                        <div key={range.label} className={`range-item ${selectedRange?.label === range.label ? 'range-item-active' : ''}`} onClick={() => handleRangeChange(range)}>
                                            {range.label}
                                        </div>
                                    ))}
                                    {dateRanges.length === 0 && loadingRanges && <div className="range-item range-item-active">{t('loading')}</div>}
                                </div>
                                <button className="scroll-btn ms-2" onClick={() => scrollRanges('right')}><i className="bi bi-chevron-right"></i></button>
                            </div>
                        </div>
                        <div className="card-body p-4" style={{ minHeight: '450px' }}>
                            {transactionStats ? (
                                <div className="row g-4">
                                    <div className="col-12 mb-3">
                                        <div className="row g-3">
                                            <div className="col-md-4"><div className="p-3 rounded-4 bg-light shadow-sm">
                                                <div className="text-muted small mb-1">{t('income')}</div><div className="fw-bold text-success fs-5">{chartStats.incomePerc}%</div>
                                            </div></div>
                                            <div className="col-md-4"><div className="p-3 rounded-4 bg-light shadow-sm">
                                                <div className="text-muted small mb-1">{t('expense')}</div><div className="fw-bold text-danger fs-5">{chartStats.expensePerc}%</div>
                                            </div></div>
                                            <div className="col-md-4"><div className={`p-3 rounded-4 shadow-sm ${chartStats.netFlow >= 0 ? 'bg-success-subtle' : 'bg-danger-subtle'}`}>
                                                <div className="text-muted small mb-1">{t('netFlow')}</div><div className={`fw-bold fs-5 ${chartStats.netFlow >= 0 ? 'text-success' : 'text-danger'}`}>{chartStats.netFlowPerc}%</div>
                                            </div></div>
                                        </div>
                                    </div>
                                    <div className="col-md-5 d-flex flex-column align-items-center justify-content-center">
                                        <div style={{ height: '240px', width: '100%', position: 'relative' }}>
                                            <Doughnut data={doughnutData} options={{ maintainAspectRatio: false, plugins: { legend: { display: false } } }} />
                                            <div className="position-absolute top-50 start-50 translate-middle text-center">
                                                <div className="text-muted extra-small text-uppercase fw-bold">{t('totalVolume')}</div><div className="fw-bold fs-6">100%</div>
                                            </div>
                                        </div>
                                    </div>
                                    <div className="col-md-7 border-start border-light-subtle ps-4">
                                        <h6 className="fw-bold mb-3 d-flex align-items-center gap-2"><i className="bi bi-layers text-primary"></i> {t('categoryDetail')}</h6>
                                        <div className="custom-scrollbar overflow-auto pe-2" style={{ maxHeight: '400px' }}>
                                            <div style={{ height: `${dynamicChartHeight}px` }}>
                                                <Bar data={barChartData} options={{ 
                                                    indexAxis: 'y', responsive: true, maintainAspectRatio: false, 
                                                    plugins: { 
                                                        legend: { display: false },
                                                        tooltip: { 
                                                            callbacks: {
                                                                label: (context) => ` ${t('weight')}: ${context.raw}%`
                                                            }
                                                        }
                                                    },
                                                    scales: {
                                                        x: { max: 100, ticks: { callback: (val) => val + '%' } }
                                                    }
                                                }} />
                                            </div>
                                        </div>
                                    </div>
                                </div>
                            ) : (
                                <div className="d-flex align-items-center justify-content-center" style={{ height: '400px' }}>
                                    <div className="spinner-border text-primary"></div>
                                </div>
                            )}
                        </div>
                    </div>
                </div>
                <div className="col-lg-4"><div className="card shadow-sm border-0 rounded-4 h-100"><div className="card-header bg-white border-0 pt-4 px-4 d-flex justify-content-between align-items-center"><h5 className="mb-0 fw-bold">{t('abnormalTrans')}</h5><button className="btn btn-sm btn-light border" onClick={() => fetchAbnormalUsers(false)}><i className="bi bi-arrow-clockwise"></i></button></div><div className="card-body p-4 d-flex flex-column h-100" style={{ minHeight: '400px' }}><div className="abnormal-list mb-auto custom-scrollbar overflow-auto" style={{maxHeight: '400px'}}>{loadingAbnormal ? [1,2,3].map(i => <div key={i} className="skeleton-shimmer mb-3" style={{height: '70px'}}></div>) : abnormalUsers.length === 0 ? <div className="text-center py-5 text-muted small">{t('noAbnormal')}</div> : abnormalUsers.map((item, idx) => (<div key={idx} className="d-flex justify-content-between align-items-center mb-3 p-3 bg-light rounded-4 border-start border-4 border-warning shadow-sm"><div><div className="fw-bold small">{item.username || 'N/A'}</div><div className="text-muted extra-small">{item.transactionCount} lần</div></div><span className="fw-bold text-danger extra-small">{formatCurrency(item.totalAmount)}</span></div>)) }</div><button className="btn btn-warning w-100 fw-bold py-3 mt-4 rounded-4 shadow-sm d-flex align-items-center justify-content-center gap-2" onClick={handleNotifyAbnormal} disabled={notifying || abnormalUsers.length === 0}>{notifying ? <span className="spinner-border spinner-border-sm"></span> : <i className="bi bi-send"></i>}{t('scanNow', { count: abnormalUsers.length })}</button></div></div></div>
             </div>
        </div>
    );

    const UsersTab = () => (
        <div className="container-fluid py-4"><div className="card shadow-sm border-0 rounded-4 overflow-hidden"><div className="card-header bg-white py-4 border-0 d-flex flex-wrap gap-3 justify-content-between align-items-center"><div className="d-flex gap-2"><input type="text" className="form-control form-control-sm bg-light border-0 px-3" placeholder={t('searchPlaceholder')} value={searchTerm} onChange={e => {setSearchTerm(e.target.value); setPage(0);}} style={{width: '240px'}} /><select className="form-select form-select-sm" style={{width: '130px'}} value={filterLocked} onChange={e => {setFilterLocked(e.target.value); setPage(0);}}><option value="">{t('status')}</option><option value="false">{t('active')}</option><option value="true">{t('locked')}</option></select><select className="form-select form-select-sm" style={{width: '130px'}} value={filterOnline} onChange={e => {setFilterOnline(e.target.value); setPage(0);}}><option value="">{t('connection')}</option><option value="true">Online</option><option value="false">Offline</option></select></div></div><div className="table-responsive" style={{ minHeight: '400px' }}><table className="table table-hover align-middle mb-0"><thead className="table-light"><tr><th className="ps-4">ID</th><th>Email</th><th>{t('phone')}</th><th>{t('status')}</th><th>{t('connection')}</th><th className="text-end pe-4">{t('actions')}</th></tr></thead><tbody>{loading ? [1,2,3,4,5,6,7,8].map(i => <tr key={i}><td colSpan="6" className="p-3"><div className="skeleton-shimmer" style={{height: '30px'}}></div></td></tr>) : users.map(u => (<tr key={u.id}><td className="ps-4 fw-bold">#{u.id}</td><td>{u.accEmail}</td><td>{u.accPhone || '-'}</td><td>{u.locked ? <span className="badge bg-danger-subtle text-danger">{t('locked')}</span> : <span className="badge bg-success-subtle text-success">{t('active')}</span>}</td><td>{u.online ? <span className="text-success small"><i className="bi bi-circle-fill me-1" style={{fontSize: '0.5rem'}}></i>Online</span> : <span className="text-muted small">Offline</span>}</td><td className="text-end pe-4"><button className="btn btn-sm btn-light border rounded-circle me-1" onClick={() => handleViewDetails(u)}><i className="bi bi-eye"></i></button><button className={`btn btn-sm ${u.locked ? 'btn-light text-success' : 'btn-light text-danger'} rounded-circle border`} onClick={() => setConfirmModal({show: true, userId: u.id, isLocked: u.locked})}><i className={`bi ${u.locked ? 'bi-unlock' : 'bi-lock'}`}></i></button></td></tr>))}</tbody></table></div>{totalPages > 1 && (<div className="card-footer bg-white border-0 py-3 d-flex justify-content-center"><button className="btn btn-sm btn-outline-secondary me-2" disabled={page===0} onClick={() => setPage(p => p-1)}><i className="bi bi-chevron-left"></i></button><span className="small mx-2">{t('page', { current: page + 1, total: totalPages })}</span><button className="btn btn-sm btn-outline-secondary ms-2" disabled={page===totalPages-1} onClick={() => setPage(p => p+1)}><i className="bi bi-chevron-right"></i></button></div>)}</div></div>
    );

    const ContactsTab = () => (
        <div className="container-fluid py-4"><div className="card shadow-sm border-0 rounded-4 overflow-hidden"><div className="card-header bg-white py-4 border-0 d-flex flex-wrap gap-3 justify-content-between align-items-center"><div className="d-flex gap-2"><select className="form-select form-select-sm" style={{width: '160px'}} value={filterStatus} onChange={e => setFilterStatus(e.target.value)}><option value="">{t('status')}</option><option value="PENDING">{t('PENDING')}</option><option value="PROCESSING">{t('PROCESSING')}</option><option value="APPROVED">{t('APPROVED')}</option><option value="REJECTED">{t('REJECTED')}</option></select><select className="form-select form-select-sm" style={{width: '180px'}} value={filterType} onChange={e => setFilterType(e.target.value)}><option value="">{t('requestType')}</option><option value="SUSPICIOUS_TX">{t('SUSPICIOUS_TX')}</option><option value="EMERGENCY">{t('EMERGENCY')}</option><option value="ACCOUNT_LOCK">{t('ACCOUNT_LOCK')}</option><option value="ACCOUNT_UNLOCK">{t('ACCOUNT_UNLOCK')}</option><option value="DATA_LOSS">{t('DATA_LOSS')}</option><option value="FORGOT_PASSWORD">{t('FORGOT_PASSWORD')}</option><option value="BUG_REPORT">{t('BUG_REPORT')}</option><option value="DATA_RECOVERY">{t('DATA_RECOVERY')}</option><option value="GENERAL">{t('GENERAL')}</option></select><select className="form-select form-select-sm" style={{width: '160px'}} value={filterPriority} onChange={e => setFilterPriority(e.target.value)}><option value="">{t('priority')}</option><option value="URGENT">{t('URGENT')}</option><option value="HIGH">{t('HIGH')}</option><option value="NORMAL">{t('NORMAL')}</option></select></div><button className="btn btn-sm btn-outline-primary rounded-pill px-3" onClick={() => fetchContactRequests(false)}><i className="bi bi-arrow-clockwise me-1"></i> Làm mới</button></div><div className="table-responsive" style={{ minHeight: '400px' }}><table className="table table-hover align-middle mb-0"><thead className="table-light"><tr><th className="ps-4">ID</th><th>{t('requestType')}</th><th>{t('sender')}</th><th>{t('priority')}</th><th>{t('status')}</th><th>{t('createdAt')}</th><th className="text-end pe-4">{t('actions')}</th></tr></thead><tbody>{loading ? [1,2,3,4,5].map(i => <tr key={i}><td colSpan="7" className="p-3"><div className="skeleton-shimmer" style={{height: '35px'}}></div></td></tr>) : contactRequests.length === 0 ? <tr><td colSpan="7" className="text-center py-5 text-muted">Không có yêu cầu nào</td></tr> : contactRequests.map(r => (<tr key={r.id} className={highlightRequestId === r.id ? 'highlight-row' : ''}><td className="ps-4 fw-bold">#{r.id}</td><td><span className="fw-medium">{t(r.requestType)}</span><div className="extra-small text-muted">{r.title}</div></td><td><div className="small fw-bold">{r.fullname}</div><div className="extra-small text-muted">{r.contactPhone || r.contactEmail}</div></td><td><span className={`badge rounded-pill ${r.requestPriority === 'URGENT' ? 'bg-danger' : r.requestPriority === 'HIGH' ? 'bg-warning text-dark' : 'bg-success'}`}>{t(r.requestPriority)}</span></td><td><span className={`badge bg-opacity-10 py-2 px-3 rounded-pill ${r.requestStatus === 'PENDING' ? 'bg-warning text-warning' : r.requestStatus === 'PROCESSING' ? 'bg-primary text-primary' : r.requestStatus === 'APPROVED' ? 'bg-success text-success' : 'bg-danger text-danger'}`}>{t(r.requestStatus)}</span></td><td className="small text-muted">{formatDate(r.createdAt)}</td><td className="text-end pe-4"><button className="btn btn-sm btn-primary rounded-pill px-3 shadow-sm" onClick={() => setResolveModal({ show: true, request: r, adminNote: r.adminNote || '', loading: false })}>{t('resolve')}</button>{r.accId && <button className="btn btn-sm btn-light border rounded-circle ms-1" onClick={() => handleGoToUser(r.accEmail)} title="Xem User"><i className="bi bi-person"></i></button>}</td></tr>))}</tbody></table></div></div></div>
    );

    return (
        <div className="d-flex min-vh-100 bg-light font-inter">
            <Sidebar /><div className="flex-grow-1 d-flex flex-column" style={{height: '100vh', overflow: 'hidden'}}><Topbar /><div className="flex-grow-1 overflow-auto bg-light">{activeTab === 'overview' && <OverviewTab />}{activeTab === 'users' && <UsersTab />}{activeTab === 'contacts' && <ContactsTab />}</div></div>
            {resolveModal.show && (
                <div className="modal fade show d-block" style={{backgroundColor: 'rgba(0,0,0,0.5)', backdropFilter: 'blur(4px)'}}><div className="modal-dialog modal-dialog-centered"><div className="modal-content border-0 rounded-4 shadow-lg"><div className="modal-header border-0 pb-0"><h5 className="modal-title fw-bold">{t('viewRequest')} #{resolveModal.request.id}</h5><button className="btn-close" onClick={() => setResolveModal({...resolveModal, show: false})}></button></div><div className="modal-body p-4"><div className="mb-4"><div className="d-flex justify-content-between mb-2"><span className="badge bg-light text-dark border">{t(resolveModal.request.requestType)}</span><span className="small text-muted">{formatDate(resolveModal.request.createdAt)}</span></div><h6 className="fw-bold mb-1">{resolveModal.request.title}</h6><p className="small text-muted bg-light p-3 rounded-3">{resolveModal.request.requestDescription || "Không có mô tả"}</p></div><div className="row g-3 mb-4"><div className="col-6"><label className="extra-small text-muted text-uppercase fw-bold d-block">{t('sender')}</label><span className="small fw-bold">{resolveModal.request.fullname}</span></div><div className="col-6"><label className="extra-small text-muted text-uppercase fw-bold d-block">Liên hệ</label><span className="small">{resolveModal.request.contactPhone || resolveModal.request.contactEmail}</span></div></div><div className="mb-4"><label className="small fw-bold mb-2">{t('adminNote')}</label><textarea className="form-control bg-light border-0" rows="3" placeholder={t('notePlaceholder')} value={resolveModal.adminNote} onChange={e => setResolveModal({...resolveModal, adminNote: e.target.value})}></textarea></div><div className="d-flex flex-wrap gap-2 pt-2 border-top">{resolveModal.request.requestStatus === 'PENDING' && (<button className="btn btn-primary rounded-pill px-4" onClick={() => handleResolveRequest('PROCESSING')} disabled={resolveModal.loading}>{t('takeRequest')}</button>)}{resolveModal.request.requestStatus === 'PROCESSING' && (<button className="btn btn-success rounded-pill px-4" onClick={() => handleResolveRequest('APPROVED')} disabled={resolveModal.loading}><i className="bi bi-check-circle me-1"></i> {t('approve')}</button>)}{(resolveModal.request.requestStatus === 'PENDING' || resolveModal.request.requestStatus === 'PROCESSING') && (<button className="btn btn-danger rounded-pill px-4" onClick={() => handleResolveRequest('REJECTED')} disabled={resolveModal.loading}><i className="bi bi-x-circle me-1"></i> {t('reject')}</button>)}{resolveModal.loading && <span className="spinner-border spinner-border-sm align-self-center ms-2"></span>}</div>{(resolveModal.request.requestStatus === 'APPROVED' || resolveModal.request.requestStatus === 'REJECTED') && (<div className={`mt-3 p-2 rounded-3 text-center small fw-bold ${resolveModal.request.requestStatus === 'APPROVED' ? 'bg-success-subtle text-success' : 'bg-danger-subtle text-danger'}`}>Đã được xử lý bởi {resolveModal.request.resolvedByName || "Admin"} vào {formatDate(resolveModal.request.resolvedAt)}</div>)}</div></div></div></div>
            )}
            {confirmModal.show && (
                <div className="modal fade show d-block" style={{backgroundColor: 'rgba(0,0,0,0.5)'}}><div className="modal-dialog modal-dialog-centered"><div className="modal-content shadow border-0 rounded-4"><div className="modal-body text-center p-5"><i className={`bi ${confirmModal.isLocked ? 'bi-unlock-fill text-success' : 'bi-lock-fill text-danger'} display-1 mb-4`}></i><h4 className="fw-bold mb-3">{confirmModal.isLocked ? t('confirmUnlock') : t('confirmLock')}</h4><p className="text-muted mb-5">{confirmModal.isLocked ? t('confirmDescUnlock') : t('confirmDescUnlock')}</p><div className="d-flex justify-content-center gap-3"><button className="btn btn-light px-5 py-2 rounded-pill fw-bold" onClick={() => setConfirmModal({...confirmModal, show: false})}>{t('cancel')}</button><button className={`btn ${confirmModal.isLocked ? 'btn-success' : 'btn-danger'} px-5 py-2 rounded-pill fw-bold text-white shadow-sm`} onClick={async () => { try { confirmModal.isLocked ? await adminApi.unlockAccount(confirmModal.userId) : await adminApi.lockAccount(confirmModal.userId); fetchUsers(false); } catch (e) { alert("Lỗi"); } finally { setConfirmModal({show: false}); } }}>{t('confirm')}</button></div></div></div></div></div>
            )}
            {detailModal.show && (
                <div className="modal fade show d-block" style={{backgroundColor: 'rgba(0,0,0,0.6)', backdropFilter: 'blur(4px)'}}><div className="modal-dialog modal-lg modal-dialog-centered"><div className="modal-content shadow-2xl border-0 rounded-4 overflow-hidden"><div className="modal-header bg-dark text-white border-0 py-3"><h5 className="modal-title fw-bold"><i className="bi bi-person-badge me-2"></i>{t('userDetails')}</h5><button type="button" className="btn-close btn-close-white" onClick={() => setDetailModal({ ...detailModal, show: false })}></button></div><div className="modal-body p-4 bg-light custom-scrollbar" style={{maxHeight: '80vh', overflowY: 'auto'}}>{loadingDetail && detailModal.transactions.length === 0 ? (<div className="text-center py-5"><div className="spinner-border text-primary mb-3"></div><p className="text-muted">Đang phân tích dữ liệu...</p></div>) : (<div className="row g-4"><div className="col-12"><div className="bg-white p-3 rounded-4 shadow-sm border-start border-4 border-primary"><h6 className="fw-bold mb-3">{t('userInsights')}</h6><div className="row text-center"><div className="col-6 border-end"><div className="text-muted small">Tổng thu nhập</div><div className="fw-bold text-success fs-5">{formatCurrency(detailModal.insights?.totalIncome || 0)}</div></div><div className="col-6"><div className="text-muted small">Tổng chi tiêu</div><div className="fw-bold text-danger fs-5">{formatCurrency(detailModal.insights?.totalExpense || 0)}</div></div></div></div></div><div className="col-12"><div className="bg-white p-3 rounded-4 shadow-sm"><div className="d-flex justify-content-between align-items-center mb-3"><h6 className="fw-bold mb-0">{t('userTransHistory')}</h6><button className="btn btn-link btn-sm text-decoration-none fw-bold p-0" onClick={handleViewAllTransactions} disabled={viewingAllTrans || detailModal.transactions.length === 0}>{viewingAllTrans ? <span className="spinner-border spinner-border-sm me-1"></span> : <i className="bi bi-list-ul me-1"></i>}{t('viewAll')}</button></div><div className="d-flex flex-wrap gap-2 mb-3 align-items-center"><select className="form-select form-select-sm" style={{width: '150px'}} value={detailModal.userTransFilterType} onChange={handleUserTransFilterTypeChange}><option value="">{t('allTypes')}</option><option value="INCOME">{t('incomeType')}</option><option value="EXPENSE">{t('expenseType')}</option></select><select className="form-select form-select-sm" style={{width: '180px'}} value={detailModal.deletedStatus} onChange={(e) => { const s = e.target.value; setDetailModal(p => ({...p, deletedStatus: s, userTransCurrentPage: 0})); fetchUserTransactions(detailModal.user.id, 0, s, detailModal.userTransFilterType); }}><option value="ACTIVE">{t('ACTIVE')}</option><option value="DELETED">{t('DELETED')}</option><option value="ALL">{t('ALL')}</option></select></div><div className="table-responsive"><table className="table table-sm table-hover align-middle"><thead className="table-light"><tr><th>Ngày</th><th>Danh mục</th><th className="text-end">Số tiền</th></tr></thead><tbody className="small">{detailModal.transactions.length === 0 ? <tr><td colSpan="3" className="text-center py-3">{t('noTrans')}</td></tr> : detailModal.transactions.map((tr, idx) => (<tr key={idx} className={tr.deleted ? 'table-danger' : ''}><td>{formatDate(tr.transDate)} {tr.deleted && <span className="badge bg-danger ms-1" style={{fontSize: '0.6rem'}}>XÓA</span>}</td><td><span className={`badge ${tr.isIncome ? 'bg-success-subtle text-success' : 'bg-danger-subtle text-danger'}`}>{tr.categoryName}</span></td><td className={`text-end fw-bold ${tr.isIncome ? 'text-success' : 'text-danger'}`}>{formatCurrency(tr.amount)}</td></tr>))}</tbody></table></div>{detailModal.userTransTotalPages > 1 && (<div className="d-flex justify-content-center mt-3"><button className="btn btn-sm btn-outline-secondary me-2" disabled={detailModal.userTransCurrentPage === 0} onClick={() => handleUserTransPageChange(detailModal.userTransCurrentPage - 1)}>{t('prevPage')}</button><span className="small mx-2">{detailModal.userTransCurrentPage + 1} / {detailModal.userTransTotalPages}</span><button className="btn btn-sm btn-outline-secondary ms-2" disabled={detailModal.userTransCurrentPage === detailModal.userTransTotalPages - 1} onClick={() => handleUserTransPageChange(detailModal.userTransCurrentPage + 1)}>{t('nextPage')}</button></div>)}</div></div></div>)}</div></div></div></div>
            )}
        </div>
    );
};

export default AdminDashboard;