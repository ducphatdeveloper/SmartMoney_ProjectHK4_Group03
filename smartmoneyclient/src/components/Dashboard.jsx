import React, { useEffect, useState, useCallback } from 'react';
import { useNavigate } from 'react-router-dom';
import { authApi, userApi, transactionApi, notificationApi } from '../server/api';
import { XAxis, YAxis, CartesianGrid, Tooltip, Legend, ResponsiveContainer, AreaChart, Area } from 'recharts';

// --- TRANSLATIONS DICTIONARY ---
const translations = {
    vi: {
        dashboard: "Tổng quan",
        mainWallet: "Ví chính",
        income: "Thu nhập",
        expense: "Chi tiêu",
        recentTransactions: "Giao dịch gần đây",
        flowAnalysis: "Phân tích thu chi",
        allTransactions: "Xem tất cả",
        noTransactions: "Chưa có giao dịch nào",
        noNotifications: "Không có thông báo mới",
        sysNotify: "Thông báo",
        profile: "Hồ sơ",
        settings: "Cài đặt",
        logout: "Đăng xuất",
        today: "Hôm nay",
        yesterday: "Hôm qua",
        thisWeek: "Tuần này",
        lastWeek: "Tuần trước",
        thisMonth: "Tháng này",
        lastMonth: "Tháng trước",
        thisQuarter: "Quý này",
        thisYear: "Năm nay",
        last7Days: "7 ngày qua",
        last30Days: "30 ngày qua",
        detected: "Phát hiện {count} thông báo",
        items: "{count} mục",
        searchPlaceholder: "Tìm kiếm...",
        accountLocked: "Tài khoản bị khóa.",
        sessionExpired: "Phiên đăng nhập hết hạn."
    },
    en: {
        dashboard: "Dashboard",
        mainWallet: "Main Wallet",
        income: "Income",
        expense: "Expense",
        recentTransactions: "Recent Transactions",
        flowAnalysis: "Cash Flow Analysis",
        allTransactions: "See all",
        noTransactions: "No transactions yet",
        noNotifications: "No new notifications",
        sysNotify: "Notifications",
        profile: "Profile",
        settings: "Settings",
        logout: "Logout",
        today: "Today",
        yesterday: "Yesterday",
        thisWeek: "This Week",
        lastWeek: "Last Week",
        thisMonth: "This Month",
        lastMonth: "Last Month",
        thisQuarter: "This Quarter",
        thisYear: "This Year",
        last7Days: "Last 7 Days",
        last30Days: "Last 30 Days",
        detected: "{count} notifications detected",
        items: "{count} items",
        searchPlaceholder: "Search...",
        accountLocked: "Account locked.",
        sessionExpired: "Session expired."
    }
};

