import React from 'react';
import { BrowserRouter as Router, Routes, Route, Navigate } from 'react-router-dom';
import 'bootstrap/dist/css/bootstrap.min.css';
import 'bootstrap-icons/font/bootstrap-icons.css';

import Login from './components/Login';
import Register from './components/Register';
import AdminDashboard from './components/AdminDashboard';

// Thành phần kiểm tra quyền Admin 🛡️
const AdminRoute = ({ children }) => {
  const user = JSON.parse(localStorage.getItem('user'));
  const token = localStorage.getItem('accessToken');

  // Kiểm tra nếu có token và role là ADMIN
  if (token && user?.role === 'ADMIN') {
    return children;
  }

  // Nếu không phải admin, đẩy về trang login
  return <Navigate to="/login" />;
};

function App() {
  return (
      <Router>
        <div className="App">
          <Routes>
            {/* Các route công khai 🌍 */}
            <Route path="/login" element={<Login />} />
            <Route path="/register" element={<Register />} />

            {/* Route bảo vệ dành cho Admin 🔐 */}
            <Route
                path="/admin"
                element={
                  <AdminRoute>
                    <AdminDashboard />
                  </AdminRoute>
                }
            />

            {/* Điều hướng mặc định khi vào trang chủ */}
            <Route path="/" element={<Navigate to="/login" />} />
          </Routes>
        </div>
      </Router>
  );
}

export default App;