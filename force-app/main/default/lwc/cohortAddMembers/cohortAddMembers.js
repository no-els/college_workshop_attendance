import { LightningElement, api, track } from 'lwc';
import { loadScript } from 'lightning/platformResourceLoader';
import FUSE_RESOURCE from '@salesforce/resourceUrl/fuse';
import { initFuse, search } from 'c/contactSearchService';
import getContacts from '@salesforce/apex/CollegeSuccessWorkshop.getContactsAll';
import addMembers from '@salesforce/apex/CohortController.addMembers';

export default class CohortAddMembers extends LightningElement {
  @api cohortId;
  @api config;
  @track searchTerm = '';
  @track filteredContacts = [];
  @track loading = false;
  
  get showCollegeSuccess() { return this.config?.showCollegeSuccess; }
  get showPPP() { return this.config?.showPPP; }

  allContacts = [];
  fuseLoaded = false;

  connectedCallback() {
    getContacts()
      .then(data => {
        this.allContacts = data;
        this.filteredContacts = data;
        if (this.fuseLoaded) {
          initFuse(this.allContacts, window.Fuse);
        }
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
    let contacts = [...this.allContacts];
    
    // Filter by record type - PPP sees Parents, College Success sees Students
    if (this.showPPP) {
      contacts = contacts.filter(c => c.RecordType?.Name === 'Parent');
    } else if (this.showCollegeSuccess) {
      contacts = contacts.filter(c => c.RecordType?.Name === 'Student');
    }
    
    if (this.fuseLoaded && this.searchTerm) {
      const results = search(this.searchTerm);
      this.filteredContacts = results.filter(c => contacts.some(contact => contact.Id === c.Id));
    } else {
      this.filteredContacts = contacts;
    }
  }

  handleAddtoCohort(event) {
    console.log("Adding contact to cohort:", this.cohortId);
    const contactId = event.target.dataset.id;
    const role = this.template.querySelector(`[data-role="${contactId}"]`)?.value || 'N/A';
    console.log(`Adding contact ${contactId} with role ${role} to cohort ${this.cohortId}`);

    if (!this.cohortId || !contactId) return;

    const newMember = {
      Contact__c: contactId,
      Cohort__c: this.cohortId,
      Role__c: role
    };
    console.log(JSON.stringify(newMember));

    this.loading = true;

    addMembers({ newMembers: [newMember] })
      .then(() => {
        this.dispatchEvent(new CustomEvent('refreshmembers'));
      })
      .catch(error => {
        console.error('Error adding member', error);
      })
      .finally(() => {
        this.loading = false;
      });
  }

  get roleOptions() {
    return [
      { label: 'N/A', value: 'N/A' },
      { label: 'Mentor', value: 'Mentor' },
      { label: 'Mentee', value: 'Mentee' }
    ];
  }
}