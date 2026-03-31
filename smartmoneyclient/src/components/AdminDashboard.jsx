import React, { useEffect, useState, useCallback } from 'react';
import { useNavigate } from 'react-router-dom';
import { adminApi, authApi, userApi } from '../server/api';
import { Chart as ChartJS, CategoryScale, LinearScale, PointElement, LineElement, BarElement, Title, Tooltip, Legend, ArcElement } from 'chart.js';
import { Bar, Doughnut } from 'react-chartjs-2';

// Register ChartJS components
ChartJS.register(CategoryScale, LinearScale, PointElement, LineElement, BarElement, Title, Tooltip, Legend, ArcElement);

// --- TRANSLATIONS DICTIONARY ---
const translations = {
    vi: {
        dashboard: "Tổng quan",
        users: "Người dùng",
        totalUsers: "Tổng Người dùng",
        onlineUsers: "Người dùng trực tuyến",
        transactions: "Giao dịch hệ thống",
        flowAnalysis: "Phân tích dòng tiền",
        categoryDetail: "Chi tiết danh mục (%)",
        ratioInExp: "Tỷ lệ Thu - Chi (%)",
        abnormalTrans: "Giao dịch bất thường",
        scanNow: "Gửi thông báo ({count})",
        scanning: "Đang quét...",
        detected: "Phát hiện: {count} người dùng",
        noAbnormal: "Không có ai vượt ngưỡng",
        autoLogout: "Thu hồi phiên quá hạn",
        loggingOut: "Đang xử lý...",
        searchPlaceholder: "Tìm kiếm user...",
        status: "Trạng thái",
        online: "Trực tuyến",
        offline: "Ngoại tuyến",
        phone: "SĐT",
        id: "ID",
        items: "{count} mục",
        connection: "Kết nối",
        active: "Hoạt động",
        locked: "Đã khóa",
        actions: "Thao tác",
        logout: "Đăng xuất",
        sysNotify: "Thông báo hệ thống",
        noNotify: "Không có thông báo mới",
        confirmLock: "Khóa tài khoản?",
        confirmUnlock: "Mở khóa tài khoản?",
        confirmDescLock: "Hành động này sẽ ngăn chặn người dùng truy cập hệ thống.",
        confirmDescUnlock: "Hành động này sẽ cho phép người dùng truy cập lại.",
        confirm: "Xác nhận", 
        cancel: "Hủy",
        week: "Tuần", month: "Tháng", year: "Năm",
        income: "Thu nhập", expense: "Chi tiêu",
        page: "Trang {current} / {total}",
        notifySuccess: "Đã gửi thông báo đến {count} người dùng.",
        notifyError: "Lỗi khi gửi thông báo.",
        autoLogoutSuccess: "Đã thu hồi các phiên đăng nhập ngoại tuyến quá hạn.",
        sessionExpired: "Phiên đăng nhập hết hạn.",
        accountLocked: "Tài khoản bị khóa."
    },
    en: {
        dashboard: "Dashboard",
        users: "Users",
        totalUsers: "Total Users",
        onlineUsers: "Online Users",
        transactions: "System Transactions",
        flowAnalysis: "Cash Flow Analysis",
        categoryDetail: "Category Details (%)",
        ratioInExp: "Income - Expense Ratio (%)",
        abnormalTrans: "Abnormal Activities",
        scanNow: "Notify Users ({count})",
        scanning: "Scanning...",
        detected: "Detected: {count} users",
        noAbnormal: "No abnormal activities",
        autoLogout: "Revoke Overdue Sessions",
        loggingOut: "Processing...",
        searchPlaceholder: "Search users...",
        status: "Status",
        online: "Online",
        offline: "Offline",
        phone: "Phone",
        id: "ID",
        items: "{count} items",
        connection: "Connection",
        active: "Active",
        locked: "Locked",
        actions: "Actions",
        logout: "Logout",
        sysNotify: "System Notifications",
        noNotify: "No new notifications",
        confirmLock: "Lock Account?",
        confirmUnlock: "Unlock Account?",
        confirmDescLock: "This action will prevent the user from accessing the system.",
        confirmDescUnlock: "This action will allow the user to access the system again.",
        confirm: "Confirm",
        cancel: "Cancel",
        week: "Week", month: "Month", year: "Year",
        income: "Income", expense: "Expense",
        page: "Page {current} of {total}",
        notifySuccess: "Successfully notified {count} users.",
        notifyError: "Error sending notification.",
        autoLogoutSuccess: "Overdue offline sessions revoked successfully.",
        sessionExpired: "Session expired.",
        accountLocked: "Account has been locked."
    }
};

