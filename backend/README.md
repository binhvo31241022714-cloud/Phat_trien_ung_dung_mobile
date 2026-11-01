# Backend API nha khoa (Node.js + Express + Firebase)

REST API cho app Flutter nha khoa. Dá»¯ liá»‡u lÆ°u trĂªn Firestore, Ä‘Äƒng nháº­p báº±ng Firebase Authentication.

## Cháº¡y

1. Xin file `serviceAccountKey.json` tá»« nhĂ³m, Ä‘áº·t vĂ o thÆ° má»¥c `backend/`.
   File nĂ y lĂ  khĂ³a quáº£n trá»‹ Firebase, **khĂ´ng commit lĂªn git** (Ä‘Ă£ cĂ³ trong `.gitignore`).
2. CĂ i thÆ° viá»‡n vĂ  cháº¡y:

```bash
cd backend
npm install
npm run dev     # tá»± khá»Ÿi Ä‘á»™ng láº¡i khi sá»­a code
# hoáº·c: npm start
```

Server cháº¡y táº¡i `http://localhost:3000`. Má»Ÿ trĂ¬nh duyá»‡t vĂ o Ä‘á»‹a chá»‰ Ä‘Ă³ tháº¥y dĂ²ng "API nha khoa Ä‘ang cháº¡y" lĂ  Ä‘Æ°á»£c.

## Cáº¥u trĂºc

```
backend/
â”œâ”€â”€ src/
â”‚   â”œâ”€â”€ server.js              # Khá»Ÿi Ä‘á»™ng server, gáº¯n route cho tá»«ng module
â”‚   â”œâ”€â”€ config/firebase.js     # Káº¿t ná»‘i Firebase, xuáº¥t ra db (Firestore) vĂ  auth
â”‚   â”œâ”€â”€ middleware/auth.js     # Kiá»ƒm tra token Ä‘Äƒng nháº­p, gáº¯n req.user
â”‚   â””â”€â”€ routes/                # Má»—i file lĂ  má»™t nhĂ³m API
â”œâ”€â”€ api-test.http              # Request máº«u Ä‘á»ƒ test (extension REST Client)
â””â”€â”€ serviceAccountKey.json     # KhĂ³a Firebase (khĂ´ng cĂ³ trĂªn git)
```

KhĂ´ng sá»­a `server.js`, `config/firebase.js`, `middleware/auth.js` khi chÆ°a bĂ¡o nhĂ³m.

## Quy Æ°á»›c viáº¿t API

Xem `routes/familyMembers.js` lĂ m máº«u.

- API cáº§n Ä‘Äƒng nháº­p thĂ¬ thĂªm middleware `auth`. Khi Ä‘Ă³ `req.user.uid` lĂ  id cá»§a user Ä‘ang gá»i.
- Dá»¯ liá»‡u riĂªng cá»§a user lÆ°u trong `users/{uid}/...` Ä‘á»ƒ ngÆ°á»i khĂ¡c khĂ´ng Ä‘á»c Ä‘Æ°á»£c.
- Tráº£ vá» document theo dáº¡ng `{ id: doc.id, ...doc.data() }`.
- Lá»—i tráº£ vá» dáº¡ng `{ "message": "..." }` vá»›i mĂ£:

| MĂ£  | Khi nĂ o |
|-----|---------|
| 400 | Thiáº¿u dá»¯ liá»‡u hoáº·c dá»¯ liá»‡u sai |
| 401 | ChÆ°a Ä‘Äƒng nháº­p hoáº·c token háº¿t háº¡n (do `auth.js` tá»± tráº£) |
| 404 | KhĂ´ng tĂ¬m tháº¥y |
| 500 | Lá»—i server (do `server.js` tá»± báº¯t, khĂ´ng cáº§n `try/catch`) |

## Gá»­i token khi gá»i API

App Flutter láº¥y ID token tá»« Firebase Auth rá»“i gá»­i kĂ¨m header:

```
Authorization: Bearer <idToken>
```

Khi test báº±ng `api-test.http`: táº¡o `backend/.env` theo `backend/.env.example` (máº­t kháº©u há»i BĂ¬nh), báº­t server, báº¥m request á»Ÿ má»¥c **ÄÄ‚NG NHáº¬P (dĂ¹ng chung)** trÆ°á»›c Ä‘á»ƒ cĂ³ `{{token}}` (vĂ  `{{staffToken}}`), sau Ä‘Ă³ má»›i báº¥m cĂ¡c request khĂ¡c. File khĂ´ng chá»©a máº­t kháº©u, máº­t kháº©u Ä‘á»c báº±ng `{{$dotenv ...}}`.

## API Module 1 - TĂ i khoáº£n vĂ  dá»¯ liá»‡u cÆ¡ báº£n

