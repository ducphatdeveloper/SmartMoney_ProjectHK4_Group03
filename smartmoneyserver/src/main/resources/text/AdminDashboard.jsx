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
        totalUsers: "Tổng User",
        onlineUsers: "User trực tuyến",
        transactions: "Giao dịch hệ thống",
        flowAnalysis: "Phân tích dòng tiền",
        categoryDetail: "Chi tiết danh mục (%)",
        ratioInExp: "Tỷ lệ Thu - Chi (%)",
        abnormalTrans: "Giao dịch bất thường",
        scanNow: "Gửi thông báo ({count})",
        scanning: "Đang quét...",
        detected: "Phát hiện: {count} người dùng",
        noAbnormal: "Không có ai vượt ngưỡng",
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
        sessionExpired: "Session expired.",
        accountLocked: "Account has been locked."
    }
};

const AdminDashboard = () => {
    // --- STATE ---
    const [activeTab, setActiveTab] = useState('overview'); // 'overview' | 'users'
    const [lang, setLang] = useState(localStorage.getItem('adminLang') || 'vi');

    // Hàm dịch hỗ trợ tham số động
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
    
    // Filter/Pagination State
    const [searchTerm, setSearchTerm] = useState('');
    const [filterLocked, setFilterLocked] = useState('');
    const [filterOnline, setFilterOnline] = useState('');
    const [threshold, setThreshold] = useState(5000000); // Ngưỡng mặc định 5tr
    const [page, setPage] = useState(0);
    const [totalPages, setTotalPages] = useState(0);
    const [rangeMode, setRangeMode] = useState('MONTHLY');
    
    // UI State
    const [loading, setLoading] = useState(false);
    const [currentUser, setCurrentUser] = useState(null);
    const [notifying, setNotifying] = useState(false);
    const [loadingAbnormal, setLoadingAbnormal] = useState(false);
    const [showNotifications, setShowNotifications] = useState(false);
    const [confirmModal, setConfirmModal] = useState({ show: false, userId: null, isLocked: false });

    const navigate = useNavigate();

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
            if (res.data.success) setStats(res.data.data);
            
            // Gọi thêm API lấy số user online thực (dựa trên active time)
            const onlineRes = await adminApi.getOnlineUsers();
            if (onlineRes.data.success) {
                setStats(prev => ({ ...prev, activeDevices: onlineRes.data.data }));
            }
        } catch (err) { console.error(err); }
    };

    const fetchTransactionStats = useCallback(async () => {
        try {
            const res = await adminApi.getSystemTransactionStats(rangeMode);
            // Cấu trúc trả về là ApiResponse -> lấy res.data.data
            setTransactionStats(res.data.data);
        } catch (err) { console.error(err); }
    }, [rangeMode]);

    const fetchAbnormalUsers = useCallback(async () => {
        setLoadingAbnormal(true);
        try {
            const res = await adminApi.getAbnormalUsers(threshold);
            // Res là ApiResponse<List<Map>> -> lấy res.data.data
            setAbnormalUsers(res.data.data || []);
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

    const fetchNotifications = async (adminId) => {
        try {
            const res = await adminApi.getAdminNotifications(adminId);
            setNotifications(res.data.data || []);
        } catch (err) { console.error(err); }
    };

    const fetchUsers = useCallback(async (isBackground = false) => {
        if (!isBackground) setLoading(true);
        try {
            const params = {
                page, size: 8,
                // Cắt khoảng trắng và chuyển thành null nếu rỗng
                search: searchTerm && searchTerm.trim() !== '' ? searchTerm.trim() : null,
                // Chuyển đổi chính xác chuỗi sang boolean hoặc null
                locked: filterLocked === 'true' ? true : (filterLocked === 'false' ? false : null),
                // Nếu filterOnline là chuỗi rỗng thì gửi null
                online: filterOnline === 'true' ? true : (filterOnline === 'false' ? false : null)
            };
            const res = await adminApi.getUsers(params);
            setUsers(res.data.data.content || []);
            setTotalPages(res.data.data.totalPages || 0);
        } catch (err) { console.error(err); } 
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
        fetchTransactionStats(); // Load initial stats
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
    
    // 1. Tính tổng volume giao dịch để tính % tỷ trọng trên toàn hệ thống
    const totalVolume = breakdown.reduce((acc, item) => acc + item.amount, 0);

    const totalIncome = breakdown.filter(i => i.type === 'INCOME').reduce((acc, i) => acc + i.amount, 0);
    const totalExpense = breakdown.filter(i => i.type === 'EXPENSE').reduce((acc, i) => acc + i.amount, 0);
    const totalInExp = totalIncome + totalExpense;

    const incomePerc = totalInExp > 0 ? ((totalIncome / totalInExp) * 100).toFixed(1) : 0;
    const expensePerc = totalInExp > 0 ? ((totalExpense / totalInExp) * 100).toFixed(1) : 0;

    // 2. Sắp xếp: Nhóm Thu nhập lên đầu, Chi tiêu bên dưới. Trong mỗi nhóm sắp xếp giảm dần theo giá trị.
    const sortedBreakdown = [...breakdown].sort((a, b) => {
        if (a.type !== b.type) return a.type === 'INCOME' ? -1 : 1;
        return b.amount - a.amount;
    });
    
    const barChartData = {
        labels: sortedBreakdown.map(item => `${item.type === 'INCOME' ? '↑' : '↓'} ${item.categoryName}`),
        datasets: [
            {
                label: 'Tỷ trọng hệ thống',
                data: sortedBreakdown.map(item => totalVolume > 0 ? ((item.amount / totalVolume) * 100).toFixed(1) : 0),
                backgroundColor: sortedBreakdown.map(item => item.type === 'INCOME' ? '#10b981' : '#f43f5e'),
                hoverBackgroundColor: sortedBreakdown.map(item => item.type === 'INCOME' ? '#059669' : '#e11d48'),
                borderRadius: 4,
                barThickness: 24,
                maxBarThickness: 35,
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
                font: { size: 15, weight: 'bold', family: 'Inter, sans-serif' },
                color: '#334155',
                padding: { bottom: 20 }
            },
            tooltip: {
                displayColors: false,
                callbacks: {
                    label: function(context) {
                        return ` Tỷ trọng trong hệ thống: ${context.raw}%`;
                    }
                },
                backgroundColor: '#1e293b',
                padding: 12,
                cornerRadius: 4
            }
        },
        scales: {
            x: {
                grid: { color: '#f1f5f9', drawBorder: false },
                max: 100,
                ticks: {
                    callback: (value) => value > 0 ? value + "%" : value,
                    font: { size: 10, weight: '500' },
                    color: '#64748b'
                }
            },
            y: {
                grid: { display: false },
                ticks: { 
                    font: { size: 12, weight: '600' },
                    color: '#334155'
                }
            }
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
            legend: {
                position: 'bottom',
                labels: {
                    usePointStyle: true,
                    padding: 20,
                    font: { size: 12, weight: '500' }
                }
            },
            title: {
                display: true,
                text: t('ratioInExp').toUpperCase(),
                font: { size: 15, weight: 'bold' },
                padding: { bottom: 10 }
            },
            tooltip: {
                callbacks: {
                    label: (context) => ` ${context.label}: ${context.raw}%`
                },
                backgroundColor: '#1e293b',
                padding: 12,
                cornerRadius: 4
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
            {/*<div className="dropdown">*/}
            {/*    <div className="d-flex align-items-center text-white text-decoration-none dropdown-toggle" id="dropdownUser1" data-bs-toggle="dropdown" aria-expanded="false">*/}
            {/*        <div className="rounded-circle bg-secondary d-flex justify-content-center align-items-center me-2" style={{width: 32, height: 32}}>*/}
            {/*            <i className="bi bi-person-fill"></i>*/}
            {/*        </div>*/}
            {/*        <strong>{currentUser?.roleName || 'Admin'}</strong>*/}
            {/*    </div>*/}
            {/*</div>*/}
        </div>
    );

    const Topbar = () => (
        <nav className="navbar navbar-expand-lg navbar-light bg-white border-bottom shadow-sm px-4 py-2 sticky-top">
            <div className="d-flex w-100 justify-content-between align-items-center">
                <h5 className="mb-0 fw-bold text-secondary">
                    {activeTab === 'overview' ? t('dashboard') : t('users')}
                </h5>
                <div className="d-flex align-items-center">
                    {/* Language Switcher */}
                    <div className="btn-group btn-group-sm me-4 shadow-sm border rounded">
                        <button onClick={() => toggleLang('vi')} className={`btn ${lang === 'vi' ? 'btn-primary' : 'btn-light'}`}>
                            VN
                        </button>
                        <button onClick={() => toggleLang('en')} className={`btn ${lang === 'en' ? 'btn-primary' : 'btn-light'}`}>
                            EN
                        </button>
                    </div>

                    {/* Notifications */}
                     <div className="position-relative me-4">
                        <button className="btn btn-light rounded-circle position-relative shadow-sm" onClick={() => setShowNotifications(!showNotifications)}>
                            <i className="bi bi-bell"></i>
                            {notifications.length > 0 && (
                                <span className="position-absolute top-0 start-100 translate-middle badge rounded-pill bg-danger" style={{fontSize: '0.6rem'}}>
                                    {notifications.length}
                                </span>
                            )}
                        </button>
                        {/* Dropdown Content */}
                        {showNotifications && (
                            <div className="position-absolute end-0 mt-3 bg-white shadow-lg rounded border" style={{ width: '320px', zIndex: 1050 }}>
                                <div className="p-2 border-bottom fw-bold bg-light rounded-top">{t('sysNotify')}</div>
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
                    
                    <button onClick={() => handleLogout()} className="btn btn-outline-danger btn-sm d-flex align-items-center gap-2">
                        <i className="bi bi-box-arrow-right"></i> {t('logout')}
                    </button>
                </div>
            </div>
        </nav>
    );

    const OverviewTab = () => (
        <div className="container-fluid py-4">
             {/* Stats Cards */}
             <div className="row g-3 mb-4">
                <div className="col-xl-4 col-md-6">
                    <div className="card shadow-sm border-0 border-start border-4 border-primary h-100" onClick={() => handleCardClick('TOTAL')} style={{cursor: 'pointer', transition: 'transform 0.2s'}}>
                        <div className="card-body p-4 d-flex justify-content-between align-items-center">
                            <div>
                                <p className="text-muted mb-1 fw-medium text-uppercase small">{t('totalUsers')}</p>
                                <h3 className="mb-0 fw-bold text-dark">{stats.totalUsers?.toLocaleString()}</h3>
                            </div>
                            <div className="rounded-circle bg-primary bg-opacity-10 p-3">
                                <i className="bi bi-people-fill fs-3 text-primary"></i>
                            </div>
                        </div>
                    </div>
                </div>
                <div className="col-xl-4 col-md-6">
                    <div className="card shadow-sm border-0 border-start border-4 border-success h-100" onClick={() => handleCardClick('ONLINE')} style={{cursor: 'pointer', transition: 'transform 0.2s'}}>
                        <div className="card-body p-4 d-flex justify-content-between align-items-center">
                            <div>
                                <p className="text-muted mb-1 fw-medium text-uppercase small">{t('onlineUsers')}</p>
                                <h3 className="mb-0 fw-bold text-dark">{stats.activeDevices?.toLocaleString()}</h3>
                            </div>
                            <div className="rounded-circle bg-success bg-opacity-10 p-3">
                                <i className="bi bi-broadcast fs-3 text-success"></i>
                            </div>
                        </div>
                    </div>
                </div>
                <div className="col-xl-4 col-md-12">
                    <div className="card shadow-sm border-0 border-start border-4 border-info h-100">
                        <div className="card-body p-4 d-flex justify-content-between align-items-center">
                            <div>
                                <p className="text-muted mb-1 fw-medium text-uppercase small">{t('transactions')}</p>
                                <h3 className="mb-0 fw-bold text-dark">{(stats.totalTransactions || 0).toLocaleString()}</h3>
                            </div>
                            <div className="rounded-circle bg-info bg-opacity-10 p-3">
                                <i className="bi bi-activity fs-3 text-info"></i>
                            </div>
                        </div>
                    </div>
                </div>
             </div>

             {/* Charts & Abnormal List */}
             <div className="row g-4">
                <div className="col-lg-8">
                    <div className="card shadow-sm border-0 rounded-3 h-100">
                        <div className="card-header bg-transparent border-0 pt-4 px-4 d-flex justify-content-between align-items-center">
                            <h6 className="mb-0 fw-bold text-dark"><i className="bi bi-graph-up-arrow me-2 text-primary"></i>{t('flowAnalysis')}</h6>
                            <div className="btn-group btn-group-sm shadow-sm rounded">
                                {['WEEKLY', 'MONTHLY', 'YEARLY'].map(m => (
                                    <button key={m} className={`btn ${rangeMode === m ? 'btn-primary' : 'btn-outline-secondary'}`} 
                                            onClick={() => setRangeMode(m)}>{m === 'WEEKLY' ? t('week') : m === 'MONTHLY' ? t('month') : t('year')}</button>
                                ))}
                            </div>
                        </div>
                        <div className="card-body">
                            {transactionStats ? (
                                <div className="row g-0 align-items-center" style={{ minHeight: '380px' }}>
                                    <div className="col-md-7 border-end border-light">
                                        <div style={{ height: '360px', padding: '10px' }}>
                                            <Bar data={barChartData} options={barOptions} />
                                        </div>
                                    </div>
                                    <div className="col-md-5">
                                        <div style={{ height: '320px', padding: '20px' }}>
                                            <Doughnut data={doughnutData} options={doughnutOptions} />
                                        </div>
                                    </div>
                                </div>
                            ) : <div className="text-center py-5">Đang tải biểu đồ...</div>}
                        </div>
                    </div>
                </div>
                <div className="col-lg-4">
                    <div className="card shadow-sm border-0 rounded-3 h-100">
                        <div className="card-header bg-transparent border-0 pt-4 px-4 d-flex justify-content-between align-items-center">
                            <div className="d-flex align-items-center gap-2">
                                <h6 className="mb-0 fw-bold text-dark"><i className="bi bi-shield-exclamation me-2 text-warning"></i>{t('abnormalTrans')}</h6>
                            </div>
                            <button className="btn btn-sm btn-light rounded-circle shadow-sm" onClick={fetchAbnormalUsers}><i className="bi bi-arrow-clockwise"></i></button>
                        </div>
                        <div className="card-body px-4">
                            {/* Threshold input removed as system detects automatically */}
                            <div className="abnormal-list mb-4 px-1" style={{maxHeight: '350px', overflowY: 'auto'}}>
                                <div className="small fw-bold mb-3 text-secondary text-uppercase border-bottom pb-2" style={{letterSpacing: '0.5px'}}>{t('detected', { count: abnormalUsers.length })}</div>
                                {loadingAbnormal ? <div className="text-center py-3 small">{t('scanning')}</div> : 
                                 abnormalUsers.length === 0 ? <div className="text-center py-3 text-muted small">{t('noAbnormal')}</div> :
                                 abnormalUsers.map((item, idx) => (
                                     <div key={idx} className="d-flex justify-content-between align-items-center mb-3 p-3 bg-white rounded-3 shadow-sm border-start border-3 border-warning card-hover">
                                         <div style={{fontSize: '0.85rem'}}>
                                             <div className="fw-bold text-dark">{item.username || 'N/A'}</div>
                                             <div className="text-muted small">{item.transactionCount} {t('transactions').toLowerCase()}</div>
                                         </div>
                                         <span className="badge text-danger" style={{fontSize: '0.7rem'}}>{formatCurrency(item.totalAmount)}</span>
                                     </div>
                                 ))
                                }
                            </div>

                            <button className="btn btn-warning w-100 fw-bold text-dark shadow-sm py-2" 
                                    onClick={handleNotifyAbnormal} 
                                    disabled={notifying || abnormalUsers.length === 0}>
                                {notifying ? <span className="spinner-border spinner-border-sm me-2"></span> : <i className="bi bi-megaphone me-2"></i>}
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
             <div className="card shadow-sm border-0">
                <div className="card-header bg-white py-3 border-0 d-flex flex-wrap gap-2 justify-content-between align-items-center">
                    <div className="d-flex gap-2">
                        <input type="text" className="form-control form-control-sm" placeholder={t('searchPlaceholder')} 
                               value={searchTerm} onChange={e => {setSearchTerm(e.target.value); setPage(0);}} style={{width: '200px'}} />
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
                <div className="table-responsive">
                    <table className="table table-hover align-middle mb-0">
                        <thead className="table-light">
                            <tr>
                                <th className="ps-4">{t('id')}</th>
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
                                 <tr key={u.id}>
                                     <td className="ps-4 fw-bold text-muted">#{u.id}</td>
                                     <td>{u.accEmail}</td>
                                     <td>{u.accPhone || '-'}</td>
                                     <td>{u.locked ? <span className="badge bg-danger-subtle text-danger">{t('locked')}</span> : <span className="badge bg-success-subtle text-success">{t('active')}</span>}</td>
                                     <td>{u.online ? <span className="badge bg-success">{t('online')}</span> : <span className="badge bg-secondary">{t('offline')}</span>}</td>
                                     <td className="text-end pe-4">
                                         <button className={`btn btn-sm ${u.locked ? 'btn-outline-success' : 'btn-outline-danger'} border-0`}
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
        <div className="d-flex min-vh-100 bg-light">
            <Sidebar />
            <div className="flex-grow-1 d-flex flex-column" style={{height: '100vh', overflow: 'hidden'}}>
                <Topbar />
                <div className="flex-grow-1 overflow-auto bg-light">
                    {activeTab === 'overview' && <OverviewTab />}
                    {activeTab === 'users' && <UsersTab />}
                </div>
            </div>

            {/* Confirm Modal */}
            {confirmModal.show && (
                <div className="modal fade show d-block" style={{backgroundColor: 'rgba(0,0,0,0.5)'}}>
                    <div className="modal-dialog modal-dialog-centered">
                        <div className="modal-content shadow border-0">
                            <div className="modal-body text-center p-4">
                                <i className={`bi ${confirmModal.isLocked ? 'bi-unlock-fill text-success' : 'bi-lock-fill text-danger'} display-1 mb-3`}></i>
                                <h5 className="fw-bold mb-3">{confirmModal.isLocked ? t('confirmUnlock') : t('confirmLock')}</h5>
                                <p className="text-muted mb-4">{confirmModal.isLocked ? t('confirmDescUnlock') : t('confirmDescLock')}</p>
                                <div className="d-flex justify-content-center gap-2">
                                    <button className="btn btn-light px-4" onClick={() => setConfirmModal({...confirmModal, show: false})}>{t('cancel')}</button>
                                    <button className={`btn ${confirmModal.isLocked ? 'btn-success' : 'btn-danger'} px-4`} onClick={confirmAction}>{t('confirm')}</button>
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