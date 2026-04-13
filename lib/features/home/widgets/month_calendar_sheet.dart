import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:table_calendar/table_calendar.dart';

import '../../race/providers/race_providers.dart';

const Color _kBg = Color(0xFF0D1117);
const Color _kCard = Color(0xFF161B22);
const Color _kPrimary = Color(0xFF1565C0);
const Color _kGold = Color(0xFFFBBF24);

/// 한글 요일 헤더 (월~일, [weekday] 1=월 … 7=일)
String _koreanDowLabel(int weekday) {
  const names = ['월', '화', '수', '목', '금', '토', '일'];
  if (weekday < 1 || weekday > 7) return '';
  return names[weekday - 1];
}

class MonthCalendarSheet extends ConsumerStatefulWidget {
  const MonthCalendarSheet({super.key, required this.initialDay});

  final DateTime initialDay;

  @override
  ConsumerState<MonthCalendarSheet> createState() =>
      _MonthCalendarSheetState();
}

class _MonthCalendarSheetState extends ConsumerState<MonthCalendarSheet> {
  late DateTime _focused;
  late DateTime _selected;

  @override
  void initState() {
    super.initState();
    final d = widget.initialDay;
    _focused = DateTime(d.year, d.month, d.day);
    _selected = _focused;
  }

  bool _hasRace(String ymd, Set<String> dates) => dates.contains(ymd);

  @override
  Widget build(BuildContext context) {
    final raceDatesAsync = ref.watch(
      monthRaceDatesProvider((year: _focused.year, month: _focused.month)),
    );
    final raceDates =
        raceDatesAsync.maybeWhen(data: (s) => s, orElse: () => <String>{});

    return Container(
      decoration: const BoxDecoration(
        color: _kBg,
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      padding: EdgeInsets.only(
        left: 16,
        right: 16,
        top: 16,
        bottom: 16 + MediaQuery.paddingOf(context).bottom,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.2),
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(height: 16),
          Text(
            '${_focused.year}년 ${_focused.month}월',
            style: const TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.w700,
              fontSize: 18,
            ),
          ),
          const SizedBox(height: 12),
          Material(
            color: _kCard,
            borderRadius: BorderRadius.circular(14),
            child: Padding(
              padding: const EdgeInsets.all(8),
              child: TableCalendar<void>(
                firstDay: DateTime.utc(2018, 1, 1),
                lastDay: DateTime.utc(2035, 12, 31),
                focusedDay: _focused,
                selectedDayPredicate: (day) => isSameDay(_selected, day),
                onDaySelected: (selected, focused) {
                  setState(() {
                    _selected = selected;
                    _focused = focused;
                  });
                  ref.read(selectedDateProvider.notifier).state =
                      DateTime(selected.year, selected.month, selected.day);
                  Navigator.of(context).pop();
                },
                onPageChanged: (focused) {
                  setState(() => _focused = focused);
                },
                startingDayOfWeek: StartingDayOfWeek.monday,
                weekendDays: const [DateTime.sunday],
                calendarFormat: CalendarFormat.month,
                availableGestures: AvailableGestures.all,
                headerVisible: false,
                daysOfWeekStyle: DaysOfWeekStyle(
                  weekdayStyle: TextStyle(
                    color: Colors.white.withValues(alpha: 0.5),
                    fontSize: 12,
                  ),
                  weekendStyle: TextStyle(
                    color: Colors.white.withValues(alpha: 0.5),
                    fontSize: 12,
                  ),
                ),
                calendarStyle: CalendarStyle(
                  outsideDaysVisible: true,
                  cellMargin: const EdgeInsets.all(4),
                  defaultDecoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(8),
                  ),
                  weekendDecoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(8),
                  ),
                  selectedDecoration: BoxDecoration(
                    color: _kPrimary,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  todayDecoration: BoxDecoration(
                    border: Border.all(color: Colors.orange, width: 1.5),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  selectedTextStyle: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w700,
                  ),
                  defaultTextStyle: const TextStyle(color: Colors.white),
                  weekendTextStyle: TextStyle(
                    color: Colors.lightBlue.shade100,
                  ),
                  outsideTextStyle: TextStyle(
                    color: Colors.white.withValues(alpha: 0.25),
                  ),
                  todayTextStyle: const TextStyle(
                    color: Colors.orange,
                    fontWeight: FontWeight.w700,
                  ),
                  markersMaxCount: 1,
                  markerDecoration: const BoxDecoration(
                    color: _kGold,
                    shape: BoxShape.circle,
                  ),
                ),
                calendarBuilders: CalendarBuilders<void>(
                  dowBuilder: (context, day) {
                    return Center(
                      child: Text(
                        _koreanDowLabel(day.weekday),
                        style: TextStyle(
                          color: Colors.white.withValues(alpha: 0.65),
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    );
                  },
                  markerBuilder: (context, day, events) {
                    final ymd = dateToYmd(day);
                    if (!_hasRace(ymd, raceDates)) return null;
                    return Positioned(
                      bottom: 4,
                      child: Container(
                        width: 6,
                        height: 6,
                        decoration: const BoxDecoration(
                          color: _kGold,
                          shape: BoxShape.circle,
                        ),
                      ),
                    );
                  },
                ),
              ),
            ),
          ),
          const SizedBox(height: 12),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                width: 8,
                height: 8,
                decoration: const BoxDecoration(
                  color: _kGold,
                  shape: BoxShape.circle,
                ),
              ),
              const SizedBox(width: 8),
              Text(
                '경주 있는 날',
                style: TextStyle(
                  color: Colors.white.withValues(alpha: 0.7),
                  fontSize: 12,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
