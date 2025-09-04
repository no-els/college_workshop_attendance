// possibleAttendeesPanel.js
import { LightningElement, wire, api, track } from 'lwc';
import { loadScript } from 'lightning/platformResourceLoader';
import { refreshApex } from '@salesforce/apex';
import addAttendee from '@salesforce/apex/CollegeSuccessWorkshop.addAttendee';
import FUSE_RESOURCE from '@salesforce/resourceUrl/fuse';
import { initFuse, search } from 'c/contactSearchService';
import getContactsAll from '@salesforce/apex/CollegeSuccessWorkshop.getContactsAll';

export default class PossibleAttendeesPanel extends LightningElement {
  @api selectedWorkshopId;
  @api config;
  @track filteredContacts = [];
  allContacts = [];
  wiredContactsResult;
  fuseLoaded = false;
  selectedSiteFilter = 'All Sites';
  searchTerm = '';
  
  get showCollegeSuccess() { return this.config?.showCollegeSuccess; }
  get showPPP() { return this.config?.showPPP; }

  @wire(getContactsAll)
  wiredContacts(result) {
    this.wiredContactsResult = result;
    if (result.data) {
      this.allContacts = result.data;
      this.filterAndSearchContacts();
      if (this.fuseLoaded) {
        initFuse(this.allContacts, window.Fuse);
      }
    } else if (result.error) {
      console.error('Error retrieving contacts:', result.error);
    }
  }

  renderedCallback() {
    if (this.fuseLoaded) return;
    loadScript(this, FUSE_RESOURCE)
      .then(() => {
        this.fuseLoaded = true;
        initFuse(this.allContacts, window.Fuse);
        this.filterAndSearchContacts();
      })
      .catch(error => {
        console.error('Error loading Fuse:', error);
      });
  }

  handleClick(event) {
    const contactId = event.detail;
    if (!this.selectedWorkshopId || this.selectedWorkshopId === 'None') {
      alert('Please select a workshop first');
      return;
    }
    addAttendee({ workshopId: this.selectedWorkshopId, contactId })
      .then(() => {
        this.dispatchEvent(new CustomEvent('refreshattendees'));
      })
      .catch(error => {
        console.error('Error adding attendee:', error);
      });
  }

  handleRefreshFromChild() {
    refreshApex(this.wiredContactsResult)
      .then(() => {
        if (this.fuseLoaded) {
          initFuse(this.allContacts, window.Fuse);
        }
        this.filterAndSearchContacts();
      })
      .catch(error => {
        console.error('Error refreshing data:', error);
      });
  }

  handleSiteFilterContactChange(event) {
    this.selectedSiteFilter = event.detail;
    this.filterAndSearchContacts();
  }

  handleSearchTermChange(event) {
    this.searchTerm = event.detail;
    this.filterAndSearchContacts();
  }

  filterAndSearchContacts() {
    let base = [...this.allContacts];

    // Filter by site
    if (this.selectedSiteFilter !== 'All Sites') {
      base = base.filter(c =>
        c.Site__c === this.selectedSiteFilter || c.Site_2__c === this.selectedSiteFilter
      );
    }

    // Fuzzy search
    if (this.fuseLoaded && this.searchTerm) {
      const fuseResults = search(this.searchTerm);
      base = base.filter(c => fuseResults.some(r => r.Id === c.Id));
    }

    this.filteredContacts = base;
  }
}