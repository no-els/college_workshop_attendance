// programManager.js
import { LightningElement, track, api } from 'lwc';

export default class ProgramManager extends LightningElement {
  @track activeTab = 'workshops';
  @api showCollegeSuccess;
  @api showPPP;

  handleTabChange(event) {
    this.activeTab = event.target.value;
  }
}