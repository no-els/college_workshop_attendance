import { LightningElement, api, track } from 'lwc';
import createParentContact from '@salesforce/apex/CollegeSuccessWorkshop.createParentContact';
import { ShowToastEvent } from 'lightning/platformShowToastEvent';

export default class PppContactModal extends LightningElement {
  @api isOpen = false;
  @track contactData = {
    FirstName: '',
    LastName: '',
    Phone: '',
    Site1: '',
    Site2: ''
  };
  @track isLoading = false;
  @track siteOptions = [];

  connectedCallback() {
    this.loadSiteOptions();
  }

  loadSiteOptions() {
    // You can either hardcode these or fetch from Apex
    this.siteOptions = [
      { label: 'Select Site', value: '' },
      { label: 'Alvarado', value: 'Alvarado' },
      { label: 'Balboa High', value: 'Balboa High' },
      { label: 'Bessie', value: 'Bessie' },
      { label: 'Bryant', value: 'Bryant' },
      { label: 'Cal Academy', value: 'Cal Academy' },
      { label: 'Cleveland', value: 'Cleveland' },
      { label: 'Everett', value: 'Everett' },
      { label: 'Flynn', value: 'Flynn' },
      { label: 'Longfellow', value: 'Longfellow' },
      { label: 'Marshall', value: 'Marshall' },
      { label: 'SFC', value: 'SFC' },
      { label: 'TECA', value: 'TECA' },
      { label: 'Moscone', value: 'Moscone' }

    ];
  }

  handleFirstNameChange(event) {
    this.contactData.FirstName = event.target.value;
  }

  handleLastNameChange(event) {
    this.contactData.LastName = event.target.value;
  }

  handlePhoneChange(event) {
    this.contactData.Phone = event.target.value;
  }

  handleSite1Change(event) {
    this.contactData.Site1 = event.detail.value;
  }

  handleSite2Change(event) {
    this.contactData.Site2 = event.detail.value;
  }

  handleClose() {
    this.resetForm();
    this.dispatchEvent(new CustomEvent('close'));
  }

  async handleCreate() {
    if (!this.isFormValid) {
      this.showToast('Error', 'Please fill in all required fields', 'error');
      return;
    }

    this.isLoading = true;

    try {
      const contactId = await createParentContact({
        firstName: this.contactData.FirstName,
        lastName: this.contactData.LastName,
        phone: this.contactData.Phone,
        site1: this.contactData.Site1,
        site2: this.contactData.Site2
      });

      this.showToast('Success', 'Parent contact created successfully', 'success');
      this.resetForm();
      this.dispatchEvent(new CustomEvent('contactcreated', { detail: contactId }));
      this.dispatchEvent(new CustomEvent('close'));
    } catch (error) {
      console.error('Error creating contact:', error);
      this.showToast('Error', 'Failed to create contact: ' + error.message, 'error');
    } finally {
      this.isLoading = false;
    }
  }

  resetForm() {
    this.contactData = {
      FirstName: '',
      LastName: '',
      Phone: '',
      Site1: '',
      Site2: ''
    };
  }

  showToast(title, message, variant) {
    this.dispatchEvent(new ShowToastEvent({
      title,
      message,
      variant
    }));
  }

  get isFormValid() {
    return this.contactData.FirstName && this.contactData.LastName;
  }
}
