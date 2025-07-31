export const workshopState = {
  id: null,
  name: "None selected",
  site: null,
  date: null
};

export function setWorkshop({ id, name, site, date }) {
  workshopState.id = id;
  workshopState.name = name;
  workshopState.site = site;
  workshopState.date = date;
}

export function clearWorkshop() {
  workshopState.id = null;
  workshopState.name = null;
  workshopState.site = null;
  workshopState.date = null;
}