import { PolymerElement, html } from '@polymer/polymer/polymer-element.js';
import './alert-message.js';
import './booking-form.js';

/**
 * `<booking-app>` — Komponen host utama yang mengorkestrasi seluruh aplikasi.
 *
 * Polymer features yang digunakan:
 *  - Shadow DOM: Encapsulated DOM tree & scoped CSS
 *  - Declared properties: State management via Polymer property system
 *  - One-way data binding [[...]]: Host → child (alert-message, booking-form)
 *  - Declarative event listeners: on-submit-booking, on-validation-error
 *  - Property observers: Reactivity pada perubahan state
 *  - CSS Custom Properties: Theming & visual customization
 *  - Lifecycle callbacks: ready()
 */
class BookingApp extends PolymerElement {

  static get template() {
    return html`
      <style>
        :host {
          display: flex;
          align-items: center;
          justify-content: center;
          min-height: 100vh;
          background: var(--app-bg,
            linear-gradient(135deg, #667eea 0%, #764ba2 100%)
          );
          font-family: -apple-system, BlinkMacSystemFont, "Segoe UI", "Inter", sans-serif;
          padding: 20px;
          box-sizing: border-box;
        }

        .card {
          background: var(--card-bg, #ffffff);
          border-radius: 16px;
          box-shadow:
            0 4px 6px -1px rgba(0, 0, 0, 0.1),
            0 20px 50px -12px rgba(0, 0, 0, 0.25);
          padding: 40px;
          width: 100%;
          max-width: 520px;
          animation: fadeUp 0.5s ease-out;
        }

        @keyframes fadeUp {
          from { opacity: 0; transform: translateY(20px); }
          to   { opacity: 1; transform: translateY(0); }
        }

        .header {
          margin-bottom: 28px;
        }

        h1 {
          font-size: 24px;
          font-weight: 700;
          color: var(--title-color, #1a1a2e);
          margin: 0 0 8px 0;
          letter-spacing: -0.02em;
        }

        .subtitle {
          color: var(--subtitle-color, #6b7280);
          font-size: 14px;
          margin: 0;
          line-height: 1.5;
        }

        .divider {
          height: 3px;
          width: 40px;
          background: linear-gradient(90deg, #667eea, #764ba2);
          border-radius: 2px;
          margin-top: 16px;
        }

        /* Override child component theming via CSS Custom Properties */
        booking-form {
          --form-focus-color: #667eea;
          --form-focus-ring: rgba(102, 126, 234, 0.2);
          --form-button-bg: linear-gradient(135deg, #667eea, #764ba2);
          --form-button-hover-bg: linear-gradient(135deg, #5a6fd6, #6a4190);
        }

        booking-form button {
          background: linear-gradient(135deg, #667eea, #764ba2);
        }
      </style>

      <div class="card">
        <div class="header">
          <h1>Book a Consultation</h1>
          <p class="subtitle">Fill in the details below to book your appointment</p>
          <div class="divider"></div>
        </div>

        <!-- booking-form: child component
             - is-submitting: one-way binding dari host ke child
             - on-submit-booking: mendengarkan CustomEvent dari child
             - on-validation-error: mendengarkan validation error dari child
        -->
        <booking-form
          id="bookingForm"
          is-submitting="[[isSubmitting]]"
          on-submit-booking="_handleBooking"
          on-validation-error="_handleValidationError"
        ></booking-form>

        <!-- alert-message (error): ditampilkan saat ada error -->
        <alert-message
          type="error"
          message="[[errorMessage]]"
          hidden$="[[!showError]]"
        ></alert-message>

        <!-- alert-message (success): ditampilkan saat booking berhasil -->
        <alert-message
          type="success"
          details="[[successData]]"
          hidden$="[[!showSuccess]]"
        ></alert-message>
      </div>
    `;
  }

  static get is() { return 'booking-app'; }

  /**
   * Polymer property system — semua state dikelola di host element.
   * Child components menerima data via one-way binding [[...]].
   */
  static get properties() {
    return {
      /**
       * Flag untuk state loading / in-flight request.
       * Diteruskan ke booking-form via one-way binding.
       */
      isSubmitting: {
        type: Boolean,
        value: false
      },

      /**
       * Pesan error yang ditampilkan di alert-message.
       */
      errorMessage: {
        type: String,
        value: ''
      },

      /**
       * Data appointment yang berhasil dibuat (dari API response).
       */
      successData: {
        type: Object,
        value: () => null
      },

      /**
       * Flag visibility untuk error alert.
       */
      showError: {
        type: Boolean,
        value: false
      },

      /**
       * Flag visibility untuk success alert.
       */
      showSuccess: {
        type: Boolean,
        value: false
      }
    };
  }

  /**
   * Polymer lifecycle callback — dipanggil saat element siap.
   * Semua Shadow DOM sudah tersedia di sini.
   */
  ready() {
    super.ready();
    console.log('[booking-app] Polymer element ready');
  }

  /**
   * Event handler — mendengarkan 'submit-booking' dari <booking-form>.
   * Ini adalah pola Polymer: event mengalir ke atas (child → host),
   * data mengalir ke bawah (host → child) via binding.
   */
  async _handleBooking(e) {
    const formData = e.detail;

    // Reset alerts
    this._clearAlerts();

    // Set submitting state — propagates to booking-form via binding
    this.isSubmitting = true;

    try {
      const response = await fetch('/api/v1/appointments', {
        method: 'POST',
        headers: {
          'Content-Type': 'application/json',
          'Accept': 'application/json'
        },
        body: JSON.stringify(formData)
      });

      const data = await response.json();

      if (response.ok) {
        // Update success state — alert-message renders via binding
        this.successData = data;
        this.showSuccess = true;

        // Reset child form via direct method call
        this.$.bookingForm.resetForm();
      } else {
        this.errorMessage = data.error || 'Booking failed. Please try again.';
        this.showError = true;
      }
    } catch (err) {
      this.errorMessage = 'Network error. Please check your connection and try again.';
      this.showError = true;
    } finally {
      // Re-enable form — property change propagates to child
      this.isSubmitting = false;
    }
  }

  /**
   * Event handler — mendengarkan 'validation-error' dari <booking-form>.
   */
  _handleValidationError(e) {
    this._clearAlerts();
    this.errorMessage = e.detail.message;
    this.showError = true;
  }

  /**
   * Helper — membersihkan semua alert state.
   */
  _clearAlerts() {
    this.showError = false;
    this.showSuccess = false;
    this.errorMessage = '';
    this.successData = null;
  }
}

customElements.define(BookingApp.is, BookingApp);

export { BookingApp };
