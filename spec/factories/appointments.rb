FactoryBot.define do
  factory :appointment do
    association :doctor
    association :patient
    start_time { 1.day.from_now.change(hour: 10, min: 0, sec: 0) }
    end_time   { 1.day.from_now.change(hour: 10, min: 30, sec: 0) }
    status     { "confirmed" }
  end
end
