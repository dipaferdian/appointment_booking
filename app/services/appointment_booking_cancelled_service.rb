# AppointmentBookingCancelledService handles appointment cancellation.
#
# Single Responsibility: validates and cancels an existing appointment in PostgreSQL,
# then syncs the updated status to MongoDB as secondary store.
# Dependency Inversion: secondary_persister is injected via constructor —
# callers can substitute any object that responds to #call(appointment).
class AppointmentBookingCancelledService
  Result = Struct.new(:success, :appointment, :error, keyword_init: true) do
    def success?
      success
    end
  end

  def initialize(appointment_id: nil, patient_id: nil, secondary_persister: MongoAppointmentPersister.new)
    @appointment_id      = appointment_id
    @patient_id          = patient_id
    @secondary_persister = secondary_persister
  end

  def call
    return Result.new(success: false, error: "appointment_id is required") unless @appointment_id

    result = cancel_in_postgres
    return result unless result.success?

    # Secondary write — OUTSIDE the PG transaction.
    # Failure is handled inside the persister (logged, not raised).
    @secondary_persister.call(result.appointment)

    result
  end

  private

  def cancel_in_postgres
    ActiveRecord::Base.transaction do
      appointment = Appointment.lock.find_by(id: @appointment_id)
      return Result.new(success: false, error: "Appointment not found") unless appointment

      if @patient_id && appointment.patient.external_id != @patient_id
        return Result.new(success: false, error: "Forbidden: you can only cancel your own appointments")
      end

      if appointment.status == "cancelled"
        return Result.new(success: false, error: "Appointment is already cancelled")
      end

      appointment.update!(status: "cancelled")
      Result.new(success: true, appointment: appointment)
    end
  rescue ActiveRecord::RecordInvalid => e
    Result.new(success: false, error: e.record.errors.full_messages.join(", "))
  rescue ActiveRecord::StatementInvalid => e
    Result.new(success: false, error: "Database error: #{e.message}")
  end
end
