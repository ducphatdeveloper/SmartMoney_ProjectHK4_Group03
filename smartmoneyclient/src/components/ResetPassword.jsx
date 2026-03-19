import React, { useState } from 'react';
import { useLocation, useNavigate } from 'react-router-dom';
import { authApi } from '../server/api';

const ResetPassword = () => {
    const location = useLocation();
    const navigate = useNavigate();

    const [email] = useState(location.state?.email || '');
    const [otp, setOtp] = useState('');
    const [newPassword, setNewPassword] = useState('');
    const [confirmPassword, setConfirmPassword] = useState('');
    const [message, setMessage] = useState('');
    const [error, setError] = useState('');
    const [isLoading, setIsLoading] = useState(false);

    const handleSubmit = async (e) => {
        e.preventDefault();
        setMessage('');
        setError('');

        if (!otp || !newPassword || !confirmPassword) {
            setError('Vui lòng nhập đầy đủ thông tin');
            return;
        }

        if (newPassword !== confirmPassword) {
            setError('Mật khẩu xác nhận không khớp');
            return;
        }

        setIsLoading(true);
        try {
            await authApi.resetPassword({ email, otp, newPassword });
            setMessage('Đặt lại mật khẩu thành công. Đang chuyển hướng...');
            setTimeout(() => {
                navigate('/login');
            }, 2000);
        } catch (err) {
            setError(err.response?.data?.message || 'Lỗi khi đặt lại mật khẩu.');
        } finally {
            setIsLoading(false);
        }
    };

    return (
        <div className="container d-flex justify-content-center align-items-center vh-100">
            <div className="card shadow-lg p-4 border-0" style={{ width: '400px', borderRadius: '1rem' }}>
                <h4 className="fw-bold text-center mb-4">Đặt Lại Mật Khẩu</h4>

                {message && <div className="alert alert-success small text-center">{message}</div>}
                {error && <div className="alert alert-danger small text-center">{error}</div>}

                <form onSubmit={handleSubmit}>
                    <div className="mb-3">
                        <label className="form-label small fw-bold">Email</label>
                        <input type="email" className="form-control" value={email} disabled />
                    </div>

                    <div className="mb-3">
                        <label className="form-label small fw-bold">Mã OTP</label>
                        <input
                            type="text"
                            className="form-control"
                            value={otp}
                            onChange={(e) => setOtp(e.target.value)}
                            placeholder="Nhập mã OTP từ email"
                        />
                    </div>

                    <div className="mb-3">
                        <label className="form-label small fw-bold">Mật khẩu mới</label>
                        <input
                            type="password"
                            className="form-control"
                            value={newPassword}
                            onChange={(e) => setNewPassword(e.target.value)}
                            placeholder="Nhập mật khẩu mới"
                        />
                    </div>

                    <div className="mb-3">
                        <label className="form-label small fw-bold">Xác nhận mật khẩu mới</label>
                        <input
                            type="password"
                            className="form-control"
                            value={confirmPassword}
                            onChange={(e) => setConfirmPassword(e.target.value)}
                            placeholder="Nhập lại mật khẩu mới"
                        />
                    </div>

                    <button type="submit" className="btn btn-primary w-100 py-2 fw-bold" disabled={isLoading}>
                        {isLoading ? (
                            <span><span className="spinner-border spinner-border-sm me-2" role="status" aria-hidden="true"></span>Đang xử lý...</span>
                        ) : (
                            "XÁC NHẬN"
                        )}
                    </button>
                </form>
            </div>
        </div>
    );
};

export default ResetPassword;