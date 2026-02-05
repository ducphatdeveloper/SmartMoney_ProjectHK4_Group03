import React, { useEffect, useState } from 'react';
import { useNavigate } from 'react-router-dom';
import { adminApi, authApi } from '../server/api';

const AdminDashboard = () => {
    const [users, setUsers] = useState([]);
    const [stats, setStats] = useState({ totalUsers: 0, totalTransactions: 0, activeDevices: 0 });
    const [currentUser, setCurrentUser] = useState(null);
    const [searchTerm, setSearchTerm] = useState('');
    const [filterLocked, setFilterLocked] = useState('');
    const [page, setPage] = useState(0);
    const [totalPages, setTotalPages] = useState(0);
    const [loading, setLoading] = useState(false);
    const navigate = useNavigate();

    useEffect(() => {
        const storedUser = JSON.parse(localStorage.getItem('user'));
        const token = localStorage.getItem('accessToken');

        // Các vai trò được phép truy cập trang admin, dựa theo @PreAuthorize từ backend
        const authorizedRoles = ["Quản trị viên", "ROLE_ADMIN", "ADMIN_SYSTEM_ALL"];

        if (!token || !storedUser || !authorizedRoles.includes(storedUser.roleName)) {
            navigate('/login');
            return;
        }
        setCurrentUser(storedUser);
        fetchStats();
    }, [navigate]);

    useEffect(() => {
        const delayDebounceFn = setTimeout(() => {
            fetchUsers();
        }, 500);

        return () => clearTimeout(delayDebounceFn);
    }, [page, searchTerm, filterLocked]);

    const fetchStats = async () => {
        try {
            const res = await adminApi.getStats();
            if (res.data) setStats(res.data);
        } catch (err) {
            console.error("Lỗi tải thống kê", err);
        }
    };

    const fetchUsers = async () => {
        setLoading(true);
        try {
            const params = {
                page: page,
                size: 8,
                search: searchTerm,
                locked: filterLocked === '' ? null : filterLocked === 'true'
            };
            const res = await adminApi.getUsers(params);
            setUsers(res.data.content || []);
            setTotalPages(res.data.totalPages || 0);
        } catch (err) {
            console.error("Lỗi tải danh sách người dùng", err);
        } finally {
            setLoading(false);
        }
    };

    const handleLockUnlock = async (id, isLocked) => {
        if (!window.confirm(`Bạn có chắc muốn ${isLocked ? 'mở khóa' : 'khóa'} tài khoản này?`)) return;

        try {
            if (isLocked) {
                await adminApi.unlockUser(id);
            } else {
                await adminApi.lockUser(id);
            }
            fetchUsers();
            fetchStats();
        } catch (err) {
            alert("Thao tác thất bại. Vui lòng thử lại.");
        }
    };

    const handleLogout = async () => {
        try {
            await authApi.logout('web-browser');
        } catch (err) {
            console.error(err);
        } finally {
            localStorage.clear();
            navigate('/login');
        }
    };

    return (
        <div className="min-vh-100 bg-light">
            {/* Navbar */}
            <nav className="navbar navbar-expand-lg navbar-dark bg-dark px-4 shadow-sm sticky-top">
                <span className="navbar-brand fw-bold text-info">
                    <i className="bi bi-shield-lock me-2"></i>ADMIN PORTAL
                </span>
                <div className="ms-auto d-flex align-items-center">
                    <div className="text-end me-3 d-none d-md-block border-end pe-3 border-secondary">
                        <small className="text-muted d-block text-uppercase" style={{ fontSize: '0.65rem' }}>{currentUser?.roleName}</small>
                        <span className="text-white fw-medium">{currentUser?.accEmail}</span>
                    </div>
                    <button onClick={handleLogout} className="btn btn-outline-danger btn-sm border-0 ms-2">
                        <i className="bi bi-power fs-5"></i>
                    </button>
                </div>
            </nav>

            <div className="container-fluid py-4 px-lg-5">
                {/* Stats Cards */}
                <div className="row g-4 mb-4">
                    <div className="col-md-6 col-lg-3">
                        <div className="card border-0 shadow-sm bg-primary text-white h-100">
                            <div className="card-body">
                                <div className="d-flex justify-content-between align-items-center">
                                    <div>
                                        <h6 className="text-white-50 text-uppercase mb-1">Tổng người dùng</h6>
                                        <h3 className="fw-bold mb-0">{stats.totalUsers || 0}</h3>
                                    </div>
                                    <i className="bi bi-people fs-1 opacity-50"></i>
                                </div>
                            </div>
                        </div>
                    </div>
                    <div className="col-md-6 col-lg-3">
                        <div className="card border-0 shadow-sm bg-success text-white h-100">
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
                <div className="card border-0 shadow-sm">
                    <div className="card-header bg-white py-3 border-0">
                        <div className="d-flex flex-column flex-md-row justify-content-between align-items-md-center gap-3">
                            <h5 className="mb-0 fw-bold text-dark"><i className="bi bi-person-lines-fill me-2"></i>Quản lý người dùng</h5>
                            
                            <div className="d-flex gap-2">
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
                                    <th className="text-end pe-4">Hành động</th>
                                </tr>
                            </thead>
                            <tbody>
                                {loading ? (
                                    <tr><td colSpan="5" className="text-center py-4 text-muted">Đang tải dữ liệu...</td></tr>
                                ) : users.length === 0 ? (
                                    <tr><td colSpan="5" className="text-center py-4 text-muted">Không tìm thấy người dùng nào.</td></tr>
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
                                            <td className="text-end pe-4">
                                                {u.locked ? (
                                                    <button 
                                                        className="btn btn-sm btn-outline-success border-0 fw-medium"
                                                        onClick={() => handleLockUnlock(u.id, true)}
                                                        title="Mở khóa tài khoản"
                                                    >
                                                        <i className="bi bi-unlock me-1"></i>Mở khóa
                                                    </button>
                                                ) : (
                                                    <button 
                                                        className="btn btn-sm btn-outline-danger border-0 fw-medium"
                                                        onClick={() => handleLockUnlock(u.id, false)}
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
        </div>
    );
};

export default AdminDashboard;