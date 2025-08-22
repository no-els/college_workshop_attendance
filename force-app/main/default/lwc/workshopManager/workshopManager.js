import { LightningElement, track } from 'lwc';
import { NavigationMixin } from 'lightning/navigation';
import { workshopState, setWorkshop } from 'c/workshopService';
import getWorkshopById from '@salesforce/apex/CollegeSuccessWorkshop.getWorkshopById';

export default class WorkshopManager extends NavigationMixin(LightningElement) {
  @track currentWorkshop = {};
  @track workshopSelectorKey = 0; // key forces LWC to rerender
  @track isSidebarOpen = true;
  @track showNearPeer = null;
  @track showDate = null;
  @track completed = null;
  connectedCallback() {
    this.currentWorkshop = { ...workshopState };
  }
   get sidebarClass() {
    return this.isSidebarOpen ? 'sidebar open' : 'sidebar collapsed';
  }
   // Color the banner based on completion
  get bannerClass() {
    const base = 'workshop-banner';
    return this.currentWorkshop?.completed ? `${base} is-completed` : base;
  }


  get sidebarToggleLabel() {
  return this.isSidebarOpen ? '«' : '»';
}
get sidebarIcon() {
  return this.isSidebarOpen ? 'utility:chevronleft' : 'utility:chevronright';
}

// Use the workshop’s value unless the user has toggled
  get effectiveShowNearPeer() {
    if (this.showNearPeer === null || this.showNearPeer === undefined) {
      return !!this.currentWorkshop?.isNearPeer;
    }
    return this.showNearPeer;
  }



  toggleSidebar() {
    this.isSidebarOpen = !this.isSidebarOpen;
  }

  async handleWorkshopSelect(e) {
  const d = e.detail;   // what you clicked from the tree
  console.log("Selecting workshop:", d);
  try {
    const w = await getWorkshopById({ workshopId: d.id }); // pull fresh from Apex

    this.currentWorkshop = {
      id: w.Id,
      name: w.Name,
      date: w.Date__c,
      site: w.Site__c,
      isNearPeer: w.Near_Peer_Workshop__c,
      completed: w.Completed__c,
      program: w.Program__c,
      showDate: w.Show_Date__c 
    };
    console.log("date here", this.currentWorkshop.showDate);
    console.log("near peer here", this.isNearPeer);

  } catch (err) {
    console.error('Error fetching workshop:', err);
  }
}


  handleEditWorkshop() {
    this[NavigationMixin.Navigate]({
      type: 'standard__recordPage',
      attributes: {
        recordId: this.currentWorkshop.id,
        objectApiName: 'Workshop__c',
        actionName: 'view'
      }
    });
  }

  // Refresh the attendees panel when a contact is added
  handleRefreshAttendees() {
    const attendeesPanel = this.template.querySelector('c-attendees-panel');
    if (attendeesPanel && typeof attendeesPanel.refresh === 'function') {
        console.log("refreshing...")
      attendeesPanel.refresh();
    } else {
      console.warn('Attendees panel not found or no refresh method available.');
    }
  }

  // Optional: handle site filter changes here if needed
  handleSiteFilterChange(event) {
    const newSite = event.detail;
    console.log('Site filter changed to', newSite);
    // You can pass this down or store it if needed
  }
  refreshWorkshops(event) {
    // Option 1: rerender workshop selector by updating key
    this.workshopSelectorKey += 1;
    console.log("refreshing workshops")
    // Optionally auto-select the new workshop
    //const newWorkshopId = event.detail.id;
    //this.currentWorkshop = { id: newWorkshopId };
    //setWorkshop(this.currentWorkshop);
  }

  handleToggle(event) {
    const newValue = !!event.detail;
    this.currentWorkshop = { ...this.currentWorkshop, isNearPeer: newValue };
    console.log('Near Peer ->', this.currentWorkshop.isNearPeer);
    this.workshopSelectorKey += 1;
  }

  handleToggleCompleted(e) {
  const value = !!e.detail;
  this.currentWorkshop = { ...this.currentWorkshop, completed: value };
  this.workshopSelectorKey += 1;
   this.reloadCurrentWorkshop();  
   
}


  handleToggleDate(event) {
  const newValue = !!event.detail;
  this.currentWorkshop = { ...this.currentWorkshop, showDate: newValue };
  this.workshopSelectorKey += 1;
  console.log(this.currentWorkshop.showDate, "from workshop manager showdate");
}


// parent (WorkshopManager.js)
async reloadCurrentWorkshop() {
  if (!this.currentWorkshop?.id) return;
  const w = await getWorkshopById({ workshopId: this.currentWorkshop.id });
  this.currentWorkshop = {
    id: w.Id,
    name: w.Name,
    date: w.Date__c,
    site: w.Site__c,
    isNearPeer: w.Near_Peer_Workshop__c,
    completed: w.Completed__c,
    program: w.Program__c,
    showDate: w.Show_Date__c
  };
  //this.template.querySelector('c-workshop-completed-toggle')?.refresh();
}


}