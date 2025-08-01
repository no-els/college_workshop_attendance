import { LightningElement, api, wire } from 'lwc';
import getAttendees from '@salesforce/apex/WorkshopController.getAttendees';
import deleteAttendee from '@salesforce/apex/WorkshopController.deleteAttendee';
import { refreshApex } from '@salesforce/apex';

export default class AttendeesPanel extends LightningElement {
  @api workshopId;
  attendees = [];
  wiredResult;

  @wire(getAttendees, { workshopId: '$workshopId' })
  wiredAttendees(value) {
    this.wiredResult = value;
    if (value.data) {
      this.attendees = value.data;
    } else if (value.error) {
      console.error('Error loading attendees:', value.error);
    }
  }

  handleRemove(event) {
    const attendeeId = event.target.dataset.id;
    deleteAttendee({ attendeeId })
      .then(result => {
        if (result === 'Success') {
          return refreshApex(this.wiredResult);
        } else {
          console.error('Failed to delete attendee:', result);
        }
      })
      .catch(error => {
        console.error('Error deleting attendee:', error);
      });
  }

  get attendeesCount() {
    return this.attendees.length;
  }

  @api refresh() {
    console.log("attempting refreshs")
  return refreshApex(this.wiredResult);
}
}