| Method | Endpoint                  | ÄÄƒng nháº­p | MĂ´ táº£ |
|--------|---------------------------|-----------|-------|
| POST   | /api/users/sync           | CĂ³  | Táº¡o há»“ sÆ¡ náº¿u chÆ°a cĂ³. Body: `{ fullName, phone }` |
| GET    | /api/users/me             | CĂ³  | Xem há»“ sÆ¡ cá»§a mĂ¬nh |
| PATCH  | /api/users/me             | CĂ³  | Sá»­a `fullName`, `phone`, `birthday`, `address`, giá»›i tĂ­nh, thĂ´ng tin sá»©c khá»e (xem bĂªn dÆ°á»›i) vĂ  `notificationsEnabled` (true/false: táº¯t thĂ¬ khĂ´ng nháº­n nháº¯c lá»‹ch, nháº¯c tĂ¡i khĂ¡m; `GET /me` máº·c Ä‘á»‹nh true) |
| GET    | /api/family-members       | CĂ³  | Danh sĂ¡ch ngÆ°á»i thĂ¢n (áº©n ngÆ°á»i Ä‘Ă£ xĂ³a) |
| POST   | /api/family-members       | CĂ³  | ThĂªm ngÆ°á»i thĂ¢n. Báº¯t buá»™c `fullName`; nháº­n thĂªm giá»›i tĂ­nh vĂ  thĂ´ng tin sá»©c khá»e |
| PATCH  | /api/family-members/:id   | CĂ³  | Sá»­a ngÆ°á»i thĂ¢n (gá»“m cáº£ giá»›i tĂ­nh vĂ  thĂ´ng tin sá»©c khá»e) |
| DELETE | /api/family-members/:id   | CĂ³  | XĂ³a má»m ngÆ°á»i thĂ¢n (xem "XĂ³a ngÆ°á»i thĂ¢n" bĂªn dÆ°á»›i) |
| PUT    | /api/users/me/avatar      | CĂ³  | Äáº·t áº£nh Ä‘áº¡i diá»‡n. Body `{ image: base64, mimeType? }` (xem "áº¢nh" bĂªn dÆ°á»›i) |
| DELETE | /api/users/me/avatar      | CĂ³  | Gá»¡ áº£nh Ä‘áº¡i diá»‡n |
| PUT    | /api/family-members/:id/avatar | CĂ³ | áº¢nh Ä‘áº¡i diá»‡n ngÆ°á»i thĂ¢n cĂ²n hoáº¡t Ä‘á»™ng |
| DELETE | /api/family-members/:id/avatar | CĂ³ | Gá»¡ áº£nh Ä‘áº¡i diá»‡n ngÆ°á»i thĂ¢n |
| GET    | /api/media/:id            | CĂ³  | Tráº£ áº£nh nhá»‹ phĂ¢n. Chá»‰ chá»§ tĂ i khoáº£n (`ownerAccountId`) hoáº·c staff, ngÆ°á»i khĂ¡c 403 |
| GET    | /api/services             | KhĂ´ng | Danh sĂ¡ch dá»‹ch vá»¥ |
| GET    | /api/services/:id         | KhĂ´ng | Chi tiáº¿t dá»‹ch vá»¥ |
| GET    | /api/combos               | KhĂ´ng | Danh sĂ¡ch combo |
| GET    | /api/combos/:id           | KhĂ´ng | Chi tiáº¿t combo |
| GET    | /api/doctors              | KhĂ´ng | Danh sĂ¡ch bĂ¡c sÄ© |
| GET    | /api/doctors/:id          | KhĂ´ng | Chi tiáº¿t bĂ¡c sÄ© |
| GET    | /api/favorites            | CĂ³  | Danh sĂ¡ch ná»™i dung Ä‘Ă£ lÆ°u |
| POST   | /api/favorites            | CĂ³  | LÆ°u ná»™i dung. Body: `{ type, itemId }` |
| DELETE | /api/favorites/:id        | CĂ³  | Bá» lÆ°u má»™t má»¥c |

### áº¢nh (khĂ´ng dĂ¹ng Firebase Storage)

áº¢nh lÆ°u trong Firestore dáº¡ng base64 á»Ÿ `media/{id}`: `{ ownerAccountId, patientId, kind ("avatar" | "treatment_photo"), mimeType, data, size, createdAt, createdBy }`.
- Chá»‰ nháº­n JPEG hoáº·c PNG, kiá»ƒm tra theo byte Ä‘áº§u cá»§a file (khĂ´ng tin `mimeType` gá»­i lĂªn); `image` cĂ³ thá»ƒ lĂ  base64 thuáº§n hoáº·c `data:image/...;base64,...`.
- Ảnh JPEG/PNG sau giải mã tối đa **716.800 bytes (700 KiB)**; vượt giới hạn trả `413`, sai định dạng trả `400`. Giới hạn này độc lập với JSON transport và không thay đổi.
- JSON request body toàn API: **1 MiB = 1.048.576 bytes** (`utils/media.js` → `jsonBody`), gồm `PUT /api/users/me/avatar`, `PUT /api/family-members/:id/avatar`, `POST /api/treatments/:id/photos`. Đo bằng `Buffer.byteLength(JSON.stringify(body), "utf8")`, gồm cả base64 và metadata. JSON vượt giới hạn trả `413` trước route; dưới/trong giới hạn vẫn có thể trả `400` do field validation (ví dụ address tối đa 200 ký tự). Bình/Phương/Ngân đã duyệt phương án B cho demo; không dùng parser dispatcher.
- Há»“ sÆ¡ lÆ°u `avatarMediaId`; thay áº£nh thĂ¬ áº£nh cÅ© bá»‹ xĂ³a trong cĂ¹ng transaction. Staff chá»‰ xem, khĂ´ng Ä‘á»•i áº£nh Ä‘áº¡i diá»‡n.

### Dá»¯ liá»‡u `users/{uid}` vĂ  `users/{uid}/family_members/{id}`

