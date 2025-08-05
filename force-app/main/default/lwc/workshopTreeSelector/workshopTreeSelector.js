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
        const workshopId = event.currentTarget.dataset.id;
        const name = event.currentTarget.dataset.name;
        const site = event.currentTarget.dataset.site;
        const date = event.currentTarget.dataset.date;
        this.dispatchEvent(new CustomEvent('workshopchange', {
            detail: { id: workshopId, name, site, date }
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
