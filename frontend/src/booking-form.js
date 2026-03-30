import { PolymerElement, html } from '@polymer/polymer/polymer-element.js';

/**
 * `<booking-form>` — Form komponen untuk input data appointment.
 *
 * Polymer features:
 *  - Shadow DOM encapsulation
 *  - Two-way data binding {{...}} untuk form inputs
 *  - Declared properties with observers
 *  - Computed properties (dynamic button text)
 *  - Declarative event handling (on-click, on-submit)
 *  - CustomEvent dispatch untuk parent communication
 *  - CSS Custom Properties for theming
 */
class BookingForm extends PolymerElement {

  static get template() {
    return html`
      <style>
        :host {
          display: block;
          font-family: var(--form-font-family, -apple-system, BlinkMacSystemFont, "Segoe UI", sans-serif);
        }

        .field {
          margin-bottom: 18px;
        }

        label {
          display: block;
          font-size: 13px;
          font-weight: 600;
          color: var(--form-label-color, #374151);
          margin-bottom: 6px;
          letter-spacing: 0.01em;
        }

        input {
          width: 100%;
          padding: 10px 14px;
          border: 1.5px solid var(--form-input-border, #d1d5db);
          border-radius: 8px;
          font-size: 14px;
          outline: none;
          transition: border-color 0.2s, box-shadow 0.2s;
          box-sizing: border-box;
          background: var(--form-input-bg, #fff);
          color: var(--form-input-color, #1a1a2e);
        }

        input:focus {
          border-color: var(--form-focus-color, #3b82f6);
          box-shadow: 0 0 0 3px var(--form-focus-ring, rgba(59, 130, 246, 0.15));
        }

        input::placeholder {
          color: var(--form-placeholder-color, #9ca3af);
        }

        button {
          width: 100%;
          padding: 12px;
          background: var(--form-button-bg, #3b82f6);
          color: var(--form-button-color, #fff);
          border: none;
          border-radius: 8px;
          font-size: 15px;
          font-weight: 600;
          cursor: pointer;
          transition: background 0.2s, opacity 0.2s, transform 0.1s;
          margin-top: 6px;
          letter-spacing: 0.01em;
        }

        button:hover:not([disabled]) {
          background: var(--form-button-hover-bg, #2563eb);
          transform: translateY(-1px);
        }

        button:active:not([disabled]) {
          transform: translateY(0);
        }

        button[disabled] {
          opacity: 0.6;
          cursor: not-allowed;
        }

        .row {
          display: flex;
          gap: 12px;
        }

        .row .field {
          flex: 1;
        }
      </style>

      <form id="form" on-submit="_handleSubmit" novalidate>
        <div class="row">
          <div class="field">
            <label for="doctor_id">Doctor ID</label>
            <input
              type="text"
              id="doctor_id"
              placeholder="e.g. D123"
              value="{{doctorId::input}}"
              required
            />
          </div>
          <div class="field">
            <label for="patient_id">Patient ID</label>
            <input
              type="text"
              id="patient_id"
              placeholder="e.g. P456"
              value="{{patientId::input}}"
              required
            />
          </div>
        </div>

        <div class="field">
          <label for="start_time">Start Time</label>
          <input
            type="datetime-local"
            id="start_time"
            value="{{startTime::input}}"
            required
          />
        </div>

        <div class="field">
          <label for="end_time">End Time</label>
          <input
            type="datetime-local"
            id="end_time"
            value="{{endTime::input}}"
            required
          />
        </div>

        <!-- Button text changes via computed property -->
        <button type="submit" disabled$="[[isSubmitting]]">
          [[_computeButtonText(isSubmitting)]]
        </button>
      </form>
    `;
  }

  static get is() { return 'booking-form'; }

  /**
   * Declared properties using Polymer's property system.
   * - Two-way bound properties for form inputs
   * - isSubmitting: controlled by parent via one-way binding
   */
  static get properties() {
    return {
      doctorId: {
        type: String,
        value: ''
      },

      patientId: {
        type: String,
        value: ''
      },

      startTime: {
        type: String,
        value: ''
      },

      endTime: {
        type: String,
        value: ''
      },

      /**
       * Controls the disabled state of the submit button.
       * Set by the parent host element.
       */
      isSubmitting: {
        type: Boolean,
        value: false,
        reflectToAttribute: true
      }
    };
  }

  /**
   * Computed binding — returns dynamic button text based on state.
   * Polymer calls this automatically whenever isSubmitting changes.
   */
  _computeButtonText(isSubmitting) {
    return isSubmitting ? 'Booking…' : 'Book Appointment';
  }

  /**
   * Declarative event handler (on-submit).
   * Validates form data and fires a CustomEvent to the parent.
   *
   * Polymer pattern: child components fire events upward,
   * parent components listen and handle business logic.
   */
  _handleSubmit(e) {
    e.preventDefault();

    // Guard: prevent double submission
    if (this.isSubmitting) return;

    const doctorId  = this.doctorId.trim();
    const patientId = this.patientId.trim();
    const startTime = this.startTime;
    const endTime   = this.endTime;

    // Client-side validation
    if (!doctorId || !patientId || !startTime || !endTime) {
      this._fireValidationError('Please fill in all fields.');
      return;
    }

    if (new Date(endTime) <= new Date(startTime)) {
      this._fireValidationError('End time must be after start time.');
      return;
    }

    // Fire custom event to parent with form data
    this.dispatchEvent(new CustomEvent('submit-booking', {
      bubbles: true,
      composed: true,  // crosses Shadow DOM boundary
      detail: {
        doctor_id:  doctorId,
        patient_id: patientId,
        start_time: new Date(startTime).toISOString(),
        end_time:   new Date(endTime).toISOString()
      }
    }));
  }

  /**
   * Fires a validation error event to the parent.
   */
  _fireValidationError(message) {
    this.dispatchEvent(new CustomEvent('validation-error', {
      bubbles: true,
      composed: true,
      detail: { message }
    }));
  }

  /**
   * Public method — resets the form fields.
   * Called by the parent after successful booking.
   */
  resetForm() {
    this.doctorId  = '';
    this.patientId = '';
    this.startTime = '';
    this.endTime   = '';
  }
}

customElements.define(BookingForm.is, BookingForm);

export { BookingForm };
