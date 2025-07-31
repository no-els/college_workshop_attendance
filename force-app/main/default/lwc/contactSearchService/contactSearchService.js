import Fuse from '@salesforce/resourceUrl/fuse';

let fuseInstance;

export function initFuse(data, FuseConstructor) {
  const options = {
    keys: ['Name', 'Phone'],
    threshold: 0.4
  };
  fuseInstance = new FuseConstructor(data, options);
}
export function search(term) {
  if (!fuseInstance || !term) return [];
  return fuseInstance.search(term).map(r => r.item);
}