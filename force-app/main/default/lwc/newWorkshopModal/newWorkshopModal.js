import { LightningElement, track } from 'lwc';
import { ShowToastEvent } from 'lightning/platformShowToastEvent';

export default class NewWorkshopModal extends LightningElement {
  @track isModalOpen = false;
  isSubmitting = false;

  openModal() { this.isModalOpen = true; }

  closeModal() {
    this.isModalOpen = false;
    this.isSubmitting = false;
  }

  handleSubmit(event) {
    event.preventDefault();
    if (this.isSubmitting) return;

    this.isSubmitting = true;

    // (Optional) If you prefer the toast on submit instead of success, uncomment:
    // this.dispatchEvent(new ShowToastEvent({
    //   title: 'Submitting…',
    //   message: 'After it saves, click Refresh to update the list.',
    //   variant: 'info'
    // }));

    const fields = event.detail.fields;
    this.template.querySelector('lightning-record-edit-form').submit(fields);
  }

  handleSuccess(event) {
    this.isSubmitting = false;

    // 🔔 Tell the user to refresh the side tree
    this.dispatchEvent(new ShowToastEvent({
      title: 'Workshop created',
      message: 'Click Refresh to see the new workshop in the list.',
      variant: 'success'
    }));

    // Let parent know (if it wants to refresh automatically later)
    this.dispatchEvent(new CustomEvent('workshopcreated'));

    this.closeModal();
  }

  handleError(event) {
    this.isSubmitting = false;
    this.dispatchEvent(new ShowToastEvent({
      title: 'Could not create workshop',
      message: event?.detail?.message || 'Please try again.',
      variant: 'error'
    }));
  }
}
