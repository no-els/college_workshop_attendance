import { LightningElement, wire, track } from 'lwc';
import getYearsSeriesWorkshops
  from '@salesforce/apex/CollegeSuccessWorkshop.getYearsSeriesWorkshops';

export default class WorkshopTreeSelector extends LightningElement {
  @track years = [];
  expandedYears = new Set();
  expandedSeries = new Set();

  @wire(getYearsSeriesWorkshops)
  wired({ data, error }) {
    if (data) this.years = data;
    if (error) console.error('Error loading years/series/workshops:', error);
  }

  // Build template-friendly view data (no expressions needed in HTML)
  get viewYears() {
    return (this.years || []).map(y => {
      const yearExpanded = this.expandedYears.has(y.value);
      return {
        ...y,
        isExpanded: yearExpanded,
        arrow: yearExpanded ? '▼' : '▶',
        series: (y.series || []).map(s => {
          const seriesExpanded = this.expandedSeries.has(s.seriesId);
          return {
            ...s,
            isExpanded: seriesExpanded,
            arrow: seriesExpanded ? '▼' : '▶'
          };
        })
      };
    });
  }

  toggleYear = (e) => {
    const id = e.currentTarget.dataset.year;
    this.expandedYears.has(id) ? this.expandedYears.delete(id) : this.expandedYears.add(id);
    // force reactivity
    this.expandedYears = new Set(this.expandedYears);
  };

  toggleSeries = (e) => {
    const id = e.currentTarget.dataset.series;
    this.expandedSeries.has(id) ? this.expandedSeries.delete(id) : this.expandedSeries.add(id);
    this.expandedSeries = new Set(this.expandedSeries);
  };

  // --- selection (unchanged from earlier suggestion) ---
  handleWorkshopSelect = (event) => {
    if (event.detail && (event.detail.id || event.detail.Id)) {
      this.fireWorkshopChange(this.normalizeWorkshop(event.detail));
      return;
    }
    if (event.currentTarget && event.currentTarget.dataset) {
      const d = event.currentTarget.dataset;
      this.fireWorkshopChange({
        id: d.id,
        name: d.name,
        site: d.site || null,
        date: d.date || null,
        nearPeer: d.nearpeer === 'true' || d.nearpeer === true
      });
      return;
    }
    if (event.target && event.target.value) {
      const selectedId = event.target.value;
      const flat = (this.years || []).flatMap(y => (y.series || []).flatMap(s => s.workshops || []));
      const w = flat.find(x => (x.id || x.Id) === selectedId);
      if (w) this.fireWorkshopChange(this.normalizeWorkshop(w));
    }
  };

  normalizeWorkshop(w) {
    return {
      id: w.id ?? w.Id,
      name: w.name ?? w.Name,
      site: w.site ?? w.Site__c ?? null,
      date: w.the_date ?? w.Date__c ?? null,
      nearPeer: (w.nearPeer ?? w.Near_Peer_Workshop__c ?? false) === true
    };
  }

  fireWorkshopChange(detail) {
    this.dispatchEvent(new CustomEvent('workshopchange', { detail }));
  }
}
