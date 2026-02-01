import React, { useEffect, useState } from 'react';
import { useNavigate } from 'react-router-dom';
import { PieChart, Pie, Cell, ResponsiveContainer, Tooltip, Legend } from 'recharts';
import { permissionApi, authApi } from '../server/api';

const AdminDashboard = () => {
    const [permissions, setPermissions] = useState([]);
    const [user, setUser] = useState(null);
    const [searchTerm, setSearchTerm] = useState('');
    const [timeFrame, setTimeFrame] = useState('month');
    const navigate = useNavigate();

    // Dữ liệu mẫu cho biểu đồ 📊
    const chartData = [
        { name: 'Chi tiêu', value: 4500000, color: '#ef4444' },
        { name: 'Thu nhập', value: 8200000, color: '#10b981' },
    ];

    useEffect(() => {
        const storedUser = JSON.parse(localStorage.getItem('user'));
        const token = localStorage.getItem('accessToken');

        // Kiểm tra quyền truy cập 🛡️
        if (!token || storedUser?.roleName !== "Quản trị viên") {
            navigate('/login');
            return;
        }
        setUser(storedUser);

        // Tải dữ liệu từ API 📋
        permissionApi.getAll()
            .then(res => setPermissions(res.data))
            .catch(err => console.error("Lỗi tải dữ liệu quyền", err));
    }, [navigate]);

    const handleLogout = async () => {
        try {
            await authApi.logout('web-browser');
            localStorage.clear();
            navigate('/login');
        } catch (err) {
            localStorage.clear();
            navigate('/login');
        }
    };

    // Logic lọc tìm kiếm
    const filteredPermissions = permissions.filter(p =>
        p.name?.toLowerCase().includes(searchTerm.toLowerCase()) ||
        p.moduleGroup?.toLowerCase().includes(searchTerm.toLowerCase())
    );

    return (
        <div className="min-vh-100 bg-light">
            {/* 1. Thanh điều hướng hiện đại 🧭 */}
            <nav className="navbar navbar-expand-lg navbar-dark bg-dark px-4 shadow-sm sticky-top">
                <span className="navbar-brand fw-bold text-info">
                    <i className="bi bi-speedometer2 me-2"></i>SMART MONEY CMS
                </span>
                <div className="ms-auto d-flex align-items-center">
                    <div className="text-end me-3 d-none d-md-block border-end pe-3 border-secondary">
                        <small className="text-muted d-block text-uppercase" style={{ fontSize: '0.65rem' }}>{user?.roleName}</small>
                        <span className="text-white fw-medium">{user?.accEmail}</span>
                    </div>
                    <button onClick={handleLogout} className="btn btn-outline-danger btn-sm border-0 ms-2">
                        <i className="bi bi-power fs-5"></i>
                    </button>
                </div>
            </nav>

            <div className="container-fluid py-4 px-lg-5">
                <div className="row g-4">
                    {/* 2. Cột trái: Thống kê tỷ trọng 📊 */}
                    <div className="col-lg-4">
                        <div className="card border-0 shadow-sm h-100">
                            <div className="card-body">
                                <div className="d-flex justify-content-between align-items-center mb-4">
                                    <h6 className="fw-bold mb-0 text-secondary">TỶ TRỌNG THU CHI</h6>
                                    <select className="form-select form-select-sm w-auto" value={timeFrame} onChange={(e) => setTimeFrame(e.target.value)}>
                                        <option value="month">Tháng này</option>
                                        <option value="year">Năm nay</option>
                                    </select>
                                </div>
                                <div style={{ width: '100%', height: 250 }}>
                                    <ResponsiveContainer>
                                        <PieChart>
                                            <Pie data={chartData} innerRadius={60} outerRadius={80} paddingAngle={5} dataKey="value">
                                                {chartData.map((entry, index) => <Cell key={index} fill={entry.color} />)}
                                            </Pie>
                                            <Tooltip formatter={(value) => new Intl.NumberFormat('vi-VN').format(value) + ' ₫'} />
                                            <Legend />
                                        </PieChart>
                                    </ResponsiveContainer>
                                </div>
                            </div>
                        </div>
                    </div>

                    {/* 3. Cột phải: Quản lý quyền hệ thống 📋 */}
                    <div className="col-lg-8">
                        <div className="card border-0 shadow-sm h-100">
                            <div className="card-header bg-white py-3 border-0">
                                <div className="d-flex justify-content-between align-items-center mb-3">
                                    <h5 className="mb-0 fw-bold text-primary">Danh sách quyền</h5>
                                    <button className="btn btn-primary btn-sm rounded-pill px-3 shadow-sm">
                                        <i className="bi bi-plus-lg me-1"></i> Tạo mới
                                    </button>
                                </div>
                                <div className="input-group input-group-sm shadow-sm">
                                    <span className="input-group-text bg-white border-end-0 text-muted"><i className="bi bi-search"></i></span>
                                    <input
                                        type="text"
                                        className="form-control border-start-0 ps-0"
                                        placeholder="Tìm tên quyền hoặc nhóm chức năng..."
                                        onChange={(e) => setSearchTerm(e.target.value)}
                                    />
                                </div>
                            </div>
                            <div className="table-responsive">
                                <table className="table table-hover align-middle mb-0">
                                    <thead className="table-light">
                                    <tr>
                                        <th className="ps-4">MÃ</th>
                                        <th>TÊN QUYỀN</th>
                                        <th>NHÓM MODULE</th>
                                        <th className="text-end pe-4">THAO TÁC</th>
                                    </tr>
                                    </thead>
                                    <tbody>
                                    {filteredPermissions.map(p => (
                                        <tr key={p.id}>
                                            <td className="ps-4 text-muted small">#{p.id}</td>
                                            <td className="fw-bold">{p.name}</td>
                                            <td>
                                                    <span className="badge bg-info-subtle text-info border border-info-subtle px-3 rounded-pill">
                                                        {p.moduleGroup}
                                                    </span>
                                            </td>
                                            <td className="text-end pe-4">
                                                <button className="btn btn-sm btn-outline-secondary border-0 me-2"><i className="bi bi-pencil-square"></i></button>
                                                <button className="btn btn-sm btn-outline-danger border-0"><i className="bi bi-trash3"></i></button>
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