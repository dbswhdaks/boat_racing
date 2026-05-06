import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../models/prediction.dart';
import '../../../models/race_entry.dart';
import '../providers/race_providers.dart';

/// "나의 선택" 위젯 — 경정 1~3착 슬롯에 코스번호를 등록/저장(SharedPreferences).
/// 슬롯을 탭하면 하단에 출주 코스 목록이 펼쳐지며, 길게 누르면 해당 슬롯이 비워진다.
class MyPickRecommender extends ConsumerStatefulWidget {
  const MyPickRecommender({
    super.key,
    required this.date,
    required this.raceNo,
    this.horizontalMargin = 16,
  });

  final String date;
  final int raceNo;
  final double horizontalMargin;

  @override
  ConsumerState<MyPickRecommender> createState() => _MyPickRecommenderState();
}

class _MyPickRecommenderState extends ConsumerState<MyPickRecommender> {
  static const _slotCount = 3;
  static const _slotLabels = ['1착', '2착', '3착'];
  static const _slotColors = [
    Color(0xFFFFD700), // 1착 - 골드
    Color(0xFF9CA3AF), // 2착 - 실버
    Color(0xFFCD7F32), // 3착 - 브론즈
  ];

  List<int?> _slots = List.filled(_slotCount, null);
  bool _loaded = false;
  int? _activeSlot;

  String get _storageKey => 'picks_${widget.date}_${widget.raceNo}';

  Set<int> get _selectedSet => _slots.whereType<int>().toSet();

  @override
  void initState() {
    super.initState();
    _loadPicks();
  }

  @override
  void didUpdateWidget(covariant MyPickRecommender old) {
    super.didUpdateWidget(old);
    if (old.date != widget.date || old.raceNo != widget.raceNo) {
      _loadPicks();
    }
  }

  Future<void> _loadPicks() async {
    final prefs = await SharedPreferences.getInstance();
    final saved = prefs.getStringList(_storageKey);
    if (saved != null && mounted) {
      final loaded = List<int?>.filled(_slotCount, null);
      for (var i = 0; i < saved.length && i < _slotCount; i++) {
        loaded[i] = int.tryParse(saved[i]);
      }
      setState(() {
        _slots = loaded;
        _loaded = true;
      });
    } else if (mounted) {
      setState(() => _loaded = true);
    }
  }