const Dashboard = () => {
    const navigate = useNavigate();
    const [currentUser, setCurrentUser] = useState(null);
    const [stats, setStats] = useState({ balance: 0, income: 0, expense: 0 });
    const [recentTransactions, setRecentTransactions] = useState([]);
    const [chartData, setChartData] = useState([]);
    const [notifications, setNotifications] = useState([]);
    const [chartRange, setChartRange] = useState('LAST_MONTH'); // Mặc định dữ liệu quá khứ (Tháng trước)
    const [lang, setLang] = useState(localStorage.getItem('adminLang') || 'vi');
    const [showNotifications, setShowNotifications] = useState(false);
    const [loading, setLoading] = useState(true);
    const [isBalanceHidden, setIsBalanceHidden] = useState(false);

    // Helper: Hàm dịch hỗ trợ tham số động
    const t = (key, params = {}) => {
        let text = translations[lang][key] || key;
        Object.keys(params).forEach(p => {
            text = text.replace(`{${p}}`, params[p]);
        });
        return text;
    };

    // Helper: Hàm phân giải ngày tháng linh hoạt (Xử lý cả chuỗi ISO và mảng Jackson [yyyy, mm, dd...])
    const parseDate = (dateValue) => {
        if (!dateValue) return null;
        if (Array.isArray(dateValue)) {
            const [y, m, d, h = 0, min = 0, s = 0] = dateValue;
            return new Date(y, m - 1, d, h, min, s);
        }
        const date = new Date(dateValue);
        return isNaN(date.getTime()) ? null : date;
    };

    // Helper: Lấy icon và màu sắc dựa trên tên danh mục (Giống Money Lover)
    const getCategoryMeta = (categoryName, type) => {
        const name = (categoryName || "").toLowerCase();
        if (name.includes("ăn") || name.includes("food")) return { icon: "bi-egg-fried", color: "#f39c12" };
        if (name.includes("xăng") || name.includes("xe") || name.includes("transport")) return { icon: "bi-car-front", color: "#3498db" };
        if (name.includes("mua") || name.includes("shop")) return { icon: "bi-bag-check", color: "#e67e22" };
        if (name.includes("lương") || name.includes("salary")) return { icon: "bi-cash-stack", color: "#27ae60" };
        if (name.includes("quà") || name.includes("gift")) return { icon: "bi-gift", color: "#9b59b6" };
        if (name.includes("học") || name.includes("edu")) return { icon: "bi-book", color: "#2980b9" };
        
        return type === 'INCOME' ? { icon: "bi-plus-circle", color: "#27ae60" } : { icon: "bi-dash-circle", color: "#95a5a6" };
    };

    // Hàm đăng xuất (sử dụng useCallback để dùng trong useEffect)
    const handleLogout = useCallback(async (reason = '') => {
        // Nếu là người dùng chủ động nhấn đăng xuất (không có lý do hệ thống), hiển thị xác nhận
        if (!reason && !window.confirm("Bạn có chắc chắn muốn đăng xuất khỏi hệ thống?")) {
            return;
        }

        try {
            await authApi.logout('web-browser');
        } catch (err) {
            console.error("Lỗi đăng xuất API:", err);
        } finally {
            // Lưu lại cài đặt ngôn ngữ trước khi xóa bộ nhớ
            const lang = localStorage.getItem('adminLang');
            localStorage.clear();
            if (lang) localStorage.setItem('adminLang', lang);

            if (reason && typeof reason === 'string') alert(reason);
            navigate('/login');
        }
    }, [navigate]);

    useEffect(() => {
        const storedUser = JSON.parse(localStorage.getItem('user'));
        const token = localStorage.getItem('accessToken');

        if (!token || !storedUser) {
            navigate('/login');
            return;
        }
        setCurrentUser(storedUser);
    }, [navigate]);

    // Effect: Tự động kiểm tra trạng thái tài khoản mỗi 5 giây
    useEffect(() => {
        const checkAccountStatus = async () => {
            try {
                // Gọi API lấy profile để check trạng thái mới nhất
                const res = await userApi.getProfile();
                
                // Nếu API trả về thông tin user và user bị khóa
                if (res.data && res.data.locked) {
                    handleLogout(t('accountLocked'));
                }
            } catch (error) {
                // Nếu gặp lỗi 401 (Unauthorized) hoặc 403 (Forbidden) -> Token hết hạn hoặc bị chặn
                if (error.response && (error.response.status === 401 || error.response.status === 403)) {
                    handleLogout(t('sessionExpired'));
                }
            }
        };

        const interval = setInterval(checkAccountStatus, 5000); // Check mỗi 5 giây

        return () => clearInterval(interval);
    }, [handleLogout]);

    const loadDashboardData = useCallback(async (userId) => {
        setLoading(true);
        try {
            // Chỉ gửi range nếu không dùng CUSTOM, xóa bỏ các key undefined hoàn toàn
            const params = { range: chartRange };

            // Gọi song song các API để tối ưu thời gian
            const [statsRes, transactionsRes, chartRes, notifRes] = await Promise.allSettled([
                transactionApi.getSummary(params),
                transactionApi.getJournal(params),
                transactionApi.getTrend(params),
                notificationApi.getByUser(userId) 
            ]);

            // 1. Xử lý Thống kê (Summary)
            if (statsRes.status === 'fulfilled' && statsRes.value.data.success) {
                const summary = statsRes.value.data.data;
                setStats({
                    income: summary.totalIncome || 0,
                    expense: summary.totalExpense || 0,
                    balance: summary.closingBalance || summary.netBalance || 0 
                });
            }

            // 2. Xử lý Giao dịch gần đây (Journal)
            if (transactionsRes.status === 'fulfilled' && transactionsRes.value.data.success) {
                // Journal trả về List<DailyTransactionGroup>, ta làm phẳng để lấy 5 giao dịch mới nhất
                const journalGroups = transactionsRes.value.data.data || [];
                const flattened = journalGroups.flatMap(group => group.transactions || [])
                    .sort((a, b) => new Date(b.date) - new Date(a.date))
                    .slice(0, 5);
                setRecentTransactions(flattened);
            }

            // 3. Xử lý Biểu đồ (Trend)
            if (chartRes.status === 'fulfilled' && chartRes.value.data.success) {
                let trendData = chartRes.value.data.data || [];
                
                // Định dạng lại nhãn trục X dựa trên Range
                const formattedData = trendData.map(item => {
                    const dateObj = parseDate(item.date);
                    let label = "N/A";

                    if (dateObj) {
                        if (chartRange.includes('YEAR') || chartRange.includes('QUARTER')) {
                            label = `Tháng ${dateObj.getMonth() + 1}`;
                        } else if (chartRange.includes('WEEK')) {
                            label = dateObj.toLocaleDateString('vi-VN', { weekday: 'short', day: '2-digit' });
                        } else if (chartRange === 'TODAY' || chartRange === 'YESTERDAY' || chartRange === 'THIS_DAY') {
                            label = dateObj.toLocaleTimeString('vi-VN', { hour: '2-digit', minute: '2-digit' });
                        } else {
                            label = dateObj.toLocaleDateString('vi-VN', { day: '2-digit', month: '2-digit' });
                        }
                    }

                    return {
                        name: label,
                        income: item.income || 0,
                        expense: item.expense || 0
                    };
                });

                let finalChartData = formattedData;
                if (formattedData.length === 1) {
                    finalChartData = [
                        { ...formattedData[0], name: '' }, 
                        formattedData[0]
                    ];
                }
                setChartData(finalChartData);
            }

            if (notifRes.status === 'fulfilled' && notifRes.value.data.success) {
                setNotifications(notifRes.value.data.data);
            }
        } catch (error) {
            console.error("Lỗi tải dữ liệu dashboard", error);
        } finally {
            setLoading(false);
        }
    }, [chartRange]); // loadDashboardData phụ thuộc vào chartRange

    useEffect(() => {
        const userId = currentUser?.userId || currentUser?.id;
        if (userId) {
            loadDashboardData(userId);
        }
    }, [loadDashboardData, currentUser]);

    const formatCurrency = (amount) => {
        return new Intl.NumberFormat('vi-VN', { style: 'currency', currency: 'VND' }).format(amount || 0);
    };

    const formatDate = (dateValue) => {
        const date = parseDate(dateValue);
        if (!date) return '---';
        return date.toLocaleDateString('vi-VN');
    };

    if (loading) {
        return (
            <div className="min-vh-100 d-flex justify-content-center align-items-center bg-light">
                <div className="spinner-border text-primary" role="status">
                    <span className="visually-hidden">Đang tải...</span>
                </div>
            </div>
        );
    }

    // Helper component cho danh sách giao dịch
    const TransactionItem = ({ icon, color, title, date, amount, isIncome }) => (
        <li className="list-group-item border-0 px-4 py-3 d-flex align-items-center">
            <div className="rounded-circle p-2 me-3 d-flex align-items-center justify-content-center" style={{ backgroundColor: color, width: '40px', height: '40px' }}>
                <i className={`bi ${icon} text-white fs-5`}></i>
            </div>
            <div className="flex-grow-1">
                <h6 className="mb-0 fw-bold text-dark">{title}</h6>
                <small className="text-muted">{formatDate(date)}</small>
            </div>
            <div className={`fw-bold ${isIncome ? 'text-success' : 'text-danger'}`}>
                {amount}
            </div>
        </li>
    );

    return (
        <div className="min-vh-100 bg-light">
            <style>{`
                .card-hover-up { transition: all 0.3s ease; }
                .card-hover-up:hover { transform: translateY(-5px); box-shadow: 0 10px 20px rgba(0,0,0,0.1) !important; }
                .animate-pulse { animation: pulse 2s infinite; }
                @keyframes pulse { 0% { opacity: 1; } 50% { opacity: 0.5; } 100% { opacity: 1; } }
                .hover-bg-light:hover { background-color: #f8f9fa; cursor: pointer; }
                .extra-small { font-size: 0.75rem; }
            `}</style>

            {/* Navbar */}
            <nav className="navbar navbar-expand-lg navbar-light bg-white shadow-sm px-4 sticky-top">
                <span className="navbar-brand fw-bold fs-4">
                    Money Lover
                </span>
                
                <div className="ms-auto d-flex align-items-center">
                    {/* Search Icon */}
                    <button className="btn btn-link text-dark me-2">
                        <i className="bi bi-search fs-5"></i>
                    </button>

                    {/* Language Switcher */}
                    <div className="btn-group btn-group-sm me-3 border rounded shadow-sm overflow-hidden">
                        <button 
                            onClick={() => { setLang('vi'); localStorage.setItem('adminLang', 'vi'); }} 
                            className={`btn ${lang === 'vi' ? 'btn-primary' : 'btn-white'}`}>VN</button>
                        <button 
                            onClick={() => { setLang('en'); localStorage.setItem('adminLang', 'en'); }} 
                            className={`btn ${lang === 'en' ? 'btn-primary' : 'btn-white'}`}>EN</button>
                    </div>

                    {/* Notification Bell */}
                    <div className="position-relative me-4">
                        <button 
                            className="btn btn-link text-dark p-0 position-relative text-decoration-none"
                            onClick={() => setShowNotifications(!showNotifications)}
                        >
                            <i className="bi bi-bell fs-4"></i>
                            {notifications.length > 0 && (
                                <span className="position-absolute top-0 start-100 translate-middle badge rounded-pill bg-danger animate-pulse" style={{ fontSize: '0.6rem' }}>
                                    {notifications.length}
                                </span>
                            )}
                        </button>

                        {/* Dropdown Thông báo */}
                        {showNotifications && (
                            <div className="position-absolute end-0 mt-3 bg-white shadow-lg rounded overflow-hidden" style={{ width: '300px', zIndex: 1050 }}>
                                <div className="p-2 border-bottom bg-light fw-bold">{t('sysNotify')}</div>
                                <div style={{ maxHeight: '300px', overflowY: 'auto' }}>
                                    {notifications.length === 0 ? (
                                        <div className="p-4 text-center text-muted">
                                            <i className="bi bi-chat-left-dots display-6 mb-2 d-block opacity-25"></i>
                                            <div className="small">{t('noNotifications')}</div>
                                        </div>
                                    ) : (
                                        notifications.map((n, idx) => (
                                            <div key={idx} className="p-2 border-bottom small hover-bg-light">
                                                <div className="fw-bold text-primary">{n.title || 'Thông báo'}</div>
                                                <div>{n.message || n.content}</div>
                                                <div className="text-muted" style={{fontSize: '0.7rem'}}>{formatDate(n.createdAt)}</div>
                                            </div>
                                        ))
                                    )}
                                </div>
                            </div>
                        )}
                    </div>

                    <div className="d-flex align-items-center">
                        <div className="me-3 text-end d-none d-sm-block">
                            <div className="fw-bold text-dark">{currentUser?.fullName || 'Người dùng'}</div>
                            <div className="text-muted small">{currentUser?.accEmail}</div>
                        </div>
                        <div className="dropdown">
                            <button className="btn btn-light rounded-circle p-0" type="button" data-bs-toggle="dropdown" style={{width: '40px', height: '40px'}}>
                                <img 
                                    src={currentUser?.avatar || "https://ui-avatars.com/api/?name=" + (currentUser?.fullName || "User")} 
                                    alt="Avatar" 
                                    className="rounded-circle w-100 h-100 object-fit-cover"
                                />
                            </button>
                            <ul className="dropdown-menu dropdown-menu-end shadow border-0">
                                <li><button className="dropdown-item" onClick={() => navigate('/profile')}><i className="bi bi-person me-2"></i>{t('profile')}</button></li>
                                <li><button className="dropdown-item" onClick={() => navigate('/settings')}><i className="bi bi-gear me-2"></i>{t('settings')}</button></li>
                                <li><hr className="dropdown-divider"/></li>
                                <li><button className="dropdown-item text-danger" onClick={() => handleLogout()}><i className="bi bi-box-arrow-right me-2"></i>{t('logout')}</button></li>
                            </ul>
                        </div>

                        {/* Nút đăng xuất nhanh cho Desktop */}
                        <button 
                            className="btn btn-outline-danger btn-sm ms-3 d-none d-md-flex align-items-center gap-2 rounded-pill shadow-sm border-2 fw-bold"
                            onClick={() => handleLogout()}
                        >
                            <i className="bi bi-box-arrow-right"></i>
                            <span>{t('logout')}</span>
                        </button>
                    </div>
                </div>
            </nav>

            <div className="container py-4">
                {/* WALLET CARD (Gradient) */}
                <div className="row mb-4">
                    <div className="col-12">
                        <div className="card border-0 shadow p-4 text-white card-hover-up" 
                            style={{ 
                                background: 'linear-gradient(to right, #4facfe 0%, #00f2fe 100%)',
                                borderRadius: '20px'
                            }}
                        >
                            <div className="card-body p-0">
                                <p className="mb-2 opacity-75">{t('mainWallet')}</p>
                                <div className="d-flex align-items-center">
                                    <h1 className="fw-bold mb-0 me-3">
                                        {isBalanceHidden ? "••••••••" : formatCurrency(stats.balance || 0)}
                                    </h1>
                                    <button 
                                        className="btn btn-link text-white p-0" 
                                        onClick={() => setIsBalanceHidden(!isBalanceHidden)}
                                    >
                                        <i className={`bi ${isBalanceHidden ? 'bi-eye-slash' : 'bi-eye'} fs-4`}></i>
                                    </button>
                                </div>
                            </div>
                        </div>
                    </div>
                </div>

                {/* MONTH FILTER */}
                <div className="d-flex justify-content-between align-items-center mb-4">
                    <h5 className="fw-bold mb-0">
                        {chartRange === 'THIS_DAY' || chartRange === 'TODAY' ? t('today') : 
                         chartRange === 'THIS_WEEK' ? t('thisWeek') :
                         chartRange === 'THIS_MONTH' ? `Tháng ${new Date().getMonth() + 1} / ${new Date().getFullYear()}` : 
                         chartRange === 'LAST_MONTH' ? t('lastMonth') :
                         chartRange === 'LAST_7_DAYS' ? t('last7Days') :
                         chartRange === 'THIS_YEAR' ? `Năm ${new Date().getFullYear()}` : t('dashboard')}
                    </h5>
                </div>

                {/* SUMMARY (Income & Expense) */}
                <div className="row g-3 mb-4">
                    <div className="col-6">
                        <div className="card border-0 shadow-sm rounded-4 card-hover-up">
                            <div className="card-body text-center">
                                <div className="bg-success-subtle text-success rounded-3 d-inline-flex p-2 mb-2">
                                    <i className="bi bi-arrow-down-left fs-5"></i>
                                </div>
                                <p className="text-muted extra-small mb-1 fw-bold">{t('income').toUpperCase()}</p>
                                <h5 className="fw-bold text-success mb-0">{formatCurrency(stats.income || 0)}</h5>
                            </div>
                        </div>
                    </div>
                    <div className="col-6">
                        <div className="card border-0 shadow-sm rounded-4">
                            <div className="card-body text-center">
                                <div className="bg-danger-subtle text-danger rounded-3 d-inline-flex p-2 mb-2">
                                    <i className="bi bi-arrow-up-right fs-5"></i>
                                </div>
                                <p className="text-muted extra-small mb-1 fw-bold">{t('expense').toUpperCase()}</p>
                                <h5 className="fw-bold text-danger mb-0">{formatCurrency(stats.expense || 0)}</h5>
                            </div>
                        </div>
                    </div>
                </div>

                {/* Chart Section */}
                <div className="row g-4">
                    <div className="col-lg-8">
                        <div className="card border-0 shadow-sm h-100 rounded-4">
                            <div className="card-header bg-white border-0 py-3 d-flex justify-content-between align-items-center">
                                <h5 className="fw-bold mb-0">{t('flowAnalysis')}</h5>
                                <select 
                                    className="form-select form-select-sm w-auto border-0 bg-light"
                                    value={chartRange}
                                    onChange={(e) => setChartRange(e.target.value)}
                                >
                                    <option value="THIS_DAY">{t('today')}</option>
                                    <option value="YESTERDAY">{t('yesterday')}</option>
                                    <option value="THIS_WEEK">{t('thisWeek')}</option>
                                    <option value="LAST_WEEK">{t('lastWeek')}</option>
                                    <option value="THIS_MONTH">{t('thisMonth')}</option>
                                    <option value="LAST_7_DAYS">{t('last7Days')}</option>
                                    <option value="LAST_30_DAYS">{t('last30Days')}</option>
                                    <option value="LAST_MONTH">{t('lastMonth')}</option>
                                    <option value="THIS_QUARTER">{t('thisQuarter')}</option>
                                    <option value="THIS_YEAR">{t('thisYear')}</option>
                                </select>
                            </div>
                            <div className="card-body" style={{ height: '350px' }}>
                                {chartData.length === 0 ? (
                                    <div className="h-100 d-flex flex-column justify-content-center align-items-center text-muted">
                                        <i className="bi bi-bar-chart display-4 opacity-25"></i>
                                        <p className="mt-2 small">{t('noTransactions')}</p>
                                    </div>
                                ) : (
                                <ResponsiveContainer width="100%" height="100%">
                                    <AreaChart data={chartData} margin={{ top: 10, right: 20, left: 0, bottom: 0 }}>
                                        <defs>
                                            <linearGradient id="colorIncome" x1="0" y1="0" x2="0" y2="1">
                                                <stop offset="5%" stopColor="#198754" stopOpacity={0.1}/>
                                                <stop offset="95%" stopColor="#198754" stopOpacity={0}/>
                                            </linearGradient>
                                            <linearGradient id="colorExpense" x1="0" y1="0" x2="0" y2="1">
                                                <stop offset="5%" stopColor="#dc3545" stopOpacity={0.1}/>
                                                <stop offset="95%" stopColor="#dc3545" stopOpacity={0}/>
                                            </linearGradient>
                                        </defs>
                                        <CartesianGrid vertical={false} strokeDasharray="3 3" stroke="#f0f0f0" />
                                        <XAxis 
                                            dataKey="name" 
                                            axisLine={false} 
                                            tickLine={false} 
                                            tick={{fontSize: 10, fill: '#666'}}
                                            minTickGap={10}
                                        />
                                        <YAxis 
                                            axisLine={false} 
                                            tickLine={false} 
                                            tick={{fontSize: 10, fill: '#666'}}
                                            tickFormatter={(value) => value >= 1000000 ? `${(value / 1000000).toFixed(1)}M` : value.toLocaleString()} 
                                        />
                                        <Tooltip 
                                            formatter={(value) => [formatCurrency(value), ""]}
                                            contentStyle={{ borderRadius: '8px', border: 'none', boxShadow: '0 4px 12px rgba(0,0,0,0.1)' }}
                                        />
                                        <Legend verticalAlign="top" height={36}/>
                                        <Area type="monotone" dataKey="income" name={t('income')} stroke="#198754" fillOpacity={1} fill="url(#colorIncome)" strokeWidth={2} />
                                        <Area type="monotone" dataKey="expense" name={t('expense')} stroke="#dc3545" fillOpacity={1} fill="url(#colorExpense)" strokeWidth={2} />
                                    </AreaChart>
                                </ResponsiveContainer>
                                )}
                            </div>
                        </div>
                    </div>

                    {/* Recent Transactions */}
                    <div className="col-lg-4">
                        <div className="card border-0 shadow-sm h-100 rounded-4">
                            <div className="card-header bg-white border-0 py-3 d-flex justify-content-between align-items-center">
                                <h5 className="fw-bold mb-0">{t('recentTransactions')}</h5>
                                <button className="btn btn-link btn-sm text-decoration-none" onClick={() => navigate('/transactions')}>{t('allTransactions')}</button>
                            </div>
                            <div className="card-body p-0">
                                {recentTransactions.length === 0 ? (
                                    <div className="text-center py-5 text-muted">
                                        <i className="bi bi-receipt display-6 mb-2 d-block opacity-50"></i>
                                        {t('noTransactions')}
                                    </div>
                                ) : (
                                    <ul className="list-group list-group-flush">
                                        {recentTransactions.map((t, idx) => {
                                            const meta = getCategoryMeta(t.categoryName || t.category, t.type);
                                            return (
                                                <TransactionItem 
                                                    key={idx}
                                                    icon={meta.icon}
                                                    color={meta.color}
                                                    title={t.categoryName || t.category || 'Giao dịch'}
                                                    date={t.date}
                                                    amount={(t.type === 'INCOME' ? '+ ' : '- ') + formatCurrency(t.amount)}
                                                    isIncome={t.type === 'INCOME'}
                                                    className="hover-bg-light"
                                                />
                                            );
                                        })}
                                    </ul>
                                )}
                            </div>
                        </div>
                    </div>
                </div>
            </div>
        </div>
    );
};

export default Dashboard;