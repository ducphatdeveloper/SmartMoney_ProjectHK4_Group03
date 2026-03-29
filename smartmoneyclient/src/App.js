import React from 'react';
import { BrowserRouter as Router, Routes, Route, Navigate } from 'react-router-dom';
import 'bootstrap/dist/css/bootstrap.min.css';

import Login from './components/Login';
import Register from './components/Register';
import AdminDashboard from './components/AdminDashboard';
import DashBoard from  './components/Dashboard';
import ForgotPassword from './components/ForgotPassword';
import ResetPassword from './components/ResetPassword';
import TransactionHistory from './components/TransactionHistory';

// Thành phần bảo vệ Route cho Người dùng thông thường
const UserRoute = ({ children }) => {
    const token = localStorage.getItem('accessToken');
    const user = JSON.parse(localStorage.getItem('user'));

    // Nếu không có token, yêu cầu đăng nhập
    if (!token || !user) return <Navigate to="/login" replace />;

    return children;
};

// Thành phần bảo vệ Route cho Admin
const AdminRoute = ({ children }) => {
    const user = JSON.parse(localStorage.getItem('user'));
    const token = localStorage.getItem('accessToken');
    
    // Nếu không có token hoặc user, chắc chắn không phải admin
    if (!token || !user) return <Navigate to="/login" replace />;

    const authorizedRoles = ["Quản trị viên", "ROLE_ADMIN", "ADMIN_SYSTEM_ALL"];
    const isAdmin = authorizedRoles.includes(user.roleName);


    if (isAdmin) return children;
    
    // Nếu đăng nhập rồi nhưng không phải admin, có thể cho về dashboard hoặc trang thông báo lỗi quyền
    return <Navigate to="/dashboard" replace />;
};

function App() {
    return (
        <Router>
            <div className="App">
                <Routes>
                    <Route path="/login" element={<Login />} />
                    <Route path="/register" element={<Register />} />
                    <Route path="/forgot-password" element={<ForgotPassword />} />
                    <Route path="/reset-password" element={<ResetPassword />} />

                    {/* Khu vực dành cho người dùng 👤 */}
                    <Route 
                        path="/dashboard" 
                        element={
                            <UserRoute>
                                <DashBoard />
                            </UserRoute>
                        } 
                    />
                    <Route 
                        path="/transactions" 
                        element={
                            <UserRoute>
                                <TransactionHistory />
                            </UserRoute>
                        } 
                    />

                    {/* Bảo vệ khu vực Admin 🔐 */}
                    <Route
                        path="/admin/*"
                        element={
                            <AdminRoute>
                                <AdminDashboard />
                            </AdminRoute>
                        }
                    />

                    <Route path="/" element={<Navigate to="/login" />} />
                    {/* Catch all - nếu không khớp route nào thì về login */}
                    <Route path="*" element={<Navigate to="/login" />} />
                </Routes>
            </div>
        </Router>
    );
}

export default App;