| TrÆ°á»ng | Kiá»ƒu | CĂ³ á»Ÿ | Ghi chĂº |
|---|---|---|---|
| `fullName` | chuá»—i, 1 Ä‘áº¿n 100 kĂ½ tá»± | cáº£ hai | Báº¯t buá»™c khi thĂªm ngÆ°á»i thĂ¢n; cĂ³ gá»­i thĂ¬ khĂ´ng Ä‘Æ°á»£c rá»—ng |
| `phone` | chuá»—i 9 Ä‘áº¿n 11 chá»¯ sá»‘ | cáº£ hai | `""` náº¿u chÆ°a cĂ³. KhĂ´ng nháº­n `+84`, dáº¥u cĂ¡ch, dáº¥u cháº¥m (app tá»± chuáº©n hĂ³a trÆ°á»›c khi gá»­i) |
| `birthday` | chuá»—i `"YYYY-MM-DD"` | cáº£ hai | `""` náº¿u chÆ°a cĂ³. Pháº£i lĂ  ngĂ y cĂ³ tháº­t, khĂ´ng á»Ÿ tÆ°Æ¡ng lai (giá» Viá»‡t Nam) |
| `email` | chuá»—i | users | Email Ä‘Äƒng nháº­p Firebase, khĂ´ng sá»­a qua API |
| `address` | chuá»—i, tá»‘i Ä‘a 200 kĂ½ tá»± | users | |
| `relationship` | chuá»—i, tá»‘i Ä‘a 50 kĂ½ tá»± | family_members | VĂ­ dá»¥ "Máº¹", "Con" |
| `gender` | `"male"` \| `"female"` \| `"other"` \| `""` | cáº£ hai | `""` lĂ  chÆ°a chá»n. GiĂ¡ trá»‹ khĂ¡c tráº£ 400 |
| `allergies` | chuá»—i, tá»‘i Ä‘a 500 kĂ½ tá»± | cáº£ hai | Dá»‹ á»©ng thuá»‘c, vĂ­ dá»¥ `"Penicillin, Lidocaine"` |
| `medicalConditions` | máº£ng chuá»—i | cáº£ hai | Chá»‰ nháº­n: `diabetes` (tiá»ƒu Ä‘Æ°á»ng), `heart_disease` (bá»‡nh tim máº¡ch), `hypertension` (huyáº¿t Ă¡p cao), `bleeding_disorder` (rá»‘i loáº¡n Ä‘Ă´ng mĂ¡u), `asthma` (hen suyá»…n), `hepatitis` (viĂªm gan), `other` (khĂ¡c). GiĂ¡ trá»‹ láº¡ tráº£ 400 |
| `currentMedications` | chuá»—i, tá»‘i Ä‘a 500 kĂ½ tá»± | cáº£ hai | Thuá»‘c Ä‘ang dĂ¹ng |
| `isPregnant` | `true` \| `false` | cáº£ hai | Pháº£i lĂ  boolean, chuá»—i `"true"` tráº£ 400 |
| `healthNotes` | chuá»—i, tá»‘i Ä‘a 500 kĂ½ tá»± | cáº£ hai | Ghi chĂº khĂ¡c |
| `createdAt` | Timestamp | cáº£ hai | |

- Kiá»ƒm tra há» tĂªn, sá»‘ Ä‘iá»‡n thoáº¡i, ngĂ y sinh, má»‘i quan há»‡, Ä‘á»‹a chá»‰ dĂ¹ng chung á»Ÿ `src/utils/profile.js` (`readProfile`). Sai kiá»ƒu hoáº·c sai Ä‘á»™ dĂ i tráº£ 400 kĂ¨m cĂ¢u bĂ¡o tiáº¿ng Viá»‡t. Chuá»—i Ä‘Æ°á»£c bá» khoáº£ng tráº¯ng Ä‘áº§u cuá»‘i trÆ°á»›c khi lÆ°u.
- Kiá»ƒm tra giá»›i tĂ­nh vĂ  sá»©c khá»e dĂ¹ng chung á»Ÿ `src/utils/health.js` (`readHealth`).
- Khi GET, trÆ°á»ng cĂ²n thiáº¿u (dá»¯ liá»‡u cÅ©) Ä‘Æ°á»£c tráº£ giĂ¡ trá»‹ máº·c Ä‘á»‹nh: `""`, `[]` hoáº·c `false` (`withHealthDefaults`).
- PATCH chá»‰ Ä‘á»•i nhá»¯ng trÆ°á»ng cĂ³ gá»­i lĂªn; POST ngÆ°á»i thĂ¢n thiáº¿u trÆ°á»ng thĂ¬ lÆ°u máº·c Ä‘á»‹nh.

### XĂ³a ngÆ°á»i thĂ¢n (xĂ³a má»m)

- `DELETE /api/family-members/:id` khĂ´ng xĂ³a document mĂ  Ä‘áº·t `isArchived: true` vĂ  `archivedAt` (Timestamp), Ä‘á»ƒ há»“ sÆ¡ khĂ¡m, hĂ³a Ä‘Æ¡n, lá»‹ch háº¹n cÅ© váº«n cĂ²n.
- NgÆ°á»i thĂ¢n cĂ²n lá»‹ch háº¹n chÆ°a há»§y vĂ  chÆ°a diá»…n ra thĂ¬ tráº£ **409**, pháº£i há»§y lá»‹ch trÆ°á»›c.
- NgÆ°á»i thĂ¢n Ä‘Ă£ xĂ³a: khĂ´ng hiá»‡n trong `GET /api/family-members`, `PATCH`/`DELETE` tráº£ 404, **khĂ´ng Ä‘áº·t lá»‹ch má»›i Ä‘Æ°á»£c** (`POST /api/appointments` tráº£ 400), nhÆ°ng chá»§ tĂ i khoáº£n **váº«n xem Ä‘Æ°á»£c há»“ sÆ¡ khĂ¡m cÅ©** (`utils/records.js` chá»‰ kiá»ƒm tra document cĂ²n tá»“n táº¡i).
- Module khĂ¡c Ä‘á»c `family_members` Ä‘á»ƒ kiá»ƒm tra ngÆ°á»i khĂ¡m thĂ¬ nhá»› xĂ©t `isArchived` náº¿u lĂ  thao tĂ¡c táº¡o má»›i.

### Ghi chĂº vá» isActive

- API danh sĂ¡ch (`GET /api/services`, `/api/combos`, `/api/doctors`) áº©n má»¥c cĂ³ `isActive: false`. Má»¥c khĂ´ng cĂ³ trÆ°á»ng `isActive` coi nhÆ° Ä‘ang báº­t.
- API chi tiáº¿t (`GET /:id`) váº«n tráº£ má»¥c Ä‘Ă£ táº¯t, Ä‘á»ƒ xem láº¡i Ä‘Æ°á»£c tá»« danh sĂ¡ch yĂªu thĂ­ch hoáº·c lá»‹ch sá»­.

### Ghi chĂº vá» favorites

