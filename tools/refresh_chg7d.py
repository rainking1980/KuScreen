#!/usr/bin/env python3
"""Rigenera assets/chg7d.json: variazione 7d per tutti i contratti
futures KuCoin attivi. Girato in CI prima di flutter build."""
import json
import time
import urllib.request
from concurrent.futures import ThreadPoolExecutor

KU = 'https://api-futures.kucoin.com'


def get(path):
    req = urllib.request.Request(KU + path, headers={'User-Agent': 'x'})
    return json.load(urllib.request.urlopen(req, timeout=30))


def chg7d(sym):
    now = int(time.time() * 1000)
    frm = now - 8 * 86400000
    d = get(f'/api/v1/kline/query?symbol={sym}'
            f'&granularity=1440&from={frm}&to={now}')['data'] or []
    d.sort(key=lambda k: k[0])
    if len(d) < 2 or not d[0][1]:
        return None
    return (d[-1][4] / d[0][1] - 1) * 100


def main():
    syms = [c['symbol'] for c in get('/api/v1/contracts/active')['data']
            if c.get('status') == 'Open']
    out = {}
    with ThreadPoolExecutor(12) as ex:
        for s, v in zip(syms, ex.map(chg7d, syms)):
            if v is not None:
                out[s] = v
    json.dump(out, open('assets/chg7d.json', 'w'))
    print(f'{len(out)}/{len(syms)} simboli -> assets/chg7d.json')


if __name__ == '__main__':
    main()
