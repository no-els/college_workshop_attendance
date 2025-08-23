import { LightningElement, api, wire, track } from 'lwc';
import getAttendees from '@salesforce/apex/CollegeSuccessWorkshop.getAttendees';
import deleteAttendee from '@salesforce/apex/WorkshopController.deleteAttendee';
import updateAttendeeStatus from '@salesforce/apex/CollegeSuccessWorkshop.updateAttendeeStatus';
import updateAttendeeAttendance from '@salesforce/apex/CollegeSuccessWorkshop.updateAttendeeAttendance';
import { refreshApex } from '@salesforce/apex';

// NEW: date apex
import setDate from '@salesforce/apex/AttendeeDateController.setDate';
import clearDate from '@salesforce/apex/AttendeeDateController.clearDate';

export default class AttendeesPanel extends LightningElement {
  @api workshopId;
  @api bottomOffset = 280;
  

  // From parent banner
  @api showNearPeer; // boolean
  @api showDate; // boolean

  attendees = [];
  wiredResult;

  
  // map of attendeeId -> true while saving date
  @track isSavingMap = {};

  get containerStyle() {
    return `max-height: calc(100vh - ${this.bottomOffset}px);`;
  }

  @wire(getAttendees, { workshopId: '$workshopId' })
wiredAttendees(value) {
  this.wiredResult = value;
  if (value.data) {
    this.attendees = value.data.map(record => ({
      ...record,
      Near_Peer_Status__c: record.Near_Peer_Status__c || '',
      Attendee_Status__c: record.Attendee_Status__c || '',
      Date__c: record.Date__c || null,
      _saving: false, // <-- add this
    }));
  } else if (value.error) {
    console.error('Error loading attendees:', value.error);
  }
  console.log("from attendeespanel showdate", this.showDate);
  
}


  handleRemove(event) {
    const attendeeId = event.target.dataset.id;
    deleteAttendee({ attendeeId })
      .then(result => {
        if (result === 'Success') {
          return refreshApex(this.wiredResult);
        } else {
          // eslint-disable-next-line no-console
          console.error('Failed to delete attendee:', result);
        }
      })
      .catch(error => {
        // eslint-disable-next-line no-console
        console.error('Error deleting attendee:', error);
      });
  }

  handleStatusChange(event) {
    const attendeeId = event.target.dataset.id;
    const newStatus = event.detail.value;
    updateAttendeeStatus({ attendeeId, newStatus })
      .then(() => refreshApex(this.wiredResult))
      .catch(error => console.error('Error updating status:', error));
  }

  handleAttendanceChange(event) {
    const attendeeId = event.target.dataset.id;
    const attendanceStatus = event.detail.value;
    updateAttendeeAttendance({ attendeeId, attendanceStatus })
      .then(() => refreshApex(this.wiredResult))
      .catch(error => console.error('Error updating attendance:', error));
  }

  // NEW: date update
  async handleDateChange(event) {
  const attendeeId = event.target.dataset.id;
  const val = event.target.value; // '' or 'YYYY-MM-DD'

  // turn on spinner for this row
  this.attendees = this.attendees.map(a =>
    a.Id === attendeeId ? { ...a, _saving: true } : a
  );

  try {
    if (val) {
      await setDate({ attendeeId, newDate: val });
    } else {
      await clearDate({ attendeeId });
    }

    // optimistic update of the date value
    this.attendees = this.attendees.map(a =>
      a.Id === attendeeId ? { ...a, Date__c: val || null } : a
    );

    // optional: requery to stay authoritative
    await refreshApex(this.wiredResult);
  } catch (e) {
    console.error('Error updating Date__c:', e);
    // (optional) toast here
  } finally {
    // turn off spinner for this row
    this.attendees = this.attendees.map(a =>
      a.Id === attendeeId ? { ...a, _saving: false } : a
    );
  }
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
      { label: 'Unexcused Absence', value: 'Unexcused Absence' }
    ];
  }

  @api refresh() {
    return refreshApex(this.wiredResult);
  }

  handleDateUpdated() {
    if (this.wiredResult) refreshApex(this.wiredResult);
  }
}