import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../core/supabase_client.dart';
import '../../core/theme.dart';
import '../../shared/widgets.dart';

class ShiftScheduleScreen extends StatefulWidget {
  const ShiftScheduleScreen({super.key});

  @override
  State<ShiftScheduleScreen> createState() => _ShiftScheduleScreenState();
}

class _ShiftScheduleScreenState extends State<ShiftScheduleScreen> {
  static const _days = [
    'monday', 'tuesday', 'wednesday', 'thursday', 'friday', 'saturday', 'sunday'
  ];
  static const _dayLabels = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
  static const _shifts = ['morning', 'lunch', 'afternoon', 'evening'];
  static const _shiftTimes = ['6am-10am', '10am-2pm', '2pm-6pm', '6pm-10pm'];

  Map<String, Set<String>> _schedule = {};
  bool _loading = true;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _loadSchedule();
  }

  Future<void> _loadSchedule() async {
    final userId = SupabaseService.currentUserId;
    if (userId == null) return;

    final data = await SupabaseService.client
        .from('rider_shifts')
        .select()
        .eq('rider_id', userId);

    final schedule = <String, Set<String>>{};
    for (final row in data) {
      final day = row['day'] as String;
      final shift = row['shift'] as String;
      schedule.putIfAbsent(day, () => {}).add(shift);
    }

    if (mounted) {
      setState(() {
        _schedule = schedule;
        _loading = false;
      });
    }
  }

  void _toggle(String day, String shift) {
    setState(() {
      _schedule.putIfAbsent(day, () => {});
      if (_schedule[day]!.contains(shift)) {
        _schedule[day]!.remove(shift);
      } else {
        _schedule[day]!.add(shift);
      }
    });
  }

  Future<void> _saveSchedule() async {
    final userId = SupabaseService.currentUserId;
    if (userId == null) return;

    setState(() => _saving = true);

    await SupabaseService.client
        .from('rider_shifts')
        .delete()
        .eq('rider_id', userId);

    final rows = <Map<String, dynamic>>[];
    for (final day in _days) {
      for (final shift in _schedule[day] ?? <String>{}) {
        rows.add({'rider_id': userId, 'day': day, 'shift': shift});
      }
    }

    if (rows.isNotEmpty) {
      await SupabaseService.client.from('rider_shifts').insert(rows);
    }

    if (mounted) {
      setState(() => _saving = false);
      showSugoBaySnackBar(context, 'Shift schedule saved!');
    }
  }

  @override
  Widget build(BuildContext context) {
    final c = context.sc;

    return Scaffold(
      backgroundColor: c.bg,
      appBar: AppBar(
        backgroundColor: c.cardBg,
        title: Text('My Shift Schedule',
            style: GoogleFonts.plusJakartaSans(
              fontSize: 18,
              fontWeight: FontWeight.w600,
              color: c.textPrimary,
            )),
        iconTheme: const IconThemeData(color: SColors.primary),
      ),
      body: _loading
          ? const Center(
              child: CircularProgressIndicator(color: SColors.primary))
          : Column(
              children: [
                Expanded(
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Tap to toggle your availability',
                            style: GoogleFonts.plusJakartaSans(
                                fontSize: 13, color: c.textTertiary)),
                        const SizedBox(height: 16),
                        _buildGrid(c),
                        const SizedBox(height: 24),
                        _buildLegend(c),
                      ],
                    ),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.all(16),
                  child: SugoBayButton(
                    text: _saving ? 'Saving...' : 'Save Schedule',
                    onPressed: _saving ? () {} : () => _saveSchedule(),
                  ),
                ),
              ],
            ),
    );
  }

  Widget _buildGrid(SugoColors c) {
    return SugoBayCard(
      child: Column(
        children: [
          Row(
            children: [
              const SizedBox(width: 60),
              ...List.generate(
                  _days.length,
                  (i) => Expanded(
                        child: Center(
                          child: Text(_dayLabels[i],
                              style: GoogleFonts.plusJakartaSans(
                                fontSize: 11,
                                fontWeight: FontWeight.bold,
                                color: SColors.primary,
                              )),
                        ),
                      )),
            ],
          ),
          const SizedBox(height: 8),
          ...List.generate(_shifts.length, (si) {
            return Padding(
              padding: const EdgeInsets.symmetric(vertical: 4),
              child: Row(
                children: [
                  SizedBox(
                    width: 60,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                            _shifts[si][0].toUpperCase() +
                                _shifts[si].substring(1),
                            style: GoogleFonts.plusJakartaSans(
                                fontSize: 10,
                                color: c.textPrimary)),
                        Text(_shiftTimes[si],
                            style: GoogleFonts.plusJakartaSans(
                                fontSize: 8,
                                color: c.textTertiary)),
                      ],
                    ),
                  ),
                  ...List.generate(_days.length, (di) {
                    final active =
                        _schedule[_days[di]]?.contains(_shifts[si]) ??
                            false;
                    return Expanded(
                      child: GestureDetector(
                        onTap: () => _toggle(_days[di], _shifts[si]),
                        child: Container(
                          margin: const EdgeInsets.all(2),
                          height: 36,
                          decoration: BoxDecoration(
                            color: active
                                ? SColors.primary.withAlpha(180)
                                : c.inputBg,
                            borderRadius: BorderRadius.circular(6),
                            border: Border.all(
                              color: active
                                  ? SColors.primary
                                  : Colors.transparent,
                              width: 1.5,
                            ),
                          ),
                          child: active
                              ? const Icon(Icons.check,
                                  color: Colors.white, size: 16)
                              : null,
                        ),
                      ),
                    );
                  }),
                ],
              ),
            );
          }),
        ],
      ),
    );
  }

  Widget _buildLegend(SugoColors c) {
    return Row(
      children: [
        Container(
            width: 16,
            height: 16,
            decoration: BoxDecoration(
                color: SColors.primary.withAlpha(180),
                borderRadius: BorderRadius.circular(4))),
        const SizedBox(width: 8),
        Text('Available',
            style:
                GoogleFonts.plusJakartaSans(fontSize: 12, color: c.textPrimary)),
        const SizedBox(width: 24),
        Container(
            width: 16,
            height: 16,
            decoration: BoxDecoration(
                color: c.inputBg,
                borderRadius: BorderRadius.circular(4))),
        const SizedBox(width: 8),
        Text('Off',
            style: GoogleFonts.plusJakartaSans(
                fontSize: 12, color: c.textTertiary)),
      ],
    );
  }
}