  Future<void> _savePicks() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList(
      _storageKey,
      _slots.map((n) => n?.toString() ?? '').toList(),
    );
  }

  void _onTapSlot(int slotIdx) {
    setState(() {
      _activeSlot = _activeSlot == slotIdx ? null : slotIdx;
    });
  }

  void _onPickNumber(int courseNo) {
    if (_activeSlot == null) return;
    setState(() {
      final prevIdx = _slots.indexOf(courseNo);
      if (prevIdx >= 0) _slots[prevIdx] = null;
      _slots[_activeSlot!] = courseNo;
      _activeSlot = null;
    });
    _savePicks();
  }

  void _onClearSlot(int slotIdx) {
    setState(() {
      _slots[slotIdx] = null;
      if (_activeSlot == slotIdx) _activeSlot = null;
    });
    _savePicks();
  }

  void _onClearAll() {
    setState(() {
      _slots = List.filled(_slotCount, null);
      _activeSlot = null;
    });
    _savePicks();
  }

  String _racerName(List<RaceEntry> entries, int courseNo) {
    return entries
            .where((e) => e.courseNo == courseNo)
            .firstOrNull
            ?.racerName ??
        '';
  }

  double? _winProb(RacePrediction? prediction, int courseNo) {
    if (prediction == null) return null;
    return prediction.rankings
        .where((r) => r.courseNo == courseNo)
        .firstOrNull
        ?.winProb;
  }

  @override
  Widget build(BuildContext context) {
    final params = (date: widget.date, raceNo: widget.raceNo);
    final entriesAsync = ref.watch(raceEntriesProvider(params));
    final predictionAsync = ref.watch(predictionProvider(params));
    final isSubscribed = ref.watch(isSubscribedProvider);

    final List<RaceEntry> entries = entriesAsync.valueOrNull?.data ?? const [];
    final RacePrediction? prediction = predictionAsync.valueOrNull;

    final allCourseNos = entries.map((e) => e.courseNo).toList()..sort();
    if (allCourseNos.isEmpty || !_loaded) return const SizedBox.shrink();
    final hasAny = _selectedSet.isNotEmpty;

    return Container(
      margin: EdgeInsets.symmetric(horizontal: widget.horizontalMargin),
      padding: const EdgeInsets.fromLTRB(14, 14, 14, 12),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF0D2A4F), Color(0xFF0F1B30)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: const Color(0xFF1565C0).withValues(alpha: 0.5),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(
                Icons.casino_rounded,
                color: Color(0xFFFBBF24),
                size: 20,
              ),
              const SizedBox(width: 8),
              const Expanded(
                child: Text(
                  '나의 선택',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w900,
                    color: Colors.white,
                  ),
                ),
              ),
              if (hasAny)
                GestureDetector(
                  onTap: _onClearAll,
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 5,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.08),
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: const Text(
                      '초기화',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                        color: Colors.white54,
                      ),
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            _activeSlot != null
                ? '${_slotLabels[_activeSlot!]}에 넣을 코스를 선택하세요'
                : '착순을 탭하여 코스 번호를 등록하세요',
            style: TextStyle(fontSize: 12, color: Colors.grey.shade500),
          ),
          const SizedBox(height: 14),
          Row(
            children: List.generate(_slotCount, (i) {
              final no = _slots[i];
              final color = _slotColors[i];
              final filled = no != null;
              final isActive = _activeSlot == i;

              return Expanded(
                child: Padding(
                  padding: EdgeInsets.only(left: i > 0 ? 8 : 0),
                  child: GestureDetector(
                    onTap: () => _onTapSlot(i),
                    onLongPress: filled ? () => _onClearSlot(i) : null,
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 200),
                      height: 68,
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(12),
                        color: isActive
                            ? color.withValues(alpha: 0.25)
                            : filled
                                ? color.withValues(alpha: 0.15)
                                : Colors.white.withValues(alpha: 0.04),
                        border: Border.all(
                          color: isActive
                              ? color
                              : filled
                                  ? color.withValues(alpha: 0.6)
                                  : Colors.white.withValues(alpha: 0.1),
                          width: isActive
                              ? 2
                              : filled
                                  ? 1.5
                                  : 1,
                        ),
                      ),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text(
                            _slotLabels[i],
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w700,
                              color: isActive || filled
                                  ? color
                                  : Colors.grey.shade600,
                            ),
                          ),
                          const SizedBox(height: 4),
                          if (filled)
                            Text(
                              '$no',
                              style: TextStyle(
                                fontSize: 22,
                                fontWeight: FontWeight.w900,
                                color: color,
                              ),
                            )
                          else
                            Icon(
                              isActive
                                  ? Icons.touch_app_rounded
                                  : Icons.add_rounded,
                              size: 20,
                              color: isActive ? color : Colors.grey.shade700,
                            ),
                        ],
                      ),
                    ),
                  ),
                ),
              );
            }),
          ),
          AnimatedSize(
            duration: const Duration(milliseconds: 250),
            curve: Curves.easeInOut,
            child: _activeSlot != null
                ? Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const SizedBox(height: 12),
                      SizedBox(
                        height: 84,
                        child: ListView.separated(
                          scrollDirection: Axis.horizontal,
                          itemCount: allCourseNos.length,
                          separatorBuilder: (_, __) => const SizedBox(width: 8),
                          itemBuilder: (context, index) {
                            final no = allCourseNos[index];
                            final alreadyUsed = _selectedSet.contains(no);
                            final prob = isSubscribed
                                ? _winProb(prediction, no)
                                : null;
                            final name = _racerName(entries, no);
                            final activeColor = _slotColors[_activeSlot!];

                            return GestureDetector(
                              onTap: () => _onPickNumber(no),
                              child: AnimatedContainer(
                                duration: const Duration(milliseconds: 150),
                                width: 64,
                                decoration: BoxDecoration(
                                  borderRadius: BorderRadius.circular(14),
                                  color: alreadyUsed
                                      ? Colors.white.withValues(alpha: 0.03)
                                      : activeColor.withValues(alpha: 0.08),
                                  border: Border.all(
                                    color: alreadyUsed
                                        ? Colors.white.withValues(alpha: 0.06)
                                        : activeColor.withValues(alpha: 0.4),
                                  ),
                                ),
                                child: Column(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Text(
                                      '$no',
                                      style: TextStyle(
                                        fontSize: 20,
                                        fontWeight: FontWeight.w900,
                                        color: alreadyUsed
                                            ? Colors.grey.shade700
                                            : Colors.white,
                                      ),
                                    ),
                                    const SizedBox(height: 2),
                                    Text(
                                      name.length > 4
                                          ? '${name.substring(0, 4)}..'
                                          : name,
                                      style: TextStyle(
                                        fontSize: 10,
                                        color: alreadyUsed
                                            ? Colors.grey.shade700
                                            : Colors.grey.shade400,
                                      ),
                                    ),
                                    if (prob != null)
                                      Text(
                                        '${prob.toStringAsFixed(1)}%',
                                        style: TextStyle(
                                          fontSize: 9,
                                          fontWeight: FontWeight.w600,
                                          color: alreadyUsed
                                              ? Colors.grey.shade800
                                              : activeColor.withValues(
                                                  alpha: 0.85,
                                                ),
                                        ),
                                      ),
                                  ],
                                ),
                              ),
                            );
                          },
                        ),
                      ),
                    ],
                  )
                : const SizedBox.shrink(),
          ),
          if (hasAny) ...[
            const SizedBox(height: 8),
            Center(
              child: Text(
                '착순 탭: 코스 변경 · 길게 누르기: 해제',
                style: TextStyle(fontSize: 10, color: Colors.grey.shade600),
              ),
            ),
          ],
        ],
      ),
    );
  }
}