const AdminDashboard = () => {
    // --- STATE ---
    const [activeTab, setActiveTab] = useState('overview'); 
    const [lang, setLang] = useState(localStorage.getItem('adminLang') || 'vi');

    const t = (key, params = {}) => {
        let text = translations[lang][key] || key;
        Object.keys(params).forEach(p => {
            text = text.replace(`{${p}}`, params[p]);
        });
        return text;
    };

    const toggleLang = (l) => {
        setLang(l);
        localStorage.setItem('adminLang', l);
    };
    
    // Data State
    const [stats, setStats] = useState({ totalUsers: 0, totalTransactions: 0, activeDevices: 0, newUsersByMonth: [] });
    const [users, setUsers] = useState([]);
    const [transactionStats, setTransactionStats] = useState(null);
    const [notifications, setNotifications] = useState([]);
    const [abnormalUsers, setAbnormalUsers] = useState([]);

    const navigate = useNavigate();
    
    // Filter/Pagination State
    const [searchTerm, setSearchTerm] = useState('');
    const [filterLocked, setFilterLocked] = useState('');
    const [filterOnline, setFilterOnline] = useState('');
    const [threshold, setThreshold] = useState(5000000); 
    const [page, setPage] = useState(0);
    const [totalPages, setTotalPages] = useState(0);
    const [rangeMode, setRangeMode] = useState('MONTHLY');
    
    // UI State
    const [loading, setLoading] = useState(false);
    const [currentUser, setCurrentUser] = useState(null);
    const [notifying, setNotifying] = useState(false);
    const [autoLoggingOut, setAutoLoggingOut] = useState(false);
    const [loadingAbnormal, setLoadingAbnormal] = useState(false);
    const [showNotifications, setShowNotifications] = useState(false);
    const [confirmModal, setConfirmModal] = useState({ show: false, userId: null, isLocked: false });

    // --- API CALLS ---
    
    const handleLogout = useCallback(async (reason = '') => {
        try {
            await authApi.logout('web-browser');
        } catch (err) {
            console.error(err);
        } finally {
            const langCache = localStorage.getItem('adminLang');
            localStorage.clear();
            if (langCache) localStorage.setItem('adminLang', langCache);
            if (reason) alert(reason);
            navigate('/login');
        }
    }, [navigate]);

    const fetchStats = async () => {
        try {
            const res = await adminApi.getStats();
            const data = res.data.success ? res.data.data : res.data;
            if (data) setStats(data);
            
            const onlineRes = await adminApi.getOnlineUsers();
            if (onlineRes.data && onlineRes.data.success) {
                setStats(prev => ({ ...prev, activeDevices: onlineRes.data.data }));
            }
        } catch (err) { console.error(err); }
    };

    const fetchTransactionStats = useCallback(async () => {
        try {
            const res = await adminApi.getSystemTransactionStats(rangeMode);
            if (res.data && res.data.success) {
                setTransactionStats(res.data.data);
            }
        } catch (err) { console.error(err); }
    }, [rangeMode]);

    const fetchAbnormalUsers = useCallback(async () => {
        setLoadingAbnormal(true);
        try {
            const res = await adminApi.getAbnormalUsers(threshold);
            if (res.data && res.data.success) {
                setAbnormalUsers(res.data.data || []);
            }
        } catch (err) {
            console.error("Lỗi lấy danh sách bất thường:", err);
        } finally { setLoadingAbnormal(false); }
    }, [threshold]);

    const handleNotifyAbnormal = async () => {
        setNotifying(true);
        try {
            await adminApi.notifyAbnormalTransactions(threshold);
            alert(t('notifySuccess', { count: abnormalUsers.length }));
        } catch (err) {
            alert(t('notifyError'));
        } finally {
            setNotifying(false);
        }
    };

    const handleAutoLogoutTrigger = async () => {
        setAutoLoggingOut(true);
        try {
            const res = await adminApi.handleAutoLogout();
            if (res.data.success) {
                alert(t('autoLogoutSuccess'));
                fetchStats();
            }
        } catch (err) {
            console.error("Lỗi Auto Logout:", err);
        } finally {
            setAutoLoggingOut(false);
        }
    };

    const fetchNotifications = async (adminId) => {
        try {
            const res = await adminApi.getAdminNotifications(adminId);
            const data = res.data.success ? res.data.data : res.data;
            setNotifications(data || []);
        } catch (err) { console.error(err); }
    };

    const fetchUsers = useCallback(async (isBackground = false) => {
        if (!isBackground) setLoading(true);
        try {
            const params = {
                page, size: 8,
                search: searchTerm && searchTerm.trim() !== '' ? searchTerm.trim() : null,
                locked: filterLocked === 'true' ? true : (filterLocked === 'false' ? false : null),
                onlineStatus: filterOnline === 'true' ? 'ONLINE' : (filterOnline === 'false' ? 'OFFLINE' : null)
            };
            const res = await adminApi.getUsers(params);
            const apiData = res.data.success ? res.data.data : res.data;
            if (apiData) {
                setUsers(apiData.content || []);
                setTotalPages(apiData.totalPages || 0);
            }
        } catch (err) { 
            console.error("Fetch users error:", err); 
            setUsers([]);
        } 
        finally { if (!isBackground) setLoading(false); }
    }, [page, searchTerm, filterLocked, filterOnline]);

    // --- EFFECTS ---

    useEffect(() => {
        const storedUser = JSON.parse(localStorage.getItem('user'));
        const token = localStorage.getItem('accessToken');
        const authorizedRoles = ["Quản trị viên", "ROLE_ADMIN", "ADMIN_SYSTEM_ALL"];

        if (!token || !storedUser || !authorizedRoles.includes(storedUser.roleName)) {
            navigate('/login');
            return;
        }
        setCurrentUser(storedUser);
        fetchStats();
        fetchTransactionStats();
        if (storedUser.userId || storedUser.id) {
             fetchNotifications(storedUser.userId || storedUser.id);
        }
    }, [navigate, fetchTransactionStats]);

    useEffect(() => {
        const delayDebounceFn = setTimeout(() => {
            if (activeTab === 'users') fetchUsers(false);
        }, 500);
        return () => clearTimeout(delayDebounceFn);
    }, [fetchUsers, activeTab]);

    useEffect(() => {
        const delayDebounceFn = setTimeout(() => {
            if (activeTab === 'overview') fetchAbnormalUsers();
        }, 600);
        return () => clearTimeout(delayDebounceFn);
    }, [fetchAbnormalUsers, activeTab]);

    useEffect(() => {
        const checkAccountStatus = async () => {
            try {
                const res = await userApi.getProfile();
                if (res.data && res.data.locked) handleLogout(t('accountLocked'));
            } catch (error) {
                if (error.response && (error.response.status === 401 || error.response.status === 403)) {
                    handleLogout(t('sessionExpired'));
                }
            }
        };
        const interval = setInterval(() => {
            fetchStats();
            if (activeTab === 'users') fetchUsers(true);
            checkAccountStatus();
        }, 5000);
        return () => clearInterval(interval);
    }, [fetchUsers, handleLogout, activeTab]);

    // --- HANDLERS ---

    const handleCardClick = (type) => {
        setActiveTab('users');
        if (type === 'TOTAL') {
            setFilterOnline(''); setFilterLocked(''); setSearchTerm('');
        } else if (type === 'ONLINE') {
            setFilterOnline('true');
            setFilterLocked('');
            setSearchTerm('');
        }
        setPage(0);
    };

    const confirmAction = async () => {
        const { userId, isLocked } = confirmModal;
        try {
            isLocked ? await adminApi.unlockAccount(userId) : await adminApi.lockAccount(userId);
            fetchUsers(false);
            fetchStats();
        } catch (err) { alert(lang === 'vi' ? "Thao tác thất bại." : "Action failed."); }
        finally { setConfirmModal({ ...confirmModal, show: false }); }
    };

    const formatDate = (d) => d ? new Date(d).toLocaleString(lang === 'vi' ? 'vi-VN' : 'en-US', {
        year: 'numeric', month: '2-digit', day: '2-digit', hour: '2-digit', minute: '2-digit'
    }) : '';

    const formatCurrency = (val) => {
        return new Intl.NumberFormat(lang === 'vi' ? 'vi-VN' : 'en-US').format(val) + (lang === 'vi' ? ' đ' : ' VND');
    };

    // --- CHART CONFIG ---
    const breakdown = transactionStats?.breakdown || [];
    const totalVolume = breakdown.reduce((acc, item) => acc + item.amount, 0);
    const totalIncome = breakdown.filter(i => i.type === 'INCOME').reduce((acc, i) => acc + i.amount, 0);
    const totalExpense = breakdown.filter(i => i.type === 'EXPENSE').reduce((acc, i) => acc + i.amount, 0);
    const totalInExp = totalIncome + totalExpense;
    const incomePerc = totalInExp > 0 ? ((totalIncome / totalInExp) * 100).toFixed(1) : 0;
    const expensePerc = totalInExp > 0 ? ((totalExpense / totalInExp) * 100).toFixed(1) : 0;

    const wrapLabel = (label, maxLength = 18) => {
        if (label.length <= maxLength) return label;
        const words = label.split(' ');
        const lines = [];
        let currentLine = "";
        words.forEach(word => {
            if ((currentLine + word).length > maxLength) {
                lines.push(currentLine.trim());
                currentLine = word + " ";
            } else {
                currentLine += word + " ";
            }
        });
        lines.push(currentLine.trim());
        return lines;
    };

    const sortedBreakdown = [...breakdown].sort((a, b) => {
        if (a.type !== b.type) return a.type === 'INCOME' ? -1 : 1;
        return b.amount - a.amount;
    });
    
    const dynamicChartHeight = Math.max(400, sortedBreakdown.length * 55);

    const barChartData = {
        labels: sortedBreakdown.map(item => wrapLabel(`${item.type === 'INCOME' ? '↑' : '↓'} ${item.categoryName}`)),
        datasets: [
            {
                label: 'Tỷ trọng hệ thống',
                data: sortedBreakdown.map(item => totalVolume > 0 ? ((item.amount / totalVolume) * 100).toFixed(1) : 0),
                backgroundColor: sortedBreakdown.map(item => item.type === 'INCOME' ? '#10b981' : '#f43f5e'),
                hoverBackgroundColor: sortedBreakdown.map(item => item.type === 'INCOME' ? '#059669' : '#e11d48'),
                borderRadius: 4,
                barPercentage: 0.6,
                categoryPercentage: 0.8,
            }
        ]
    };
    
    const barOptions = {
        indexAxis: 'y',
        responsive: true,
        maintainAspectRatio: false,
        plugins: {
            legend: { display: false },
            title: { 
                display: true, 
                text: t('categoryDetail').toUpperCase(),
                font: { size: 15, weight: 'bold' }
            },
            tooltip: {
                callbacks: {
                    label: function(context) {
                        return ` Tỷ trọng: ${context.raw}%`;
                    }
                }
            }
        },
        scales: {
            x: { max: 100, ticks: { callback: (value) => value + "%" } },
            y: { ticks: { autoSkip: false } }
        }
    };

    const doughnutData = {
        labels: [`${t('income')} (%)`, `${t('expense')} (%)`],
        datasets: [{
            data: [incomePerc, expensePerc],
            backgroundColor: ['#10b981', '#f43f5e'],
            hoverBackgroundColor: ['#059669', '#e11d48'],
            borderWidth: 0,
            cutout: '70%'
        }]
    };

    const doughnutOptions = {
        responsive: true,
        maintainAspectRatio: false,
        plugins: {
            legend: { position: 'bottom' },
            title: {
                display: true,
                text: t('ratioInExp').toUpperCase(),
                font: { size: 15, weight: 'bold' }
            }
        }
    };

    // --- RENDERERS ---

    const Sidebar = () => (
        <div className="d-flex flex-column flex-shrink-0 p-3 text-white bg-dark" style={{ width: '260px', height: '100vh', position: 'sticky', top: 0 }}>
            <div className="d-flex align-items-center mb-3 mb-md-0 me-md-auto text-white text-decoration-none px-2">
                <i className="bi bi-wallet2 fs-4 me-2 text-info"></i>
                <span className="fs-5 fw-bold">Admin Portal</span>
            </div>
            <hr />
            <ul className="nav nav-pills flex-column mb-auto">
                <li className="nav-item mb-1">
                    <button onClick={() => setActiveTab('overview')} className={`nav-link w-100 text-start text-white ${activeTab === 'overview' ? 'active bg-primary' : ''}`}>
                        <i className="bi bi-speedometer2 me-2"></i> {t('dashboard')}
                    </button>
                </li>
                <li className="nav-item mb-1">
                    <button onClick={() => setActiveTab('users')} className={`nav-link w-100 text-start text-white ${activeTab === 'users' ? 'active bg-primary' : ''}`}>
                        <i className="bi bi-people me-2"></i> {t('users')}
                    </button>
                </li>
            </ul>
            <hr />
            <div className="mt-auto px-2">
                <button 
                    className="btn btn-outline-light btn-sm w-100 d-flex align-items-center justify-content-center gap-2 py-2"
                    onClick={handleAutoLogoutTrigger}
                    disabled={autoLoggingOut}
                    title="Dọn dẹp các phiên đăng nhập ngoại tuyến đã quá hạn"
                >
                    {autoLoggingOut ? <span className="spinner-border spinner-border-sm"></span> : <i className="bi bi-shield-check"></i>}
                    <span className="extra-small fw-bold text-uppercase" style={{fontSize: '0.65rem'}}>{t('autoLogout')}</span>
                </button>
            </div>
        </div>
    );

    const Topbar = () => (
        <nav className="navbar navbar-expand-lg navbar-light bg-white border-bottom shadow-sm px-4 py-2 sticky-top">
            <div className="d-flex w-100 justify-content-between align-items-center">
                <h5 className="mb-0 fw-bold text-secondary">
                    {activeTab === 'overview' ? t('dashboard') : t('users')}
                </h5>
                <div className="d-flex align-items-center">
                    <div className="btn-group btn-group-sm me-4 shadow-sm border rounded">
                        <button onClick={() => toggleLang('vi')} className={`btn ${lang === 'vi' ? 'btn-primary' : 'btn-light'}`}>VN</button>
                        <button onClick={() => toggleLang('en')} className={`btn ${lang === 'en' ? 'btn-primary' : 'btn-light'}`}>EN</button>
                    </div>

                     <div className="position-relative me-4">
                        <button className="btn btn-light rounded-circle position-relative shadow-sm" onClick={() => setShowNotifications(!showNotifications)}>
                            <i className="bi bi-bell"></i>
                            <span className={`position-absolute top-0 start-100 translate-middle badge rounded-pill bg-danger ${notifications.length > 0 ? 'animate-pulse' : 'd-none'}`} style={{fontSize: '0.6rem'}}>
                                {notifications.length}
                            </span>
                        </button>
                        {showNotifications && (
                            <div className="position-absolute end-0 mt-3 bg-white shadow-lg rounded border" style={{ width: '320px', zIndex: 1050 }}>
                                <div className="p-3 border-bottom fw-bold bg-light rounded-top d-flex justify-content-between">
                                    <span>{t('sysNotify')}</span>
                                    <span className="badge bg-primary">{notifications.length}</span>
                                </div>
                                <div style={{ maxHeight: '300px', overflowY: 'auto' }}>
                                    {notifications.length === 0 ? <p className="text-center text-muted m-3 small">{t('noNotify')}</p> : 
                                        notifications.map((n, i) => (
                                            <div key={i} className="p-2 border-bottom small hover-bg-light">
                                                <div className="fw-bold text-primary">{formatDate(n.createdAt)}</div>
                                                <div>{n.message || n.content}</div>
                                            </div>
                                        ))
                                    }
                                </div>
                            </div>
                        )}
                    </div>
                    
                    <button onClick={() => handleLogout()} className="btn btn-danger btn-sm px-3 shadow-sm d-flex align-items-center gap-2 rounded-pill">
                        <i className="bi bi-box-arrow-right"></i> {t('logout')}
                    </button>
                </div>
            </div>
        </nav>
    );

    const OverviewTab = () => (
        <div className="container-fluid py-4 px-lg-4">
            <style>{`
                .card-hover-up { transition: all 0.3s ease; }
                .card-hover-up:hover { transform: translateY(-5px); box-shadow: 0 10px 20px rgba(0,0,0,0.1) !important; }
                .animate-pulse { animation: pulse 2s infinite; }
                @keyframes pulse { 0% { opacity: 1; } 50% { opacity: 0.5; } 100% { opacity: 1; } }
                .custom-scrollbar::-webkit-scrollbar { width: 6px; }
                .custom-scrollbar::-webkit-scrollbar-thumb { background: #e2e8f0; border-radius: 10px; }
            `}</style>
            
            <div className="row g-4 mb-5">
                {[
                    { key: 'TOTAL', label: t('totalUsers'), value: stats.totalUsers, icon: 'bi-people-fill', color: '#6366f1', bg: '#eef2ff' },
                    { key: 'ONLINE', label: t('onlineUsers'), value: stats.activeDevices, icon: 'bi-broadcast-pin', color: '#10b981', bg: '#ecfdf5', isLive: true },
                    { key: 'TRANS', label: t('transactions'), value: stats.totalTransactions, icon: 'bi-lightning-charge-fill', color: '#0ea5e9', bg: '#f0f9ff' }
                ].map((item, idx) => (
                    <div className="col-xl-4 col-md-6" key={idx}>
                        <div 
                            className="card shadow-sm border-0 rounded-4 card-hover-up h-100"
                            onClick={() => item.key !== 'TRANS' && handleCardClick(item.key)}
                            style={{ cursor: item.key !== 'TRANS' ? 'pointer' : 'default' }}
                        >
                            <div className="card-body p-4">
                                <div className="d-flex justify-content-between align-items-center mb-3">
                                    <div className="rounded-4 d-flex align-items-center justify-content-center" style={{ width: '56px', height: '56px', backgroundColor: item.bg }}>
                                        <i className={`bi ${item.icon} fs-3`} style={{ color: item.color }}></i>
                                    </div>
                                    {item.isLive && <span className="badge bg-success-subtle text-success border border-success-subtle rounded-pill px-3 py-2 animate-pulse small fw-bold">LIVE</span>}
                                </div>
                                <p className="text-muted mb-1 fw-bold text-uppercase small" style={{ letterSpacing: '1px' }}>{item.label}</p>
                                <h2 className="mb-0 fw-bold text-dark">{(item.value || 0).toLocaleString()}</h2>
                            </div>
                        </div>
                    </div>
                ))}
            </div>

             <div className="row g-4">
                <div className="col-lg-8">
                    <div className="card shadow-sm border-0 rounded-4 h-100">
                        <div className="card-header bg-white border-0 pt-4 px-4 d-flex justify-content-between align-items-center">
                            <div className="d-flex align-items-center">
                                <div className="p-2 bg-primary-subtle rounded-3 me-3"><i className="bi bi-graph-up-arrow text-primary"></i></div>
                                <h5 className="mb-0 fw-bold text-dark">{t('flowAnalysis')}</h5>
                            </div>
                            <div className="btn-group btn-group-sm p-1 bg-light rounded-3 shadow-sm">
                                {['WEEKLY', 'MONTHLY', 'YEARLY'].map(m => (
                                    <button key={m} className={`btn border-0 px-3 rounded-2 ${rangeMode === m ? 'btn-white shadow-sm fw-bold text-primary' : 'text-muted'}`} 
                                            onClick={() => setRangeMode(m)}>{m === 'WEEKLY' ? t('week') : m === 'MONTHLY' ? t('month') : t('year')}</button>
                                ))}
                            </div>
                        </div>
                        <div className="card-body p-4">
                            {transactionStats ? (
                                <div className="row g-5">
                                    <div className="col-12">
                                        <div className="row align-items-center">
                                            <div className="col-md-5 d-flex flex-column align-items-center">
                                                <div style={{ height: '280px', width: '100%' }}><Doughnut data={doughnutData} options={doughnutOptions} /></div>
                                            </div>
                                            <div className="col-md-7">
                                                <div className="p-4 bg-light rounded-4 shadow-sm border border-white mt-4 mt-md-0">
                                                    <div className="mb-4">
                                                        <div className="d-flex justify-content-between mb-2">
                                                            <span className="small fw-bold text-secondary text-uppercase">{t('income')}</span>
                                                            <span className="small fw-bold text-success">{incomePerc}%</span>
                                                        </div>
                                                        <div className="progress rounded-pill" style={{height: '10px', backgroundColor: '#e2e8f0'}}><div className="progress-bar bg-success" style={{width: `${incomePerc}%`}}></div></div>
                                                    </div>
                                                    <div>
                                                        <div className="d-flex justify-content-between mb-2">
                                                            <span className="small fw-bold text-secondary text-uppercase">{t('expense')}</span>
                                                            <span className="small fw-bold text-danger">{expensePerc}%</span>
                                                        </div>
                                                        <div className="progress rounded-pill" style={{height: '10px', backgroundColor: '#e2e8f0'}}><div className="progress-bar bg-danger" style={{width: `${expensePerc}%`}}></div></div>
                                                    </div>
                                                </div>
                                            </div>
                                        </div>
                                    </div>
                                    <div className="col-12 pt-4 border-top border-light">
                                        <div className="d-flex justify-content-between align-items-center mb-4">
                                            <h6 className="small fw-bold text-uppercase text-muted mb-0">{t('categoryDetail')}</h6>
                                            <span className="badge bg-light text-dark border px-3 py-2 rounded-pill">{sortedBreakdown.length} {t('items', {count: ''})}</span>
                                        </div>
                                        <div className="custom-scrollbar pe-2" style={{ height: '450px', overflowY: 'auto' }}>
                                            <div style={{ height: `${dynamicChartHeight}px` }}><Bar data={barChartData} options={barOptions} /></div>
                                        </div>
                                    </div>
                                </div>
                            ) : <div className="text-center py-5">Đang tải biểu đồ...</div>}
                        </div>
                    </div>
                </div>
                <div className="col-lg-4">
                    <div className="card shadow-sm border-0 rounded-4 h-100">
                        <div className="card-header bg-white border-0 pt-4 px-4 d-flex justify-content-between align-items-center">
                            <div className="d-flex align-items-center">
                                <div className="p-2 bg-warning-subtle rounded-3 me-3"><i className="bi bi-shield-lock-fill text-warning"></i></div>
                                <h5 className="mb-0 fw-bold text-dark">{t('abnormalTrans')}</h5>
                            </div>
                            <button className="btn btn-sm btn-light border rounded-circle shadow-sm" onClick={fetchAbnormalUsers}><i className="bi bi-arrow-clockwise"></i></button>
                        </div>
                        <div className="card-body p-4 d-flex flex-column h-100">
                            <div className="abnormal-list mb-auto custom-scrollbar" style={{maxHeight: '420px', overflowY: 'auto'}}>
                                <div className="d-flex justify-content-between align-items-center small fw-bold mb-3 text-uppercase text-secondary border-bottom pb-2">
                                    <span>{t('detected', { count: abnormalUsers.length })}</span>
                                    {abnormalUsers.length > 0 && <span className="badge bg-danger rounded-pill px-2">RISK</span>}
                                </div>
                                {loadingAbnormal ? (
                                    <div className="text-center py-5 text-muted small"><div className="spinner-border spinner-border-sm me-2 text-warning"></div>{t('scanning')}</div>
                                ) : abnormalUsers.length === 0 ? (
                                    <div className="text-center py-5"><i className="bi bi-check2-circle fs-1 text-success opacity-25"></i><p className="text-muted small mt-2">{t('noAbnormal')}</p></div>
                                ) : (
                                    abnormalUsers.map((item, idx) => (
                                        <div key={idx} className="d-flex justify-content-between align-items-center mb-3 p-3 bg-light rounded-4 border-start border-4 border-warning">
                                            <div>
                                                <div className="fw-bold text-dark small">{item.username || 'N/A'}</div>
                                                <div className="text-muted extra-small">{item.transactionCount} {t('transactions').toLowerCase()}</div>
                                            </div>
                                            <span className="fw-bold text-danger extra-small">{formatCurrency(item.totalAmount)}</span>
                                        </div>
                                    ))
                                )}
                            </div>
                            <button className="btn btn-warning w-100 fw-bold text-dark shadow-sm py-3 mt-4 rounded-3 d-flex align-items-center justify-content-center gap-2" 
                                    onClick={handleNotifyAbnormal} disabled={notifying || abnormalUsers.length === 0}>
                                {notifying ? <span className="spinner-border spinner-border-sm"></span> : <i className="bi bi-send-fill"></i>}
                                {t('scanNow', { count: abnormalUsers.length })}
                            </button>
                        </div>
                    </div>
                </div>
             </div>
        </div>
    );

    const UsersTab = () => (
        <div className="container-fluid py-4">
             <div className="card shadow-sm border-0 rounded-4 overflow-hidden">
                <div className="card-header bg-white py-4 border-0 d-flex flex-wrap gap-3 justify-content-between align-items-center">
                    <div className="d-flex gap-2">
                        <input type="text" className="form-control form-control-sm bg-light border-0 px-3 py-2 rounded-3" placeholder={t('searchPlaceholder')} 
                               value={searchTerm} onChange={e => {setSearchTerm(e.target.value); setPage(0);}} style={{width: '240px'}} />
                        <select className="form-select form-select-sm" style={{width: '130px'}} value={filterLocked} onChange={e => {setFilterLocked(e.target.value); setPage(0);}}>
                            <option value="">{t('status')}</option>
                            <option value="false">{t('active')}</option>
                            <option value="true">{t('locked')}</option>
                        </select>
                        <select className="form-select form-select-sm" style={{width: '130px'}} value={filterOnline} onChange={e => {setFilterOnline(e.target.value); setPage(0);}}>
                            <option value="">{t('connection')}</option>
                            <option value="true">Online</option>
                            <option value="false">Offline</option>
                        </select>
                    </div>
                    <div className="small text-muted">{t('items', { count: users.length })}</div>
                </div>
                <div className="table-responsive custom-scrollbar">
                    <table className="table table-hover align-middle mb-0">
                        <thead className="table-light">
                            <tr>
                                <th className="ps-4 py-3">{t('id')}</th>
                                <th>Email</th>
                                <th>{t('phone')}</th>
                                <th>{t('status')}</th>
                                <th>{t('connection')}</th>
                                <th className="text-end pe-4">{t('actions')}</th>
                            </tr>
                        </thead>
                        <tbody>
                            {loading ? <tr><td colSpan="6" className="text-center py-5">Đang tải...</td></tr> : 
                             users.length === 0 ? <tr><td colSpan="6" className="text-center py-5">Không tìm thấy dữ liệu</td></tr> :
                             users.map(u => (
                                 <tr key={u.id} className="border-bottom-0">
                                     <td className="ps-4 fw-bold text-muted">#{u.id}</td>
                                     <td className="fw-medium">{u.accEmail}</td>
                                     <td>{u.accPhone || '-'}</td>
                                     <td>{u.locked ? <span className="badge bg-danger-subtle text-danger px-3 py-2 rounded-pill">{t('locked')}</span> : <span className="badge bg-success-subtle text-success px-3 py-2 rounded-pill">{t('active')}</span>}</td>
                                     <td>{u.online ? <div className="d-flex align-items-center gap-2"><span className="p-1 bg-success rounded-circle animate-pulse"></span><span className="small">{t('online')}</span></div> : <div className="d-flex align-items-center gap-2"><span className="p-1 bg-secondary rounded-circle"></span><span className="small">{t('offline')}</span></div>}</td>
                                     <td className="text-end pe-4">
                                         <button className={`btn btn-sm ${u.locked ? 'btn-light text-success' : 'btn-light text-danger'} rounded-circle shadow-sm border p-2`}
                                                 onClick={() => setConfirmModal({show: true, userId: u.id, isLocked: u.locked})}>
                                             <i className={`bi ${u.locked ? 'bi-unlock' : 'bi-lock'}`}></i>
                                         </button>
                                     </td>
                                 </tr>
                             ))
                            }
                        </tbody>
                    </table>
                </div>
                {totalPages > 1 && (
                    <div className="card-footer bg-white border-0 py-3 d-flex justify-content-center">
                         <button className="btn btn-sm btn-outline-secondary me-2" disabled={page===0} onClick={() => setPage(p => p-1)}><i className="bi bi-chevron-left"></i></button>
                         <span className="align-self-center small mx-2">{t('page', { current: page + 1, total: totalPages })}</span>
                         <button className="btn btn-sm btn-outline-secondary ms-2" disabled={page===totalPages-1} onClick={() => setPage(p => p+1)}><i className="bi bi-chevron-right"></i></button>
                    </div>
                )}
             </div>
        </div>
    );

    return (
        <div className="d-flex min-vh-100 bg-light font-inter">
            <Sidebar />
            <div className="flex-grow-1 d-flex flex-column" style={{height: '100vh', overflow: 'hidden'}}>
                <Topbar />
                <div className="flex-grow-1 overflow-auto bg-light">
                    {activeTab === 'overview' && <OverviewTab />}
                    {activeTab === 'users' && <UsersTab />}
                </div>
            </div>

            {confirmModal.show && (
                <div className="modal fade show d-block" style={{backgroundColor: 'rgba(0,0,0,0.5)'}}>
                    <div className="modal-dialog modal-dialog-centered">
                        <div className="modal-content shadow border-0 rounded-4">
                            <div className="modal-body text-center p-5">
                                <i className={`bi ${confirmModal.isLocked ? 'bi-unlock-fill text-success' : 'bi-lock-fill text-danger'} display-1 mb-4`}></i>
                                <h4 className="fw-bold mb-3">{confirmModal.isLocked ? t('confirmUnlock') : t('confirmLock')}</h4>
                                <p className="text-muted mb-5">{confirmModal.isLocked ? t('confirmDescUnlock') : t('confirmDescLock')}</p>
                                <div className="d-flex justify-content-center gap-3">
                                    <button className="btn btn-light px-5 py-2 rounded-pill fw-bold" onClick={() => setConfirmModal({...confirmModal, show: false})}>{t('cancel')}</button>
                                    <button className={`btn ${confirmModal.isLocked ? 'btn-success' : 'btn-danger'} px-5 py-2 rounded-pill fw-bold text-white shadow-sm`} onClick={confirmAction}>{t('confirm')}</button>
                                </div>
                            </div>
                        </div>
                    </div>
                </div>
            )}
        </div>
    );
};

export default AdminDashboard;