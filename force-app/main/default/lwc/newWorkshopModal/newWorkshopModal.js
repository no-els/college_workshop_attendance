import { LightningElement, track } from 'lwc';

export default class NewWorkshopModal extends LightningElement {
    @track isModalOpen = false;
    isSubmitting = false; // Flag to prevent duplicate submissions

    openModal() {
        this.isModalOpen = true;
    }

    closeModal() {
        this.isModalOpen = false;
        this.isSubmitting = false; // Reset flag when closing the modal
    }

    // Prevent duplicate submission and submit the form
    handleSubmit(event) {
        event.preventDefault(); // Stop the default submit action
        if (this.isSubmitting) {
            return; // If already submitting, do nothing
        }
        this.isSubmitting = true; // Set flag to prevent further clicks
        const fields = event.detail.fields;
        // Optionally modify fields here if needed
        this.template.querySelector('lightning-record-edit-form').submit(fields);
    }

    // Handle a successful creation
    handleSuccess(event) {
        // Reset the submission flag
        this.isSubmitting = false;
        // Dispatch an event so a parent component can refresh its workshop list if needed
        this.dispatchEvent(new CustomEvent('workshopcreated'));
        this.closeModal();
    }
    
}
