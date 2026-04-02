import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../models/odds.dart';

const Color _kPrimary = Color(0xFF1565C0);

/// 배당률 패널 (단승·복승·쌍승·삼복승·삼쌍승)
class OddsPanel extends StatelessWidget {
  final Odds odds;

  const OddsPanel({super.key, required this.odds});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _OddsSection(
          title: '단승',
          child: _WinGrid(odds.win),
        ),
        const SizedBox(height: 16),
        _OddsSection(
          title: '복승',
          child: _ComboMap(odds.place),
        ),
        const SizedBox(height: 16),
        _OddsSection(
          title: '쌍승',
          child: _ComboMap(odds.quinella),
        ),
        const SizedBox(height: 16),
        _OddsSection(
          title: '삼복승',
          child: _ComboMap(odds.trio),
        ),
        const SizedBox(height: 16),
        _OddsSection(
          title: '삼쌍승',
          child: _ComboMap(odds.trifecta),
        ),
      ],
    );
  }
}

class _OddsSection extends StatelessWidget {
  final String title;
  final Widget child;

  const _OddsSection({required this.title, required this.child});

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title,
              style: GoogleFonts.notoSansKr(
                fontSize: 15,
                fontWeight: FontWeight.w800,
                color: const Color(0xFFFBBF24),
              ),
            ),
            const SizedBox(height: 12),
            child,
          ],
        ),
      ),
    );
  }
}

class _WinGrid extends StatelessWidget {
  final Map<int, double> win;

  const _WinGrid(this.win);

  @override
  Widget build(BuildContext context) {
    if (win.isEmpty) {
      return _EmptyOdds();
    }
    final keys = win.keys.toList()..sort();
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: keys.map((k) {
        final v = win[k]!;
        return OddsChip(label: '$k코스', value: v);
      }).toList(),
    );
  }
}

class _ComboMap extends StatelessWidget {
  final Map<String, double> map;

  const _ComboMap(this.map);

  @override
  Widget build(BuildContext context) {
    if (map.isEmpty) {
      return _EmptyOdds();
    }
    final entries = map.entries.toList()
      ..sort((a, b) => a.key.compareTo(b.key));
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: entries.map((e) {
        return OddsChip(label: e.key, value: e.value);
      }).toList(),
    );
  }
}

class _EmptyOdds extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Text(
        '배당 정보 없음',
        style: GoogleFonts.notoSansKr(
          color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.55),
        ),
      ),
    );
  }
}

/// Primary 그라데이션 배경의 배당 칩
class OddsChip extends StatelessWidget {
  final String label;
  final double value;

  const OddsChip({
    super.key,
    required this.label,
    required this.value,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(12),
        gradient: LinearGradient(
          colors: [
            _kPrimary,
            _kPrimary.withValues(alpha: 0.75),
            const Color(0xFF0D47A1),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        boxShadow: [
          BoxShadow(
            color: _kPrimary.withValues(alpha: 0.35),
            blurRadius: 6,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            label,
            style: GoogleFonts.notoSansKr(
              fontSize: 11,
              fontWeight: FontWeight.w600,
              color: Colors.white.withValues(alpha: 0.9),
            ),
          ),
          const SizedBox(height: 2),
          Text(
            _formatOdds(value),
            style: GoogleFonts.notoSansKr(
              fontSize: 15,
              fontWeight: FontWeight.w800,
              color: Colors.white,
            ),
          ),
        ],
      ),
    );
  }

  String _formatOdds(double v) {
    if (v == v.roundToDouble()) return '${v.toInt()}배';
    return '${v.toStringAsFixed(1)}배';
  }
}
