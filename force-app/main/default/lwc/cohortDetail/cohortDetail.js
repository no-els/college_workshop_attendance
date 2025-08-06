import { LightningElement, api, wire, track } from 'lwc';
import { refreshApex } from '@salesforce/apex';
import getCohortDetails from '@salesforce/apex/CohortController.getCohortDetails';
import deleteMember from '@salesforce/apex/CohortController.deleteMember';

export default class CohortDetail extends LightningElement {
  @api cohortId;

  @track cohort;
  @track members = [];
  @track error;
  wiredCohortDetail;
  @track isLoading = false;


  @wire(getCohortDetails, { cohortId: '$cohortId' })
  wiredDetails(result) {
    this.wiredCohortDetail = result;
    const { data, error } = result;

    if (data) {
      this.cohort = data.cohort;
      this.members = data.members;
      this.error = undefined;
    } else if (error) {
      this.error = error;
      this.cohort = undefined;
      this.members = [];
    }
  }

  @api
  refresh() {
    console.log("Refreshing cohort detail for in detail component:", this.cohortId);
    if (this.wiredCohortDetail) {
      return refreshApex(this.wiredCohortDetail);
    }
  }

 handleRemove(event) {
  const membershipId = event.target.dataset.id;
  this.isLoading = true;

  deleteMember({ membershipId })
    .then(() => {
      return this.refresh();
    })
    .catch(error => {
      console.error('Error removing member:', error);
    })
    .finally(() => {
      this.isLoading = false;
    });
}

}
