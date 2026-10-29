// market.dart — layer dati KuCoin futures + CoinGecko (port di gui/market.py)
// Nessun server: il telefono chiama le API pubbliche direttamente.
import 'dart:async';
import 'dart:convert';
import 'package:http/http.dart' as http;

class Contract {
  final String sym;      // XBTUSDTM
  final String base;     // XBT
  final double px, chg, hi, lo, turn, fund, oiUsd;
  final int lev;
  String cat;            // riempito da CategoryService
  double? mcap;
  double? chg7d;
  bool fav;

  Contract({
    required this.sym, required this.base, required this.px,
    required this.chg, required this.hi, required this.lo,
    required this.turn, required this.fund, required this.oiUsd,
    required this.lev,
    this.cat = 'altro', this.mcap, this.chg7d, this.fav = false,
  });

  String get pretty => sym.replaceAll('XBT', 'BTC');
}

class MarketApi {
  static const _ku = 'https://api-futures.kucoin.com';
  static const _cg = 'https://api.coingecko.com';

  static Future<List<Contract>> fetchContracts() async {
    final r = await http.get(Uri.parse('$_ku/api/v1/contracts/active'))
        .timeout(const Duration(seconds: 30));
    final d = jsonDecode(r.body)['data'] as List;
    final out = <Contract>[];
    for (final c in d) {
      if (c['status'] != 'Open') continue;
      try {
        out.add(Contract(
          sym: c['symbol'],
          base: c['displayBaseCurrency'] ?? c['baseCurrency'],
          px: _f(c['markPrice']),
          chg: _f(c['priceChgPct']) * 100,
          hi: _f(c['highPrice']),
          lo: _f(c['lowPrice']),
          turn: _f(c['turnoverOf24h']),
          fund: _f(c['fundingFeeRate']) * 100,
          oiUsd: _f(c['openInterest']) * _f(c['markPrice']) *
              _f(c['multiplier'] ?? 1),
          lev: (c['maxLeverage'] ?? 0).toInt(),
        ));
      } catch (_) {}
    }
    out.sort((a, b) => b.turn.compareTo(a.turn));
    return out;
  }

  /// Candele [ts_ms, o, h, l, c, vol] — pagine da 190 (cap API ~200).
  static Future<List<List<num>>> fetchKlines(String sym, int gran,
      {int want = 300}) async {
    final out = <int, List<num>>{};
    var to = DateTime.now().millisecondsSinceEpoch;
    for (var p = 0; p < 8 && out.length < want; p++) {
      final frm = to - gran * 60000 * 190;
      final u = Uri.parse('$_ku/api/v1/kline/query'
          '?symbol=$sym&granularity=$gran&from=$frm&to=$to');
      List d;
      try {
        final r = await http.get(u).timeout(const Duration(seconds: 30));
        d = jsonDecode(r.body)['data'] as List? ?? [];
      } catch (_) {
        break;
      }
      if (d.isEmpty) break;
      for (final row in d) {
        out[(row[0] as num).toInt()] =
            row.map((e) => e as num).toList();
      }
      if (d.length < 2) break;
      to = d.map((r) => (r[0] as num).toInt()).reduce((a, b) => a < b ? a : b) - 1;
    }
    final keys = out.keys.toList()..sort();
    final all = keys.map((k) => out[k]!).toList();
    return all.length > want ? all.sublist(all.length - want) : all;
  }

