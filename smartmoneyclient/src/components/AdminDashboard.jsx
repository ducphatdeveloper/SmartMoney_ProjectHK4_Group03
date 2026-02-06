import React, { useEffect, useState, useCallback } from 'react';
import { useNavigate } from 'react-router-dom';
import { adminApi, authApi, userApi } from '../server/api';

const AdminDashboard = () => {
    const [users, setUsers] = useState([]);
    const [stats, setStats] = useState({ totalUsers: 0, totalTransactions: 0, activeDevices: 0 });
    const [currentUser, setCurrentUser] = useState(null);
    const [searchTerm, setSearchTerm] = useState('');
    const [filterLocked, setFilterLocked] = useState('');
    const [filterOnline, setFilterOnline] = useState('');
    const [page, setPage] = useState(0);
    const [totalPages, setTotalPages] = useState(0);
    const [loading, setLoading] = useState(false);
    
    // State cho modal xác nhận
    const [confirmModal, setConfirmModal] = useState({ show: false, userId: null, isLocked: false });

    // State cho thông báo
    const [notifications, setNotifications] = useState([]);
    const [showNotifications, setShowNotifications] = useState(false);
    
    const navigate = useNavigate();

    // Hàm đăng xuất
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
        } catch (err) {
            console.error("Lỗi tải thống kê", err);
        }
    };

    const fetchNotifications = async (adminId) => {
        try {
            const res = await adminApi.getAdminNotifications(adminId);
            setNotifications(res.data || []);
        } catch (err) {
            console.error("Lỗi tải thông báo", err);
        }
    };

    // Hàm fetchUsers được cập nhật để hỗ trợ tải ngầm (isBackground = true thì không hiện loading)
    const fetchUsers = useCallback(async (isBackground = false) => {
        if (!isBackground) setLoading(true);
        try {
            // Chuẩn bị params khớp với AdminController
            const params = {
                page: page,
                size: 8,
                search: searchTerm || null, // Gửi null nếu rỗng
                locked: filterLocked === '' ? null : (filterLocked === 'true'), // Convert sang Boolean hoặc null
                onlineStatus: filterOnline === '' ? null : filterOnline // Gửi null nếu rỗng
            };
            
            const res = await adminApi.getUsers(params);
            setUsers(res.data.content || []);
            setTotalPages(res.data.totalPages || 0);
        } catch (err) {
            console.error("Lỗi tải danh sách người dùng", err);
        } finally {
            if (!isBackground) setLoading(false);
        }
    }, [page, searchTerm, filterLocked, filterOnline]);

    useEffect(() => {
        const storedUser = JSON.parse(localStorage.getItem('user'));
        const token = localStorage.getItem('accessToken');

        // Các vai trò được phép truy cập trang admin
        const authorizedRoles = ["Quản trị viên", "ROLE_ADMIN", "ADMIN_SYSTEM_ALL"];

        if (!token || !storedUser || !authorizedRoles.includes(storedUser.roleName)) {
            navigate('/login');
            return;
        }
        setCurrentUser(storedUser);
        fetchStats();
        
        // Lấy thông báo nếu có ID
        if (storedUser.id) {
            fetchNotifications(storedUser.id);
        }
    }, [navigate]);

    // Effect 1: Debounce khi search/filter thay đổi (Hiện loading)
    useEffect(() => {
        const delayDebounceFn = setTimeout(() => {
            fetchUsers(false); // false = hiện loading
        }, 500);

        return () => clearTimeout(delayDebounceFn);
    }, [fetchUsers]);

    // Effect 2: Tự động refresh dữ liệu mỗi 5 giây (Polling)
    useEffect(() => {
        const checkAccountStatus = async () => {
            try {
                // Gọi API lấy profile để check trạng thái mới nhất của chính Admin
                const res = await userApi.getProfile();
                
                // Nếu API trả về thông tin user và user bị khóa
                if (res.data && res.data.locked) {
                    handleLogout("Tài khoản quản trị của bạn đã bị khóa.");
                }
            } catch (error) {
                // Nếu gặp lỗi 401 (Unauthorized) hoặc 403 (Forbidden) -> Token hết hạn hoặc bị chặn
                if (error.response && (error.response.status === 401 || error.response.status === 403)) {
                    handleLogout("Phiên đăng nhập hết hạn hoặc tài khoản đã bị khóa.");
                }
            }
        };

        const interval = setInterval(() => {
            fetchUsers(true); // true = chạy ngầm, không hiện loading
            fetchStats();     // Cập nhật cả thống kê số lượng online
            checkAccountStatus(); // Kiểm tra trạng thái tài khoản Admin
        }, 5000); // 5 giây

        return () => clearInterval(interval);
    }, [fetchUsers, handleLogout]);

    const openConfirmModal = (userId, isLocked) => {
        setConfirmModal({ show: true, userId, isLocked });
    };

    const closeConfirmModal = () => {
        setConfirmModal({ ...confirmModal, show: false });
    };

    const handleConfirmAction = async () => {
        const { userId, isLocked } = confirmModal;
        try {
            if (isLocked) {
                await adminApi.unlockUser(userId);
            } else {
                await adminApi.lockUser(userId);
            }
            fetchUsers(false);
            fetchStats();
        } catch (err) {
            alert("Thao tác thất bại. Vui lòng thử lại.");
        } finally {
            closeConfirmModal();
        }
    };

    const handleLogoutClick = async () => {
        try {
            await authApi.logout('web-browser');
        } catch (err) {
            console.error(err);
        } finally {
            localStorage.clear();
            navigate('/login');
        }
    };

    // Xử lý click vào thẻ thống kê để lọc nhanh
    const handleCardClick = (type) => {
        if (type === 'TOTAL') {
            setFilterOnline('');
            setFilterLocked('');
            setSearchTerm('');
        } else if (type === 'ONLINE') {
            setFilterOnline('online');
        }
        setPage(0);
        // Cuộn xuống bảng
        document.getElementById('user-management-section')?.scrollIntoView({ behavior: 'smooth' });
    };

    // Format ngày tháng
    const formatDate = (dateString) => {
        if (!dateString) return '';
        return new Date(dateString).toLocaleString('vi-VN', {
            day: '2-digit', month: '2-digit', year: 'numeric', hour: '2-digit', minute: '2-digit'
        });
    };

    return (
        <div className="min-vh-100 bg-light">
            {/* Navbar */}
            <nav className="navbar navbar-expand-lg navbar-dark bg-dark px-4 shadow-sm sticky-top">
                <span className="navbar-brand fw-bold text-info">
                    <i className="bi bi-shield-lock me-2"></i>ADMIN PORTAL
                </span>
                <div className="ms-auto d-flex align-items-center">
                    
                    {/* Notification Bell */}
                    <div className="position-relative me-4">
                        <button 
                            className="btn btn-link text-white p-0 position-relative"
                            onClick={() => setShowNotifications(!showNotifications)}
                            style={{ textDecoration: 'none' }}
                        >
                            <i className="bi bi-bell fs-5"></i>
                            {notifications.length > 0 && (
                                <span className="position-absolute top-0 start-100 translate-middle badge rounded-pill bg-danger" style={{ fontSize: '0.6rem' }}>
                                    {notifications.length}
                                </span>
                            )}
                        </button>

                        {/* Notification Dropdown */}
                        {showNotifications && (
                            <div className="position-absolute end-0 mt-3 bg-white shadow-lg rounded overflow-hidden" style={{ width: '320px', zIndex: 1050, right: '-10px' }}>
                                <div className="d-flex justify-content-between align-items-center px-3 py-2 bg-light border-bottom">
                                    <h6 className="mb-0 fw-bold text-dark">Thông báo</h6>
                                    <span className="badge bg-primary rounded-pill">{notifications.length} mới</span>
                                </div>
                                <div style={{ maxHeight: '350px', overflowY: 'auto' }}>
                                    {notifications.length === 0 ? (
                                        <div className="text-center py-4 text-muted">
                                            <i className="bi bi-bell-slash display-6 d-block mb-2"></i>
                                            <small>Không có thông báo nào</small>
                                        </div>
                                    ) : (
                                        <ul className="list-group list-group-flush">
                                            {notifications.map((notif, index) => (
                                                <li key={index} className="list-group-item list-group-item-action px-3 py-3 border-bottom">
                                                    <div className="d-flex w-100 justify-content-between mb-1">
                                                        <strong className="text-primary small mb-1">Hệ thống</strong>
                                                        <small className="text-muted" style={{ fontSize: '0.7rem' }}>
                                                            {formatDate(notif.createdDate || notif.createdAt)}
                                                        </small>
                                                    </div>
                                                    <p className="mb-0 small text-dark">{notif.message || notif.content}</p>
                                                </li>
                                            ))}
                                        </ul>
                                    )}
                                </div>
                                <div className="text-center py-2 bg-light border-top">
                                    <button className="btn btn-link btn-sm text-decoration-none" onClick={() => setShowNotifications(false)}>Đóng</button>
                                </div>
                            </div>
                        )}
                    </div>

                    {/* User Info */}
                    <div className="text-end me-3 d-none d-md-block border-end pe-3 border-secondary">
                        <small className="text-muted d-block text-uppercase" style={{ fontSize: '0.65rem' }}>{currentUser?.roleName}</small>
                        <span className="text-white fw-medium">{currentUser?.accEmail}</span>
                    </div>
                    <button onClick={handleLogoutClick} className="btn btn-outline-danger btn-sm border-0 ms-2">
                        <i className="bi bi-power fs-5"></i>
                    </button>
                </div>
            </nav>

            <div className="container-fluid py-4 px-lg-5">
                {/* Stats Cards */}
                <div className="row g-4 mb-4">
                    <div className="col-md-6 col-lg-3">
                        <div 
                            className="card border-0 shadow-sm bg-primary text-white h-100" 
                            onClick={() => handleCardClick('TOTAL')}
                            style={{ cursor: 'pointer', transition: 'transform 0.2s' }}
                            onMouseOver={(e) => e.currentTarget.style.transform = 'scale(1.02)'}
                            onMouseOut={(e) => e.currentTarget.style.transform = 'scale(1)'}
                            title="Nhấn để xem tất cả người dùng (Role User)"
                        >
                            <div className="card-body">
                                <div className="d-flex justify-content-between align-items-center">
                                    <div>
                                        <h6 className="text-white-50 text-uppercase mb-1">Tổng người dùng (User)</h6>
                                        <h3 className="fw-bold mb-0">{stats.totalUsers || 0}</h3>
                                    </div>
                                    <i className="bi bi-people fs-1 opacity-50"></i>
                                </div>
                            </div>
                        </div>
                    </div>
                    <div className="col-md-6 col-lg-3">
                        <div 
                            className="card border-0 shadow-sm bg-success text-white h-100"
                            onClick={() => handleCardClick('ONLINE')}
                            style={{ cursor: 'pointer', transition: 'transform 0.2s' }}
                            onMouseOver={(e) => e.currentTarget.style.transform = 'scale(1.02)'}
                            onMouseOut={(e) => e.currentTarget.style.transform = 'scale(1)'}
                            title="Nhấn để lọc người dùng đang Online"
                        >
                            <div className="card-body">
                                <div className="d-flex justify-content-between align-items-center">
                                    <div>
                                        <h6 className="text-white-50 text-uppercase mb-1">Người dùng đang online</h6>
                                        <h3 className="fw-bold mb-0">{stats.activeDevices || 0}</h3>
                                    </div>
                                    <i className="bi bi-phone fs-1 opacity-50"></i>
                                </div>
                            </div>
                        </div>
                    </div>
                </div>

                {/* User Management */}
                <div className="card border-0 shadow-sm" id="user-management-section">
                    <div className="card-header bg-white py-3 border-0">
                        <div className="d-flex flex-column flex-md-row justify-content-between align-items-md-center gap-3">
                            <h5 className="mb-0 fw-bold text-dark"><i className="bi bi-person-lines-fill me-2"></i>Quản lý người dùng</h5>
                            
                            <div className="d-flex gap-2">
                                <select 
                                    className="form-select form-select-sm w-auto shadow-sm"
                                    value={filterOnline}
                                    onChange={(e) => { setFilterOnline(e.target.value); setPage(0); }}
                                >
                                    <option value="">Tất cả kết nối</option>
                                    <option value="online">Online</option>
                                    <option value="offline">Offline</option>
                                </select>

                                <select 
                                    className="form-select form-select-sm w-auto shadow-sm"
                                    value={filterLocked}
                                    onChange={(e) => { setFilterLocked(e.target.value); setPage(0); }}
                                >
                                    <option value="">Tất cả trạng thái</option>
                                    <option value="false">Đang hoạt động</option>
                                    <option value="true">Đã khóa</option>
                                </select>
                                <div className="input-group input-group-sm shadow-sm" style={{ maxWidth: '300px' }}>
                                    <span className="input-group-text bg-white border-end-0 text-muted"><i className="bi bi-search"></i></span>
                                    <input
                                        type="text"
                                        className="form-control border-start-0 ps-0"
                                        placeholder="Tìm email, số điện thoại..."
                                        value={searchTerm}
                                        onChange={(e) => { setSearchTerm(e.target.value); setPage(0); }}
                                    />
                                </div>
                            </div>
                        </div>
                    </div>

                    <div className="table-responsive">
                        <table className="table table-hover align-middle mb-0">
                            <thead className="table-light">
                                <tr>
                                    <th className="ps-4">ID</th>
                                    <th>Email</th>
                                    <th>Số điện thoại</th>
                                    <th>Trạng thái</th>
                                    <th>Online</th>
                                    <th className="text-end pe-4">Hành động</th>
                                </tr>
                            </thead>
                            <tbody>
                                {loading ? (
                                    <tr><td colSpan="6" className="text-center py-4 text-muted">Đang tải dữ liệu...</td></tr>
                                ) : users.length === 0 ? (
                                    <tr><td colSpan="6" className="text-center py-4 text-muted">Không tìm thấy người dùng nào.</td></tr>
                                ) : (
                                    users.map(u => (
                                        <tr key={u.id}>
                                            <td className="ps-4 text-muted small">#{u.id}</td>
                                            <td className="fw-medium">{u.accEmail}</td>
                                            <td>{u.accPhone || <span className="text-muted fst-italic">Chưa cập nhật</span>}</td>
                                            <td>
                                                {u.locked ? (
                                                    <span className="badge bg-danger-subtle text-danger border border-danger-subtle px-3 rounded-pill">
                                                        <i className="bi bi-lock-fill me-1"></i>Đã khóa
                                                    </span>
                                                ) : (
                                                    <span className="badge bg-success-subtle text-success border border-success-subtle px-3 rounded-pill">
                                                        <i className="bi bi-check-circle-fill me-1"></i>Hoạt động
                                                    </span>
                                                )}
                                            </td>
                                            <td>
                                                {u.online ? (
                                                    <span className="badge bg-success border border-success px-2 rounded-pill">
                                                        <i className="bi bi-wifi me-1"></i>Online
                                                    </span>
                                                ) : (
                                                    <span className="badge bg-secondary border border-secondary px-2 rounded-pill opacity-75">
                                                        <i className="bi bi-wifi-off me-1"></i>Offline
                                                    </span>
                                                )}
                                            </td>
                                            <td className="text-end pe-4">
                                                {u.locked ? (
                                                    <button 
                                                        className="btn btn-sm btn-outline-success border-0 fw-medium"
                                                        onClick={() => openConfirmModal(u.id, true)}
                                                        title="Mở khóa tài khoản"
                                                    >
                                                        <i className="bi bi-unlock me-1"></i>Mở khóa
                                                    </button>
                                                ) : (
                                                    <button 
                                                        className="btn btn-sm btn-outline-danger border-0 fw-medium"
                                                        onClick={() => openConfirmModal(u.id, false)}
                                                        title="Khóa tài khoản"
                                                    >
                                                        <i className="bi bi-lock me-1"></i>Khóa
                                                    </button>
                                                )}
                                            </td>
                                        </tr>
                                    ))
                                )}
                            </tbody>
                        </table>
                    </div>

                    {/* Pagination */}
                    {totalPages > 1 && (
                        <div className="card-footer bg-white border-0 py-3">
                            <nav>
                                <ul className="pagination justify-content-center mb-0">
                                    <li className={`page-item ${page === 0 ? 'disabled' : ''}`}>
                                        <button className="page-link border-0 rounded-circle mx-1" onClick={() => setPage(p => Math.max(0, p - 1))}>
                                            <i className="bi bi-chevron-left"></i>
                                        </button>
                                    </li>
                                    {[...Array(totalPages)].map((_, i) => (
                                        <li key={i} className={`page-item ${page === i ? 'active' : ''}`}>
                                            <button 
                                                className={`page-link border-0 rounded-circle mx-1 ${page === i ? 'bg-primary text-white shadow-sm' : 'text-dark'}`}
                                                onClick={() => setPage(i)}
                                            >
                                                {i + 1}
                                            </button>
                                        </li>
                                    ))}
                                    <li className={`page-item ${page === totalPages - 1 ? 'disabled' : ''}`}>
                                        <button className="page-link border-0 rounded-circle mx-1" onClick={() => setPage(p => Math.min(totalPages - 1, p + 1))}>
                                            <i className="bi bi-chevron-right"></i>
                                        </button>
                                    </li>
                                </ul>
                            </nav>
                        </div>
                    )}
                </div>
            </div>

            {/* Confirmation Modal */}
            {confirmModal.show && (
                <div className="modal fade show d-block" style={{ backgroundColor: 'rgba(0,0,0,0.5)' }} tabIndex="-1" role="dialog">
                    <div className="modal-dialog modal-dialog-centered">
                        <div className="modal-content border-0 shadow">
                            <div className="modal-header border-bottom-0">
                                <h5 className="modal-title fw-bold">Xác nhận hành động</h5>
                                <button type="button" className="btn-close" onClick={closeConfirmModal}></button>
                            </div>
                            <div className="modal-body text-center py-4">
                                <div className="mb-3">
                                    <i className={`bi ${confirmModal.isLocked ? 'bi-unlock-fill text-success' : 'bi-lock-fill text-danger'} display-4`}></i>
                                </div>
                                <p className="mb-0 fs-5">
                                    Bạn có chắc chắn muốn <span className="fw-bold">{confirmModal.isLocked ? 'mở khóa' : 'khóa'}</span> tài khoản này không?
                                </p>
                                <p className="text-muted small mt-2">Hành động này sẽ cập nhật trạng thái truy cập của người dùng.</p>
                            </div>
                            <div className="modal-footer border-top-0 justify-content-center pb-4">
                                <button type="button" className="btn btn-light px-4 me-2" onClick={closeConfirmModal}>Hủy bỏ</button>
                                <button 
                                    type="button" 
                                    className={`btn ${confirmModal.isLocked ? 'btn-success' : 'btn-danger'} px-4`}
                                    onClick={handleConfirmAction}
                                >
                                    Đồng ý
                                </button>
                            </div>
                        </div>
                    </div>
                </div>
            )}
        </div>
    );
};

export default AdminDashboard;