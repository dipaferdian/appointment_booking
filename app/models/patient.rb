class Patient < ApplicationRecord
  has_many :appointments

  validates :external_id, presence: true, uniqueness: true
  validates :name, presence: true
end
