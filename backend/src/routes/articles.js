const router = require('express').Router();
const { db } = require('../config/firebase');

// Invalid/missing publication dates sort last without hiding published articles.
function publishedMillis(value) {
  try {
    const date = value && typeof value.toDate === 'function' ? value.toDate() :
      value instanceof Date ? value :
      typeof value === 'string' || typeof value === 'number' ? new Date(value) : null;
    const millis = date ? date.getTime() : NaN;
    return Number.isFinite(millis) ? millis : -Infinity;
  } catch { return -Infinity; }
}

router.get('/', async (req, res) => {
  const category = req.query.category;
  if (category !== undefined && typeof category !== 'string') {
    return res.status(400).json({ message: 'category phải là chuỗi' });
  }
  let query = db.collection('articles').where('isPublished', '==', true);
  if (category && category.trim()) query = query.where('category', '==', category.trim());
  const snap = await query.get();
  const articles = snap.docs.map(doc => ({ ...doc.data(), id: doc.id }))
    .filter(article => article.isPublished === true);
  articles.sort((a, b) => publishedMillis(b.publishedAt) - publishedMillis(a.publishedAt) || a.id.localeCompare(b.id));
  res.json(articles);
});

router.get('/:id', async (req, res) => {
  const doc = await db.collection('articles').doc(req.params.id).get();
  if (!doc.exists || doc.data().isPublished !== true) {
    return res.status(404).json({ message: 'Không tìm thấy bài viết' });
  }
  res.json({ ...doc.data(), id: doc.id });
});

module.exports = router;
