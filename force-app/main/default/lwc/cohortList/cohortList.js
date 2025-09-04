import { LightningElement, api } from 'lwc';

export default class CohortList extends LightningElement {
  @api cohorts = [];
  @api config;
  
  get showCollegeSuccess() { return this.config?.showCollegeSuccess; }
  get showPPP() { return this.config?.showPPP; }

  handleSelect(event) {
    const cohortId = event.target.dataset.id;
    this.dispatchEvent(new CustomEvent('select', { detail: cohortId }));
  }

  handleDelete(event) {
    const cohortId = event.target.dataset.id;
    this.dispatchEvent(new CustomEvent('delete', { detail: cohortId }));
  }

  get hasCohorts() {
    return this.cohorts && this.cohorts.length > 0;
  }
}