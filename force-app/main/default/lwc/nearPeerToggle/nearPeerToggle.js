import { LightningElement, api, track } from 'lwc';
import getNearPeerFlag from '@salesforce/apex/CollegeSuccessWorkshop.getNearPeerFlag';
import updateWorkshopNearPeer from '@salesforce/apex/CollegeSuccessWorkshop.updateWorkshopNearPeer';

export default class NearPeerToggle extends LightningElement {
  @api config;
  @track isNearPeer;
  @track isLoading = false;
  error;
  
  get showCollegeSuccess() { return this.config?.showCollegeSuccess; }
  get showPPP() { return this.config?.showPPP; }

  _workshopId;

  @api
  get workshopId() {
    return this._workshopId;
  }
  set workshopId(value) {
    this._workshopId = value;
    this.fetchFlag(); // run this whenever parent updates the ID
  }

  fetchFlag() {
    if (!this._workshopId) return;

    this.isLoading = true;
    getNearPeerFlag({ workshopId: this._workshopId })
      .then(result => {
        this.isNearPeer = result;
        this.error = null;
      })
      .catch(error => {
        this.error = error;
        console.error('Error fetching near peer flag:', error);
      })
      .finally(() => {
        this.isLoading = false;
      });
  }

  handleToggle(event) {
    const newValue = event.target.checked;
    console.log('Toggle event to:', newValue);
    this.isLoading = true;
    this.dispatchEvent(new CustomEvent('togglenearpeer', { detail: newValue }));

    updateWorkshopNearPeer({ 
      workshopId: this._workshopId, 
      isNearPeer: newValue 
    })
      .then(() => {
        this.isNearPeer = newValue;
        this.error = null;
      })
      .catch(error => {
        this.error = error;
        console.error('Error updating flag:', error);
      })
      .finally(() => {
        this.isLoading = false;
      });
  }

  get labelText() {
    return this.isNearPeer ? 'Near Peer Workshop: Yes' : 'Near Peer Workshop: No';
  }
}