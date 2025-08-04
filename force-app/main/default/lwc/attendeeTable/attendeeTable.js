import { LightningElement, api } from 'lwc';
import updateAttendeeStatus from '@salesforce/apex/CollegeSuccessWorkshop.updateAttendeeStatus';
import { refreshApex } from '@salesforce/apex';
export default class AttendeeTable extends LightningElement {

  @api contacts;

  handleClick(event) {
    const contactId = event.target.dataset.id;
    this.dispatchEvent(new CustomEvent('select', { detail: contactId }));
  }
  @api refresh() {
      console.log("attempting refreshs")
    return refreshApex(this.wiredAttendeesResult);
  }

  handleStatusChange(event) {
    const attendeeId = event.target.dataset.id;
    const newStatus = event.detail.value;
  
    updateAttendeeStatus({ attendeeId, newStatus })
      .then(() => {
        return refreshApex(this.wiredResult);
      })
      .catch(error => {
        console.error('Error updating status:', error);
      });
  }

    get statusOptions() {
  return [
    { label: 'N/A', value: 'N/A' },
    { label: 'Mentor', value: 'mentor' },
    { label: 'Mentee', value: 'mentee' }
  ];
}
  
}