# This file is auto-generated from the current state of the database. Instead
# of editing this file, please use the migrations feature of Active Record to
# incrementally modify your database, and then regenerate this schema definition.
#
# This file is the source Rails uses to define your schema when running `bin/rails
# db:schema:load`. When creating a new database, `bin/rails db:schema:load` tends to
# be faster and is potentially less error prone than running all of your
# migrations from scratch. Old migrations may fail to apply correctly if those
# migrations use external dependencies or application code.
#
# It's strongly recommended that you check this file into your version control system.

ActiveRecord::Schema[8.1].define(version: 2026_03_07_000003) do
  # These are extensions that must be enabled in order to support this database
  enable_extension "pg_catalog.plpgsql"

  create_table "appointments", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.bigint "doctor_id", null: false
    t.datetime "end_time", null: false
    t.string "notes"
    t.bigint "patient_id", null: false
    t.datetime "start_time", null: false
    t.string "status", default: "confirmed", null: false
    t.datetime "updated_at", null: false
    t.index ["doctor_id", "start_time", "end_time"], name: "idx_appointments_doctor_time"
    t.index ["doctor_id", "start_time", "end_time"], name: "idx_appointments_doctor_time_confirmed", where: "((status)::text = 'confirmed'::text)"
    t.index ["doctor_id"], name: "index_appointments_on_doctor_id"
    t.index ["patient_id"], name: "index_appointments_on_patient_id"
    t.check_constraint "end_time > start_time", name: "chk_appointments_end_after_start"
  end

  create_table "doctors", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.string "external_id", null: false
    t.string "name", null: false
    t.string "specialization"
    t.datetime "updated_at", null: false
    t.index ["external_id"], name: "index_doctors_on_external_id", unique: true
  end

  create_table "patients", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.string "email"
    t.string "external_id", null: false
    t.string "name", null: false
    t.string "phone"
    t.datetime "updated_at", null: false
    t.index ["external_id"], name: "index_patients_on_external_id", unique: true
  end

  add_foreign_key "appointments", "doctors"
  add_foreign_key "appointments", "patients"
end
