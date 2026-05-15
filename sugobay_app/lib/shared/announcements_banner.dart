import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../core/supabase_client.dart';
import '../core/theme.dart';

class AnnouncementsBanner extends StatefulWidget {
  const AnnouncementsBanner({super.key});

  @override
  State<AnnouncementsBanner> createState() => _AnnouncementsBannerState();
}

class _AnnouncementsBannerState extends State<AnnouncementsBanner> {
  List<Map<String, dynamic>> _announcements = [];
  int _currentIndex = 0;
  bool _dismissed = false;

  @override
  void initState() {
    super.initState();
    _loadAnnouncements();
  }

  Future<void> _loadAnnouncements() async {
    try {
      final role = await SupabaseService.getUserRole() ?? 'customer';
      final res = await SupabaseService.announcements()
          .select()
          .or('target_role.eq.all,target_role.eq.$role')
          .order('sent_at', ascending: false)
          .limit(5);
      if (mounted) {
        setState(() {
          _announcements = List<Map<String, dynamic>>.from(res);
        });
      }
    } catch (_) {}
  }

  @override
  Widget build(BuildContext context) {
    if (_dismissed || _announcements.isEmpty) return const SizedBox.shrink();

    final c = context.sc;
    final a = _announcements[_currentIndex];

    return Container(
      margin: const EdgeInsets.fromLTRB(16, 8, 16, 4),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            SColors.primary.withValues(alpha: 0.2),
            SColors.gold.withValues(alpha: 0.1),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: SColors.primary.withValues(alpha: 0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.campaign_rounded, color: SColors.gold, size: 18),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  a['title'] ?? 'Announcement',
                  style: GoogleFonts.plusJakartaSans(
                    color: c.textPrimary,
                    fontWeight: FontWeight.w600,
                    fontSize: 13,
                  ),
                ),
              ),
              if (_announcements.length > 1)
                GestureDetector(
                  onTap: () => setState(() {
                    _currentIndex =
                        (_currentIndex + 1) % _announcements.length;
                  }),
                  child: Icon(Icons.chevron_right,
                      color: c.textTertiary, size: 20),
                ),
              const SizedBox(width: 4),
              GestureDetector(
                onTap: () => setState(() => _dismissed = true),
                child: Icon(Icons.close, color: c.textTertiary, size: 16),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            a['message'] ?? '',
            style: GoogleFonts.plusJakartaSans(
                color: c.textSecondary, fontSize: 12, height: 1.4),
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
          if (_announcements.length > 1)
            Padding(
              padding: const EdgeInsets.only(top: 6),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: List.generate(_announcements.length, (i) {
                  return Container(
                    width: i == _currentIndex ? 14 : 6,
                    height: 4,
                    margin: const EdgeInsets.symmetric(horizontal: 2),
                    decoration: BoxDecoration(
                      color: i == _currentIndex
                          ? SColors.primary
                          : c.border,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  );
                }),
              ),
            ),
        ],
      ),
    );
  }
}
