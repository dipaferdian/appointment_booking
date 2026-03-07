# MongoAppointmentPersister is responsible for writing a confirmed appointment
# to MongoDB as a secondary store (analytics, audit trail, reporting).
#
# Single Responsibility: only handles MongoDB persistence — no booking logic.
# Failures are logged but never raised, so MongoDB downtime cannot affect bookings.
class MongoAppointmentPersister
  def call(appointment)
    AppointmentDocument.create!(
      pg_id:      appointment.id,
      doctor_id:  appointment.doctor.external_id,
      patient_id: appointment.patient.external_id,
      start_time: appointment.start_time,
      end_time:   appointment.end_time,
      status:     appointment.status
    )
  rescue => e
    Rails.logger.error(
      "[MongoDB] Failed to persist appointment #{appointment.id}: #{e.class} — #{e.message}"
    )
  end
end
