import { LightningElement, track } from 'lwc';
import createCohort from '@salesforce/apex/CohortController.createCohort';

export default class CohortCreate extends LightningElement {
  @api config;
  @track name = '';
  
  get showCollegeSuccess() { return this.config?.showCollegeSuccess; }
  get showPPP() { return this.config?.showPPP; }

  handleNameChange(e) {
    this.name = e.target.value;
  }

  handleCreate() {
console.log('Creating cohort with name:', this.name);
  if (!this.name.trim()) {
    // Optional: show error notification
    return;
  }
  createCohort({ name: this.name })
    .then(result => {
      this.dispatchEvent(new CustomEvent('created', { detail: result.Id }));
      this.name = '';
    })
    .catch(error => {
      console.error('Error creating cohort:', error);
    });
}

}