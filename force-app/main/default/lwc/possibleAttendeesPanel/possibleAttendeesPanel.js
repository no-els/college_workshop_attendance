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
  
  get siteOptions() {
    const sites = new Set();
    this.allContacts.forEach(contact => {
      if (contact.Site__c) sites.add(contact.Site__c);
      if (contact.Site_2__c) sites.add(contact.Site_2__c);
    });
    
    const options = [{ label: 'All Sites', value: 'All Sites' }];
    Array.from(sites).sort().forEach(site => {
      options.push({ label: site, value: site });
    });
    
    return options;
  }

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
    this.selectedSiteFilter = event.detail.value;
    this.filterAndSearchContacts();
  }

  handleSearchTermChange(event) {
    this.searchTerm = event.detail;
    this.filterAndSearchContacts();
  }

  filterAndSearchContacts() {
    let base = [...this.allContacts];
    console.log('Starting with', base.length, 'contacts');

    // Filter by record type - PPP sees Parents, College Success sees Students
    if (this.showPPP) {
      base = base.filter(c => c.RecordType?.Name === 'Parent');
      console.log('After PPP filter:', base.length, 'contacts');
    } else if (this.showCollegeSuccess) {
      base = base.filter(c => c.RecordType?.Name === 'Student');
      console.log('After College Success filter:', base.length, 'contacts');
    }

    // Filter by site
    if (this.selectedSiteFilter && this.selectedSiteFilter !== 'All Sites') {
      base = base.filter(c =>
        c.Site__c === this.selectedSiteFilter || c.Site_2__c === this.selectedSiteFilter
      );
      console.log('After site filter:', base.length, 'contacts, filter:', this.selectedSiteFilter);
    }

    // Fuzzy search
    if (this.fuseLoaded && this.searchTerm) {
      const fuseResults = search(this.searchTerm);
      base = base.filter(c => fuseResults.some(r => r.Id === c.Id));
      console.log('After search filter:', base.length, 'contacts');
    }

    this.filteredContacts = base;
    console.log('Final filtered contacts:', this.filteredContacts.length);
  }
}