const MAX_OPTIONS = 12;
const MAX_VALUES = 24;
const MAX_ID_LENGTH = 64;
const MAX_TEXT_LENGTH = 100;
const MAX_PRICE_DELTA_VND = 5000000;

export function validateMenuOptions(value) {
  if (value == null) return { options: [] };
  if (!Array.isArray(value)) return { error: 'Item options must be an array.' };
  if (value.length > MAX_OPTIONS) return { error: `Item is limited to ${MAX_OPTIONS} option groups.` };

  const ids = new Set();
  const options = [];
  for (const raw of value) {
    const id = cleanId(raw?.id);
    const type = String(raw?.type ?? '');
    const name = localizedText(raw?.name);
    if (!id || ids.has(id) || !name) return { error: 'Every option needs a unique id and EN/RU/VI name.' };
    ids.add(id);

    if (type === 'dots') {
      const min = toInt(raw?.min);
      const max = toInt(raw?.max);
      const defaultValue = toInt(raw?.default);
      const pricePerStepVnd = toPrice(raw?.pricePerStepVnd ?? 0);
      if (min == null || max == null || defaultValue == null || pricePerStepVnd == null) {
        return { error: `Invalid dots option: ${id}.` };
      }
      if (min < 0 || max > 8 || max < min || defaultValue < min || defaultValue > max) {
        return { error: `Invalid dots range: ${id}.` };
      }
      options.push({
        id,
        type,
        name,
        min,
        max,
        default: defaultValue,
        pricePerStepVnd,
      });
      continue;
    }

    if (type !== 'single' && type !== 'multiple') {
      return { error: `Unsupported option type: ${type || id}.` };
    }

    const rawValues = Array.isArray(raw?.values) ? raw.values : [];
    if (rawValues.length < 1 || rawValues.length > MAX_VALUES) {
      return { error: `Option ${id} needs 1-${MAX_VALUES} values.` };
    }
    const valueIds = new Set();
    const values = [];
    for (const rawValue of rawValues) {
      const valueId = cleanId(rawValue?.id);
      const valueName = localizedText(rawValue?.name);
      const priceDeltaVnd = toPrice(rawValue?.priceDeltaVnd ?? 0);
      if (!valueId || valueIds.has(valueId) || !valueName || priceDeltaVnd == null) {
        return { error: `Invalid value in option ${id}.` };
      }
      valueIds.add(valueId);
      values.push({ id: valueId, name: valueName, priceDeltaVnd });
    }

    let defaultValue = raw?.default == null ? null : cleanId(raw.default);
    if (defaultValue && !valueIds.has(defaultValue)) {
      return { error: `Invalid default for option ${id}.` };
    }
    const required = raw?.required === true;
    if (type === 'single' && required && !defaultValue && raw?.allowNoDefault !== true) {
      // Required single-choice options may intentionally have no default so the
      // customer must choose (e.g. beverage brand).
      defaultValue = null;
    }

    options.push({
      id,
      type,
      name,
      required,
      default: type === 'single' ? defaultValue : null,
      values,
    });
  }
  return { options };
}

export function parseMenuOptions(value) {
  if (value == null || value === '') return [];
  let parsed = value;
  if (typeof value === 'string') {
    try {
      parsed = JSON.parse(value);
    } catch {
      return [];
    }
  }
  const checked = validateMenuOptions(parsed);
  return checked.error ? [] : checked.options;
}

