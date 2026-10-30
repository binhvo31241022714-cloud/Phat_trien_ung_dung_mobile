// Kiểm tra các trường hồ sơ cơ bản dùng chung cho users và family_members
// (họ tên, số điện thoại, ngày sinh, mối quan hệ, địa chỉ)

const { isValidDateKey, toVietnamDateKey } = require('./booking');

const LABELS = {
  fullName: 'Họ tên',
  phone: 'Số điện thoại',
  birthday: 'Ngày sinh',
  relationship: 'Mối quan hệ',
  address: 'Địa chỉ',
};
const MAX_LENGTH = { fullName: 100, relationship: 50, address: 200 };

// Đọc các trường trong [fields] có trong body. Trả về { data } nếu hợp lệ,
// { error } nếu sai. Trường không gửi thì bỏ qua (dùng cho PATCH).
// requireName: bắt buộc có họ tên (khi thêm người thân).
function readProfile(body, fields, { requireName = false } = {}) {
  const data = {};

  for (const key of fields) {
    if (body[key] === undefined) continue;
    const label = LABELS[key];
    if (typeof body[key] !== 'string') return { error: `${label} phải là chuỗi` };
    const value = body[key].trim();

    if (key === 'fullName' && value.length === 0) {
      return { error: 'Họ tên không được để trống' };
    }
    if (MAX_LENGTH[key] && value.length > MAX_LENGTH[key]) {
      return { error: `${label} tối đa ${MAX_LENGTH[key]} ký tự` };
    }
    // Cho phép rỗng (chưa có số điện thoại, chưa có ngày sinh)
    if (key === 'phone' && value !== '' && !/^\d{9,11}$/.test(value)) {
      return { error: 'Số điện thoại chỉ gồm chữ số, từ 9 đến 11 số' };
    }
    if (key === 'birthday' && value !== '') {
      if (!isValidDateKey(value)) {
        return { error: 'Ngày sinh phải là ngày hợp lệ dạng YYYY-MM-DD' };
      }
      // So chuỗi YYYY-MM-DD với ngày hôm nay theo giờ Việt Nam
      if (value > toVietnamDateKey(new Date())) {
        return { error: 'Ngày sinh không được ở tương lai' };
      }
    }
    data[key] = value;
  }

  if (requireName && data.fullName === undefined) {
    return { error: 'Thiếu họ tên' };
  }
  return { data };
}

module.exports = { readProfile };