- KhĂ´ng lÆ°u Ä‘Æ°á»£c má»¥c cĂ³ `isActive: false` (tráº£ 400).

- `type` lĂ  má»™t trong: `service`, `combo`, `doctor`, `article`. `itemId` lĂ  id document trong collection tÆ°Æ¡ng á»©ng (`services`, `combos`, `doctors`, `articles`).
- Id cá»§a má»¥c Ä‘Ă£ lÆ°u lĂ  `${type}_${itemId}`, vĂ­ dá»¥ `service_svc_01`. LÆ°u cĂ¹ng má»™t mĂ³n nhiá»u láº§n váº«n chá»‰ cĂ³ 1 má»¥c.
- Muá»‘n bá» lÆ°u thĂ¬ gá»i `DELETE /api/favorites/service_svc_01`.

## Module khĂ¡c

Module 2 (Ä‘áº·t lá»‹ch), Module 3 (há»“ sÆ¡ nha khoa), Module 4 (ná»™i dung vĂ  thĂ´ng bĂ¡o): ngÆ°á»i phá»¥ trĂ¡ch bá»• sung báº£ng API cá»§a mĂ¬nh vĂ o Ä‘Ă¢y khi viáº¿t xong.

## Module 3 - Há»“ sÆ¡ nha khoa

| Method | Endpoint | ÄÄƒng nháº­p | MĂ´ táº£ |
|---|---|---|---|
| GET | `/api/patients/:id/visits` | CĂ³ | Lá»‹ch sá»­ khĂ¡m cá»§a báº£n thĂ¢n hoáº·c ngÆ°á»i thĂ¢n |
| GET | `/api/visits/:id` | CĂ³ | Káº¿t quáº£ khĂ¡m vĂ  cháº©n Ä‘oĂ¡n |
| GET | `/api/visits/:id/prescriptions` | CĂ³ | ÄÆ¡n thuá»‘c cá»§a láº§n khĂ¡m |
| GET | `/api/patients/:id/invoices` | CĂ³ | Danh sĂ¡ch hĂ³a Ä‘Æ¡n |
| GET | `/api/invoices/:id` | CĂ³ | Chi tiáº¿t hĂ³a Ä‘Æ¡n |
| GET | `/api/patients/:id/treatments` | CĂ³ | Danh sĂ¡ch liá»‡u trĂ¬nh |
| GET | `/api/treatments/:id` | CĂ³ | Chi tiáº¿t vĂ  tiáº¿n Ä‘á»™ liá»‡u trĂ¬nh |
| GET | `/api/treatments/:id/sessions` | CĂ³ | CĂ¡c buá»•i Ä‘iá»u trá»‹ |
| POST | `/api/treatments/:id/sessions/link-visit` | CĂ³ | Gáº¯n má»™t láº§n khĂ¡m Ä‘Ă£ hoĂ n thĂ nh vĂ o buá»•i do ngÆ°á»i dĂ¹ng chá»n. Body: `{ visitId, sessionId }`. Visit pháº£i cĂ³ `status: "completed"` (A10) |
| POST | `/api/treatments` | Staff | Táº¡o liá»‡u trĂ¬nh kĂ¨m cĂ¡c buá»•i dá»± kiáº¿n. Body `{ accountId, patientId?, doctorId?, name, diagnosis?, startAt?, endAt?, sessions: [{ scheduledAt?, notes? }] }`. Liá»‡u trĂ¬nh vĂ  buá»•i Ä‘á»u `planned` |
| PATCH | `/api/treatments/:id/sessions/:sessionId` | Staff | ÄĂ¡nh dáº¥u buá»•i Ä‘Ă£ lĂ m. Body `{ status: "completed", visitId, notes? }`; visit pháº£i hoĂ n táº¥t, cĂ¹ng bá»‡nh nhĂ¢n, chÆ°a gáº¯n buá»•i khĂ¡c. Liá»‡u trĂ¬nh tá»± chuyá»ƒn `in_progress`, xong háº¿t buá»•i thĂ¬ `completed` |
| GET | `/api/treatments/:id/photos` | CĂ³ hoáº·c Staff | áº¢nh cÅ© (`photos`, `treatment_photos`, máº£ng `photos` cá»§a treatment) vĂ  áº£nh má»›i; áº£nh má»›i cĂ³ `imageUrl` = `/api/media/:mediaId`, má»i áº£nh cĂ³ `canDelete` |
| POST | `/api/treatments/:id/photos` | CĂ³ hoáº·c Staff | Táº£i áº£nh. Body `{ phase: "before" \| "after", sessionId?, image, mimeType?, note? }`. Chá»§ tĂ i khoáº£n (báº£n thĂ¢n hoáº·c ngÆ°á»i thĂ¢n cĂ²n hoáº¡t Ä‘á»™ng) hoáº·c staff; tá»‘i Ä‘a 30 áº£nh má»—i liá»‡u trĂ¬nh (409) |
| DELETE | `/api/treatments/:id/photos/:photoId` | CĂ³ hoáº·c Staff | XĂ³a áº£nh vĂ  media; chá»‰ ngÆ°á»i táº£i lĂªn hoáº·c staff. áº¢nh cÅ© khĂ´ng cĂ³ `mediaId` tráº£ 409 |
| GET | `/api/patients/:id/follow-ups` | CĂ³ | Lá»‹ch tĂ¡i khĂ¡m |
| GET | `/api/follow-ups/:id` | CĂ³ hoáº·c Staff | Chi tiáº¿t Ä‘á» xuáº¥t tĂ¡i khĂ¡m (app dĂ¹ng khi báº¥m thĂ´ng bĂ¡o `follow_up`) |
| POST | `/api/follow-ups` | Staff | Äá» xuáº¥t tĂ¡i khĂ¡m. Body `{ accountId, patientId?, scheduledAt, reason, notes?, doctorId?, visitId?, treatmentId?, serviceId? }`. LÆ°u `status: "suggested"`, táº¡o thĂ´ng bĂ¡o `follow_up` |

