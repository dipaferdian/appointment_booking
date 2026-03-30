import { PolymerElement, html } from '@polymer/polymer/polymer-element.js';

/**
 * `<alert-message>` — Komponen untuk menampilkan pesan sukses atau error.
 *
 * Polymer features:
 *  - Shadow DOM encapsulation (scoped styles)
 *  - Declared properties with types & defaults
 *  - One-way data binding [[...]]
 *  - Computed binding (computed property)
 *  - CSS Custom Properties for theming
 *  - Conditional rendering via hidden attribute
 */
class AlertMessage extends PolymerElement {

  static get template() {
    return html`
      <style>
        :host {
          display: block;
          margin-top: 18px;
        }

        :host([hidden]) {
          display: none !important;
        }

        .alert {
          padding: 14px 18px;
          border-radius: 10px;
          font-size: 14px;
          font-family: var(--alert-font-family, -apple-system, BlinkMacSystemFont, "Segoe UI", sans-serif);
          line-height: 1.5;
          animation: slideIn 0.3s ease-out;
        }

        @keyframes slideIn {
          from { opacity: 0; transform: translateY(-8px); }
          to   { opacity: 1; transform: translateY(0); }
        }

        .alert.error {
          background: var(--alert-error-bg, #fef2f2);
          border: 1px solid var(--alert-error-border, #fca5a5);
          color: var(--alert-error-color, #b91c1c);
        }

        .alert.success {
          background: var(--alert-success-bg, #f0fdf4);
          border: 1px solid var(--alert-success-border, #86efac);
          color: var(--alert-success-color, #166534);
        }

        .detail-row {
          display: flex;
          justify-content: space-between;
          font-size: 13px;
          margin-top: 6px;
        }

        .detail-row .label {
          color: var(--alert-detail-label-color, #6b7280);
        }

        .detail-row .value {
          font-weight: 600;
          color: var(--alert-detail-value-color, #111827);
        }

        strong {
          display: block;
          margin-bottom: 4px;
        }
      </style>

      <div class$="alert [[type]]">
        <template is="dom-if" if="[[_isSuccess(type)]]">
          <strong>Appointment Confirmed!</strong>
          <div class="detail-row">
            <span class="label">Appointment ID</span>
            <span class="value">#[[details.id]]</span>
          </div>
          <div class="detail-row">
            <span class="label">Doctor</span>
            <span class="value">[[details.doctor_id]]</span>
          </div>
          <div class="detail-row">
            <span class="label">Patient</span>
            <span class="value">[[details.patient_id]]</span>
          </div>
          <div class="detail-row">
            <span class="label">Start</span>
            <span class="value">[[_formatDate(details.start_time)]]</span>
          </div>
          <div class="detail-row">
            <span class="label">End</span>
            <span class="value">[[_formatDate(details.end_time)]]</span>
          </div>
        </template>

        <template is="dom-if" if="[[_isError(type)]]">
          [[message]]
        </template>
      </div>
    `;
  }

  static get is() { return 'alert-message'; }

  /**
   * Declared properties — Polymer's property system.
   * Each property gets type checking, default values, and
   * automatic attribute ↔ property reflection.
   */
  static get properties() {
    return {
      /**
       * Type of alert: 'error' or 'success'
       */
      type: {
        type: String,
        value: 'error',
        reflectToAttribute: true
      },

      /**
       * Error message text (only used when type='error')
       */
      message: {
        type: String,
        value: ''
      },

      /**
       * Appointment details object (only used when type='success')
       * Shape: { id, doctor_id, patient_id, start_time, end_time }
       */
      details: {
        type: Object,
        value: () => ({})
      }
    };
  }

  /**
   * Computed binding helper — determines if type is 'success'
   */
  _isSuccess(type) {
    return type === 'success';
  }

  /**
   * Computed binding helper — determines if type is 'error'
   */
  _isError(type) {
    return type === 'error';
  }

  /**
   * Computed binding — formats ISO date string to locale string
   */
  _formatDate(isoString) {
    if (!isoString) return '';
    return new Date(isoString).toLocaleString();
  }
}

customElements.define(AlertMessage.is, AlertMessage);

export { AlertMessage };
