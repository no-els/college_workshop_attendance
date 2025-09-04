import { LightningElement, api, track } from 'lwc';
import getCohorts from '@salesforce/apex/CohortController.getCohorts';
import getCohortMembers from '@salesforce/apex/CohortController.getCohortMembers';
import addBatchAttendance from '@salesforce/apex/CollegeSuccessWorkshop.addBatchAttendance';

export default class BatchAttendanceFromCohort extends LightningElement {
  @api workshopId;
  @api config;
  @track cohortOptions = [];
  @track selectedCohortId;
  members = [];
  
  get showCollegeSuccess() { return this.config?.showCollegeSuccess; }
  get showPPP() { return this.config?.showPPP; }

  connectedCallback() {
    getCohorts()
      .then(data => {
        this.cohortOptions = data.map(c => ({
          label: c.Name,
          value: c.Id
        }));
      })
      .catch(error => {
        console.error('Error fetching cohorts', error);
      });
  }

  get disableAddButton() {
    return !this.selectedCohortId;
  }

  handleCohortChange(e) {
    this.selectedCohortId = e.detail.value;
  }

  handleAddToWorkshop() {
    if (!this.selectedCohortId || !this.workshopId) return;

    getCohortMembers({ cohortId: this.selectedCohortId })
      .then(data => {
        const payload = data.map(m => ({
          ContactId: m.Contact__c,
          WorkshopId: this.workshopId,
          Near_Peer: m.Role__c
        }));
        // 🔍 Log each entry to verify Near_Peer (Role__c) is correct
      console.log('Payload to be sent to addBatchAttendance:');
      payload.forEach(p => {
        console.log(`ContactId: ${p.ContactId}, WorkshopId: ${p.WorkshopId}, Near_Peer: ${p.Near_Peer}`);
      });


        return addBatchAttendance({ records: payload });
      })
      .then(() => {
        console.log('Batch attendance added successfully');
        this.dispatchEvent(new CustomEvent('refreshattendees'));
      })
      .catch(error => {
        console.error('Error adding batch attendance', error);
      });
  }
}