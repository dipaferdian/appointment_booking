class Patient < ApplicationRecord
  has_many :appointments

  validates :external_id, presence: true, uniqueness: true
  validates :name, presence: true
  validates :email, presence: true, uniqueness: true, format: { with: URI::MailTo::EMAIL_REGEXP }
end
