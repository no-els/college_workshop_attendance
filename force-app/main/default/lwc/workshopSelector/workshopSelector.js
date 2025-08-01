import { LightningElement } from 'lwc';
import searchWorkshops from '@salesforce/apex/WorkshopController.searchWorkshops';
import { debounce } from 'c/utils';



export default class WorkshopSelector extends LightningElement {
  workshops = [];
  selectedSiteFilter = 'All Sites';
  searchTerm = '';

  connectedCallback() {
    this.performSearch();
  }


  handleSiteFilterChange(event) {
    this.selectedSiteFilter = event.detail;
    this.dispatchEvent(new CustomEvent('sitefilterchange', { detail: event.detail }));
    this.performSearch();
  }

  handleInputChange(event) {
    this.searchTerm = event.target.value;
    debounce(this.performSearch.bind(this), 300)();
  }

  performSearch() {
    searchWorkshops({ searchTerm: this.searchTerm })
      .then(result => {
        this.workshops = result;
      })
      .catch(error => {
        console.error('Error fetching workshops:', error);
      });
  }

  get filteredWorkshops() {
    if (this.selectedSiteFilter === 'All Sites') {
      return this.workshops;
    }
    return this.workshops.filter(w => w.Site__c === this.selectedSiteFilter);
  }

  get workshopOptions() {
    return this.filteredWorkshops.map(w => ({ label: w.Name, value: w.Id }));
  }
  

  handleWorkshopSelect(event) {
    const selectedId = event.target.value;
    const selected = this.workshops.find(w => w.Id === selectedId);
    this.dispatchEvent(new CustomEvent('workshopchange', {
      detail: {
        id: selected.Id,
        name: selected.Name,
        site: selected.Site__c,
        date: selected.Date__c
      }
    }));
  }

  
}