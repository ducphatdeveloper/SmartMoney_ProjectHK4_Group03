import React, { useEffect, useState, useCallback } from 'react';
import { useNavigate } from 'react-router-dom';
import { authApi, userApi, transactionApi, notificationApi } from '../server/api';
import { XAxis, YAxis, CartesianGrid, Tooltip, Legend, ResponsiveContainer, AreaChart, Area } from 'recharts';

const Dashboard = () => {
    const navigate = useNavigate();
    const [currentUser, setCurrentUser] = useState(null);
    const [stats, setStats] = useState({ balance: 0, income: 0, expense: 0 });
    const [recentTransactions, setRecentTransactions] = useState([]);
    const [chartData, setChartData] = useState([]);
    const [notifications, setNotifications] = useState([]);
    const [showNotifications, setShowNotifications] = useState(false);
    const [loading, setLoading] = useState(true);

    // Hàm đăng xuất (sử dụng useCallback để dùng trong useEffect)
    const handleLogout = useCallback(async (reason = '') => {
        try {
            await authApi.logout('web-browser');
        } catch (err) {
            console.error(err);
        } finally {
            localStorage.clear();
            if (reason) alert(reason);
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
        loadDashboardData(storedUser.id);
    }, [navigate]);

    // Effect: Tự động kiểm tra trạng thái tài khoản mỗi 5 giây
    useEffect(() => {
        const checkAccountStatus = async () => {
            try {
                // Gọi API lấy profile để check trạng thái mới nhất
                const res = await userApi.getProfile();
                
                // Nếu API trả về thông tin user và user bị khóa
                if (res.data && res.data.locked) {
                    handleLogout("Bạn đã bị khóa");
                }
            } catch (error) {
                // Nếu gặp lỗi 401 (Unauthorized) hoặc 403 (Forbidden) -> Token hết hạn hoặc bị chặn
                if (error.response && (error.response.status === 401 || error.response.status === 403)) {
                    handleLogout("Phiên đăng nhập hết hạn hoặc tài khoản đã bị khóa.");
                }
            }
        };

        const interval = setInterval(checkAccountStatus, 5000); // Check mỗi 5 giây

        return () => clearInterval(interval);
    }, [handleLogout]);

    const loadDashboardData = async (userId) => {
        setLoading(true);
        try {
            // Gọi song song các API để tối ưu thời gian
            const [statsRes, transactionsRes, chartRes, notifRes] = await Promise.allSettled([
                userApi.getDashboardStats(),
                transactionApi.getRecent(5),
                transactionApi.getChartData('month'),
                notificationApi.getByUser(userId)
            ]);

            if (statsRes.status === 'fulfilled') setStats(statsRes.value.data);
            if (transactionsRes.status === 'fulfilled') setRecentTransactions(transactionsRes.value.data);
            if (chartRes.status === 'fulfilled') setChartData(chartRes.value.data);
            if (notifRes.status === 'fulfilled') setNotifications(notifRes.value.data);

        } catch (error) {
            console.error("Lỗi tải dữ liệu dashboard", error);
        } finally {
            setLoading(false);
        }
    };

    const formatCurrency = (amount) => {
        return new Intl.NumberFormat('vi-VN', { style: 'currency', currency: 'VND' }).format(amount);
    };

    const formatDate = (dateString) => {
        return new Date(dateString).toLocaleDateString('vi-VN');
    };

    // Dữ liệu mẫu cho biểu đồ nếu API chưa có
    const dummyChartData = [
        { name: 'T2', income: 4000000, expense: 2400000 },
        { name: 'T3', income: 3000000, expense: 1398000 },
        { name: 'T4', income: 2000000, expense: 9800000 },
        { name: 'T5', income: 2780000, expense: 3908000 },
        { name: 'T6', income: 1890000, expense: 4800000 },
        { name: 'T7', income: 2390000, expense: 3800000 },
        { name: 'CN', income: 3490000, expense: 4300000 },
    ];

    const dataToUse = chartData.length > 0 ? chartData : dummyChartData;

    if (loading) {
        return (
            <div className="min-vh-100 d-flex justify-content-center align-items-center bg-light">
                <div className="spinner-border text-primary" role="status">
                    <span className="visually-hidden">Đang tải...</span>
                </div>
            </div>
        );
    }

    return (
        <div className="min-vh-100 bg-light">
            {/* Navbar */}
            <nav className="navbar navbar-expand-lg navbar-light bg-white shadow-sm px-4 sticky-top">
                <span className="navbar-brand fw-bold text-primary">
                    <i className="bi bi-wallet2 me-2"></i>SmartMoney
                </span>
                
                <div className="ms-auto d-flex align-items-center">
                    {/* Notification Bell */}
                    <div className="position-relative me-4">
                        <button 
                            className="btn btn-link text-dark p-0 position-relative"
                            onClick={() => setShowNotifications(!showNotifications)}
                        >
                            <i className="bi bi-bell fs-5"></i>
                            {notifications.length > 0 && (
                                <span className="position-absolute top-0 start-100 translate-middle badge rounded-pill bg-danger" style={{ fontSize: '0.6rem' }}>
                                    {notifications.length}
                                </span>
                            )}
                        </button>

                        {/* Dropdown Thông báo */}
                        {showNotifications && (
                            <div className="position-absolute end-0 mt-3 bg-white shadow-lg rounded overflow-hidden" style={{ width: '300px', zIndex: 1050 }}>
                                <div className="p-2 border-bottom bg-light fw-bold">Thông báo</div>
                                <div style={{ maxHeight: '300px', overflowY: 'auto' }}>
                                    {notifications.length === 0 ? (
                                        <div className="p-3 text-center text-muted small">Không có thông báo mới</div>
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
                                <li><button className="dropdown-item" onClick={() => navigate('/profile')}><i className="bi bi-person me-2"></i>Hồ sơ</button></li>
                                <li><button className="dropdown-item" onClick={() => navigate('/settings')}><i className="bi bi-gear me-2"></i>Cài đặt</button></li>
                                <li><hr className="dropdown-divider"/></li>
                                <li><button className="dropdown-item text-danger" onClick={() => handleLogout()}><i className="bi bi-box-arrow-right me-2"></i>Đăng xuất</button></li>
                            </ul>
                        </div>
                    </div>
                </div>
            </nav>

            <div className="container py-4">
                {/* Welcome Section */}
                <div className="mb-4">
                    <h4 className="fw-bold text-dark">Xin chào, {currentUser?.fullName || 'Bạn'}! 👋</h4>
                    <p className="text-muted">Đây là tổng quan tài chính của bạn hôm nay.</p>
                </div>

                {/* Stats Cards */}
                <div className="row g-4 mb-4">
                    <div className="col-md-4">
                        <div className="card border-0 shadow-sm h-100 bg-primary text-white overflow-hidden position-relative">
                            <div className="card-body position-relative z-1">
                                <h6 className="text-white-50 text-uppercase mb-2">Tổng số dư</h6>
                                <h2 className="fw-bold mb-0">{formatCurrency(stats.balance || 15000000)}</h2>
                            </div>
                            <i className="bi bi-wallet2 position-absolute end-0 bottom-0 display-1 opacity-25 me-n3 mb-n3" style={{transform: 'rotate(-15deg)'}}></i>
                        </div>
                    </div>
                    <div className="col-md-4">
                        <div className="card border-0 shadow-sm h-100">
                            <div className="card-body">
                                <div className="d-flex align-items-center mb-2">
                                    <div className="bg-success-subtle text-success rounded-circle p-2 me-2">
                                        <i className="bi bi-arrow-down-left fs-5"></i>
                                    </div>
                                    <h6 className="text-muted text-uppercase mb-0">Tổng thu nhập</h6>
                                </div>
                                <h3 className="fw-bold text-success mb-0">{formatCurrency(stats.income || 25000000)}</h3>
                                <small className="text-muted">Tháng này</small>
                            </div>
                        </div>
                    </div>
                    <div className="col-md-4">
                        <div className="card border-0 shadow-sm h-100">
                            <div className="card-body">
                                <div className="d-flex align-items-center mb-2">
                                    <div className="bg-danger-subtle text-danger rounded-circle p-2 me-2">
                                        <i className="bi bi-arrow-up-right fs-5"></i>
                                    </div>
                                    <h6 className="text-muted text-uppercase mb-0">Tổng chi tiêu</h6>
                                </div>
                                <h3 className="fw-bold text-danger mb-0">{formatCurrency(stats.expense || 10000000)}</h3>
                                <small className="text-muted">Tháng này</small>
                            </div>
                        </div>
                    </div>
                </div>

                {/* Chart Section */}
                <div className="row g-4">
                    <div className="col-lg-8">
                        <div className="card border-0 shadow-sm h-100">
                            <div className="card-header bg-white border-0 py-3 d-flex justify-content-between align-items-center">
                                <h5 className="fw-bold mb-0">Phân tích thu chi</h5>
                                <select className="form-select form-select-sm w-auto border-0 bg-light">
                                    <option>7 ngày qua</option>
                                    <option>Tháng này</option>
                                    <option>Năm nay</option>
                                </select>
                            </div>
                            <div className="card-body" style={{ height: '350px' }}>
                                <ResponsiveContainer width="100%" height="100%">
                                    <AreaChart data={dataToUse} margin={{ top: 10, right: 30, left: 0, bottom: 0 }}>
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
                                        <XAxis dataKey="name" axisLine={false} tickLine={false} />
                                        <YAxis axisLine={false} tickLine={false} tickFormatter={(value) => `${value / 1000000}M`} />
                                        <CartesianGrid vertical={false} strokeDasharray="3 3" stroke="#f0f0f0" />
                                        <Tooltip 
                                            formatter={(value) => formatCurrency(value)}
                                            contentStyle={{ borderRadius: '8px', border: 'none', boxShadow: '0 4px 12px rgba(0,0,0,0.1)' }}
                                        />
                                        <Legend verticalAlign="top" height={36}/>
                                        <Area type="monotone" dataKey="income" name="Thu nhập" stroke="#198754" fillOpacity={1} fill="url(#colorIncome)" strokeWidth={2} />
                                        <Area type="monotone" dataKey="expense" name="Chi tiêu" stroke="#dc3545" fillOpacity={1} fill="url(#colorExpense)" strokeWidth={2} />
                                    </AreaChart>
                                </ResponsiveContainer>
                            </div>
                        </div>
                    </div>

                    {/* Recent Transactions */}
                    <div className="col-lg-4">
                        <div className="card border-0 shadow-sm h-100">
                            <div className="card-header bg-white border-0 py-3 d-flex justify-content-between align-items-center">
                                <h5 className="fw-bold mb-0">Giao dịch gần đây</h5>
                                <button className="btn btn-link btn-sm text-decoration-none" onClick={() => navigate('/transactions')}>Xem tất cả</button>
                            </div>
                            <div className="card-body p-0">
                                {recentTransactions.length === 0 ? (
                                    <div className="text-center py-5 text-muted">
                                        <i className="bi bi-receipt display-6 mb-2 d-block opacity-50"></i>
                                        Chưa có giao dịch nào
                                    </div>
                                ) : (
                                    <ul className="list-group list-group-flush">
                                        {recentTransactions.map((t, idx) => (
                                            <li key={idx} className="list-group-item border-0 px-4 py-3 d-flex align-items-center">
                                                <div className={`rounded-circle p-2 me-3 ${t.type === 'INCOME' ? 'bg-success-subtle text-success' : 'bg-danger-subtle text-danger'}`}>
                                                    <i className={`bi ${t.type === 'INCOME' ? 'bi-arrow-down-left' : 'bi-arrow-up-right'} fs-5`}></i>
                                                </div>
                                                <div className="flex-grow-1">
                                                    <h6 className="mb-0 fw-bold text-dark">{t.category || 'Giao dịch chung'}</h6>
                                                    <small className="text-muted">{formatDate(t.date)}</small>
                                                </div>
                                                <div className={`fw-bold ${t.type === 'INCOME' ? 'text-success' : 'text-danger'}`}>
                                                    {t.type === 'INCOME' ? '+' : '-'}{formatCurrency(t.amount)}
                                                </div>
                                            </li>
                                        ))}
                                        {/* Dữ liệu mẫu nếu chưa có API */}
                                        {recentTransactions.length === 0 && (
                                            <>
                                                <li className="list-group-item border-0 px-4 py-3 d-flex align-items-center">
                                                    <div className="rounded-circle p-2 me-3 bg-danger-subtle text-danger">
                                                        <i className="bi bi-cart fs-5"></i>
                                                    </div>
                                                    <div className="flex-grow-1">
                                                        <h6 className="mb-0 fw-bold text-dark">Siêu thị</h6>
                                                        <small className="text-muted">Hôm nay</small>
                                                    </div>
                                                    <div className="fw-bold text-danger">-500.000 ₫</div>
                                                </li>
                                                <li className="list-group-item border-0 px-4 py-3 d-flex align-items-center">
                                                    <div className="rounded-circle p-2 me-3 bg-success-subtle text-success">
                                                        <i className="bi bi-cash-coin fs-5"></i>
                                                    </div>
                                                    <div className="flex-grow-1">
                                                        <h6 className="mb-0 fw-bold text-dark">Lương tháng 10</h6>
                                                        <small className="text-muted">Hôm qua</small>
                                                    </div>
                                                    <div className="fw-bold text-success">+15.000.000 ₫</div>
                                                </li>
                                                <li className="list-group-item border-0 px-4 py-3 d-flex align-items-center">
                                                    <div className="rounded-circle p-2 me-3 bg-danger-subtle text-danger">
                                                        <i className="bi bi-cup-hot fs-5"></i>
                                                    </div>
                                                    <div className="flex-grow-1">
                                                        <h6 className="mb-0 fw-bold text-dark">Cafe & Ăn uống</h6>
                                                        <small className="text-muted">20/10/2023</small>
                                                    </div>
                                                    <div className="fw-bold text-danger">-85.000 ₫</div>
                                                </li>
                                            </>
                                        )}
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