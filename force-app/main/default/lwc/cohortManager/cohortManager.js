import { LightningElement, track, wire } from 'lwc';
import getCohorts from '@salesforce/apex/CohortController.getCohorts';
import { refreshApex } from '@salesforce/apex';
import deleteCohort from '@salesforce/apex/CohortController.deleteCohort';

export default class CohortManager extends LightningElement {
  @track cohorts = [];
  @track selectedCohortId;
  wiredCohortsResult;

  @wire(getCohorts)
  wiredCohorts(result) {
    this.wiredCohortsResult = result;

    if (result && result.data) {
      this.cohorts = [...result.data];
    } else if (result && result.error) {
      console.error('Error fetching cohorts:', result.error);
    }
  }

  handleCohortSelect(event) {
    this.selectedCohortId = event.detail;
  }

  handleDeleteCohort(event) {
  const cohortId = event.detail;
  deleteCohort({ cohortId })
    .then(() => {
      return refreshApex(this.wiredCohortsResult);
    })
    .catch(error => {
      console.error('Error deleting cohort', error);
    });
}

  handleCohortCreated() {
    this.refreshCohorts();
  }

  handleRefreshMembers() {
  console.log("Refreshing cohort members for:", this.selectedCohortId);

  const detailComponent = this.template.querySelector('c-cohort-detail');
  if (detailComponent && typeof detailComponent.refresh === 'function') {
    detailComponent.refresh().then(() => {
      console.log("Cohort detail refreshed");
    }).catch(err => {
      console.error("Error refreshing cohort detail:", err);
    });
  } else {
    console.warn("Cohort detail component not found or refresh method missing.");
  }
}

  refreshCohorts() {
    if (!this.wiredCohortsResult) return;
    this.template.querySelector('c-cohort-detail')?.refresh();
    refreshApex(this.wiredCohortsResult)
      .then((result) => {
        if (result && result.data) {
          this.cohorts = [...result];
          console.log("Cohorts refreshed");
        } else {
          console.warn("No cohort data returned during refresh");
        }
      })
      .catch((error) => {
        console.error("Error refreshing cohorts:", error);
      });
  }
  
}