export function resolveMenuSelection({
  itemName,
  basePriceVnd,
  options,
  selection,
}) {
  const checked = validateMenuOptions(options);
  if (checked.error) return { error: checked.error };
  const selected = selection && typeof selection === 'object' && !Array.isArray(selection)
    ? selection
    : {};

  let unitPriceVnd = Number(basePriceVnd);
  if (!Number.isSafeInteger(unitPriceVnd) || unitPriceVnd <= 0) {
    return { error: 'Invalid base price.' };
  }

  const normalized = {};
  const summaryParts = [];
  for (const option of checked.options) {
    if (option.type === 'dots') {
      const rawValue = selected[option.id] ?? option.default;
      const value = toInt(rawValue);
      if (value == null || value < option.min || value > option.max) {
        return { error: `Choose a valid ${english(option.name)}.` };
      }
      normalized[option.id] = value;
      unitPriceVnd += (value - option.min) * option.pricePerStepVnd;
      summaryParts.push(`${english(option.name)} ${value}/${option.max}`);
      continue;
    }

    if (option.type === 'single') {
      let valueId = cleanId(selected[option.id] ?? option.default);
      if (!valueId) {
        if (option.required) return { error: `Choose ${english(option.name)}.` };
        continue;
      }
      const value = option.values.find((entry) => entry.id === valueId);
      if (!value) return { error: `Choose a valid ${english(option.name)}.` };
      normalized[option.id] = value.id;
      unitPriceVnd += value.priceDeltaVnd;
      summaryParts.push(english(value.name));
      continue;
    }

    const rawValues = selected[option.id] == null
      ? []
      : Array.isArray(selected[option.id])
        ? selected[option.id]
        : [selected[option.id]];
    const unique = [];
    for (const rawValue of rawValues) {
      const valueId = cleanId(rawValue);
      if (!valueId || unique.includes(valueId)) continue;
      const value = option.values.find((entry) => entry.id === valueId);
      if (!value) return { error: `Choose a valid ${english(option.name)}.` };
      unique.push(value.id);
      unitPriceVnd += value.priceDeltaVnd;
      summaryParts.push(english(value.name));
    }
    normalized[option.id] = unique;
  }

  if (!Number.isSafeInteger(unitPriceVnd) || unitPriceVnd <= 0 || unitPriceVnd > 999999999) {
    return { error: 'Invalid configured price.' };
  }

  const selectionSummary = summaryParts.join(' · ').slice(0, 300);
  const displayName = selectionSummary
    ? `${String(itemName)} · ${selectionSummary}`.slice(0, 400)
    : String(itemName).slice(0, 400);

  return {
    unitPriceVnd,
    selection: normalized,
    selectionJson: JSON.stringify(normalized),
    selectionSummary,
    displayName,
  };
}

export function selectionSignature(itemId, selection) {
  const id = cleanId(itemId);
  if (!id) return '';
  return `${id}:${stableJson(selection && typeof selection === 'object' ? selection : {})}`;
}

function stableJson(value) {
  if (Array.isArray(value)) return `[${value.map(stableJson).join(',')}]`;
  if (value && typeof value === 'object') {
    return `{${Object.keys(value).sort().map((key) => `${JSON.stringify(key)}:${stableJson(value[key])}`).join(',')}}`;
  }
  return JSON.stringify(value);
}

function localizedText(value) {
  if (typeof value === 'string') {
    const text = cleanText(value);
    return text ? { en: text, ru: text, vi: text } : null;
  }
  if (!value || typeof value !== 'object' || Array.isArray(value)) return null;
  const en = cleanText(value.en);
  const ru = cleanText(value.ru);
  const vi = cleanText(value.vi);
  return en && ru && vi ? { en, ru, vi } : null;
}

function english(value) {
  if (typeof value === 'string') return value;
  return String(value?.en ?? value?.ru ?? value?.vi ?? '');
}

function cleanText(value) {
  if (typeof value !== 'string') return '';
  const text = value.trim().replace(/\s+/g, ' ');
  return text && text.length <= MAX_TEXT_LENGTH ? text : '';
}

function cleanId(value) {
  const text = typeof value === 'string' ? value.trim().toLowerCase() : '';
  return /^[a-z0-9][a-z0-9_-]{0,63}$/.test(text) ? text : '';
}

function toInt(value) {
  const number = Number(value);
  return Number.isSafeInteger(number) ? number : null;
}

function toPrice(value) {
  const number = toInt(value);
  return number != null && number >= 0 && number <= MAX_PRICE_DELTA_VND ? number : null;
}
