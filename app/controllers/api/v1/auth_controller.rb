module Api
  module V1
    class AuthController < ApplicationController
      # POST /api/v1/auth/token
      # Body: { "name": "Ahmad Fauzi", "email": "ahmad@example.com" }
      def token
        patient = Patient.find_by(auth_params.to_h)
        return render json: { error: "Invalid name or email" }, status: :unauthorized unless patient

        jwt_token = JsonWebToken.encode(patient_id: patient.external_id)
        render json: { token: jwt_token }, status: :ok
      end

      private

      def auth_params
        params.permit(:name, :email)
      end
    end
  end
end