  /// Market cap da CoinPaprika: TUTTE le coin in 1 sola richiesta,
  /// vince la coin piu' grossa per symbol (rank).
  static Future<Map<String, double>> fetchMcaps() async {
    final out = <String, double>{};
    try {
      final r = await http
          .get(Uri.parse('https://api.coinpaprika.com/v1/tickers'))
          .timeout(const Duration(seconds: 45));
      final d = jsonDecode(r.body) as List;
      final best = <String, int>{};
      for (final c in d) {
        final s = (c['symbol'] ?? '').toString().toUpperCase();
        final rk = (c['rank'] ?? 999999) as int;
        final mc = (c['quotes']?['USD']?['market_cap'] as num?)
            ?.toDouble();
        if (s.isEmpty || mc == null) continue;
        if (!best.containsKey(s) || rk < best[s]!) {
          best[s] = rk;
          out[s] = mc;
        }
      }
      if (out.containsKey('BTC')) out['XBT'] = out['BTC']!;
    } catch (_) {}
    return out;
  }

  /// Variazione 7d per una lista di simboli (1 req ognuna).
  static Future<Map<String, double>> fetch7d(List<String> syms,
      {int workers = 8}) async {
    final res = <String, double>{};
    final queue = List<String>.from(syms);
    Future<void> worker() async {
      while (queue.isNotEmpty) {
        final s = queue.removeAt(0);
        try {
          final frm = DateTime.now().millisecondsSinceEpoch - 8 * 86400000;
          final u = Uri.parse('$_ku/api/v1/kline/query'
              '?symbol=$s&granularity=1440&from=$frm');
          final r = await http.get(u).timeout(const Duration(seconds: 20));
          var k = jsonDecode(r.body)['data'] as List? ?? [];
          k.sort((a, b) => (a[0] as num).compareTo(b[0] as num));
          if (k.length >= 2) {
            final o = (k.first[1] as num).toDouble();
            final c = (k.last[4] as num).toDouble();
            if (o != 0) res[s] = (c / o - 1) * 100;
          }
        } catch (_) {}
        await Future.delayed(const Duration(milliseconds: 150));
      }
    }
    await Future.wait(List.generate(workers, (_) => worker()));
    return res;
  }

  static double _f(dynamic v) =>
      v == null ? 0.0 : (v is num ? v.toDouble() : double.tryParse('$v') ?? 0);
}

/// Categorie + market cap da CoinGecko (stessa logica del web).
class CategoryService {
  static const catIds = <String, String>{
    'meme-token': 'Meme', 'dog-themed-coins': 'Meme',
    'cat-themed-coins': 'Meme', 'frog-themed-coins': 'Meme',
    'artificial-intelligence': 'AI', 'ai-agents': 'AI',
    'ai-meme-coins': 'AI',
    'gaming': 'Gaming', 'metaverse': 'Gaming', 'play-to-earn': 'Gaming',
    'nft': 'NFT',
    'layer-1': 'L1', 'smart-contract-platform': 'L1', 'layer-2': 'L2',
    'decentralized-finance-defi': 'DeFi', 'decentralized-exchange': 'DeFi',
    'lending-borrowing': 'DeFi', 'liquid-staking': 'DeFi',
    'yield-farming': 'DeFi',
    'privacy-coins': 'Privacy',
    'real-world-assets-rwa': 'RWA',
    'depin': 'DePIN', 'internet-of-things-iot': 'DePIN',
    'centralized-exchange-token-cex': 'Exchange',
    'oracle': 'Oracoli', 'interoperability': 'Infra',
    'storage': 'Storage', 'stablecoins': 'Stable',
    'sports': 'Fan/Sport', 'fan-token': 'Fan/Sport',
  };