### Há»“ sÆ¡ khĂ¡m táº¡o khi staff hoĂ n táº¥t lá»‹ch

`PATCH /api/appointments/:id/status` vá»›i `status: "completed"` cĂ³ thá»ƒ gá»­i thĂªm
`visit { diagnosis, result, notes }`, `prescriptions [{ medicineName, dosage, frequency, durationDays, instructions }]`,
`invoice { items?: [{ name, quantity, unitPrice }], discount?, paymentMethod?, paid? }`.
Trong cĂ¹ng transaction backend táº¡o `visits/visit_{id lá»‹ch}` (`status: "completed"`, `scheduledAt` lĂ  ngĂ y giá» lá»‹ch,
`doctorNote` láº¥y tá»« `notes`), `prescriptions/rx_{id lá»‹ch}` (chá»‰ khi cĂ³ thuá»‘c, thuá»‘c náº±m trong `items[]`),
`invoices/inv_{id lá»‹ch}` (cĂ³ cáº£ `visitId` vĂ  `appointmentId`) vĂ  1 thĂ´ng bĂ¡o `visit_result` cĂ³ `refId` lĂ  visitId.
KhĂ´ng gá»­i `invoice` thĂ¬ hĂ³a Ä‘Æ¡n tá»± láº­p tá»« combo, dá»‹ch vá»¥, voucher cá»§a lá»‹ch, máº·c Ä‘á»‹nh `unpaid`.
`paymentMethod` lĂ  `cash`, `bank_transfer`, `card` hoáº·c `e_wallet`. Gá»i hoĂ n táº¥t láº¡i tráº£ `409`, khĂ´ng táº¡o trĂ¹ng.

CĂ¡c API staff kiá»ƒm tra `patientId` lĂ  chĂ­nh chá»§ `accountId` hoáº·c ngÆ°á»i thĂ¢n cĂ²n hoáº¡t Ä‘á»™ng cá»§a tĂ i khoáº£n Ä‘Ă³.
Äá» xuáº¥t tĂ¡i khĂ¡m cÅ© cĂ³ `status: "scheduled"` Ä‘Æ°á»£c app hiá»ƒu lĂ  "ÄĂ£ Ä‘á» xuáº¥t".

`patientId` khĂ´ng Ä‘Æ°á»£c láº¥y tá»« body/query cá»§a client. Vá»›i API danh sĂ¡ch, `:id` chá»‰ Ä‘Æ°á»£c phĂ©p lĂ 
`req.user.uid` hoáº·c id document trong `users/{req.user.uid}/family_members`. Vá»›i API theo
document id, backend Ä‘á»c document trÆ°á»›c rá»“i kiá»ƒm tra `patientId`; tĂ i khoáº£n khĂ´ng cĂ³ quyá»n
nháº­n `403`.

## Module 2 - Äáº·t lá»‹ch nha khoa

| Method | Endpoint | ÄÄƒng nháº­p | MĂ´ táº£ |
|---|---|---|---|
| POST | `/api/bookings/quote` | KhĂ´ng | BĂ¡o giĂ¡ dá»‹ch vá»¥/combo, tráº£ `subtotal`, `discount`, `totalPrice`, `durationMinutes`; cĂ³ thá»ƒ gá»­i `voucherCode` |
| GET | `/api/availability?date=YYYY-MM-DD&durationMinutes=30` | KhĂ´ng | Giá» trá»‘ng theo ngĂ y; cĂ³ thá»ƒ truyá»n `doctorId`, `comboId`, `serviceIds` (cĂ¡c mĂ£ phĂ¢n tĂ¡ch báº±ng dáº¥u pháº©y) |
| POST | `/api/vouchers/validate` | KhĂ´ng | Body gá»“m `code` vĂ  `serviceIds` vĂ /hoáº·c `comboId`; giĂ¡ Ä‘Æ°á»£c tĂ­nh láº¡i trĂªn backend |
| POST | `/api/appointments` | CĂ³ | Táº¡o lá»‹ch cho báº£n thĂ¢n hoáº·c ngÆ°á»i thĂ¢n; `doctorId` cĂ³ thá»ƒ bá» trá»‘ng Ä‘á»ƒ chá»n ngáº«u nhiĂªn; body cĂ³ `patientId?`, `serviceIds?`, `comboId?`, `date`, `startTime`, `voucherCode?`, `note?`, `followUpId?`; header tĂ¹y chá»n `Idempotency-Key` |
| GET | `/api/appointments` | CĂ³ | Lá»‹ch cá»§a tĂ i khoáº£n Ä‘ang Ä‘Äƒng nháº­p, bao gá»“m lá»‹ch Ä‘áº·t cho ngÆ°á»i thĂ¢n |
| GET | `/api/appointments/:id` | CĂ³ | Chi tiáº¿t lá»‹ch; chá»‰ chá»§ tĂ i khoáº£n Ä‘Æ°á»£c xem |
| PATCH | `/api/appointments/:id/cancel` | CĂ³ | Há»§y lá»‹ch tÆ°Æ¡ng lai vĂ  giáº£i phĂ³ng cĂ¡c slot Ä‘Ă£ giá»¯ |
| GET | `/api/appointments/staff?status=booked&date=YYYY-MM-DD&sort=newest` | Staff | NhĂ¢n viĂªn xem lá»‹ch theo tráº¡ng thĂ¡i (máº·c Ä‘á»‹nh `booked`), lá»c ngĂ y tĂ¹y chá»n, má»—i lá»‹ch cĂ³ `patientName`. `sort=newest`: má»›i Ä‘áº·t/má»›i Ä‘á»•i tráº¡ng thĂ¡i lĂªn trÆ°á»›c (máº·c Ä‘á»‹nh xáº¿p theo ngĂ y giá» khĂ¡m) |
| PATCH | `/api/appointments/:id/status` | Staff | NhĂ¢n viĂªn Ä‘á»•i tráº¡ng thĂ¡i. Body `{ status: "confirmed" \| "rejected" \| "completed", reason? }`, `reason` báº¯t buá»™c khi `rejected` (tá»‘i Ä‘a 500 kĂ½ tá»±). Khi `completed` cĂ³ thá»ƒ kĂ¨m káº¿t quáº£ khĂ¡m, Ä‘Æ¡n thuá»‘c, hĂ³a Ä‘Æ¡n (xem Module 3) |

