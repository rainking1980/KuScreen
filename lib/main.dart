import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'package:shared_preferences/shared_preferences.dart';
import 'market.dart';
import 'market_screen.dart';
import 'chart_screen.dart';

void main() => runApp(const App());

class App extends StatelessWidget {
  const App({super.key});
  @override
  Widget build(BuildContext context) => MaterialApp(
        title: 'KuCoin Screener',
        debugShowCheckedModeBanner: false,
        theme: ThemeData.dark(useMaterial3: true).copyWith(
          colorScheme: ColorScheme.fromSeed(
              seedColor: Colors.lightBlue,
              brightness: Brightness.dark),
          scaffoldBackgroundColor: const Color(0xFF121212),
        ),
        home: const MarketScreen(),
        routes: {'/chart': (_) => const ChartScreen()},
      );
}

/// Stato condiviso tra le schermate: contratti, categorie, preferiti.
class MarketState extends ChangeNotifier {
  List<Contract> rows = [];
  Set<String> favs = {};
  bool loading = true;
  String? error;
  DateTime? catUpdated;
  bool catLoading = false;

  static final MarketState I = MarketState._();
  MarketState._() {
    _boot();
  }

  Future<void> _boot() async {
    final p = await SharedPreferences.getInstance();
    favs = (p.getStringList('favs') ?? []).toSet();
    await _loadCatCache(p);
    if (_catMap.isEmpty) await _loadCatAsset();
    await refresh();
    _refreshCategoriesIfStale(p);
  }

  /// Snapshot categorie/mcap incluso nell'APK: primo avvio istantaneo.
  Future<void> _loadCatAsset() async {
    try {
      final raw = await rootBundle.loadString('assets/catmap.json');
      final d = jsonDecode(raw) as Map;
      _catMap = {
        for (final e in (d['m'] as Map).entries)
          e.key: {'cat': e.value[0], 'mcap': e.value[1]}
      };
      catUpdated =
          DateTime.fromMillisecondsSinceEpoch((d['t'] * 1000).toInt());
    } catch (_) {}
  }

  Future<void> refresh() async {
    try {
      rows = await MarketApi.fetchContracts();
      error = null;
      for (final c in rows) {
        c.fav = favs.contains(c.sym);
        c.cat = _catOf(c.base);
        c.mcap = _mcapOf(c.base);
      }
      unawaited(_refresh7d());
      unawaited(_refreshMcap());
    } catch (e) {
      final s = '$e';
      error = s.contains('Socket') ||
              s.contains('host') ||
              s.contains('Connection') ||
              s.contains('Timeout')
          ? 'rete offline / KuCoin irraggiungibile'
          : s;
    }
    loading = false;
    notifyListeners();
  }

  // ---- 7d%: posticipato e gentile per non saturare la rete del
  // telefono mentre l'utente naviga (il fetch completo e' 700+ req)
  bool _fetch7dDone = false;
  Future<void> _refresh7d() async {
    if (_fetch7dDone) return;
    _fetch7dDone = true;
    await Future.delayed(const Duration(seconds: 20));
    final m = await MarketApi.fetch7d(
        rows.map((c) => c.sym).toList(), workers: 3);
    for (final c in rows) {
      c.chg7d = m[c.sym];
    }
    notifyListeners();
  }

  // ---- mcap da CoinPaprika: 1 req leggera, sempre fresca -------------
  bool _mcapDone = false;
  Future<void> _refreshMcap() async {
    if (_mcapDone) return;
    _mcapDone = true;
    final m = await MarketApi.fetchMcaps();
    if (m.isEmpty) return;
    for (final c in rows) {
      c.mcap = m[c.base.toUpperCase()] ?? c.mcap;
    }
    notifyListeners();
  }

  // ---- categorie/mcap cache su disco (72h) -----------------------------
  Map<String, Map<String, dynamic>> _catMap = {};

  Future<void> _loadCatCache(SharedPreferences p) async {
    final raw = p.getString('catMap');
    final t = p.getInt('catMapT') ?? 0;
    if (raw != null &&
        DateTime.now().millisecondsSinceEpoch - t < 72 * 3600000) {
      _catMap = {for (final e in (jsonDecode(raw) as Map).entries)
          e.key: Map<String, dynamic>.from(e.value)};
      catUpdated = DateTime.fromMillisecondsSinceEpoch(t);
    }
  }

  Future<void> _refreshCategoriesIfStale(SharedPreferences p) async {
    final t = p.getInt('catMapT') ?? 0;
    if (DateTime.now().millisecondsSinceEpoch - t < 12 * 3600000) {
      return;
    }
    catLoading = true;
    notifyListeners();
    try {
      _catMap = await CategoryService.fetchAll();
      await p.setString('catMap', jsonEncode(_catMap));
      await p.setInt(
          'catMapT', DateTime.now().millisecondsSinceEpoch);
      catUpdated = DateTime.now();
      for (final c in rows) {
        c.cat = _catOf(c.base);
        c.mcap = _mcapOf(c.base);
      }
    } catch (_) {}
    catLoading = false;
    notifyListeners();
  }

  String _catOf(String base) =>
      (_catMap[base.toUpperCase()]?['cat'] as String?) ?? 'altro';
  double? _mcapOf(String base) =>
      (_catMap[base.toUpperCase()]?['mcap'] as num?)?.toDouble();

  Future<void> toggleFav(String sym) async {
    if (favs.contains(sym)) {
      favs.remove(sym);
    } else {
      favs.add(sym);
    }
    for (final c in rows) {
      if (c.sym == sym) c.fav = favs.contains(sym);
    }
    notifyListeners();
    final p = await SharedPreferences.getInstance();
    await p.setStringList('favs', favs.toList());
  }
}
