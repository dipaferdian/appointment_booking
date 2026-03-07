# Seeds: creates sample data matching the assignment's example IDs
# Doctor D123 and Patient P456 from the request example

puts "Seeding doctors..."
Doctor.find_or_create_by!(external_id: "D123") do |d|
  d.name = "Dr. Budi Santoso"
  d.specialization = "General Practitioner"
end

Doctor.find_or_create_by!(external_id: "D124") do |d|
  d.name = "Dr. Siti Rahayu"
  d.specialization = "Cardiologist"
end

puts "Seeding patients..."
Patient.find_or_create_by!(external_id: "P456") do |p|
  p.name = "Ahmad Fauzi"
  p.phone = "+6281234567890"
  p.email = "ahmad@example.com"
end

Patient.find_or_create_by!(external_id: "P457") do |p|
  p.name = "Dewi Lestari"
  p.phone = "+6287654321098"
  p.email = "dewi@example.com"
end

puts "Done! Created #{Doctor.count} doctors and #{Patient.count} patients."
