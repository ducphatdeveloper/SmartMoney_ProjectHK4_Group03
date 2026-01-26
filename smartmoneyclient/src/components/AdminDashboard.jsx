import React, { useEffect, useState } from 'react';
import { useNavigate } from 'react-router-dom';
import { permissionApi, authApi } from '../server/api';

const AdminDashboard = () => {
    const [permissions, setPermissions] = useState([]);
    const [user, setUser] = useState(null);
    const navigate = useNavigate();

    useEffect(() => {
        // Kiểm tra trạng thái đăng nhập
        const storedUser = JSON.parse(localStorage.getItem('user'));
        if (!storedUser) {
            navigate('/login');
            return;
        }
        setUser(storedUser);

        // Tải danh sách quyền từ API
        permissionApi.getAll()
            .then(res => setPermissions(res.data))
            .catch(err => console.error("Lỗi tải dữ liệu quyền", err));
    }, [navigate]);

    const handleLogout = async () => {
        try {
            await authApi.logout('web-browser'); //
            localStorage.clear();
            navigate('/login');
        } catch (err) {
            localStorage.clear();
            navigate('/login');
        }
    };

    return (
        <div className="min-vh-100 bg-light">
            <nav className="navbar navbar-dark bg-primary px-4 shadow-sm">
                <span className="navbar-brand fw-bold"><i className="bi bi-speedometer2 me-2"></i>Smart Money CMS</span>
                <div className="d-flex align-items-center">
                    <span className="text-white me-3 d-none d-md-inline">Xin chào, <strong>{user?.username || 'Admin'}</strong></span>
                    <button onClick={handleLogout} className="btn btn-light btn-sm fw-bold">
                        <i className="bi bi-box-arrow-right"></i> Đăng xuất
                    </button>
                </div>
            </nav>

            <div className="container py-4">
                <div className="row g-4">
                    <div className="col-12">
                        <div className="card border-0 shadow-sm">
                            <div className="card-header bg-white py-3 border-0 d-flex justify-content-between align-items-center">
                                <h5 className="mb-0 text-primary fw-bold">Quản lý quyền hệ thống</h5>
                                <button className="btn btn-primary btn-sm"><i className="bi bi-plus-lg"></i> Thêm mới</button>
                            </div>
                            <div className="table-responsive">
                                <table className="table table-hover align-middle mb-0">
                                    <thead className="table-light">
                                    <tr>
                                        <th className="ps-4">ID</th>
                                        <th>Tên quyền</th>
                                        <th>Nhóm chức năng</th>
                                        <th className="text-end pe-4">Thao tác</th>
                                    </tr>
                                    </thead>
                                    <tbody>
                                    {permissions.map(p => (
                                        <tr key={p.id}>
                                            <td className="ps-4 text-muted">#{p.id}</td>
                                            <td className="fw-bold">{p.name}</td>
                                            <td><span className="badge bg-soft-info text-info border border-info px-3">{p.moduleGroup}</span></td>
                                            <td className="text-end pe-4">
                                                <button className="btn btn-sm btn-outline-secondary me-2"><i className="bi bi-pencil-square"></i></button>
                                                <button className="btn btn-sm btn-outline-danger"><i className="bi bi-trash3"></i></button>
                                            </td>
                                        </tr>
                                    ))}
                                    </tbody>
                                </table>
                            </div>
                        </div>
                    </div>
                </div>
            </div>
        </div>
    );
};

export default AdminDashboard;