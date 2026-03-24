import React, { useEffect, useState, useCallback } from 'react';
import { useNavigate } from 'react-router-dom';
import { adminApi, authApi, userApi } from '../server/api';
import { Chart as ChartJS, CategoryScale, LinearScale, PointElement, LineElement, BarElement, Title, Tooltip, Legend, ArcElement } from 'chart.js';
import { Bar } from 'react-chartjs-2';

// Register ChartJS components
ChartJS.register(CategoryScale, LinearScale, PointElement, LineElement, BarElement, Title, Tooltip, Legend, ArcElement);

const AdminDashboard = () => {
    // --- STATE ---
    const [activeTab, setActiveTab] = useState('overview'); // 'overview' | 'users'
    
    // Data State
    const [stats, setStats] = useState({ totalUsers: 0, totalTransactions: 0, activeDevices: 0, newUsersByMonth: [] });
    const [users, setUsers] = useState([]);
    const [transactionStats, setTransactionStats] = useState(null);
    const [overspentBudgets, setOverspentBudgets] = useState([]);
    const [notifications, setNotifications] = useState([]);
    
    // Filter/Pagination State
    const [searchTerm, setSearchTerm] = useState('');
    const [filterLocked, setFilterLocked] = useState('');
    const [filterOnline, setFilterOnline] = useState('');
    const [page, setPage] = useState(0);
    const [totalPages, setTotalPages] = useState(0);
    const [rangeMode, setRangeMode] = useState('MONTHLY');
    
    // UI State
    const [loading, setLoading] = useState(false);
    const [currentUser, setCurrentUser] = useState(null);
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
            localStorage.clear();
            if (reason) alert(reason);
            navigate('/login');
        }
    }, [navigate]);

    const fetchStats = async () => {
        try {
            const res = await adminApi.getStats();
            if (res.data) setStats(res.data);
            
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
            
            const resBudget = await adminApi.getSystemOverspentBudgets(rangeMode);
            // Cấu trúc trả về là ApiResponse -> lấy res.data.data
            setOverspentBudgets(resBudget.data.data || []);
        } catch (err) { console.error(err); }
    }, [rangeMode]);

    const fetchNotifications = async (adminId) => {
        try {
            const res = await adminApi.getAdminNotifications(adminId);
            setNotifications(res.data || []);
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
            setUsers(res.data.content || []);
            setTotalPages(res.data.totalPages || 0);
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
        const checkAccountStatus = async () => {
            try {
                const res = await userApi.getProfile();
                if (res.data && res.data.locked) handleLogout("Tài khoản bị khóa.");
            } catch (error) {
                if (error.response && (error.response.status === 401 || error.response.status === 403)) {
                    handleLogout("Phiên đăng nhập hết hạn.");
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
            isLocked ? await adminApi.unlockUser(userId) : await adminApi.lockUser(userId);
            fetchUsers(false);
            fetchStats();
        } catch (err) { alert("Thao tác thất bại."); }
        finally { setConfirmModal({ ...confirmModal, show: false }); }
    };

    const formatDate = (d) => d ? new Date(d).toLocaleString('vi-VN') : '';

    // --- CHART CONFIG ---
    const breakdown = transactionStats?.breakdown || [];
    const totalAmount = breakdown.reduce((acc, item) => acc + item.amount, 0);
    
    const barChartData = {
        labels: breakdown.map(item => item.categoryName),
        datasets: [
            {
                label: 'Tỷ lệ (%)',
                data: breakdown.map(item => totalAmount > 0 ? ((item.amount / totalAmount) * 100).toFixed(1) : 0),
                backgroundColor: breakdown.map(item => item.type === 'INCOME' ? 'rgba(25, 135, 84, 0.6)' : 'rgba(220, 53, 69, 0.6)'),
                borderColor: breakdown.map(item => item.type === 'INCOME' ? '#198754' : '#dc3545'),
                borderWidth: 1
            }
        ]
    };
    
    // Options cho Bar chart (thay vì Line)
    const chartOptions = {
        responsive: true,
        plugins: {
            legend: { display: false },
            title: { display: true, text: `Tỷ lệ dòng tiền ${rangeMode === 'WEEKLY' ? 'Tuần này' : rangeMode === 'MONTHLY' ? 'Tháng này' : 'Năm nay'}` },
            tooltip: {
                callbacks: {
                    label: function(context) {
                        const percentage = context.raw; // Giá trị %
                        const amount = breakdown[context.dataIndex]?.amount || 0;
                        return `${percentage}% (${amount.toLocaleString('vi-VN')}đ)`;
                    }
                }
            }
        },
        scales: {
            y: {
                ticks: {
                    callback: function(value) {
                        return value + "%";
                    }
                }
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
                        <i className="bi bi-speedometer2 me-2"></i> Tổng quan
                    </button>
                </li>
                <li className="nav-item mb-1">
                    <button onClick={() => setActiveTab('users')} className={`nav-link w-100 text-start text-white ${activeTab === 'users' ? 'active bg-primary' : ''}`}>
                        <i className="bi bi-people me-2"></i> Người dùng
                    </button>
                </li>
            </ul>
            <hr />
            <div className="dropdown">
                <div className="d-flex align-items-center text-white text-decoration-none dropdown-toggle" id="dropdownUser1" data-bs-toggle="dropdown" aria-expanded="false">
                    <div className="rounded-circle bg-secondary d-flex justify-content-center align-items-center me-2" style={{width: 32, height: 32}}>
                        <i className="bi bi-person-fill"></i>
                    </div>
                    <strong>{currentUser?.roleName || 'Admin'}</strong>
                </div>
            </div>
        </div>
    );

    const Topbar = () => (
        <nav className="navbar navbar-expand-lg navbar-light bg-white border-bottom shadow-sm px-4 py-2 sticky-top">
            <div className="d-flex w-100 justify-content-between align-items-center">
                <h5 className="mb-0 fw-bold text-secondary">
                    {activeTab === 'overview' ? 'Dashboard Overview' : 'User Management'}
                </h5>
                <div className="d-flex align-items-center">
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
                                <div className="p-2 border-bottom fw-bold bg-light rounded-top">Thông báo hệ thống</div>
                                <div style={{ maxHeight: '300px', overflowY: 'auto' }}>
                                    {notifications.length === 0 ? <p className="text-center text-muted m-3 small">Không có thông báo mới</p> : 
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
                        <i className="bi bi-box-arrow-right"></i> Đăng xuất
                    </button>
                </div>
            </div>
        </nav>
    );

    const OverviewTab = () => (
        <div className="container-fluid py-4">
             {/* Stats Cards */}
             <div className="row g-4 mb-4">
                <div className="col-md-4">
                    <div className="card shadow-sm border-0 bg-primary text-white h-100" onClick={() => handleCardClick('TOTAL')} style={{cursor: 'pointer'}}>
                        <div className="card-body d-flex justify-content-between align-items-center">
                            <div>
                                <div className="small text-white-50 text-uppercase">Tổng User</div>
                                <div className="display-6 fw-bold">{stats.totalUsers}</div>
                            </div>
                            <i className="bi bi-people fs-1 opacity-25"></i>
                        </div>
                    </div>
                </div>
                <div className="col-md-4">
                    <div className="card shadow-sm border-0 bg-success text-white h-100" onClick={() => handleCardClick('ONLINE')} style={{cursor: 'pointer'}}>
                        <div className="card-body d-flex justify-content-between align-items-center">
                            <div>
                                <div className="small text-white-50 text-uppercase">Người dùng đang online</div>
                                <div className="display-6 fw-bold">{stats.activeDevices}</div>
                            </div>
                            <i className="bi bi-wifi fs-1 opacity-25"></i>
                        </div>
                    </div>
                </div>
                <div className="col-md-4">
                    <div className="card shadow-sm border-0 bg-info text-white h-100">
                        <div className="card-body d-flex justify-content-between align-items-center">
                            <div>
                                <div className="small text-white-50 text-uppercase">Giao dịch hệ thống</div>
                                <div className="display-6 fw-bold">{stats.totalTransactions || 0}</div>
                            </div>
                            <i className="bi bi-receipt fs-1 opacity-25"></i>
                        </div>
                    </div>
                </div>
             </div>

             {/* Charts & Budget */}
             <div className="row g-4">
                <div className="col-lg-8">
                    <div className="card shadow-sm border-0 h-100">
                        <div className="card-header bg-white border-0 py-3 d-flex justify-content-between align-items-center">
                            <h6 className="mb-0 fw-bold">Phân tích dòng tiền hệ thống</h6>
                            <div className="btn-group btn-group-sm">
                                {['WEEKLY', 'MONTHLY', 'YEARLY'].map(m => (
                                    <button key={m} className={`btn ${rangeMode === m ? 'btn-primary' : 'btn-outline-secondary'}`} 
                                            onClick={() => setRangeMode(m)}>{m === 'WEEKLY' ? 'Tuần' : m === 'MONTHLY' ? 'Tháng' : 'Năm'}</button>
                                ))}
                            </div>
                        </div>
                        <div className="card-body">
                             {transactionStats ? <Bar data={barChartData} options={chartOptions} /> 
                                               : <div className="text-center py-5">Đang tải biểu đồ...</div>}
                        </div>
                    </div>
                </div>
                <div className="col-lg-4">
                    <div className="card shadow-sm border-0 h-100">
                        <div className="card-header bg-white border-0 py-3">
                            <h6 className="mb-0 fw-bold text-danger">Cảnh báo ngân sách</h6>
                        </div>
                        <div className="card-body p-0 overflow-auto" style={{maxHeight: '400px'}}>
                            {overspentBudgets.length === 0 ? <div className="text-center text-muted py-4 small">Không có ngân sách vượt mức</div> : 
                                <ul className="list-group list-group-flush">
                                    {overspentBudgets.map((b, i) => (
                                        <li key={i} className="list-group-item d-flex justify-content-between align-items-center px-4 py-3">
                                            <div>
                                                <div className="fw-bold text-dark">{b.categoryName}</div>
                                                <div className="small text-muted">{b.userEmail}</div>
                                            </div>
                                            <span className="badge bg-danger rounded-pill">-{b.overAmount?.toLocaleString()}đ</span>
                                        </li>
                                    ))}
                                </ul>
                            }
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
                        <input type="text" className="form-control form-control-sm" placeholder="Tìm kiếm user..." 
                               value={searchTerm} onChange={e => {setSearchTerm(e.target.value); setPage(0);}} style={{width: '200px'}} />
                        <select className="form-select form-select-sm" style={{width: '130px'}} value={filterLocked} onChange={e => {setFilterLocked(e.target.value); setPage(0);}}>
                            <option value="">Trạng thái</option>
                            <option value="false">Hoạt động</option>
                            <option value="true">Đã khóa</option>
                        </select>
                        <select className="form-select form-select-sm" style={{width: '130px'}} value={filterOnline} onChange={e => {setFilterOnline(e.target.value); setPage(0);}}>
                            <option value="">Kết nối</option>
                            <option value="true">Online</option>
                            <option value="false">Offline</option>
                        </select>
                    </div>
                    <div className="small text-muted">Hiển thị {users.length} kết quả</div>
                </div>
                <div className="table-responsive">
                    <table className="table table-hover align-middle mb-0">
                        <thead className="table-light">
                            <tr>
                                <th className="ps-4">ID</th>
                                <th>Email</th>
                                <th>SĐT</th>
                                <th>Trạng thái</th>
                                <th>Kết nối</th>
                                <th className="text-end pe-4">Thao tác</th>
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
                                     <td>{u.locked ? <span className="badge bg-danger-subtle text-danger">Đã khóa</span> : <span className="badge bg-success-subtle text-success">Hoạt động</span>}</td>
                                     <td>{u.online ? <span className="badge bg-success">Online</span> : <span className="badge bg-secondary">Offline</span>}</td>
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
                         <span className="align-self-center small mx-2">Trang {page+1} / {totalPages}</span>
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
                                <h5 className="fw-bold mb-3">{confirmModal.isLocked ? 'Mở khóa tài khoản?' : 'Khóa tài khoản?'}</h5>
                                <p className="text-muted mb-4">Hành động này sẽ {confirmModal.isLocked ? 'cho phép người dùng truy cập lại' : 'ngăn chặn người dùng truy cập'} hệ thống.</p>
                                <div className="d-flex justify-content-center gap-2">
                                    <button className="btn btn-light px-4" onClick={() => setConfirmModal({...confirmModal, show: false})}>Hủy</button>
                                    <button className={`btn ${confirmModal.isLocked ? 'btn-success' : 'btn-danger'} px-4`} onClick={confirmAction}>Xác nhận</button>
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