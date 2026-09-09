const encoder = new TextEncoder();

export const VIETCOMBANK_BIN = '970436';

export function buildVietQrPayload({
  bankBin = VIETCOMBANK_BIN,
  accountNumber,
  amountVnd,
  description,
}) {
  const bank = cleanAccountPart(bankBin, 'Bank BIN');
  const account = cleanAccountPart(accountNumber, 'Account number');
  const amount = Number(amountVnd);
  const message = cleanAscii(description, 60, 'Description');

  if (!Number.isSafeInteger(amount) || amount <= 0 || amount > 999999999) {
    throw new Error('Amount must be a positive integer VND value.');
  }

  const beneficiary = tlv('00', bank) + tlv('01', account);
  const merchantAccount =
    tlv('00', 'A000000727') +
    tlv('01', beneficiary) +
    tlv('02', 'QRIBFTTA');

  const payloadWithoutCrc =
    tlv('00', '01') +
    tlv('01', '12') +
    tlv('38', merchantAccount) +
    tlv('53', '704') +
    tlv('54', String(amount)) +
    tlv('58', 'VN') +
    tlv('62', tlv('08', message)) +
    '6304';

  return payloadWithoutCrc + crc16Hex(payloadWithoutCrc);
}

export function tlv(id, value) {
  if (!/^\d{2}$/.test(id)) throw new Error('TLV id must be two digits.');
  const text = String(value);
  const length = encoder.encode(text).length;
  if (length > 99) throw new Error(`TLV ${id} is too long.`);
  return `${id}${String(length).padStart(2, '0')}${text}`;
}

export function crc16Ccitt(value) {
  let crc = 0xffff;
  const bytes = typeof value === 'string' ? encoder.encode(value) : value;
  for (const byte of bytes) {
    crc ^= byte << 8;
    for (let bit = 0; bit < 8; bit += 1) {
      crc = crc & 0x8000 ? ((crc << 1) ^ 0x1021) & 0xffff : (crc << 1) & 0xffff;
    }
  }
  return crc;
}

export function crc16Hex(value) {
  return crc16Ccitt(value).toString(16).toUpperCase().padStart(4, '0');
}

function cleanAccountPart(value, label) {
  const text = typeof value === 'string' ? value.trim() : '';
  if (!/^[A-Za-z0-9]{6,32}$/.test(text)) {
    throw new Error(`${label} is invalid.`);
  }
  return text;
}

function cleanAscii(value, maxLength, label) {
  const text = typeof value === 'string' ? value.trim().replace(/\s+/g, ' ') : '';
  if (!text || text.length > maxLength || !/^[\x20-\x7E]+$/.test(text)) {
    throw new Error(`${label} is invalid.`);
  }
  return text;
}
