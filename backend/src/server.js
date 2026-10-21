const express = require('express');
const cors = require('cors');

const app = express();
app.use(cors());
app.use(express.json());

app.get('/', (req, res) => res.send('API nha khoa đang chạy'));

app.use('/api/users', require('./routes/users'));
app.use('/api/family-members', require('./routes/familyMembers'));

// Không tìm thấy API
app.use((req, res) => res.status(404).json({ message: 'API không tồn tại' }));

// Bắt lỗi chung, tránh server bị sập
app.use((err, req, res, next) => {
  console.error(err);
  res.status(500).json({ message: 'Lỗi server' });
});

const PORT = 3000;
app.listen(PORT, () => console.log(`Server chạy tại http://localhost:${PORT}`));