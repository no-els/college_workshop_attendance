import { LightningElement, api, track } from 'lwc';
import { loadScript } from 'lightning/platformResourceLoader';
import FUSE_RESOURCE from '@salesforce/resourceUrl/fuse';
import { initFuse, search } from 'c/contactSearchService';
import getContacts from '@salesforce/apex/CollegeSuccessWorkshop.getContactsAll';
import addMembers from '@salesforce/apex/CohortController.addMembers';

export default class CohortAddMembers extends LightningElement {
  @api cohortId;
  @track searchTerm = '';
  @track filteredContacts = [];
  allContacts = [];
  fuseLoaded = false;

  connectedCallback() {
    getContacts()
      .then(data => {
        this.allContacts = data;
        if (this.fuseLoaded) initFuse(this.allContacts, window.Fuse);
        this.filteredContacts = data;
      })
      .catch(error => console.error('Error loading contacts', error));
  }

  renderedCallback() {
    if (this.fuseLoaded) return;
    loadScript(this, FUSE_RESOURCE)
      .then(() => {
        this.fuseLoaded = true;
        initFuse(this.allContacts, window.Fuse);
      })
      .catch(e => console.error('Fuse load error', e));
  }

  handleSearchChange(event) {
    this.searchTerm = event.target.value;
    this.performSearch();
  }

  performSearch() {
    if (this.fuseLoaded && this.searchTerm) {
      const results = search(this.searchTerm);
      this.filteredContacts = results;
    } else {
      this.filteredContacts = [...this.allContacts];
    }
  }

  handleAddToCohort(event) {
  const contactId = event.target.dataset.id;
  const roleInput = this.template.querySelector(`[data-role="${contactId}"]`);
  const role = roleInput ? roleInput.value : 'N/A';

  if (!this.cohortId || !contactId) {
    console.warn('Missing cohortId or contactId');
    return;
  }

  const payload = [{
    Contact__c: contactId,
    Cohort__c: this.cohortId,
    Role__c: role
  }];

  addMembers({ members: payload })
    .then(() => {
      this.dispatchEvent(new CustomEvent('refreshmembers'));
    })
    .catch(error => {
      console.error('Error adding member:', JSON.stringify(error));
    });
}


}
