function text(value, label, max) {
  if (value === undefined) return undefined;
  if (typeof value !== 'string') return { error: `${label} phải là chuỗi` };
  const result = value.trim();
  if (result.length > max) return { error: `${label} tối đa ${max} ký tự` };
  return { value: result };
}
function readProfile(body, fields, options = {}) {
  const data = {};
  for (const field of fields) {
    const result = text(body[field], field === 'fullName' ? 'Họ tên' : field, field === 'fullName' ? 100 : field === 'address' ? 200 : 100);
    if (result && result.error) return { error: result.error };
    if (result) data[field] = result.value;
  }
  if (options.requireName && (!data.fullName || !data.fullName.trim())) return { error: 'Họ tên là bắt buộc' };
  if (data.phone !== undefined && data.phone !== '' && !/^\d{9,11}$/.test(data.phone)) return { error: 'Số điện thoại phải gồm 9 đến 11 chữ số' };
  if (data.birthday !== undefined && data.birthday !== '') {
    if (!/^\d{4}-\d{2}-\d{2}$/.test(data.birthday) || Number.isNaN(new Date(`${data.birthday}T00:00:00+07:00`).getTime()) || new Date(`${data.birthday}T00:00:00+07:00`) > new Date()) return { error: 'Ngày sinh không hợp lệ' };
  }
  return { data };
}
module.exports = { readProfile };
