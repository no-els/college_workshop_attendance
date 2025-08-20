import { LightningElement, api, track } from 'lwc';
import { ShowToastEvent } from 'lightning/platformShowToastEvent';
import getCompletedFlag from '@salesforce/apex/CollegeSuccessWorkshop.getCompletedFlag';
import updateWorkshopCompleted from '@salesforce/apex/CollegeSuccessWorkshop.updateWorkshopCompleted';

export default class WorkshopCompletedToggle extends LightningElement {
  @track isCompleted = false;
  @track isLoading = false;
  error;

  _workshopId;
  @api
  get workshopId() {
    return this._workshopId;
  }
  set workshopId(value) {
    this._workshopId = value;
    this.fetchFlag(); // refresh whenever parent changes selected workshop
  }

  async fetchFlag() {
    if (!this._workshopId) return;
    this.isLoading = true;
    try {
      const result = await getCompletedFlag({ workshopId: this._workshopId });
      this.isCompleted = !!result;
      this.error = null;

      // Optional: let parent know current state (uncomment if you want initial sync)
      // this.fireChange(this.isCompleted);
    } catch (e) {
      this.error = e;
      // eslint-disable-next-line no-console
      console.error('Error fetching completed flag:', e);
      this.toast('Error', this.normalizeError(e), 'error');
    } finally {
      this.isLoading = false;
    }
  }

  async handleToggle(event) {
    const newValue = event.target.checked;
    // Optimistic UI (so banner can recolor immediately)
    const prev = this.isCompleted;
    this.isCompleted = newValue;
    this.fireChange(newValue);

    this.isLoading = true;
    try {
      await updateWorkshopCompleted({
        workshopId: this._workshopId,
        completed: newValue
      });
      this.toast('Saved', `Completed: ${newValue ? 'Yes' : 'No'}`, 'success');
    } catch (e) {
      // Revert on failure
      this.isCompleted = prev;
      this.fireChange(prev);
      event.target.checked = prev;
      this.toast('Error saving', this.normalizeError(e), 'error');
    } finally {
      this.isLoading = false;
    }
  }

  fireChange(value) {
    this.dispatchEvent(
      new CustomEvent('togglecompleted', {
        detail: !!value,
        bubbles: true,
        composed: true
      })
    );
  }

  toast(title, message, variant) {
    this.dispatchEvent(new ShowToastEvent({ title, message, variant }));
  }

  normalizeError(error) {
    if (!error) return 'Unknown error';
    if (Array.isArray(error.body)) return error.body.map(e => e.message).join(', ');
    if (error.body && typeof error.body.message === 'string') return error.body.message;
    if (typeof error.message === 'string') return error.message;
    return 'Unknown error';
  }


  // workshopCompletedToggle.js
get isDisabled() {
  return this.isLoading || !this.workshopId;
}

}