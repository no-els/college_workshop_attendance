import { LightningElement, track } from 'lwc';
import { NavigationMixin } from 'lightning/navigation';
import { workshopState, setWorkshop } from 'c/workshopService';

export default class WorkshopManager extends NavigationMixin(LightningElement) {
  @track currentWorkshop = {};
  @track workshopSelectorKey = 0; // key forces LWC to rerender
  @track isSidebarOpen = true;
  @track showNearPeer = null;
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

  handleWorkshopSelect(e) {
  const d = e.detail;
  this.currentWorkshop = {
    id: d.id,
    name: d.name,
    date: d.date,
    // nearPeer might come as 'true'/'false' or boolean — normalize:
    isNearPeer: !!(d.nearPeer ?? d.isNearPeer),
    completed: !!(d.completed ?? d.isCompleted)
  };
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
  }

  handleToggleCompleted(e) {
    // keep manager state in sync with child (optimistic already applied)
    const { value } = e.detail || {};
    this.currentWorkshop = { ...this.currentWorkshop, completed: !!value };
    // If you also want to ping other panels, do it here.
  }
}