  static const staticCat = <String, String>{
    'BTC': 'L1', 'XBT': 'L1', 'ETH': 'L1', 'SOL': 'L1', 'ADA': 'L1',
    'AVAX': 'L1', 'DOT': 'L1', 'ATOM': 'L1', 'NEAR': 'L1', 'APT': 'L1',
    'SUI': 'L1', 'SEI': 'L1', 'TRX': 'L1', 'ALGO': 'L1', 'HBAR': 'L1',
    'EGLD': 'L1', 'TON': 'L1', 'INJ': 'L1', 'KAS': 'L1', 'FTM': 'L1',
    'LTC': 'L1', 'BCH': 'L1', 'XLM': 'L1', 'VET': 'L1', 'ICP': 'L1',
    'XDC': 'L1', 'MINA': 'L1', 'CFX': 'L1',
    'MATIC': 'L2', 'POL': 'L2', 'ARB': 'L2', 'OP': 'L2', 'MANTA': 'L2',
    'STRK': 'L2', 'ZK': 'L2', 'MNT': 'L2',
    'KCS': 'Exchange', 'BNB': 'Exchange', 'CRO': 'Exchange',
    'BGB': 'Exchange', 'OKB': 'Exchange', 'GT': 'Exchange',
    'FET': 'AI', 'TAO': 'AI', 'RENDER': 'AI', 'AGIX': 'AI',
    'OCEAN': 'AI', 'GRT': 'AI', 'WLD': 'AI',
    'AKT': 'DePIN',
    'AXS': 'Gaming', 'SAND': 'Gaming', 'MANA': 'Gaming',
    'IMX': 'Gaming', 'GALA': 'Gaming', 'PIXEL': 'Gaming',
    'APE': 'Gaming', 'ILV': 'Gaming', 'RON': 'Gaming',
    'LDO': 'DeFi', 'MKR': 'DeFi', 'AAVE': 'DeFi', 'CRV': 'DeFi',
    'UNI': 'DeFi',
    'LINK': 'Oracoli', 'PYTH': 'Oracoli', 'TRB': 'Oracoli',
    'FIL': 'Storage', 'AR': 'Storage',
    'QNT': 'Infra',
    'XMR': 'Privacy', 'ZEC': 'Privacy', 'DASH': 'Privacy',
    'ROSE': 'Privacy', 'SCRT': 'Privacy',
    'USDT': 'Stable', 'USDC': 'Stable', 'DAI': 'Stable',
    'USDE': 'Stable', 'USD1': 'Stable', 'PYUSD': 'Stable',
  };

  /// sym -> {'cat': label, 'mcap': usd}. Persistito in SharedPreferences.
  static Future<Map<String, Map<String, dynamic>>> fetchAll(
      {void Function(int done, int tot)? onProgress}) async {
    final map = <String, String>{...staticCat};
    final mcap = <String, double>{};
    final rank = {for (final s in staticCat.keys) s: 0};
    final ids = catIds.entries.toList();
    var done = 0;
    for (final e in ids) {
      for (var page = 1; page <= 2; page++) {
        List? d;
        for (var att = 0; att < 3; att++) {
          try {
            final r = await http.get(Uri.parse(
                    '${MarketApi._cg}/api/v3/coins/markets'
                    '?vs_currency=usd&category=${e.key}'
                    '&per_page=250&page=$page&sparkline=false'))
                .timeout(const Duration(seconds: 30));
            if (r.statusCode == 200) {
              d = jsonDecode(r.body) as List;
              break;
            }
          } catch (_) {}
          await Future.delayed(Duration(seconds: 30 + att * 30));
        }
        if (d == null || d.isEmpty) break;
        for (final c in d) {
          final s = (c['symbol'] ?? '').toString().toUpperCase();
          final rk = (c['market_cap_rank'] ?? 999999) as int;
          final mc = (c['market_cap'] as num?)?.toDouble();
          if (s.isEmpty) continue;
          if (!map.containsKey(s) || rk < (rank[s] ?? 999999)) {
            map[s] = e.value;
            rank[s] = rk;
            if (mc != null) mcap[s] = mc;
          } else if (mc != null && !mcap.containsKey(s)) {
            mcap[s] = mc;
          }
        }
        if (d.length < 250) break;
        await Future.delayed(const Duration(seconds: 7));
      }
      done++;
      onProgress?.call(done, ids.length);
      await Future.delayed(const Duration(seconds: 7));
    }
    return {
      for (final s in map.keys)
        s: {'cat': map[s], 'mcap': mcap[s]},
    };
  }
}
