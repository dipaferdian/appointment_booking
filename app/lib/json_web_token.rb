module JsonWebToken
  SECRET_KEY = Rails.application.secret_key_base

  def self.encode(payload, exp = 24.hours.from_now)
    payload[:exp] = exp.to_i
    JWT.encode(payload, SECRET_KEY, "HS256")
  end

  def self.decode(token)
    decoded = JWT.decode(token, SECRET_KEY, true, algorithms: ["HS256"])
    HashWithIndifferentAccess.new(decoded.first)
  rescue JWT::ExpiredSignature
    raise JWT::ExpiredSignature, "Token has expired"
  rescue JWT::DecodeError => e
    raise JWT::DecodeError, "Invalid token: #{e.message}"
  end
end
