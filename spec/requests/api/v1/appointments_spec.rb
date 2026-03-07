require "rails_helper"

RSpec.describe "POST /api/v1/appointments", type: :request do
  let(:doctor)  { create(:doctor) }
  let(:patient) { create(:patient) }

  def future_time(hour, min)
    1.day.from_now.change(hour: hour, min: min, sec: 0)
  end

  let(:valid_params) do
    {
      doctor_id:  doctor.external_id,
      patient_id: patient.external_id,
      start_time: future_time(10, 0).iso8601,
      end_time:   future_time(10, 30).iso8601
    }
  end

  def post_appointment(params)
    post "/api/v1/appointments",
         params:  params.to_json,
         headers: { "Content-Type" => "application/json", "Accept" => "application/json" }
  end

  context "with valid params" do
    it "returns 201 Created" do
      post_appointment(valid_params)
      expect(response).to have_http_status(:created)
    end

    it "returns the appointment JSON with all required fields" do
      post_appointment(valid_params)
      body = JSON.parse(response.body)

      expect(body).to include(
        "id"         => be_a(Integer),
        "doctor_id"  => doctor.external_id,
        "patient_id" => patient.external_id,
        "status"     => "confirmed"
      )
      expect(body["start_time"]).to be_present
      expect(body["end_time"]).to be_present
      expect(body["created_at"]).to be_present
    end

    it "persists the appointment in PostgreSQL" do
      expect { post_appointment(valid_params) }.to change(Appointment, :count).by(1)
    end

    it "also persists the appointment in MongoDB" do
      expect { post_appointment(valid_params) }.to change(AppointmentDocument, :count).by(1)
    end

    it "stores the correct fields in MongoDB" do
      post_appointment(valid_params)
      doc = AppointmentDocument.last

      pg_appointment = Appointment.last
      expect(doc.pg_id).to eq(pg_appointment.id)
      expect(doc.doctor_id).to eq(doctor.external_id)
      expect(doc.patient_id).to eq(patient.external_id)
      expect(doc.status).to eq("confirmed")
      expect(doc.start_time).to be_within(1.second).of(pg_appointment.start_time)
      expect(doc.end_time).to be_within(1.second).of(pg_appointment.end_time)
    end
  end

  context "when MongoDB is unavailable" do
    before do
      allow(AppointmentDocument).to receive(:create!).and_raise(Mongo::Error, "No server available")
    end

    it "still returns 201 Created (booking is not affected)" do
      post_appointment(valid_params)
      expect(response).to have_http_status(:created)
    end

    it "still persists the appointment in PostgreSQL" do
      expect { post_appointment(valid_params) }.to change(Appointment, :count).by(1)
    end
  end

  context "with an overlapping time slot" do
    before do
      create(:appointment,
             doctor:     doctor,
             patient:    patient,
             start_time: future_time(10, 0),
             end_time:   future_time(10, 30))
    end

    it "returns 422 Unprocessable Entity" do
      post_appointment(valid_params)
      expect(response).to have_http_status(:unprocessable_entity)
    end

    it "returns an error message about the overlap" do
      post_appointment(valid_params)
      body = JSON.parse(response.body)
      expect(body["error"]).to include("Doctor already has an appointment")
    end

    it "does not create a new appointment in PostgreSQL" do
      expect { post_appointment(valid_params) }.not_to change(Appointment, :count)
    end

    it "does not create a document in MongoDB" do
      expect { post_appointment(valid_params) }.not_to change(AppointmentDocument, :count)
    end
  end

  context "when doctor does not exist" do
    it "returns 422 Unprocessable Entity" do
      post_appointment(valid_params.merge(doctor_id: "D999"))
      expect(response).to have_http_status(:unprocessable_entity)
    end

    it "returns an error message identifying the missing doctor" do
      post_appointment(valid_params.merge(doctor_id: "D999"))
      body = JSON.parse(response.body)
      expect(body["error"]).to include("D999").and include("not found")
    end
  end

  context "when patient does not exist" do
    it "returns 422 Unprocessable Entity" do
      post_appointment(valid_params.merge(patient_id: "P999"))
      expect(response).to have_http_status(:unprocessable_entity)
    end

    it "returns an error message identifying the missing patient" do
      post_appointment(valid_params.merge(patient_id: "P999"))
      body = JSON.parse(response.body)
      expect(body["error"]).to include("P999").and include("not found")
    end
  end

  context "when end_time is before start_time" do
    it "returns 422 Unprocessable Entity" do
      post_appointment(valid_params.merge(
        start_time: future_time(11, 0).iso8601,
        end_time:   future_time(10, 0).iso8601
      ))
      expect(response).to have_http_status(:unprocessable_entity)
    end

    it "returns an error about end_time ordering" do
      post_appointment(valid_params.merge(
        start_time: future_time(11, 0).iso8601,
        end_time:   future_time(10, 0).iso8601
      ))
      body = JSON.parse(response.body)
      expect(body["error"]).to include("end_time must be after start_time")
    end
  end

  context "when required params are missing" do
    it "returns 422 when doctor_id is missing" do
      post_appointment(valid_params.except(:doctor_id))
      expect(response).to have_http_status(:unprocessable_entity)
    end

    it "returns 422 when start_time is an invalid format" do
      post_appointment(valid_params.merge(start_time: "not-a-date"))
      expect(response).to have_http_status(:unprocessable_entity)
    end
  end
end
