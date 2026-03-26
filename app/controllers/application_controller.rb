class ApplicationController < ActionController::API
  private

  def authenticate_user!
    token = extract_token
    return render_unauthorized("Missing token") unless token

    payload = JsonWebToken.decode(token)
    @current_user = Patient.find_by(external_id: payload[:patient_id])
    render_unauthorized("Patient not found") unless @current_user
  rescue JWT::ExpiredSignature
    render_unauthorized("Token has expired")
  rescue JWT::DecodeError => e
    render_unauthorized(e.message)
  end

  def current_user
    @current_user
  end

  def extract_token
    header = request.headers["Authorization"]
    header&.split(" ")&.last
  end

  def render_unauthorized(message)
    render json: { error: message }, status: :unauthorized
  end
end
