import 'dart:async';
import 'package:flutter/material.dart';
import 'package:candlesticks/candlesticks.dart';
import 'market.dart';

class ChartScreen extends StatefulWidget {
  const ChartScreen({super.key});
  @override
  State<ChartScreen> createState() => _ChartScreenState();
}

class _ChartScreenState extends State<ChartScreen> {
  static const grans = {
    '1m': 1, '5m': 5, '15m': 15, '30m': 30, '1h': 60,
    '2h': 120, '4h': 240, '1d': 1440, '1w': 10080,
  };

  String sym = '';
  int gran = 60;
  List<Candle> candles = [];
  bool loading = true;
  String? err;
  Timer? _timer;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final arg = ModalRoute.of(context)?.settings.arguments;
    if (arg is String && sym.isEmpty) {
      sym = arg;
      _load();
      _timer = Timer.periodic(
          const Duration(seconds: 30), (_) => _load(quiet: true));
    }
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  Future<void> _load({bool quiet = false}) async {
    if (!quiet) setState(() { loading = true; err = null; });
    try {
      final ks = await MarketApi.fetchKlines(sym, gran)
          .timeout(const Duration(seconds: 60));
      if (!mounted) return;
      setState(() {
        candles = [
          for (final k in ks)
            Candle(
              date: DateTime.fromMillisecondsSinceEpoch(k[0].toInt(),
                  isUtc: true),
              open: k[1].toDouble(), high: k[2].toDouble(),
              low: k[3].toDouble(), close: k[4].toDouble(),
              volume: k[5].toDouble(),
            )
        ];
        loading = false;
        if (ks.isEmpty) err = 'nessun dato da KuCoin';
      });
    } catch (e) {
      if (!mounted) return;
      final s = '$e';
      setState(() {
        loading = false;
        err = s.contains('Socket') ||
                s.contains('host') ||
                s.contains('Connection') ||
                s.contains('Timeout')
            ? 'rete offline / KuCoin irraggiungibile'
            : 'errore: $e';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(sym.replaceAll('XBT', 'BTC'))),
      body: Column(children: [
        SizedBox(
          height: 44,
          child: ListView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 8),
            children: [
              for (final e in grans.entries)
                Padding(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 3, vertical: 6),
                  child: ChoiceChip(
                    label: Text(e.key,
                        style: const TextStyle(fontSize: 12)),
                    selected: gran == e.value,
                    onSelected: (_) {
                      setState(() => gran = e.value);
                      _load();
                    },
                  ),
                ),
            ],
          ),
        ),
        Expanded(
          child: loading
              ? const Center(child: CircularProgressIndicator())
              : err != null
                  ? Center(
                      child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(err!,
                                style: const TextStyle(
                                    color: Colors.redAccent)),
                            TextButton(
                                onPressed: _load,
                                child: const Text('riprova')),
                          ]))
                  : Candlesticks(candles: candles),
        ),
      ]),
    );
  }
}