### Tráº¡ng thĂ¡i lá»‹ch háº¹n

| Tráº¡ng thĂ¡i | NghÄ©a | App hiá»ƒn thá»‹ |
|---|---|---|
| `booked` | Vá»«a Ä‘áº·t, chá» phĂ²ng khĂ¡m xĂ¡c nháº­n | Chá» xĂ¡c nháº­n |
| `confirmed` | PhĂ²ng khĂ¡m Ä‘Ă£ xĂ¡c nháº­n | ÄĂ£ xĂ¡c nháº­n |
| `rejected` | PhĂ²ng khĂ¡m tá»« chá»‘i (cĂ³ lĂ½ do trong `statusReason`) | Bá»‹ tá»« chá»‘i |
| `cancelled` | Bá»‡nh nhĂ¢n há»§y | ÄĂ£ há»§y |
| `completed` | ÄĂ£ khĂ¡m xong | ÄĂ£ hoĂ n táº¥t |

Tráº¡ng thĂ¡i khĂ¡c: app hiá»ƒn thá»‹ "KhĂ´ng xĂ¡c Ä‘á»‹nh".

Chuyá»ƒn há»£p lá»‡ (kiá»ƒm tra báº±ng `canTransition` trong `utils/booking.js`), cĂ²n láº¡i tráº£ **409**, ká»ƒ cáº£ gá»i láº¡i cĂ¹ng tráº¡ng thĂ¡i:

```
booked    â†’ confirmed | rejected | cancelled
confirmed â†’ completed | cancelled
```

- Bá»‡nh nhĂ¢n chá»‰ há»§y qua `PATCH /:id/cancel`. NhĂ¢n viĂªn dĂ¹ng `PATCH /:id/status`.
- Khi Ä‘á»•i tráº¡ng thĂ¡i lÆ°u `status`, `statusUpdatedAt` (Timestamp), `statusUpdatedBy` (uid nhĂ¢n viĂªn), `statusReason` (náº¿u cĂ³).
- `rejected` giáº£i phĂ³ng slot vĂ  tráº£ 1 lÆ°á»£t voucher giá»‘ng luá»“ng há»§y (hĂ m dĂ¹ng chung `readRelease`/`writeRelease` trong `routes/appointments.js`).
- Má»—i láº§n Ä‘á»•i tráº¡ng thĂ¡i táº¡o Ä‘Ăºng 1 thĂ´ng bĂ¡o gá»­i `accountId`, id cá»‘ Ä‘á»‹nh `${appointmentId}_${status}`, `type` lĂ  `appointment_confirmed` hoáº·c `appointment_rejected` (`refId` lĂ  id lá»‹ch); hoĂ n táº¥t táº¡o `visit_result` (`refId` lĂ  visitId).

### Äáº·t lá»‹ch tá»« Ä‘á» xuáº¥t tĂ¡i khĂ¡m (`followUpId`, A08)

- Follow-up pháº£i cĂ³ tháº­t, Ä‘Ăºng `patientId`, cĂ¹ng tĂ i khoáº£n (náº¿u cĂ³ `accountId`) vĂ  cĂ²n `suggested` hoáº·c `scheduled` (dá»¯ liá»‡u cÅ©); cĂ³ `serviceId` thĂ¬ lá»‹ch pháº£i gá»“m dá»‹ch vá»¥ Ä‘Ă³.
- CĂ¹ng transaction giá»¯ chá»—: lá»‹ch lÆ°u `followUpId`, follow-up chuyá»ƒn `booked` kĂ¨m `appointmentId`. Äáº·t láº§n ná»¯a tráº£ 409.
- Lá»‹ch bá»‹ há»§y hoáº·c tá»« chá»‘i: follow-up vá» `suggested`; lá»‹ch hoĂ n táº¥t: follow-up `completed`.
- `followUpId` náº±m trong dáº¥u vĂ¢n tay Idempotency-Key.

### Nháº¯c lá»‹ch tá»± Ä‘á»™ng (`src/jobs/reminders.js`, A03)

- Server cháº¡y job khi khá»Ÿi Ä‘á»™ng vĂ  má»—i 10 phĂºt (test khĂ´ng náº¡p `server.js` nĂªn khĂ´ng cháº¡y). Staff cháº¡y ngay báº±ng `POST /api/notifications/run-reminders`.
- `appointment_reminder`: appointment `confirmed` trong cửa sổ 24 giờ; ID `{appointmentId}_{YYYY-MM-DD}_{HH:mm}`. Giữ transaction/chống trùng AUD-05 và inbox visibility AUD-08; không thêm mốc 1 giờ/2 giờ trong thay đổi này.
- `follow_up_reminder`: **AUD-07 DEFERRED (out of demo scope), chưa triển khai**; owners Nhi/Phương/Ngân. Một test acceptance giữ callback/assertions dưới TODO, không tính PASS. Mở lại sau khi owners duyệt timing/eligibility và triển khai riêng; bỏ TODO sau khi kiểm chứng. Không nhầm với event thông báo follow-up đã có.
- Má»—i nháº¯c táº¡o trong transaction Ä‘á»c láº¡i tráº¡ng thĂ¡i, giá», `notificationsEnabled` cá»§a tĂ i khoáº£n; Ä‘Ă£ cĂ³ thĂ¬ bá» qua. Há»§y hoáº·c tá»« chá»‘i lá»‹ch xĂ³a nháº¯c Ä‘Ă£ gá»­i. `GET /api/notifications` khĂ´ng táº¡o thĂ´ng bĂ¡o.

