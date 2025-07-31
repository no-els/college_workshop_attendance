import { LightningElement } from 'lwc';
export default class ContactSearchInput extends LightningElement {
  handleSearchChange(e) {
    this.dispatchEvent(new CustomEvent('searchtermchange', { detail: e.target.value }));
  }
}