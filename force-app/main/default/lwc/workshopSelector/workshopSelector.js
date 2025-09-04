import { LightningElement, api } from 'lwc';
import searchWorkshops from '@salesforce/apex/CollegeSuccessWorkshop.searchWorkshops';
import { debounce } from 'c/utils';



export default class WorkshopSelector extends LightningElement {
  @api config;
  workshops = [];
  selectedSiteFilter = 'All Sites';
  searchTerm = '';
  
  get showCollegeSuccess() { return this.config?.showCollegeSuccess; }
  get showPPP() { return this.config?.showPPP; }

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
  

  handleWorkshopSelecta(event) {
    console.log("Workshop selected!", event.target);
    const selectedId = event.target.value;
    const selected = this.workshops.find(w => w.Id === selectedId);
    this.dispatchEvent(new CustomEvent('workshopchange', {
      detail: {
        id: selected.Id,
        name: selected.Name,
        site: selected.Site__c,
        date: selected.Date__c,
       nearPeer: selected.Near_Peer_Workshop__c
      }
    }));
  }
  

  handleWorkshopSelect(event) {
  // If event was dispatched manually with CustomEvent
  if (event.detail && event.detail.id) {
    const selected = event.detail;

    console.log('Workshop selected via tree:', selected);

    this.dispatchEvent(new CustomEvent('workshopchange', {
      detail: {
        id: selected.id,
        name: selected.name,
        site: selected.site, // Optional
        date: selected.date,
        nearPeer: selected.nearpeer
      }
    }));

    console.log(selected.nearpeer, "near peer value from workshop selector");
  }
  // If event came from lightning-combobox
  else if (event.target && event.target.value) {
    const selectedId = event.target.value;
    const selected = this.workshops.find(w => w.Id === selectedId);

    if (selected) {
      console.log('Workshop selected via dropdown:', selected);

      this.dispatchEvent(new CustomEvent('workshopchange', {
        detail: {
          id: selected.Id,
          name: selected.Name,
          site: selected.Site__c,
          date: selected.Date__c,
          nearPeer: selected.Near_Peer_Workshop__c
        }
      }));
    }
  }
}


  
}