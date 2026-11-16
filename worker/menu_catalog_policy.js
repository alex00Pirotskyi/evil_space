// Compatibility with menu catalogs already published to D1.
// Existing orders must keep their historical catalog and item IDs; we only
// curate the active view and future publishes. This transformation is pure.
export function curateLegacyMenuGroups(groups) {
  if (!Array.isArray(groups)) return [];

  const coworkingExists = groups.some(group => group?.id === 'coworking');
  const monthly = coworkingExists
    ? groups.flatMap(group => Array.isArray(group?.items) ? group.items : [])
      .find(item => item?.id === 'coworking-month')
    : null;

  const result = [];
  for (const group of groups) {
    if (!group || group.id === 'storage-locker') continue;
    const sourceItems = Array.isArray(group.items) ? group.items : [];
    const items = sourceItems.filter(item =>
      item && item.id !== 'storage-locker-month' &&
      !(monthly && group.id !== 'coworking' && item.id === 'coworking-month'));

    if (group.id === 'coworking' && monthly &&
        !items.some(item => item.id === 'coworking-month')) {
      items.push(monthly);
    }
    // Keep ordinary empty draft groups. Only remove groups emptied by
    // discontinuing an item or relocating Monthly Desk to Coworking.
    if (items.length || sourceItems.length === 0) result.push({ ...group, items });
  }
  return result;
}

export function discontinuedMenuItem(id) {
  return id === 'storage-locker-month';
}

export function canonicalMenuGroupForItem(itemKey, groupKey) {
  return itemKey === 'coworking-month' ? 'coworking' : groupKey;
}
