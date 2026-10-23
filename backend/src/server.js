const express = require('express');
const cors = require('cors');

const app = express();
app.use(cors());
app.use(express.json());

app.get('/', (req, res) => res.send('API nha khoa đang chạy'));

// Module 1 - Tài khoản và dữ liệu cơ bản (Bình)
app.use('/api/users', require('./routes/users'));
app.use('/api/family-members', require('./routes/familyMembers'));
app.use('/api/services', require('./routes/services'));
app.use('/api/combos', require('./routes/combos'));
app.use('/api/doctors', require('./routes/doctors'));
app.use('/api/favorites', require('./routes/favorites'));

// Module 2 - Đặt lịch nha khoa (Phương)
app.use('/api/bookings', require('./routes/bookings'));
app.use('/api/availability', require('./routes/availability'));
app.use('/api/vouchers', require('./routes/vouchers'));
app.use('/api/appointments', require('./routes/appointments'));

// Module 3 - Hồ sơ nha khoa (Ngân)
app.use('/api/patients', require('./routes/patients'));
app.use('/api/visits', require('./routes/visits'));
app.use('/api/invoices', require('./routes/invoices'));
app.use('/api/treatments', require('./routes/treatments'));

// Module 4 - Nội dung và thông báo (Nhi)
app.use('/api/articles', require('./routes/articles'));
app.use('/api/home', require('./routes/home'));
app.use('/api/notifications', require('./routes/notifications'));

// Không tìm thấy API
app.use((req, res) => res.status(404).json({ message: 'API không tồn tại' }));

// Bắt lỗi chung, tránh server bị sập
app.use((err, req, res, next) => {
  console.error(err);
  res.status(500).json({ message: 'Lỗi server' });
});

const PORT = 3000;
app.listen(PORT, () => console.log(`Server chạy tại http://localhost:${PORT}`));