### Ghi chĂº lá»‹ch háº¹n (`note`)

- Chuá»—i, bá» khoáº£ng tráº¯ng hai Ä‘áº§u, tá»‘i Ä‘a 500 kĂ½ tá»±, cho phĂ©p rá»—ng. KhĂ´ng gá»­i hoáº·c `null` thĂ¬ lÆ°u `""`. Sai kiá»ƒu hoáº·c quĂ¡ dĂ i tráº£ **400**.
- LÆ°u trong lá»‹ch, tráº£ vá» á»Ÿ `GET /api/appointments`, `GET /:id` vĂ  `GET /staff`.

### Chá»‘ng táº¡o trĂ¹ng (`Idempotency-Key`)

- App sinh má»™t UUID cho má»—i láº§n xĂ¡c nháº­n Ä‘áº·t lá»‹ch, gá»­i qua header `Idempotency-Key`; báº¥m láº¡i hoáº·c gá»­i láº¡i do lá»—i máº¡ng dĂ¹ng Ä‘Ăºng key Ä‘Ă³, sá»­a lá»±a chá»n thĂ¬ Ä‘á»•i key.
- Key há»£p lá»‡: 8 Ä‘áº¿n 100 kĂ½ tá»± chá»¯, sá»‘, `-`, `_`. Sai tráº£ **400**. KhĂ´ng gá»­i key thĂ¬ cháº¡y nhÆ° cÅ©.
- Backend lÆ°u `appointment_requests/{uid}_{key}` = `{ accountId, key, appointmentId, fingerprint, createdAt }` trong **cĂ¹ng transaction** táº¡o lá»‹ch. `fingerprint` lĂ  SHA-256 cá»§a ngÆ°á»i khĂ¡m, ngĂ y, giá», bĂ¡c sÄ©, dá»‹ch vá»¥, combo, voucher, ghi chĂº.
- Gá»­i láº¡i cĂ¹ng key, cĂ¹ng ná»™i dung: tráº£ **201** Ä‘Ăºng lá»‹ch Ä‘Ă£ táº¡o (cĂ¹ng `id`), khĂ´ng táº¡o thĂªm lá»‹ch, thĂ´ng bĂ¡o, lÆ°á»£t voucher. Kiá»ƒm tra cáº£ trÆ°á»›c transaction (vĂ¬ slot Ä‘ang bá»‹ chĂ­nh lá»‹ch Ä‘Ă³ giá»¯) vĂ  Ä‘áº§u transaction (hai láº§n gá»­i Ä‘á»“ng thá»i thĂ¬ láº§n thua Ä‘Æ°á»£c cháº¡y láº¡i vĂ  nháº­n lá»‹ch cá»§a láº§n tháº¯ng).
- CĂ¹ng key, khĂ¡c ná»™i dung: **409** "MĂ£ yĂªu cáº§u Ä‘Ă£ dĂ¹ng cho má»™t lá»‹ch khĂ¡c".
- Táº¡o lá»‹ch tháº¥t báº¡i thĂ¬ khĂ´ng ghi `appointment_requests`; gá»­i láº¡i cĂ¹ng key sau khi sá»­a Ä‘Æ°á»£c lá»—i váº«n táº¡o Ä‘Æ°á»£c.
- App: gá»­i bá»‹ máº¥t káº¿t ná»‘i/háº¿t thá»i gian chá» thĂ¬ khĂ³a má»i lá»±a chá»n, chá»‰ cho "Thá»­ láº¡i" (key cÅ©) hoáº·c "Chá»n láº¡i" (táº£i láº¡i lá»‹ch; Ä‘Ă£ cĂ³ lá»‹ch cĂ¹ng ngÆ°á»i khĂ¡m, ngĂ y, giá» thĂ¬ bĂ¡o thĂ nh cĂ´ng vĂ  má»Ÿ lá»‹ch Ä‘Ă³; chÆ°a cĂ³ thĂ¬ má»Ÿ khĂ³a, láº§n gá»­i sau dĂ¹ng key má»›i).

### Quyá»n nhĂ¢n viĂªn (staff)

- DĂ¹ng Firebase custom claims `{ role: "staff" }`. Middleware `src/middleware/requireStaff.js` (Ä‘áº·t sau `auth`) tráº£ **403** náº¿u khĂ´ng pháº£i staff.
- GĂ¡n: `node scripts/set-staff.js staff@nhakhoa.com`. Gá»¡: thĂªm `--remove`. NgÆ°á»i Ä‘Æ°á»£c gĂ¡n/gá»¡ pháº£i **Ä‘Äƒng nháº­p láº¡i** Ä‘á»ƒ token cĂ³ quyá»n má»›i.

### Lá»‹ch lĂ m viá»‡c bĂ¡c sÄ©

- `node scripts/seed-schedules.js` cháº¡y thá»­ (in ra), thĂªm `--apply` Ä‘á»ƒ ghi. Táº¡o ca cho má»i bĂ¡c sÄ© Ä‘ang hoáº¡t Ä‘á»™ng, tá»« hĂ´m nay tá»›i 30 ngĂ y sau, thá»© 2 Ä‘áº¿n thá»© 7: ca sĂ¡ng 08:00 Ä‘áº¿n 12:00, ca chiá»u 13:30 Ä‘áº¿n 17:30, slot 30 phĂºt. Id `${doctorId}_${YYYY-MM-DD}_am` / `_pm`.
- KhĂ´ng xĂ³a, khĂ´ng ghi Ä‘Ă¨: id Ä‘Ă£ cĂ³ thĂ¬ bá» qua; bĂ¡c sÄ© Ä‘Ă£ cĂ³ ca báº¥t ká»³ trong ngĂ y thĂ¬ bá» qua ngĂ y Ä‘Ă³. **Cháº¡y láº¡i trÆ°á»›c hĂ´m demo** Ä‘á»ƒ cĂ³ lá»‹ch cho cĂ¡c ngĂ y má»›i.
- `loadSchedulingData(date)` chá»‰ Ä‘á»c ca cĂ³ `startAt` trong ngĂ y Ä‘ang há»i (giá» Viá»‡t Nam) vĂ  lá»‹ch háº¹n, slot cĂ³ `date` báº±ng ngĂ y Ä‘Ă³. Ca lá»—i Ä‘á»‹nh dáº¡ng bá»‹ bá» qua kĂ¨m `console.warn`, khĂ´ng lĂ m há»ng viá»‡c Ä‘áº·t lá»‹ch.

