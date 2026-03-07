FactoryBot.define do
  factory :patient do
    sequence(:external_id) { |n| "P#{n}" }
    name { "Test Patient" }
    phone { "+6281234567890" }
    email { "patient@example.com" }
  end
end
