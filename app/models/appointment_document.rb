# AppointmentDocument is a Mongoid model that mirrors confirmed appointments
# from PostgreSQL into MongoDB. It serves as a secondary store for:
#   - Analytics and reporting queries
#   - Audit trail / event log
#   - Read-heavy workloads that don't need PG consistency
#
# PostgreSQL remains the source of truth for booking correctness.
# This document is written AFTER the PG transaction commits — any failure
# here is logged but does not affect the booking result.
class AppointmentDocument
  include Mongoid::Document
  include Mongoid::Timestamps

  store_in collection: "appointment_booking"

  field :pg_id,       type: Integer  # Reference back to PostgreSQL appointments.id
  field :doctor_id,   type: String
  field :patient_id,  type: String
  field :start_time,  type: Time
  field :end_time,    type: Time
  field :status,      type: String

  index({ doctor_id: 1, start_time: 1 })
  index({ pg_id: 1 }, { unique: true })
  index({ patient_id: 1, start_time: -1 })
end
