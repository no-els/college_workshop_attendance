export const workshopState = {
  id: null,
  name: "None selected",
  site: null,
  date: null,
  nearPeer: false
};

export function setWorkshop({ id, name, site, date, nearPeer }) {
  workshopState.id = id;
  workshopState.name = name;
  workshopState.site = site;
  workshopState.date = date;
  workshopState.nearPeer = nearPeer;
}

export function clearWorkshop() {
  workshopState.id = null;
  workshopState.name = null;
  workshopState.site = null;
  workshopState.date = null;
  workshopState.nearPeer = false;
}
