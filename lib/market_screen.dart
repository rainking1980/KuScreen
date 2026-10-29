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
  String _minTurnK = '1e6';
  String _minChgK = '0';
  String _mcapK = '0';          // '0' = tutte
  int _minLev = 0;
  String _fund = 'tutti';
  String _minOiK = '0';
  String _cat = 'tutte';
  bool _onlyFav = false;
  bool _liqOnly = true;
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
      if (_liqOnly && c.turn < double.parse(_minTurnK)) return false;
      if (c.chg.abs() < double.parse(_minChgK)) return false;
      if (c.lev < _minLev) return false;
      if (c.oiUsd < double.parse(_minOiK)) return false;
      final ml = double.parse(_mcapK);
      if (ml > 0 && (c.mcap ?? 1e18) >= ml) return false;
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
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('KuCoin futures',
                style: TextStyle(fontSize: 18)),
            Text(
                st.updated == null
                    ? ''
                    : 'agg. ${st.updated!.hour.toString().padLeft(2, '0')}:'
                        '${st.updated!.minute.toString().padLeft(2, '0')}:'
                        '${st.updated!.second.toString().padLeft(2, '0')}',
                style: const TextStyle(
                    fontSize: 11, color: Colors.grey)),
          ],
        ),
        actions: [
          if (st.catLoading)
            const Padding(
              padding: EdgeInsets.all(14),
              child: SizedBox(width: 16, height: 16,
                  child: CircularProgressIndicator(strokeWidth: 2))),
          IconButton(
              icon: const Icon(Icons.info_outline,
                  color: Colors.lightBlueAccent),
              onPressed: _showLegend),
          IconButton(
              icon: const Icon(Icons.refresh),
              onPressed: () => st.refresh()),
        ],
      ),
      body: Column(children: [
        _catAverages(),
        Expanded(
          child: st.loading
              ? const Center(child: CircularProgressIndicator())
              : SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _filters(),
                      SizedBox(
                        width: _tableW,
                        child: Padding(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 8, vertical: 2),
                          child: Row(children: [
                            Text('${rows.length} mercati',
                                style: const TextStyle(
                                    color: Colors.grey,
                                    fontSize: 12)),
                            const Spacer(),
                            Text(st.error ?? '',
                                style: const TextStyle(
                                    color: Colors.red,
                                    fontSize: 11)),
                          ]),
                        ),
                      ),
                      SizedBox(
                        width: _tableW,
                        child: _header(),
                      ),
                      Expanded(
                        child: SizedBox(
                          width: _tableW,
                          child: ListView.builder(
                            itemCount: rows.length,
                            itemBuilder: (_, i) => _row(rows[i]),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
        ),
      ]),
    );
  }

  // (sortKey, label, width, allineaDx)
  static const _cols = [
    ('sym', 'sym', 100.0, false),
    ('cat', 'cat', 58.0, false),
    ('px', 'prezzo', 70.0, true),
    ('chg', '24h%', 60.0, true),
    ('c7d', '7d%', 56.0, true),
    ('fund', 'fund', 62.0, true),
    ('turn', 'vol', 64.0, true),
    ('oi', 'OI', 62.0, true),
    ('mcap', 'mcap', 68.0, true),
    ('lev', 'lev', 42.0, true),
  ];
  static const _starW = 30.0;
  static const _tableW = _starW + 704.0;

  Widget _header() => Container(
        height: 26,
        color: const Color(0xFF1E1E1E),
        child: Row(children: [
          const SizedBox(width: _starW),
          for (final (k, lbl, w, _) in _cols)
            GestureDetector(
              onTap: () => _tapSort(k),
              child: SizedBox(
                width: w,
                child: Text(
                  '$lbl${_sort == k ? (_sortAsc ? ' ▲' : ' ▼') : ''}',
                  textAlign: k == 'sym' || k == 'cat'
                      ? TextAlign.left
                      : TextAlign.right,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                      fontSize: 11,
                      color: _sort == k
                          ? Colors.lightBlueAccent
                          : Colors.grey),
                ),
              ),
            ),
        ]),
      );

  Widget _filters() => Padding(
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
          Row(children: [
            const Text('liq',
                style: TextStyle(fontSize: 11, color: Colors.grey)),
            Switch(
                value: _liqOnly,
                materialTapTargetSize:
                    MaterialTapTargetSize.shrinkWrap,
                onChanged: (v) => setState(() => _liqOnly = v)),
          ]),
          _dd('vol', {
            '0': '≥0', '1e6': '≥1M', '5e6': '≥5M',
            '2e7': '≥20M', '1e8': '≥100M'
          }, _minTurnK, (v) => _minTurnK = v),
          _dd('|24h|', {
            '0': '≥0%', '3': '≥3%', '5': '≥5%',
            '10': '≥10%', '20': '≥20%'
          }, _minChgK, (v) => _minChgK = v),
          _dd('mcap', {
            '0': 'tutte', '1e6': '<1M', '5e6': '<5M',
            '1e7': '<10M', '1e8': '<100M'
          }, _mcapK, (v) => _mcapK = v),
          _dd('lev', {
            '0': '≥0', '10': '≥10', '25': '≥25',
            '50': '≥50', '100': '≥100'
          }, '$_minLev', (v) => _minLev = int.parse(v)),
          _dd('fund', {
            'tutti': 'tutti', '>0': '>0', '<0': '<0',
            'estremo': 'extr'
          }, _fund, (v) => _fund = v),
          _dd('OI', {
            '0': '≥0', '1e6': '≥1M', '1e7': '≥10M', '5e7': '≥50M'
          }, _minOiK, (v) => _minOiK = v),
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

  Widget _catAverages() {
    // medie 24h%/7d% per categoria su TUTTI i mercati (breadth
    // settoriale: dove sta ruotando il denaro)
    final agg = <String, List<double>>{};
    for (final c in MarketState.I.rows) {
      final a = agg.putIfAbsent(c.cat, () => [0, 0, 0, 0]);
      a[0]++;
      a[1] += c.chg;
      if (c.chg7d != null) {
        a[2]++;
        a[3] += c.chg7d!;
      }
    }
    final keys = agg.keys.toList()
      ..sort((a, b) => agg[b]![1].compareTo(agg[a]![1]));
    Color cc(double v) => v >= 0
        ? const Color(0xFF4CAF50)
        : const Color(0xFFF44336);
    return ExpansionTile(
      dense: true,
      tilePadding: const EdgeInsets.symmetric(horizontal: 8),
      title: const Text('medie per categoria',
          style: TextStyle(fontSize: 12, color: Colors.grey)),
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(8, 0, 8, 8),
          child: Wrap(
            spacing: 8,
            runSpacing: 4,
            children: [
              for (final k in keys)
                Builder(builder: (_) {
                  final a = agg[k]!;
                  final m24 = a[1] / a[0];
                  final m7 = a[2] > 0 ? a[3] / a[2] : null;
                  return Text.rich(TextSpan(children: [
                    TextSpan(
                        text: '$k ${a[0].toInt()} ',
                        style: const TextStyle(
                            fontSize: 11, color: Colors.white)),
                    TextSpan(
                        text:
                            '${m24 >= 0 ? '+' : ''}${m24.toStringAsFixed(1)}%',
                        style: TextStyle(fontSize: 11, color: cc(m24))),
                    TextSpan(
                        text: m7 == null
                            ? ''
                            : ' / ${m7 >= 0 ? '+' : ''}${m7.toStringAsFixed(1)}%7d',
                        style: TextStyle(
                            fontSize: 11,
                            color: m7 == null
                                ? Colors.grey
                                : cc(m7))),
                  ]));
                }),
            ],
          ),
        ),
      ],
    );
  }

  Widget _dd(String lbl, Map<String, String> opts, String val,
          void Function(String) set) =>
      Padding(
        padding: const EdgeInsets.only(right: 6),
        child: DropdownButton<String>(
          value: val,
          isDense: true,
          dropdownColor: const Color(0xFF2A2A2A),
          iconEnabledColor: Colors.white,
          underline: const SizedBox(),
          style: const TextStyle(fontSize: 12, color: Colors.white),
          items: [
            for (final e in opts.entries)
              DropdownMenuItem(
                  value: e.key,
                  child: Text('$lbl ${e.value}',
                      style: const TextStyle(color: Colors.white)))
          ],
          onChanged: (v) => setState(() => set(v!)),
        ),
      );

  static const _legend = <(String, String)>[
    ('sym', "Il contratto futures perpetuo. XBT = bitcoin su KuCoin, "
        "il suffisso USDTM = marginato in USDT. Tap sulla riga "
        "per aprire il grafico a candele."),
    ('cat', "Settore della coin (CoinGecko): L1/L2 blockchain, Meme, "
        "AI, Gaming, DeFi, Privacy, RWA = real-world asset, "
        "DePIN = reti fisiche, Exchange = token di exchange."),
    ('prezzo', "Il mark price: il prezzo 'onesto' calcolato sugli "
        "index di riferimento. Liquidazioni e PnL si calcolano "
        "su questo, non sull'ultimo trade."),
    ('24h%', "Variazione del prezzo nelle ultime 24 ore."),
    ('7d%', "Variazione dell'ultima settimana (candele daily). "
        "24h verde + 7d rosso = rimbalzo in trend debole; "
        "entrambe verdi = momentum confermato."),
    ('fund', "Funding rate %/8h: chi sta dalla parte affollata paga "
        "l'altra. Positivo = i LONG pagano gli SHORT. In rosa "
        "quando estremo (≥0.03%): posizionamento sbilanciato, "
        "rischio squeeze."),
    ('vol', "Volume (turnover) 24h in dollari: quanta attività c'è. "
        "Sotto ~1M\$ slippage alto, sopra ~50M\$ liquido."),
    ('OI', "Open interest: dollari nelle posizioni aperte ora. "
        "OI che sale + prezzo che sale = trend forte; OI che "
        "scende = posizioni che chiudono (squeeze/liquidazioni)."),
    ('mcap', "Market cap totale della coin (prezzo × supply, "
        "da CoinPaprika/CoinGecko). Le piccole (<10M\$) sono "
        "le più volatili e manipolabili."),
    ('lev', "Leva massima consentita su KuCoin. Bassa = l'exchange "
        "considera il contratto rischioso."),
  ];

  void _showLegend() => showDialog(
        context: context,
        builder: (_) => AlertDialog(
          backgroundColor: const Color(0xFF1E1E1E),
          title: const Text('Legenda colonne',
              style: TextStyle(fontSize: 16)),
          content: SizedBox(
            width: double.maxFinite,
            child: ListView(
              shrinkWrap: true,
              children: [
                for (final (t, d) in _legend)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 10),
                    child: RichText(
                      text: TextSpan(children: [
                        TextSpan(
                            text: '$t — ',
                            style: const TextStyle(
                                fontWeight: FontWeight.bold,
                                color: Colors.white,
                                fontSize: 12)),
                        TextSpan(
                            text: d,
                            style: const TextStyle(
                                color: Colors.white70,
                                fontSize: 12)),
                      ]),
                    ),
                  ),
              ],
            ),
          ),
          actions: [
            TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('chiudi')),
          ],
        ),
      );

  Widget _cell(String txt, double w,
          {Color color = Colors.white,
          bool right = true,
          double fs = 11.5,
          bool bold = false}) =>
      SizedBox(
        width: w,
        child: Text(txt,
            textAlign: right ? TextAlign.right : TextAlign.left,
            overflow: TextOverflow.ellipsis,
            maxLines: 1,
            style: TextStyle(
                fontSize: fs,
                color: color,
                fontWeight:
                    bold ? FontWeight.bold : FontWeight.normal)),
      );

  Widget _row(Contract c) {
    Color chgC(double v) =>
        v >= 0 ? const Color(0xFF4CAF50) : const Color(0xFFF44336);
    return InkWell(
      onTap: () => Navigator.pushNamed(context, '/chart',
          arguments: c.sym),
      child: Container(
        height: 30,
        padding: const EdgeInsets.symmetric(horizontal: 4),
        child: Row(children: [
          SizedBox(
            width: _starW,
            child: GestureDetector(
              onTap: () => MarketState.I.toggleFav(c.sym),
              child: Icon(c.fav ? Icons.star : Icons.star_border,
                  size: 15,
                  color: c.fav ? Colors.amber : Colors.grey),
            ),
          ),
          _cell(c.pretty, 100,
              right: false,
              color: Colors.lightBlueAccent,
              fs: 12,
              bold: true),
          _cell(c.cat, 58, right: false, color: Colors.grey, fs: 10),
          _cell(_px(c.px), 70),
          _cell('${c.chg >= 0 ? '+' : ''}${c.chg.toStringAsFixed(2)}',
              60,
              color: chgC(c.chg), bold: true),
          _cell(
              c.chg7d == null
                  ? '—'
                  : '${c.chg7d! >= 0 ? '+' : ''}${c.chg7d!.toStringAsFixed(1)}',
              56,
              color: c.chg7d == null ? Colors.grey : chgC(c.chg7d!)),
          _cell('${c.fund >= 0 ? '+' : ''}${c.fund.toStringAsFixed(3)}',
              62,
              color: c.fund.abs() >= 0.03
                  ? Colors.pinkAccent
                  : Colors.grey),
          _cell(_usd(c.turn), 64, color: Colors.grey),
          _cell(_usd(c.oiUsd), 62, color: Colors.grey),
          _cell(_usd(c.mcap), 68, color: Colors.grey),
          _cell('${c.lev}', 42, color: Colors.grey),
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
