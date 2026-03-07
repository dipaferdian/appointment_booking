require "rails_helper"

RSpec.describe AppointmentBookingService do
  let(:doctor)  { create(:doctor) }
  let(:patient) { create(:patient) }

  # Base slot: tomorrow 10:00–10:30 (use 1.day.from_now to get a proper TimeWithZone)
  let(:base_start) { 1.day.from_now.change(hour: 10, min: 0,  sec: 0).iso8601 }
  let(:base_end)   { 1.day.from_now.change(hour: 10, min: 30, sec: 0).iso8601 }

  def call_service(doctor_id: doctor.external_id, patient_id: patient.external_id,
                   start_time: base_start, end_time: base_end)
    described_class.new(
      doctor_id:  doctor_id,
      patient_id: patient_id,
      start_time: start_time,
      end_time:   end_time
    ).call
  end

  def future_time(hour, min)
    1.day.from_now.change(hour: hour, min: min, sec: 0)
  end

  # Stub MongoDB persistence — unit tests focus on booking logic, not secondary store
  before { allow(AppointmentDocument).to receive(:create!) }

  describe "#call" do
    context "success cases" do
      it "creates an appointment and returns a success result" do
        result = call_service

        expect(result).to be_success
        expect(result.appointment).to be_a(Appointment)
        expect(result.appointment).to be_persisted
        expect(result.appointment.doctor).to eq(doctor)
        expect(result.appointment.patient).to eq(patient)
        expect(result.appointment.status).to eq("confirmed")
      end

      it "succeeds when the new slot starts exactly when an existing slot ends (adjacent)" do
        create(:appointment, doctor: doctor, patient: patient,
               start_time: future_time(9, 30),
               end_time:   future_time(10, 0))

        result = call_service  # starts at 10:00 which equals existing end_time
        expect(result).to be_success
      end

      it "succeeds when a cancelled appointment occupies the same slot" do
        create(:appointment, doctor: doctor, patient: patient,
               start_time: future_time(10, 0),
               end_time:   future_time(10, 30),
               status: "cancelled")

        result = call_service
        expect(result).to be_success
      end
    end

    context "validation failures" do
      it "returns an error when start_time format is invalid" do
        result = call_service(start_time: "not-a-date")

        expect(result).not_to be_success
        expect(result.error).to include("Invalid start_time format")
      end

      it "returns an error when end_time format is invalid" do
        result = call_service(end_time: "not-a-date")

        expect(result).not_to be_success
        expect(result.error).to include("Invalid end_time format")
      end

      it "returns an error when end_time equals start_time" do
        result = call_service(end_time: base_start)

        expect(result).not_to be_success
        expect(result.error).to include("end_time must be after start_time")
      end

      it "returns an error when end_time is before start_time" do
        result = call_service(
          start_time: future_time(10, 30).iso8601,
          end_time:   future_time(10, 0).iso8601
        )

        expect(result).not_to be_success
        expect(result.error).to include("end_time must be after start_time")
      end
    end

    context "not found errors" do
      it "returns an error when doctor_id does not exist" do
        result = call_service(doctor_id: "D999")

        expect(result).not_to be_success
        expect(result.error).to include("D999")
        expect(result.error).to include("not found")
      end

      it "returns an error when patient_id does not exist" do
        result = call_service(patient_id: "P999")

        expect(result).not_to be_success
        expect(result.error).to include("P999")
        expect(result.error).to include("not found")
      end
    end

    context "overlap detection" do
      before do
        # Existing appointment: 10:00–10:30
        create(:appointment, doctor: doctor, patient: patient,
               start_time: future_time(10, 0),
               end_time:   future_time(10, 30))
      end

      it "rejects an appointment with the exact same time slot" do
        result = call_service  # 10:00–10:30

        expect(result).not_to be_success
        expect(result.error).to include("Doctor already has an appointment")
      end

      it "rejects a new appointment that overlaps from the left (starts before, ends during)" do
        result = call_service(
          start_time: future_time(9, 45).iso8601,
          end_time:   future_time(10, 15).iso8601
        )

        expect(result).not_to be_success
        expect(result.error).to include("Doctor already has an appointment")
      end

      it "rejects a new appointment that overlaps from the right (starts during, ends after)" do
        result = call_service(
          start_time: future_time(10, 15).iso8601,
          end_time:   future_time(10, 45).iso8601
        )

        expect(result).not_to be_success
        expect(result.error).to include("Doctor already has an appointment")
      end

      it "rejects a new appointment that fully contains the existing slot" do
        result = call_service(
          start_time: future_time(9, 45).iso8601,
          end_time:   future_time(10, 45).iso8601
        )

        expect(result).not_to be_success
        expect(result.error).to include("Doctor already has an appointment")
      end

      it "rejects a new appointment fully contained within the existing slot" do
        result = call_service(
          start_time: future_time(10, 5).iso8601,
          end_time:   future_time(10, 20).iso8601
        )

        expect(result).not_to be_success
        expect(result.error).to include("Doctor already has an appointment")
      end
    end
  end
end
