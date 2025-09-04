// programManager.js
import { LightningElement, track, api } from 'lwc';

export default class ProgramManager extends LightningElement {
  @track activeTab = 'workshops';
  @api showCollegeSuccess = false;
  @api showPPP = false;

  handleTabChange(event) {
    this.activeTab = event.target.value;
  }

  get config() {
    return Object.freeze({
      showCollegeSuccess: this.showCollegeSuccess,
      showPPP: this.showPPP
    });
  }
}