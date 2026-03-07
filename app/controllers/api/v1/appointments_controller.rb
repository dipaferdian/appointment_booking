module Api
  module V1
    class AppointmentsController < ApplicationController
      # POST /api/v1/appointments
      def create
        result = AppointmentBookingService.new(**appointment_params.to_h.symbolize_keys).call

        if result.success?
          render json: appointment_response(result.appointment), status: :created
        else
          render json: { error: result.error }, status: :unprocessable_entity
        end
      end

      private

      # Strong parameters — documents the expected JSON request body:
      #
      #   {
      #     "doctor_id":  "D123",                        // String, required — doctor's external ID
      #     "patient_id": "P456",                        // String, required — patient's external ID
      #     "start_time": "2026-06-01T10:00:00+07:00",  // ISO 8601, required
      #     "end_time":   "2026-06-01T10:30:00+07:00"   // ISO 8601, required — must be after start_time
      #   }
      def appointment_params
        params.permit(:doctor_id, :patient_id, :start_time, :end_time)
      end

      def appointment_response(appointment)
        {
          id:         appointment.id,
          doctor_id:  appointment.doctor.external_id,
          patient_id: appointment.patient.external_id,
          start_time: appointment.start_time.iso8601,
          end_time:   appointment.end_time.iso8601,
          status:     appointment.status,
          created_at: appointment.created_at.iso8601
        }
      end
    end
  end
end
