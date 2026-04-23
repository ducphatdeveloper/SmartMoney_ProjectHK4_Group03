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
            setError('Please fill in all information');
            return;
        }

        if (newPassword !== confirmPassword) {
            setError('Passwords do not match');
            return;
        }

        setIsLoading(true);
        try {
            await authApi.resetPassword({ email, otp, newPassword });
            setMessage('Password reset successful. Redirecting...');
            setTimeout(() => {
                navigate('/login');
            }, 2000);
        } catch (err) {
            setError(err.response?.data?.message || 'Error resetting password.');
        } finally {
            setIsLoading(false);
        }
    };

    return (
        <div className="container d-flex justify-content-center align-items-center vh-100">
            <div className="card shadow-lg p-4 border-0" style={{ width: '400px', borderRadius: '1rem' }}>
                <h4 className="fw-bold text-center mb-4">Reset Password</h4>

                {message && <div className="alert alert-success small text-center">{message}</div>}
                {error && <div className="alert alert-danger small text-center">{error}</div>}

                <form onSubmit={handleSubmit}>
                    <div className="mb-3">
                        <label className="form-label small fw-bold">Email</label>
                        <input type="email" className="form-control" value={email} disabled />
                    </div>

                    <div className="mb-3">
                        <label className="form-label small fw-bold">OTP Code</label>
                        <input
                            type="text"
                            className="form-control"
                            value={otp}
                            onChange={(e) => setOtp(e.target.value)}
                            placeholder="Enter the OTP code from email"
                        />
                    </div>

                    <div className="mb-3">
                        <label className="form-label small fw-bold">New password</label>
                        <input
                            type="password"
                            className="form-control"
                            value={newPassword}
                            onChange={(e) => setNewPassword(e.target.value)}
                            placeholder="Enter new password"
                        />
                    </div>

                    <div className="mb-3">
                        <label className="form-label small fw-bold">Confirm new password</label>
                        <input
                            type="password"
                            className="form-control"
                            value={confirmPassword}
                            onChange={(e) => setConfirmPassword(e.target.value)}
                            placeholder="Re-enter new password"
                        />
                    </div>

                    <button type="submit" className="btn btn-primary w-100 py-2 fw-bold" disabled={isLoading}>
                        {isLoading ? (
                            <span><span className="spinner-border spinner-border-sm me-2" role="status" aria-hidden="true"></span>Processing...</span>
                        ) : (
                            "CONFIRM"
                        )}
                    </button>
                </form>
            </div>
        </div>
    );
};

export default ResetPassword;