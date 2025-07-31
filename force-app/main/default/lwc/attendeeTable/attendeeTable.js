import { LightningElement, api } from 'lwc';
export default class AttendeeTable extends LightningElement {
  @api contacts;

  handleClick(event) {
    const contactId = event.target.dataset.id;
    this.dispatchEvent(new CustomEvent('select', { detail: contactId }));
  }
}
