const fs = require('fs');
const path = require('path');

// Đọc file dạng KEY=VALUE (backend/.env), không thêm thư viện. Không in giá trị ra màn hình.
function readEnvFile(name) {
  const file = path.join(__dirname, '..', name);
  if (!fs.existsSync(file)) return null;
  const values = {};
  for (const line of fs.readFileSync(file, 'utf8').replace(/^﻿/, '').split(/\r?\n/)) {
    const match = line.match(/^\s*([A-Za-z_][A-Za-z0-9_]*)\s*=(.*)$/);
    if (!match) continue;
    values[match[1]] = match[2].trim().replace(/^(['"])(.*)\1$/, '$2');
  }
  return values;
}

module.exports = { readEnvFile };
