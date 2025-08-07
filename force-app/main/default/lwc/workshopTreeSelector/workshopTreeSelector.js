import { LightningElement, wire } from 'lwc';
import getWorkshopsGroupedBySeries from '@salesforce/apex/CollegeSuccessWorkshop.getWorkshopsGroupedBySeries';

export default class WorkshopTreeSelector extends LightningElement {
    groupedWorkshops = {};
    expandedSeries = new Set();

    @wire(getWorkshopsGroupedBySeries)
    wiredWorkshops({ error, data }) {
        if (data) {
            this.groupedWorkshops = data;
        } else if (error) {
            console.error('Error loading workshop data:', error);
        }
    }

    toggleSeries(event) {
        const seriesId = event.currentTarget.dataset.id;
        if (this.expandedSeries.has(seriesId)) {
            this.expandedSeries.delete(seriesId);
        } else {
            this.expandedSeries.add(seriesId);
        }
        this.expandedSeries = new Set(this.expandedSeries); // force reactivity
    }

    isSeriesExpanded(seriesId) {
        return this.expandedSeries.has(seriesId);
    }

   handleWorkshopClick(event) {
  const li = event.currentTarget;
  const dataset = li.dataset;

  console.log('Clicked workshop data:', dataset);

  this.dispatchEvent(new CustomEvent('workshopchange', {
    detail: {
      id: dataset.id,
      name: dataset.name,
      date: dataset.date,
      nearPeer: dataset.nearpeer === 'true' // cast to boolean if needed
    }
  }));
}



    get seriesList() {
    return Object.entries(this.groupedWorkshops).map(([seriesId, workshops]) => {
        return {
            id: seriesId,
            name: workshops[0]?.Workshop_Series__r?.Name || 'Unnamed Series',
            workshops,
            isExpanded: this.expandedSeries.has(seriesId),
            toggleArrow: this.expandedSeries.has(seriesId) ? '▼' : '▶'
        };
    });
}

}
