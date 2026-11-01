const express = require('express');
const { db } = require('../config/firebase');
const { ApiError } = require('./booking');
const jsonBody = express.json({ limit: '1mb' });
function decodeImage(body = {}) {
  if (typeof body.image !== 'string' || !body.image.trim()) throw new ApiError(400, 'Thiếu ảnh');
  const match = body.image.match(/^data:([^;]+);base64,(.*)$/s);
  const encoded = (match ? match[2] : body.image).replace(/\s/g, '');
  if (!/^[A-Za-z0-9+/]*={0,2}$/.test(encoded) || encoded.length % 4 === 1) {
    throw new ApiError(400, 'Ảnh base64 không hợp lệ');
  }
  let buffer;
  try { buffer = Buffer.from(encoded, 'base64'); } catch (_) { throw new ApiError(400, 'Ảnh base64 không hợp lệ'); }
  if (!buffer.length || buffer.length > 700 * 1024) throw new ApiError(buffer.length > 700 * 1024 ? 413 : 400, 'Ảnh phải có kích thước từ 1 byte đến 700 KB');
  const mimeType = buffer[0] === 0xff && buffer[1] === 0xd8 && buffer[2] === 0xff ? 'image/jpeg' :
    buffer[0] === 0x89 && buffer[1] === 0x50 && buffer[2] === 0x4e && buffer[3] === 0x47 ? 'image/png' : null;
  if (!mimeType) throw new ApiError(400, 'Chỉ hỗ trợ ảnh JPEG hoặc PNG');
  return { buffer, mimeType, size: buffer.length, data: buffer.toString('base64') };
}
function mediaDocument({ ownerAccountId, patientId, kind, image, createdBy, note, phase, sessionId }) {
  return { ownerAccountId, patientId, kind, mimeType: image.mimeType, data: image.data, size: image.size, ...(note ? { note } : {}), ...(phase ? { phase } : {}), ...(sessionId ? { sessionId } : {}), createdAt: new Date(), createdBy };
}
const mediaUrl = (id) => `/api/media/${id}`;
async function replaceAvatar(profileRef, { uid, patientId, image, isAllowed }) {
  const result = await db.runTransaction(async transaction => {
    const profile = await transaction.get(profileRef);
    if (!profile.exists) throw new ApiError(404, 'Không tìm thấy hồ sơ');
    if (!isAllowed(profile)) throw new ApiError(404, 'Không tìm thấy hồ sơ');
    const oldId = profile.data().avatarMediaId;
    if (oldId) transaction.delete(db.collection('media').doc(oldId));
    if (!image) { transaction.update(profileRef, { avatarMediaId: null }); return { message: 'Đã gỡ ảnh' }; }
    const ref = db.collection('media').doc();
    transaction.set(ref, mediaDocument({ ownerAccountId: uid, patientId, kind: 'avatar', image, createdBy: uid }));
    transaction.update(profileRef, { avatarMediaId: ref.id });
    return { avatarMediaId: ref.id };
  });
  return result;
}
module.exports = { jsonBody, decodeImage, mediaDocument, mediaUrl, replaceAvatar };
