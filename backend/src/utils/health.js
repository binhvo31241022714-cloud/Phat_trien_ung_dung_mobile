// Kiểm tra và đọc thông tin sức khỏe, giới tính dùng chung cho users và family_members

const MEDICAL_CONDITIONS = [
  'diabetes', // tiểu đường
  'heart_disease', // bệnh tim mạch
  'hypertension', // huyết áp cao
  'bleeding_disorder', // rối loạn đông máu
  'asthma', // hen suyễn
  'hepatitis', // viêm gan
  'other', // khác
];
// '' nghĩa là chưa chọn
const GENDERS = ['male', 'female', 'other', ''];
const MAX_TEXT = 500;
const TEXT_FIELDS = {
  allergies: 'Dị ứng thuốc',
  currentMedications: 'Thuốc đang dùng',
  healthNotes: 'Ghi chú sức khỏe',
};

// Giá trị mặc định khi document chưa có trường
const DEFAULTS = {
  gender: '',
  allergies: '',
  medicalConditions: [],
  currentMedications: '',
  isPregnant: false,
  healthNotes: '',
};

// Đọc các trường có trong body. Trả về { data } nếu hợp lệ, { error } nếu sai.
// Trường không gửi thì bỏ qua (dùng cho PATCH).
function readHealth(body) {
  const data = {};

  for (const [key, label] of Object.entries(TEXT_FIELDS)) {
    if (body[key] === undefined) continue;
    if (typeof body[key] !== 'string') return { error: `${label} phải là chuỗi` };
    const value = body[key].trim();
    if (value.length > MAX_TEXT) {
      return { error: `${label} tối đa ${MAX_TEXT} ký tự` };
    }
    data[key] = value;
  }

  if (body.medicalConditions !== undefined) {
    if (!Array.isArray(body.medicalConditions)) {
      return { error: 'medicalConditions phải là mảng' };
    }
    const invalid = body.medicalConditions.find((c) => !MEDICAL_CONDITIONS.includes(c));
    if (invalid !== undefined) {
      return { error: `Bệnh nền không hợp lệ: ${JSON.stringify(invalid)}` };
    }
    data.medicalConditions = [...new Set(body.medicalConditions)];
  }

  if (body.isPregnant !== undefined) {
    if (typeof body.isPregnant !== 'boolean') {
      return { error: 'isPregnant phải là true hoặc false' };
    }
    data.isPregnant = body.isPregnant;
  }

  if (body.gender !== undefined) {
    if (!GENDERS.includes(body.gender)) {
      return { error: 'Giới tính chỉ nhận "male", "female" hoặc "other"' };
    }
    data.gender = body.gender;
  }

  return { data };
}

// Thêm giá trị mặc định cho trường còn thiếu (dữ liệu cũ chưa có các trường này)
const withHealthDefaults = (doc) => ({ ...DEFAULTS, ...doc });

module.exports = { readHealth, withHealthDefaults, MEDICAL_CONDITIONS, DEFAULTS };
