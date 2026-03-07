FactoryBot.define do
  factory :doctor do
    sequence(:external_id) { |n| "D#{n}" }
    name { "Dr. Test Doctor" }
    specialization { "General Practitioner" }
  end
end
