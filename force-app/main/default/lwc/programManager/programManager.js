// programManager.js
import { LightningElement, track } from 'lwc';

export default class ProgramManager extends LightningElement {
  @track activeTab = 'workshops';

  handleTabChange(event) {
    this.activeTab = event.target.value;
  }
}
