class CreateAppointments < ActiveRecord::Migration[8.1]
  def change
    create_table :appointments do |t|
      t.references :doctor, null: false, foreign_key: true
      t.references :patient, null: false, foreign_key: true
      t.datetime :start_time, null: false
      t.datetime :end_time, null: false
      t.string :status, null: false, default: "confirmed"
      t.string :notes

      t.timestamps
    end

    # Compound index for fast overlap queries: WHERE doctor_id = ? AND start_time < ? AND end_time > ?
    add_index :appointments, [:doctor_id, :start_time, :end_time],
              name: "idx_appointments_doctor_time"

    # Partial index only on active appointments (confirmed) for even faster overlap checks
    add_index :appointments, [:doctor_id, :start_time, :end_time],
              where: "status = 'confirmed'",
              name: "idx_appointments_doctor_time_confirmed"

    add_check_constraint :appointments, "end_time > start_time",
                         name: "chk_appointments_end_after_start"
  end
end
