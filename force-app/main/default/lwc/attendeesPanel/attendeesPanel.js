import { LightningElement, api, wire } from 'lwc';
import getAttendees from '@salesforce/apex/CollegeSuccessWorkshop.getAttendees';
import deleteAttendee from '@salesforce/apex/WorkshopController.deleteAttendee';
import { refreshApex } from '@salesforce/apex';
import updateAttendeeStatus from '@salesforce/apex/CollegeSuccessWorkshop.updateAttendeeStatus';
import updateAttendeeAttendance from '@salesforce/apex/CollegeSuccessWorkshop.updateAttendeeAttendance';


export default class AttendeesPanel extends LightningElement {
  @api workshopId;
  attendees = [];
  wiredResult;
  @api bottomOffset = 280;
  get containerStyle() {
    // Uses viewport height; adjust offset as needed or expose it from parent
    return `max-height: calc(100vh - ${this.bottomOffset}px);`;
  }

  @wire(getAttendees, { workshopId: '$workshopId' })
  wiredAttendees(value) {
    this.wiredResult = value;
    if (value.data) {
    this.attendees = value.data.map(record => ({
    ...record,
    Near_Peer_Status__c: record.Near_Peer_Status__c || '',
    Attendee_Status__c: record.Attendee_Status__c || ''
  }));
} else if (value.error) {
      console.error('Error loading attendees:', value.error);
    }
    console.log('Fetched attendees:', JSON.stringify(value.data, null, 2));

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

  handleStatusChange(event) {
  const attendeeId = event.target.dataset.id;
  const newStatus = event.detail.value;
  console.log("Updating status for attendee:", attendeeId, "to", newStatus);

  updateAttendeeStatus({ attendeeId, newStatus })
    .then(() => {
      return refreshApex(this.wiredResult);
    })
    .catch(error => {
      console.error('Error updating status:', error);
    });
}

  get attendeesCount() {
    return this.attendees.length;
  }

  get statusOptions() {
  return [
    { label: 'N/A', value: 'N/A' },
    { label: 'Mentor', value: 'Mentor' },
    { label: 'Mentee', value: 'Mentee' }
  ];
}

get AttendanceOptions() {
  return [
    { label: 'Present', value: 'Present' },
    { label: 'Excused Absence', value: 'Excused Absence' },
    { label: 'Unexcused Absence', value: 'Unexcused Absence' },
  ];
}

handleAttendanceChange(event) {
  const attendeeId = event.target.dataset.id; 
  const attendanceStatus = event.detail.value;
  console.log("Updating status for attendee:", attendeeId, "to", attendanceStatus);
  console.log("Updating attendance for attendee:", event.target.dataset.id);

  updateAttendeeAttendance({ attendeeId, attendanceStatus})
    .then(() => {
      return refreshApex(this.wiredResult);
    })
    .catch(error => {
      console.error('Error updating status:', error);
    });
}



  @api refresh() {
    console.log("attempting refreshs")
  return refreshApex(this.wiredResult);
}
}