import { flw } from './flw';

export type BillKind = 'airtime' | 'data' | 'power' | 'tv' | 'internet';
export interface Item { itemCode: string; name: string; amount: number; fee: number; label: string }

// App provider id -> Flutterwave biller code. Providers not listed here are not offered by the payment partner.
const MAP: Record<BillKind, Record<string, string>> = {
  airtime: { mtn: 'BIL099', airtel: 'BIL100', glo: 'BIL102', t2: 'BIL103' },
  data: { mtn: 'BIL104', airtel: 'BIL106', glo: 'BIL105', t2: 'BIL107' },
  power: { ibedc: 'BIL116', ikeja: 'BIL113', eko: 'BIL111', enugu: 'BIL117', kano: 'BIL115', kaduna: 'BIL112', phed: 'BIL114', benin: 'BIL118' },
  tv: { dstv: 'BIL119', gotv: 'BIL120', startimes_tv: 'BIL123' },
  internet: { spectranet: 'BIL125', smile: 'BIL101', ipnx: 'BIL127' },
};

export const supported = (): Record<BillKind, string[]> =>
  Object.fromEntries(Object.entries(MAP).map(([k, v]) => [k, Object.keys(v)])) as Record<BillKind, string[]>;

let cache: { at: number; byBiller: Map<string, Item[]> } | undefined;
async function catalog(): Promise<Map<string, Item[]>> {
  if (cache && Date.now() - cache.at < 3600_000) return cache.byBiller;
  const r = await flw<any[]>('/bill-categories?country=NG');
  const byBiller = new Map<string, Item[]>();
  if (r.ok && Array.isArray(r.data)) {
    for (const x of r.data) {
      const list = byBiller.get(x.biller_code) ?? [];
      if (list.some((i) => i.itemCode === x.item_code)) continue;
      list.push({ itemCode: x.item_code, name: String(x.biller_name || x.short_name || '').trim(), amount: Number(x.amount) || 0, fee: Number(x.fee) || 0, label: x.label_name || 'Customer ID' });
      byBiller.set(x.biller_code, list);
    }
    cache = { at: Date.now(), byBiller };
  } else if (cache) return cache.byBiller;
  return byBiller;
}

export function billerFor(kind: BillKind, provider: string): string | undefined {
  return MAP[kind]?.[provider];
}

export async function items(kind: BillKind, provider: string): Promise<{ billerCode: string; items: Item[] } | null> {
  const billerCode = billerFor(kind, provider);
  if (!billerCode) return null;
  let list = (await catalog()).get(billerCode) ?? [];
  if (kind === 'airtime') list = list.slice(-1); // one VTU item per network
  return { billerCode, items: list.sort((a, b) => a.amount - b.amount) };
}
