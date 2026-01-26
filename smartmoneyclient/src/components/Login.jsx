import React, { useState } from 'react';
import { useNavigate, Link } from 'react-router-dom';
import { authApi } from '../server/api';

const Login = () => {
    const [formData, setFormData] = useState({
        email: '',
        password: '',
        deviceToken: 'web-browser',
        deviceType: 'WEB'
    });
    const [error, setError] = useState('');
    const navigate = useNavigate();

    const handleSubmit = async (e) => {
        e.preventDefault();
        try {
            const response = await authApi.login(formData);
            const { accessToken, refreshToken, userInfo } = response.data;

            // Lưu trữ thông tin xác thực
            localStorage.setItem('accessToken', accessToken);
            localStorage.setItem('refreshToken', refreshToken);
            localStorage.setItem('user', JSON.stringify(userInfo));

            // Kiểm tra Role 🛡️
            if (userInfo.role === 'ADMIN') {
                navigate('/admin');
            } else {
                navigate('/user-dashboard'); // Hoặc trang bất kỳ cho User
            }

        } catch (err) {
            setError('Đăng nhập thất bại. Vui lòng kiểm tra lại email/mật khẩu.');
        }
    };

    return (
        <div className="container d-flex justify-content-center align-items-center vh-100">
            <div className="card shadow-lg p-4 border-0" style={{ width: '400px', borderRadius: '1rem' }}>
                <div className="text-center mb-4">
                    <i className="bi bi-wallet2 text-primary display-4"></i>
                    <h2 className="fw-bold mt-2">Smart Money</h2>
                </div>

                {error && <div className="alert alert-danger p-2 small text-center">{error}</div>}

                <form onSubmit={handleSubmit}>
                    <div className="mb-3">
                        <div className="input-group">
                            <span className="input-group-text bg-white"><i className="bi bi-envelope text-muted"></i></span>
                            <input type="email" className="form-control" placeholder="Email" required
                                   onChange={(e) => setFormData({...formData, email: e.target.value})} />
                        </div>
                    </div>
                    <div className="mb-3">
                        <div className="input-group">
                            <span className="input-group-text bg-white"><i className="bi bi-lock text-muted"></i></span>
                            <input type="password" className="form-control" placeholder="Mật khẩu" required
                                   onChange={(e) => setFormData({...formData, password: e.target.value})} />
                        </div>
                    </div>
                    <button type="submit" className="btn btn-primary w-100 py-2 shadow-sm fw-bold">ĐĂNG NHẬP</button>
                    <div className="text-center mt-3 small text-muted">
                        Chưa có tài khoản? <Link to="/register" className="text-primary text-decoration-none fw-bold">Đăng ký ngay</Link>
                    </div>
                </form>
            </div>
        </div>
    );
};

export default Login;