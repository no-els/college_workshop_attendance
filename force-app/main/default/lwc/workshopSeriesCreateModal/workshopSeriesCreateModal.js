import { LightningElement, track } from 'lwc';
import { ShowToastEvent } from 'lightning/platformShowToastEvent';

export default class WorkshopSeriesCreateModal extends LightningElement {
  @api config;
  @track isOpen = false;
  @track isSubmitting = false;
  
  get showCollegeSuccess() { return this.config?.showCollegeSuccess; }
  get showPPP() { return this.config?.showPPP; }
  
  get defaultProgram() {
    if (this.showPPP) {
      return 'Parent Partner Program';
    } else if (this.showCollegeSuccess) {
      return 'College Success';
    }
    return '';
  }

  openModal = () => {
    this.isOpen = true;
  };

  closeModal = () => {
    if (this.isSubmitting) return; // avoid closing while saving
    this.isOpen = false;
    this.isSubmitting = false;
  };

  handleKeydown = (evt) => {
    if (evt.key === 'Escape') this.closeModal();
  };

  // Compute default school year based on Aug 1 cutoff (adjust if needed)
  get defaultSchoolYear() {
    const today = new Date();
    const y = today.getUTCFullYear();
    const m = today.getUTCMonth() + 1; // 1..12
    const start = (m >= 8) ? y : y - 1; // Aug -> next summer
    const startYY = String(start).slice(-2).padStart(2, '0');
    const endYY = String(start + 1).slice(-2).padStart(2, '0');
    return `${startYY}-${endYY}`; // e.g., "24-25"
  }

  submitForm = () => {
    const form = this.template.querySelector('lightning-record-edit-form[data-id="form"]');
    if (form) {
      this.isSubmitting = true;
      form.submit(); // LDS validates required fields
    }
  };

  handleLoad = () => {
    // Prefill School Year if empty
    const sy = this.template.querySelector('lightning-input-field[data-id="school-year"]');
    if (sy && (sy.value === null || sy.value === undefined || sy.value === '')) {
      sy.value = this.defaultSchoolYear;
    }
  };

  handleSubmit = (evt) => {
    // Ensure School_Year__c is set even if user didn't touch it
    const fields = evt.detail.fields;
    if (!fields.School_Year__c) {
      fields.School_Year__c = this.defaultSchoolYear;
    }
    // Ensure Program__c is set based on user type
    if (!fields.Program__c) {
      fields.Program__c = this.defaultProgram;
    }
    // Optionally normalize Name (example: trim)
    if (fields.Name && typeof fields.Name === 'string') {
      fields.Name = fields.Name.trim();
    }
    // Let LDS proceed
  };

  handleSuccess = (evt) => {
    this.isSubmitting = false;
    const recId = evt.detail.id;

    // Try to capture the values we just submitted (for parent convenience)
    const sy = this.template.querySelector('lightning-input-field[data-id="school-year"]')?.value || this.defaultSchoolYear;
    const name = this.template.querySelector('lightning-input-field[field-name="Name"]')?.value || null;

    this.dispatchEvent(
      new ShowToastEvent({
        title: 'Workshop Series created',
        message: `Record Id: ${recId}`,
        variant: 'success'
      })
    );

    // Bubble an event so parent can refresh & auto-expand (year + series)
    this.dispatchEvent(new CustomEvent('created', {
      detail: { recordId: recId, schoolYear: sy, name }
    }));

    this.closeModal();
  };

  handleError = (evt) => {
    this.isSubmitting = false;
    const msg =
      (evt?.detail?.detail || evt?.detail?.message || 'There was a problem creating the record.');
    this.dispatchEvent(
      new ShowToastEvent({
        title: 'Error',
        message: msg,
        variant: 'error',
        mode: 'sticky'
      })
    );
  };
}