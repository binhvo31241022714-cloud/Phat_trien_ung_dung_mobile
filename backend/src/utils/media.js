// Ảnh lưu trong Firestore dạng base64 (không dùng Firebase Storage).
// media/{id}: { ownerAccountId, patientId?, kind, mimeType, data, size, createdAt, createdBy }
// Giới hạn 700 KB sau giải mã: base64 ~956 KB, vẫn dưới giới hạn 1 MiB của
// một document Firestore.
const express = require('express');
const { ApiError, db } = require('./booking');

const MAX_IMAGE_BYTES = 700 * 1024;
const MAX_BASE64_LENGTH = Math.ceil(MAX_IMAGE_BYTES / 3) * 4;
const MEDIA_KINDS = ['avatar', 'treatment_photo'];

const SIGNATURES = {
  'image/jpeg': [0xff, 0xd8, 0xff],
  'image/png': [0x89, 0x50, 0x4e, 0x47, 0x0d, 0x0a, 0x1a, 0x0a],
};

// Chỉ các route ảnh được nhận body tới 1 MB; route khác giữ mặc định 100 KB.
const LARGE_BODY_PATHS = [
  /^\/api\/users\/me\/avatar\/?$/,
  /^\/api\/family-members\/[^/]+\/avatar\/?$/,
  /^\/api\/treatments\/[^/]+\/photos\/?$/,
];
const largeJson = express.json({ limit: '1mb' });
const normalJson = express.json();
function jsonBody(req, res, next) {
  const parser = LARGE_BODY_PATHS.some((pattern) => pattern.test(req.path)) ? largeJson : normalJson;
  return parser(req, res, next);
}

function detectMimeType(buffer) {
  for (const [mimeType, bytes] of Object.entries(SIGNATURES)) {
    if (buffer.length >= bytes.length && bytes.every((byte, i) => buffer[i] === byte)) return mimeType;
  }
  return null;
}

// Đọc ảnh từ body: { image: "<base64>" | "data:image/png;base64,...", mimeType? }.
// Kiểm tra nội dung file thật (byte đầu), không tin mimeType app gửi.
function decodeImage(body) {
  let text = body?.image;
  if (typeof text !== 'string' || !text.trim()) throw new ApiError(400, 'Thiếu ảnh (image dạng base64)');
  let declared = typeof body.mimeType === 'string' ? body.mimeType.trim().toLowerCase() : null;
  const dataUrl = /^data:([^;,]+);base64,/i.exec(text);
  if (dataUrl) {
    declared = dataUrl[1].toLowerCase();
    text = text.slice(dataUrl[0].length);
  }
  text = text.replace(/\s+/g, '');
  if (text.length > MAX_BASE64_LENGTH + 4) {
    throw new ApiError(413, 'Ảnh quá lớn, tối đa 700 KB');
  }
  if (!text || text.length % 4 !== 0 || !/^[A-Za-z0-9+/]+={0,2}$/.test(text)) {
    throw new ApiError(400, 'Dữ liệu ảnh không phải base64 hợp lệ');
  }
  const buffer = Buffer.from(text, 'base64');
  if (buffer.length > MAX_IMAGE_BYTES) throw new ApiError(413, 'Ảnh quá lớn, tối đa 700 KB');
  const mimeType = detectMimeType(buffer);
  if (!mimeType) throw new ApiError(400, 'Chỉ nhận ảnh JPEG hoặc PNG');
  if (declared && declared !== mimeType && !(declared === 'image/jpg' && mimeType === 'image/jpeg')) {
    throw new ApiError(400, 'Định dạng ảnh không khớp với nội dung file');
  }
  return { buffer, mimeType };
}

function mediaDocument({ image, ownerAccountId, patientId = null, kind, createdBy, now = new Date() }) {
  if (!MEDIA_KINDS.includes(kind)) throw new Error(`kind không hợp lệ: ${kind}`);
  return {
    ownerAccountId,
    patientId,
    kind,
    mimeType: image.mimeType,
    data: image.buffer.toString('base64'),
    size: image.buffer.length,
    createdAt: now,
    createdBy,
  };
}

const mediaUrl = (id) => `/api/media/${id}`;

// Ảnh đại diện của document hồ sơ (users/{uid} hoặc family_members/{id}).
// Thay ảnh: tạo media mới, gỡ ảnh cũ trong cùng transaction để không để rác.
// isAllowed(snapshot) trả false thì 404 (không có hồ sơ, người thân đã xóa).
async function replaceAvatar(profileRef, { uid, patientId, image, isAllowed }) {
  return db.runTransaction(async (transaction) => {
    const snap = await transaction.get(profileRef);
    if (!snap.exists || !isAllowed(snap)) throw new ApiError(404, 'Không tìm thấy hồ sơ');
    const oldId = snap.data().avatarMediaId;
    const oldRef = oldId ? db.collection('media').doc(oldId) : null;
    const oldSnap = oldRef ? await transaction.get(oldRef) : null;
    const mediaRef = db.collection('media').doc();
    const now = new Date();
    if (image) {
      transaction.set(mediaRef, mediaDocument({
        image, ownerAccountId: uid, patientId, kind: 'avatar', createdBy: uid, now,
      }));
    }
    if (oldSnap?.exists && oldSnap.data().ownerAccountId === uid) transaction.delete(oldRef);
    transaction.update(profileRef, { avatarMediaId: image ? mediaRef.id : null, avatarUpdatedAt: now });
    return image
      ? { avatarMediaId: mediaRef.id, avatarUrl: mediaUrl(mediaRef.id), size: image.buffer.length }
      : { avatarMediaId: null, avatarUrl: null };
  });
}

module.exports = {
  MAX_IMAGE_BYTES,
  MEDIA_KINDS,
  jsonBody,
  decodeImage,
  mediaDocument,
  mediaUrl,
  replaceAvatar,
};
