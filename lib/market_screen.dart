import 'package:flutter/material.dart';
import 'main.dart';
import 'market.dart';

class MarketScreen extends StatefulWidget {
  const MarketScreen({super.key});
  @override
  State<MarketScreen> createState() => _MarketScreenState();
}

class _MarketScreenState extends State<MarketScreen> {
  final _q = TextEditingController();
  double _minTurn = 1e6;
  double _minChg = 0;
  double _mcapLim = 0;          // 0 = tutte
  int _minLev = 0;
  String _fund = 'tutti';
  double _minOi = 0;
  String _cat = 'tutte';
  bool _onlyFav = false;
  String _sort = 'turn';
  bool _sortAsc = false;

  static const cats = ['tutte', 'L1', 'L2', 'Meme', 'AI', 'Gaming',
    'NFT', 'DeFi', 'Privacy', 'RWA', 'DePIN', 'Exchange', 'Oracoli',
    'Infra', 'Storage', 'Stable', 'Fan/Sport', 'altro'];

  @override
  void initState() {
    super.initState();
    MarketState.I.addListener(_onChange);
    // refresh leggero ogni 30s
    Stream.periodic(const Duration(seconds: 30))
        .listen((_) => MarketState.I.refresh());
  }

  void _onChange() => mounted ? setState(() {}) : null;

  @override
  void dispose() {
    MarketState.I.removeListener(_onChange);
    _q.dispose();
    super.dispose();
  }

  List<Contract> get _filtered {
    var out = MarketState.I.rows.where((c) {
      if (_onlyFav && !c.fav) return false;
      final q = _q.text.toUpperCase();
      if (q.isNotEmpty &&
          !c.sym.contains(q) &&
          !c.base.toUpperCase().contains(q) &&
          !c.sym.contains(q.replaceAll('BTC', 'XBT'))) {
        return false;
      }
      if (c.turn < _minTurn) return false;
      if (c.chg.abs() < _minChg) return false;
      if (c.lev < _minLev) return false;
      if (c.oiUsd < _minOi) return false;
      if (_mcapLim > 0 && (c.mcap ?? 1e18) >= _mcapLim) return false;
      if (_cat != 'tutte' && c.cat != _cat) return false;
      if (_fund == '>0' && c.fund <= 0) return false;
      if (_fund == '<0' && c.fund >= 0) return false;
      if (_fund == 'estremo' && c.fund.abs() < 0.03) return false;
      return true;
    }).toList();
    int cmp(Contract a, Contract b) {
      final v = switch (_sort) {
        'sym' => a.sym.compareTo(b.sym),
        'px' => a.px.compareTo(b.px),
        'chg' => a.chg.compareTo(b.chg),
        'c7d' => (a.chg7d ?? -1e9).compareTo(b.chg7d ?? -1e9),
        'fund' => a.fund.compareTo(b.fund),
        'oi' => a.oiUsd.compareTo(b.oiUsd),
        'mcap' => (a.mcap ?? -1).compareTo(b.mcap ?? -1),
        'lev' => a.lev.compareTo(b.lev),
        'cat' => a.cat.compareTo(b.cat),
        _ => a.turn.compareTo(b.turn),
      };
      return _sortAsc ? v : -v;
    }
    out.sort(cmp);
    return out;
  }

  void _tapSort(String k) => setState(() {
        if (_sort == k) {
          _sortAsc = !_sortAsc;
        } else {
          _sort = k;
          _sortAsc = false;
        }
      });

