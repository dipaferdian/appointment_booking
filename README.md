# Sistem Pemesanan Janji Temu (Appointment Booking)

## Tech Stack

| Komponen          | Pilihan                      | Versi     |
| ----------------- | ---------------------------- | --------- |
| Runtime           | Ruby                         | 3.3.10    |
| Framework         | Ruby on Rails (API-only)     | ~> 8.1.2  |
| Web Server        | Puma                         | >= 5.0    |
| Database Utama    | PostgreSQL                   | pg ~> 1.1 |
| Database Sekunder | MongoDB (via Mongoid)        | ~> 9.0    |
| Testing           | RSpec Rails                  | ~> 7.0    |
| Factory           | FactoryBot Rails             | latest    |
| DB Cleaner        | DatabaseCleaner ActiveRecord | latest    |

**Mengapa PostgreSQL sebagai database utama?**
Pemesanan janji temu membutuhkan konsistensi tinggi: dua pasien tidak boleh memesan slot yang sama secara bersamaan. PostgreSQL mendukung `SELECT FOR UPDATE` (pessimistic locking) yang menjamin keamanan ini di level database. MongoDB tidak memiliki row-level locking native; untuk mencapai keamanan yang sama dibutuhkan distributed lock berbasis Redis (Redlock), yang menambah kompleksitas.

---

## Langkah Setup

### Prasyarat

Pastikan sudah terinstall:

