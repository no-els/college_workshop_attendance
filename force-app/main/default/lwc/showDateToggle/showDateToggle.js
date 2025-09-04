import { LightningElement, api, track } from 'lwc';
import getShowDateFlag from '@salesforce/apex/AttendeeDateController.getShowDateFlag';
import updateShowDateFlag from '@salesforce/apex/AttendeeDateController.updateShowDateFlag';

export default class showDateToggle extends LightningElement {
  @api config;
  @api isShowDate;
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
    getShowDateFlag({ workshopId: this._workshopId })
      .then(result => {
        this.isShowDate = result;
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
    this.dispatchEvent(new CustomEvent('toggledate', { detail: newValue }));

    updateShowDateFlag({ 
      workshopId: this._workshopId, 
      showDate: newValue 
    })
      .then(() => {
        this.isShowDate = newValue;
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
    return this.isShowDate ? 'Date: Yes' : 'Date: No';
  }
}