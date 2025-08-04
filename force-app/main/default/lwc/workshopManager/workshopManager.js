import { LightningElement, track } from 'lwc';
import { NavigationMixin } from 'lightning/navigation';
import { workshopState, setWorkshop } from 'c/workshopService';

export default class WorkshopManager extends NavigationMixin(LightningElement) {
  @track currentWorkshop = {};
  @track workshopSelectorKey = 0; // key forces LWC to rerender
  connectedCallback() {
    this.currentWorkshop = { ...workshopState };
  }

  handleWorkshopSelect(event) {
    setWorkshop(event.detail);
    this.currentWorkshop = { ...event.detail }; // Update tracked state
    console.log('Workshop selected:', this.currentWorkshop);
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

}