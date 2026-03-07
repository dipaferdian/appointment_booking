# AppointmentBookingService orchestrates the appointment booking flow.
#
# Single Responsibility: validates input and coordinates the PG booking transaction.
# MongoDB persistence is delegated to an injected secondary_persister (default: MongoAppointmentPersister).
#
# Dependency Inversion: depends on the persister via constructor injection — callers
# can substitute any object that responds to #call(appointment), e.g. a test double.
#
# Open/Closed: adding a new secondary store requires no changes here — pass a different persister.
class AppointmentBookingService
  Result = Struct.new(:success, :appointment, :error, keyword_init: true) do
    def success?
      success
    end
  end

  def initialize(doctor_id: nil, patient_id: nil, start_time: nil, end_time: nil,
                 secondary_persister: MongoAppointmentPersister.new)
    @doctor_id           = doctor_id
    @patient_id          = patient_id
    @start_time          = parse_time(start_time)
    @end_time            = parse_time(end_time)
    @secondary_persister = secondary_persister
  end

  def call
    return Result.new(success: false, error: "Invalid start_time format") unless @start_time
    return Result.new(success: false, error: "Invalid end_time format") unless @end_time
    return Result.new(success: false, error: "end_time must be after start_time") if @end_time <= @start_time

    result = book_in_postgres
    return result unless result.success?

    # Secondary write — OUTSIDE the PG transaction.
    # Failure is handled inside the persister (logged, not raised).
    @secondary_persister.call(result.appointment)

    result
  end

  private

  def book_in_postgres
    ActiveRecord::Base.transaction do
      # SELECT FOR UPDATE: serializes concurrent requests for the same doctor at DB level
      doctor = Doctor.lock.find_by(external_id: @doctor_id)
      return Result.new(success: false, error: "Doctor '#{@doctor_id}' not found") unless doctor

      patient = Patient.find_by(external_id: @patient_id)
      return Result.new(success: false, error: "Patient '#{@patient_id}' not found") unless patient

      # Overlap check runs inside the lock — safe from race conditions
      if Appointment.overlapping_with(doctor.id, @start_time, @end_time).exists?
        return Result.new(success: false, error: "Doctor already has an appointment during this time slot")
      end

      appointment = Appointment.create!(
        doctor:     doctor,
        patient:    patient,
        start_time: @start_time,
        end_time:   @end_time,
        status:     "confirmed"
      )

      Result.new(success: true, appointment: appointment)
    end
  rescue ActiveRecord::RecordInvalid => e
    Result.new(success: false, error: e.record.errors.full_messages.join(", "))
  rescue ActiveRecord::StatementInvalid => e
    Result.new(success: false, error: "Database error: #{e.message}")
  end

  def parse_time(value)
    return nil if value.blank?
    Time.parse(value.to_s)
  rescue ArgumentError, TypeError
    nil
  end
end
