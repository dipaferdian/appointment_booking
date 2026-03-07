class Appointment < ApplicationRecord
  belongs_to :doctor
  belongs_to :patient

  STATUSES = %w[confirmed cancelled].freeze

  validates :start_time, :end_time, :status, presence: true
  validates :status, inclusion: { in: STATUSES }
  validate :end_time_after_start_time

  scope :confirmed, -> { where(status: "confirmed") }

  def self.overlapping_with(doctor_id, start_time, end_time)
    confirmed
      .where(doctor_id: doctor_id)
      .where("start_time < ? AND end_time > ?", end_time, start_time)
  end

  private

  def end_time_after_start_time
    return if start_time.blank? || end_time.blank?
    errors.add(:end_time, "must be after start time") if end_time <= start_time
  end
end