### Quy Æ°á»›c Module 2

- BĂ¡o giĂ¡ luĂ´n Ä‘á»c `price`, `durationMinutes` tá»« `services`/`combos`; khĂ´ng tin giĂ¡ do client gá»­i. Khi chá»n combo kĂ¨m cĂ¡c dá»‹ch vá»¥ Ä‘Ă£ náº±m trong combo, cĂ¡c dá»‹ch vá»¥ Ä‘Ă³ khĂ´ng bá»‹ tĂ­nh phĂ­/thá»i lÆ°á»£ng láº§n hai. `totalPrice` lĂ  sá»‘ tiá»n sau giáº£m giĂ¡, `subtotal` lĂ  trÆ°á»›c giáº£m giĂ¡, `discount` lĂ  sá»‘ tiá»n Ä‘Æ°á»£c giáº£m.
- `doctor_schedules` dĂ¹ng `doctorId`, `startAt`, `endAt`, `slotMinutes`, `isAvailable`. `startAt`/`endAt` lĂ  thá»i Ä‘iá»ƒm Firestore; há»‡ thá»‘ng diá»…n giáº£i theo mĂºi giá» Viá»‡t Nam (`Asia/Ho_Chi_Minh`). Má»—i document lĂ  má»™t ca/ngĂ y cá»¥ thá»ƒ, khĂ´ng tá»± láº·p theo tuáº§n.
- Lá»‹ch háº¹n lÆ°u `accountId`, `patientId`, `doctorId`, `serviceIds`, `comboId`, `date` (`YYYY-MM-DD`), `startTime`/`endTime` (`HH:mm`), `totalPrice`, `discount`, `voucherCode`, `status: "booked"`, `createdAt` (Timestamp). Lá»‹ch cho ngÆ°á»i thĂ¢n pháº£i tham chiáº¿u má»™t document trong `users/{accountId}/family_members` chÆ°a bá»‹ xĂ³a (`isArchived`); bÆ°á»›c kiá»ƒm tra ngÆ°á»i khĂ¡m cháº¡y trÆ°á»›c má»i bÆ°á»›c kiá»ƒm tra dá»‹ch vá»¥, lá»‹ch lĂ m viá»‡c, khung giá».
- Test tá»± Ä‘á»™ng: `node --test test/module2/*.test.cjs` (Firestore giáº£ dĂ¹ng chung á»Ÿ `test/module2/support/fakeFirestore.cjs`, cĂ³ mĂ´ phá»ng xung Ä‘á»™t transaction).
- Viá»‡c táº¡o lá»‹ch dĂ¹ng Firestore Transaction vĂ  collection ná»™i bá»™ `appointment_slots` Ä‘á»ƒ giá»¯ tá»«ng Ä‘oáº¡n thá»i gian 15 phĂºt; lá»‹ch Ä‘Ă£ há»§y sáº½ giáº£i phĂ³ng slot. Khi dĂ¹ng voucher, `usedCount` Ä‘Æ°á»£c tÄƒng trong cĂ¹ng transaction vá»›i Ä‘áº·t lá»‹ch.
- Notification má»›i cĂ³ cĂ¡c trÆ°á»ng `userId`, `title`, `body`, `type`, `refId`, `isRead`, `createdAt` theo quy Æ°á»›c á»Ÿ README gá»‘c.
- Request test náº±m á»Ÿ má»¥c **MODULE 2** trong `backend/api-test.http`; token vĂ  id lá»‹ch láº¥y tá»± Ä‘á»™ng tá»« response, chá»‰ cáº§n chá»‰nh ngĂ y (`@a01Date`, `@a11Date`) vĂ o ngĂ y Ä‘Ă£ cĂ³ lá»‹ch lĂ m viá»‡c.

### Script dá»n dá»¯ liá»‡u vĂ  seed demo (Giai Ä‘oáº¡n 5)

Máº·c Ä‘á»‹nh cĂ¡c script chá»‰ preview, khĂ´ng khá»Ÿi táº¡o Firebase vĂ  khĂ´ng ghi dá»¯ liá»‡u:

```bash
node scripts/cleanup-test-data.js <email> [--keep-profile]
node scripts/seed-demo.js <email>
node scripts/seed-schedules.js
```

Chá»‰ thĂªm `--apply` sau khi xĂ¡c nháº­n Ä‘Ăºng project vĂ  tĂ i khoáº£n. Cleanup chá»‰ xá»­ lĂ½
dá»¯ liá»‡u nghiá»‡p vá»¥ cá»§a email, khĂ´ng xĂ³a `services`, `combos`, `doctors`, `articles`,
`vouchers` hoáº·c `doctor_schedules`; `--keep-profile` giá»¯ há»“ sÆ¡ vĂ  ngÆ°á»i thĂ¢n.
Seed demo khĂ´ng xĂ³a dá»¯ liá»‡u cĂ³ sáºµn vĂ  dĂ¹ng `writeCompletion` Ä‘á»ƒ táº¡o hai há»“ sÆ¡ khĂ¡m.

Cháº¡y test backend báº±ng `npm test`. Frontend dĂ¹ng `flutter test`,
`flutter test --dart-define=DATA_SOURCE=api` vĂ  `flutter analyze`.

