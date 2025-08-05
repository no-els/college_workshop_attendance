import { LightningElement, api } from 'lwc';

export default class CohortList extends LightningElement {
  @api cohorts = [];

  handleSelect(event) {
    const cohortId = event.target.dataset.id;
    this.dispatchEvent(new CustomEvent('select', { detail: cohortId }));
  }

  get hasCohorts() {
    return this.cohorts && this.cohorts.length > 0;
  }
}