  @override
  Widget build(BuildContext context) {
    final st = MarketState.I;
    final rows = _filtered;
    return Scaffold(
      appBar: AppBar(
        title: const Text('KuCoin futures'),
        actions: [
          if (st.catLoading)
            const Padding(
              padding: EdgeInsets.all(14),
              child: SizedBox(width: 16, height: 16,
                  child: CircularProgressIndicator(strokeWidth: 2))),
          IconButton(
              icon: const Icon(Icons.refresh),
              onPressed: () => st.refresh()),
        ],
      ),
      body: Column(children: [
        _filters(),
        _sortBar(),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
          child: Row(children: [
            Text('${rows.length} mercati',
                style: const TextStyle(color: Colors.grey, fontSize: 12)),
            const Spacer(),
            Text(st.error ?? '',
                style: const TextStyle(color: Colors.red, fontSize: 11)),
          ]),
        ),
        Expanded(
          child: st.loading
              ? const Center(child: CircularProgressIndicator())
              : ListView.builder(
                  itemCount: rows.length,
                  itemBuilder: (_, i) => _row(rows[i]),
                ),
        ),
      ]),
    );
  }

  Widget _filters() => SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
        child: Row(children: [
          SizedBox(
            width: 130,
            height: 36,
            child: TextField(
              controller: _q,
              style: const TextStyle(fontSize: 13),
              decoration: const InputDecoration(
                  hintText: 'cerca', isDense: true,
                  border: OutlineInputBorder()),
              onChanged: (_) => setState(() {}),
            ),
          ),
          const SizedBox(width: 8),
          _dd('turn', {
            '0': '≥0', '1e6': '≥1M', '5e6': '≥5M',
            '2e7': '≥20M', '1e8': '≥100M'
          }, '$_minTurn', (v) => _minTurn = double.parse(v)),
          _dd('|24h|', {
            '0': '≥0%', '3': '≥3%', '5': '≥5%',
            '10': '≥10%', '20': '≥20%'
          }, '$_minChg', (v) => _minChg = double.parse(v)),
          _dd('mcap', {
            '0': 'tutte', '1e6': '<1M', '5e6': '<5M',
            '1e7': '<10M', '1e8': '<100M'
          }, '$_mcapLim', (v) => _mcapLim = double.parse(v)),
          _dd('lev', {
            '0': '≥0', '10': '≥10', '25': '≥25',
            '50': '≥50', '100': '≥100'
          }, '$_minLev', (v) => _minLev = int.parse(v)),
          _dd('fund', {
            'tutti': 'tutti', '>0': '>0', '<0': '<0',
            'estremo': 'estremo'
          }, _fund, (v) => _fund = v),
          _dd('OI', {
            '0': '≥0', '1e6': '≥1M', '1e7': '≥10M', '5e7': '≥50M'
          }, '$_minOi', (v) => _minOi = double.parse(v)),
          _dd('cat', {for (final c in cats) c: c}, _cat,
              (v) => _cat = v),
          const SizedBox(width: 4),
          FilterChip(
            label: const Text('★'),
            selected: _onlyFav,
            onSelected: (v) => setState(() => _onlyFav = v),
          ),
        ]),
      );

  Widget _dd(String lbl, Map<String, String> opts, String val,
          void Function(String) set) =>
      Padding(
        padding: const EdgeInsets.only(right: 6),
        child: DropdownButton<String>(
          value: val,
          isDense: true,
          style: const TextStyle(fontSize: 12),
          items: [
            for (final e in opts.entries)
              DropdownMenuItem(
                  value: e.key, child: Text('$lbl ${e.value}'))
          ],
          onChanged: (v) => setState(() => set(v!)),
        ),
      );

  Widget _sortBar() => SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 8),
        child: Row(children: [
          for (final e in const {
            'sym': 'sym', 'cat': 'cat', 'px': 'prezzo',
            'chg': '24h%', 'c7d': '7d%', 'fund': 'fund',
            'turn': 'turn', 'oi': 'OI', 'mcap': 'mcap',
            'lev': 'lev'
          }.entries)
            Padding(
              padding: const EdgeInsets.only(right: 2),
              child: TextButton(
                style: TextButton.styleFrom(
                    padding: const EdgeInsets.symmetric(horizontal: 6),
                    minimumSize: Size.zero,
                    tapTargetSize:
                        MaterialTapTargetSize.shrinkWrap),
                onPressed: () => _tapSort(e.key),
                child: Text(
                  '${e.value}${_sort == e.key ? (_sortAsc ? '▲' : '▼') : ''}',
                  style: TextStyle(
                      fontSize: 11,
                      color: _sort == e.key
                          ? Colors.lightBlueAccent
                          : Colors.grey),
                ),
              ),
            ),
        ]),
      );

  Widget _row(Contract c) {
    Color chgC(double v) =>
        v >= 0 ? const Color(0xFF4CAF50) : const Color(0xFFF44336);
    return InkWell(
      onTap: () => Navigator.pushNamed(context, '/chart',
          arguments: c.sym),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
        child: Row(children: [
          GestureDetector(
            onTap: () => MarketState.I.toggleFav(c.sym),
            child: Icon(c.fav ? Icons.star : Icons.star_border,
                size: 18,
                color: c.fav ? Colors.amber : Colors.grey),
          ),
          const SizedBox(width: 6),
          SizedBox(
            width: 105,
            child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(c.pretty,
                      style: const TextStyle(fontSize: 13)),
                  Text(c.cat,
                      style: const TextStyle(
                          fontSize: 10, color: Colors.grey)),
                ]),
          ),
          Expanded(
            flex: 3,
            child: Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(_px(c.px),
                      style: const TextStyle(fontSize: 13)),
                  Text('OI ${_usd(c.oiUsd)}  mc ${_usd(c.mcap)}',
                      style: const TextStyle(
                          fontSize: 10, color: Colors.grey)),
                ]),
          ),
          Expanded(
            flex: 2,
            child: Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text('${c.chg >= 0 ? '+' : ''}${c.chg.toStringAsFixed(2)}%',
                      style: TextStyle(
                          fontSize: 13,
                          color: chgC(c.chg),
                          fontWeight: FontWeight.bold)),
                  Text(
                      c.chg7d == null
                          ? '7d —'
                          : '7d ${c.chg7d! >= 0 ? '+' : ''}${c.chg7d!.toStringAsFixed(1)}%',
                      style: TextStyle(
                          fontSize: 11,
                          color: c.chg7d == null
                              ? Colors.grey
                              : chgC(c.chg7d!))),
                ]),
          ),
          const SizedBox(width: 6),
          Column(crossAxisAlignment: CrossAxisAlignment.end,
              children: [
            Text(_usd(c.turn),
                style: const TextStyle(
                    fontSize: 11, color: Colors.grey)),
            Text(
                '${c.fund >= 0 ? '+' : ''}${c.fund.toStringAsFixed(3)}%',
                style: TextStyle(
                    fontSize: 10,
                    color: c.fund.abs() >= 0.03
                        ? Colors.pinkAccent
                        : Colors.grey)),
          ]),
        ]),
      ),
    );
  }

  static String _px(double v) {
    if (v >= 1000) return v.toStringAsFixed(0);
    if (v >= 1) return v.toStringAsFixed(2);
    return v.toStringAsFixed(5);
  }

  static String _usd(double? v) {
    if (v == null) return '—';
    if (v >= 1e9) return '${(v / 1e9).toStringAsFixed(2)}B';
    if (v >= 1e6) return '${(v / 1e6).toStringAsFixed(0)}M';
    return '${(v / 1e3).toStringAsFixed(0)}k';
  }
}
