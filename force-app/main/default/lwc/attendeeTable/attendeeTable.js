import { LightningElement, api, track } from 'lwc';
import updateAttendeeStatus from '@salesforce/apex/CollegeSuccessWorkshop.updateAttendeeStatus';
import { refreshApex } from '@salesforce/apex';

export default class AttendeeTable extends LightningElement {
  @api contacts;
  @track isLoading = false; // 🌀 NEW: loading state

  handleClick(event) {
    const contactId = event.target.dataset.id;
    this.dispatchEvent(new CustomEvent('select', { detail: contactId }));
  }

  @api refresh() {
    console.log("attempting refreshs");
    this.isLoading = true; // show spinner
    return refreshApex(this.wiredAttendeesResult)
      .finally(() => {
        this.isLoading = false; // hide spinner
      });
  }

  handleStatusChange(event) {
    const attendeeId = event.target.dataset.id;
    const newStatus = event.detail.value;

    this.isLoading = true;
    updateAttendeeStatus({ attendeeId, newStatus })
      .then(() => {
        return refreshApex(this.wiredResult);
      })
      .catch(error => {
        console.error('Error updating status:', error);
      })
      .finally(() => {
        this.isLoading = false;
      });
  }

  get statusOptions() {
    return [
      { label: 'N/A', value: 'N/A' },
      { label: 'Mentor', value: 'Mentor' },
      { label: 'Mentee', value: 'Mentee' }
    ];
  }
}
