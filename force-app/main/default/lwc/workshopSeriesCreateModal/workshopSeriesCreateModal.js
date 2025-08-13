import { LightningElement, track } from 'lwc';
import { ShowToastEvent } from 'lightning/platformShowToastEvent';

export default class WorkshopSeriesCreateModal extends LightningElement {
  @track isOpen = false;
  @track isSubmitting = false;

  openModal = () => {
    this.isOpen = true;
  };

  closeModal = () => {
    if (this.isSubmitting) return; // avoid closing while saving
    this.isOpen = false;
    this.isSubmitting = false;
  };

  submitForm = () => {
    const form = this.template.querySelector('lightning-record-edit-form[data-id="form"]');
    if (form) {
      this.isSubmitting = true;
      // Let LDS validate required fields first:
      form.submit();
    }
  };

  handleLoad = () => {
    // You can prefill defaults here if needed by setting fields via querySelector on lightning-input-field
  };

  handleSuccess = (evt) => {
    this.isSubmitting = false;
    const recId = evt.detail.id;

    this.dispatchEvent(
      new ShowToastEvent({
        title: 'Workshop Series created',
        message: `Record Id: ${recId}`,
        variant: 'success'
      })
    );

    // Bubble an event in case a parent needs to refresh a list
    this.dispatchEvent(new CustomEvent('created', { detail: { recordId: recId } }));

    this.closeModal();
  };

  handleError = (evt) => {
    this.isSubmitting = false;

    // LDS already shows inline messages, but we’ll surface a toast too
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
