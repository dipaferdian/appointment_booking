module Api
  module V1
    class AppointmentsController < ApplicationController
      before_action :authenticate_user!

      # POST /api/v1/appointments
      def create
        result = AppointmentBookingService.new(
          **appointment_params.to_h.symbolize_keys,
          patient_id: current_user.external_id
        ).call

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
      #     "start_time": "2026-06-01T10:00:00+07:00",  // ISO 8601, required
      #     "end_time":   "2026-06-01T10:30:00+07:00"   // ISO 8601, required — must be after start_time
      #   }
      #   patient_id diambil otomatis dari JWT token (current_user)
      def appointment_params
        params.permit(:doctor_id, :start_time, :end_time)
      end

      # DELETE /api/v1/appointments/:id
      def cancel
        result = AppointmentBookingCancelledService.new(
          appointment_id: params[:id].to_i,
          patient_id:     current_user.external_id
        ).call

        if result.success?
          render json: appointment_response(result.appointment), status: :ok
        else
          status = result.error.start_with?("Forbidden") ? :forbidden : :unprocessable_entity
          render json: { error: result.error }, status: status
        end
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