- Ruby 3.3.10 (disarankan menggunakan [rbenv](https://github.com/rbenv/rbenv) atau [asdf](https://asdf-vm.com/))
- PostgreSQL (berjalan di localhost, port 5432)
- MongoDB (berjalan di localhost, port 27017 atau sesuaikan di `.env`)
- Bundler (`gem install bundler`)

### 1. Clone & Masuk ke Direktori Proyek

```bash
git clone <repo-url>
cd appointment_booking
```

### 2. Install Ruby (jika menggunakan rbenv)

```bash
rbenv install 3.3.10
rbenv local 3.3.10
```

### 3. Install Dependencies

```bash
bundle install
```

### 4. Konfigurasi Environment

Buat file `.env` di root proyek:

```bash
# .env
MONGODB_URI=mongodb://localhost:27017/appointment_booking_development
```

Untuk koneksi MongoDB dengan autentikasi:

```bash
MONGODB_URI=mongodb://admin:admin@localhost:27018/master
```

Sesuaikan juga `config/database.yml` jika PostgreSQL menggunakan user/password tertentu.

### 5. Setup Database

```bash
# Buat database, jalankan migrasi, dan seed data contoh
bin/rails db:create db:migrate db:seed
```

Data seed yang dibuat:

- Dokter dengan `external_id: "D123"`
- Pasien dengan `external_id: "P456"`

### 6. Jalankan Server

```bash
bin/rails server
```

Server akan berjalan di `http://localhost:3000`.

---

## Menjalankan RSpec (Test Suite)

### Setup Database Test

```bash
bin/rails db:create db:migrate RAILS_ENV=test
```

### Jalankan Semua Test

```bash
bundle exec rspec
```

### Jalankan Test Tertentu

```bash
# Hanya test request/controller
bundle exec rspec spec/requests/

# Hanya test service
bundle exec rspec spec/services/

# File spesifik
bundle exec rspec spec/requests/api/v1/appointments_spec.rb
bundle exec rspec spec/services/appointment_booking_service_spec.rb

# Dengan output format dokumentasi
bundle exec rspec --format documentation

# Jalankan skenario spesifik berdasarkan teks `it "..."`
bundle exec rspec spec/requests/api/v1/appointments_spec.rb -e "still returns 201 Created (booking is not affected)"
```

### Struktur Test

```
spec/
  factories/
    appointments.rb
    doctors.rb
    patients.rb
  requests/
    api/v1/
      appointments_spec.rb    # Test endpoint POST /api/v1/appointments
  services/
    appointment_booking_service_spec.rb  # Test logika booking & concurrency
  rails_helper.rb
  spec_helper.rb
```

---

## MongoDB Dual-Write

Setiap pemesanan janji temu yang berhasil juga ditulis ke MongoDB sebagai secondary store.

### Mengapa Dual-Write?

| Kebutuhan                                  | PostgreSQL | MongoDB            |
| ------------------------------------------ | ---------- | ------------------ |
| Sumber kebenaran data                      | Ya         | Tidak              |
| Keamanan concurrency (`SELECT FOR UPDATE`) | Ya         | Tidak              |
| Query analytics / reporting                | Bisa       | Ya (lebih cepat)   |
| Audit trail / event log                    | Bisa       | Ya (lebih natural) |
| Fleksibilitas skema                        | Tidak      | Ya                 |

### Cara Kerja

```
POST /api/v1/appointments
       |
       v
  [Transaksi PostgreSQL]
  SELECT FOR UPDATE (baris dokter)
  Cek overlap
  INSERT appointment          <- sumber kebenaran
       | commit
       v
  [Penulisan MongoDB] (di luar transaksi PG)
  AppointmentDocument.create! <- salinan sekunder
       |
       v  (jika MongoDB gagal -> log error, booking tetap berhasil)
  Kembalikan 201 ke client
```

### Struktur Dokumen MongoDB

Koleksi: `appointments`

| Field        | Tipe     | Keterangan                                |
| ------------ | -------- | ----------------------------------------- |
| `_id`        | ObjectId | Primary key MongoDB                       |
| `pg_id`      | Integer  | Referensi ke `appointments.id` PostgreSQL |
| `doctor_id`  | String   | ID eksternal dokter (misal "D123")        |
| `patient_id` | String   | ID eksternal pasien (misal "P456")        |
| `start_time` | DateTime | Waktu mulai janji temu                    |
| `end_time`   | DateTime | Waktu selesai janji temu                  |
| `status`     | String   | "confirmed" / "cancelled"                 |
| `created_at` | DateTime | Dikelola otomatis oleh Mongoid            |
| `updated_at` | DateTime | Dikelola otomatis oleh Mongoid            |

Index: `(doctor_id, start_time)`, `(patient_id, start_time)`, `(pg_id, unique)`

### Resiliensi

Jika MongoDB tidak tersedia, pemesanan janji temu tetap **berhasil** — error hanya dicatat di log:

```
[MongoDB] Failed to persist appointment 42: Mongo::Error::NoServerAvailable — ...
```

Hal ini mencegah downtime MongoDB memblokir pemesanan pasien.

---

## Task A – API Endpoint

### POST /api/v1/appointments

**Request:**

```json
{
  "doctor_id": "D123",
  "patient_id": "P456",
  "start_time": "2026-02-10T10:00:00+07:00",
  "end_time": "2026-02-10T10:30:00+07:00"
}
```

**Sukses (201 Created):**

```json
{
  "id": 1,
  "doctor_id": "D123",
  "patient_id": "P456",
  "start_time": "2026-02-10T03:00:00Z",
  "end_time": "2026-02-10T03:30:00Z",
  "status": "confirmed",
  "created_at": "2026-03-07T10:00:00Z"
}
```

**Error – Slot sudah terisi (422):**

```json
{ "error": "Doctor already has an appointment during this time slot" }
```

**Error – Dokter tidak ditemukan (422):**

```json
{ "error": "Doctor 'D999' not found" }
```

### Keamanan Concurrency

Endpoint menggunakan **pessimistic locking** (`SELECT FOR UPDATE`) pada baris dokter:

```ruby
ActiveRecord::Base.transaction do
  doctor = Doctor.lock.find_by(external_id: @doctor_id)  # <- memblokir request lain untuk dokter yang sama
  # ... cek overlap di dalam lock ...
  Appointment.create!(...)
end
```

Ini menjamin bahwa meskipun 100 request datang secara bersamaan untuk Dr. D123, mereka diproses secara serial di level database — hanya satu yang berhasil per slot.

### Test dengan curl

```bash
# Booking pertama — seharusnya berhasil
curl -s -X POST http://localhost:3000/api/v1/appointments \
  -H 'Content-Type: application/json' \
  -d '{"doctor_id":"D123","patient_id":"P456","start_time":"2026-02-10T10:00:00+07:00","end_time":"2026-02-10T10:30:00+07:00"}' | jq

# Slot yang sama lagi — seharusnya mengembalikan 422
curl -s -X POST http://localhost:3000/api/v1/appointments \
  -H 'Content-Type: application/json' \
  -d '{"doctor_id":"D123","patient_id":"P456","start_time":"2026-02-10T10:00:00+07:00","end_time":"2026-02-10T10:30:00+07:00"}' | jq
```

---

## Task B – Data & Performa

### 1. Jutaan Record

Karena sistem menggunakan **dual-write** (setiap booking juga disimpan ke MongoDB), query analytics dan reporting skala besar dilayani oleh MongoDB — bukan PostgreSQL. PostgreSQL menangani transaksi booking (sumber kebenaran); MongoDB menangani workload read-heavy dan analitis.

**Indexing di MongoDB (koleksi `appointments`):**

```javascript
// Index compound untuk query per dokter berdasarkan waktu
db.appointments.createIndex({ doctor_id: 1, start_time: 1 });

// Index untuk riwayat janji temu pasien
db.appointments.createIndex({ patient_id: 1, start_time: -1 });

// Index unik yang mereferensikan primary key PostgreSQL
db.appointments.createIndex({ pg_id: 1 }, { unique: true });
```

**Paginasi:**

- Gunakan **cursor-based pagination** dengan `_id` atau `start_time` sebagai cursor — jangan `skip()`.
- `skip(100000)` di MongoDB tetap scan 100k dokumen sebelum mengembalikan hasil; cursor-based adalah O(log n) tanpa tergantung kedalaman halaman.

### 2. Apakah MongoDB Cocok?

**Untuk booking (write + concurrency): Tidak. Untuk analytics/reporting (read skala besar): Ya.**

| Kebutuhan                     | PostgreSQL                 | MongoDB                        |
| ----------------------------- | -------------------------- | ------------------------------ |
| Cegah double-booking          | `SELECT FOR UPDATE` Ya     | Butuh Redis distributed lock   |
| Query overlap waktu           | Native SQL + index Ya      | Bisa, tapi tanpa atomic lock   |
| Integritas data               | Foreign key, constraint Ya | Tidak ada FK native            |
| Transaksi ACID                | Ya                         | Hanya sejak 4.0 (multi-doc)    |
| Analytics / read skala besar  | Bisa, tapi lebih berat     | Native aggregation pipeline Ya |
| Skema fleksibel & audit trail | Kaku                       | Sangat cocok                   |

**Kesimpulan:** Itulah mengapa sistem ini menggunakan **keduanya** — PostgreSQL untuk konsistensi booking, MongoDB untuk penyimpanan persisten dan analytics jangka panjang.

---

## Task C – Frontend Flow

Buka `http://localhost:3000/booking.html` di browser.

**Fitur yang diimplementasikan:**

- Form dengan semua field yang dibutuhkan (doctor_id, patient_id, waktu mulai/selesai)
- **Pencegahan double submission**: tombol dinonaktifkan segera saat diklik dan diaktifkan kembali setelah respons API
- Validasi sisi klien sebelum mengirim (field kosong, end > start)
- Menampilkan pesan error dari respons JSON API
- Menampilkan konfirmasi booking dengan detail janji temu jika berhasil

---

## Task D – Reliabilitas & Production Readiness

### 1. Error di production, tidak bisa direproduksi secara lokal

Langkah investigasi:

1. Cek structured log (Papertrail / Datadog / CloudWatch) dengan `request_id` dari request yang gagal
2. Bandingkan environment variable dan `config/` antar environment
3. Cek perbedaan state database (data yang hilang, schema drift jika migrasi belum dijalankan)
4. Aktifkan verbose SQL logging di production sementara (hati-hati soal PII)
5. Gunakan feature flag untuk merutekan sebagian kecil traffic ke versi dengan logging debug yang lebih detail

### 2. Logging & Monitoring Kegagalan Booking

- Structured JSON logging dengan field: `request_id`, `doctor_id`, `patient_id`, `outcome` (`success`/`overlap`/`error`), `duration_ms`
- Custom metrics: appointment success rate, overlap rejection rate, per-doctor contention rate
- Alert: lonjakan error 422/500, p95 latency > 500ms, DB connection pool exhaustion
- Tools: Datadog APM, Sentry, CloudWatch

### 3. API Tiba-tiba Lambat

Langkah investigasi:

1. Cek APM traces — identifikasi layer mana yang lambat (controller, DB query, external call)
2. Cek PostgreSQL slow query log dan `pg_stat_activity` untuk lock contention
3. Cari N+1 query dengan gem `bullet` di staging
4. Cek DB connection pool — jika request menunggu koneksi, tambah pool size atau gunakan PgBouncer
5. Cek apakah dokter tertentu menjadi "hot row" yang menyebabkan lock contention

---

## Task E – Keamanan

### Otorisasi Pasien

JWT token diterbitkan saat login berisi `{ patient_id: "P456" }`. Controller memaksa:

```ruby
if current_patient.external_id != params[:patient_id]
  render json: { error: "Forbidden" }, status: :forbidden
end
```

### Manajemen Secret

- Jangan hardcode credentials. Gunakan `rails credentials:edit` untuk production secrets
- Di cloud: AWS Secrets Manager atau HashiCorp Vault
- File `.env` tidak boleh di-commit ke git (tambahkan ke `.gitignore`)

### Rate Limiting

Implementasi via gem `rack-attack`:

```ruby
Rack::Attack.throttle("appointments/patient", limit: 10, period: 60) do |req|
  req.params["patient_id"] if req.path == "/api/v1/appointments" && req.post?
end

Rack::Attack.throttle("appointments/ip", limit: 30, period: 60) do |req|
  req.ip if req.path == "/api/v1/appointments"
end
```

---

## Task F – AI-Assisted Development

### Penggunaan AI Tools

Ya. Saya menggunakan AI tools (Claude, ChatGPT, Gemini) untuk mempercepat development — membuat boilerplate, eksplorasi dokumentasi API, dan menyusun implementasi awal yang kemudian saya review dan adaptasi.

### Bagian yang Tidak Boleh Mengandalkan AI Sepenuhnya

| Area                           | Mengapa butuh penilaian manusia                                                                                                                                                                                                                                                                                                                                              |
| ------------------------------ | ---------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| **Logika concurrency**         | Strategi locking (pessimistic vs optimistic, baris mana yang dikunci, cakupan transaksi) harus diverifikasi oleh developer                                                                                                                                                                                                                                                   |
| **Keamanan & otorisasi**       | AI bisa menyarankan pola JWT, tapi logika otorisasi membutuhkan pemahaman business rules dan threat model                                                                                                                                                                                                                                                                    |
| **Debugging production**       | Investigasi spesifik konteks — membaca log, memahami state data — membutuhkan penilaian manusia                                                                                                                                                                                                                                                                              |
| **Keputusan trade-off**        | Memilih PostgreSQL vs MongoDB, cursor vs offset pagination — membutuhkan pemahaman kapabilitas operasional tim                                                                                                                                                                                                                                                               |
| **Context requirement**        | Memahami kebutuhan bisnis secara menyeluruh — siapa penggunanya, alur kerja nyata, edge case domain — tidak bisa ditebak AI dari spesifikasi teknis saja                                                                                                                                                                                                                     |
| **Konsistensi design pattern** | Membaca alur kode secara menyeluruh untuk memastikan pattern yang digunakan konsisten — proyek ini menggunakan MVC + Service Object: controller hanya menangani HTTP, business logic ada di service, model hanya untuk validasi dan query. AI cenderung meletakkan logika di tempat yang salah (misalnya langsung di controller) tanpa memperhatikan konvensi yang sudah ada |

---

## Struktur Proyek

```
app/
  controllers/api/v1/appointments_controller.rb  # Task A endpoint
  models/
    appointment.rb   # validasi + scope overlap
    doctor.rb
    patient.rb
  services/
    appointment_booking_service.rb  # logika booking inti dengan locking
config/routes.rb
db/migrate/
  20260307000001_create_doctors.rb
  20260307000002_create_patients.rb
  20260307000003_create_appointments.rb
db/seeds.rb          # data contoh D123, P456
public/booking.html  # Task C frontend
spec/
  factories/         # FactoryBot factories
  requests/          # RSpec request specs
  services/          # RSpec service specs
README.md            # file ini
```
