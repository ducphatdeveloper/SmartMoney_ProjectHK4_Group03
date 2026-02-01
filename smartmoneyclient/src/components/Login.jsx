import React, { useState } from 'react';
import { useNavigate, Link } from 'react-router-dom';
import { authApi } from '../server/api';

const Login = () => {
    const [formData, setFormData] = useState({
        username: '',
        password: '',
        deviceToken: 'web-browser', // Cần thiết cho logic UserDevice của bạn
        deviceType: 'WEB'
    });
    const [error, setError] = useState('');
    const navigate = useNavigate();

    const handleSubmit = async (e) => {
        e.preventDefault();
        try {
            const response = await authApi.login(formData);
            const serverData = response.data.data;

            if (serverData && serverData.accessToken) {
                localStorage.setItem('accessToken', serverData.accessToken);

                // Cập nhật cách lưu userData 💾
                // Vì server trả về roleId là "Quản trị viên", ta sẽ dùng chính nó để kiểm tra
                const userData = {
                    userId: serverData.userId,
                    accEmail: serverData.accEmail,
                    roleName: serverData.roleId, // Lưu lại giá trị "Quản trị viên"
                };
                localStorage.setItem('user', JSON.stringify(userData));

                // Kiểm tra điều kiện điều hướng ngay tại đây
                if (serverData.roleId === "Quản trị viên") {
                    navigate('/admin');
                } else {
                    navigate('/dashboard');
                }
            }
        } catch (err) {
            setError('Đăng nhập thất bại');
        }
    };
    return (
        <div className="container d-flex justify-content-center align-items-center vh-100">
            <div className="card shadow-lg p-4 border-0" style={{ width: '400px', borderRadius: '1rem' }}>
                <h3 className="text-center fw-bold mb-4">Smart Money 💰</h3>
                {error && <div className="alert alert-danger py-2 small text-center">{error}</div>}

                <form onSubmit={handleSubmit}>
                    <div className="mb-3">
                        <label className="form-label small fw-bold">Email hoặc Số điện thoại</label>
                        <input
                            type="text"
                            className="form-control"
                            required
                            value={formData.username}
                            onChange={(e) => setFormData({...formData, username: e.target.value})}
                        />
                    </div>
                    <div className="mb-3">
                        <label className="form-label small fw-bold">Mật khẩu</label>
                        <input
                            type="password"
                            className="form-control"
                            required
                            value={formData.password}
                            onChange={(e) => setFormData({...formData, password: e.target.value})}
                        />
                    </div>
                    <button type="submit" className="btn btn-primary w-100 py-2 fw-bold">ĐĂNG NHẬP</button>
                    <div className="text-center mt-4 small">
                        Chưa có tài khoản? <Link to="/register" className="text-decoration-none fw-bold">Đăng ký ngay</Link>
                    </div>
                </form>
            </div>
        </div>
    );
};

export default Login;