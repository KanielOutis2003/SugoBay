import 'package:flutter/material.dart';
import '../../core/constants.dart';
import '../../shared/widgets.dart';

/// Habal-habal (motorcycle taxi) tab — coming soon placeholder.
class HabalHabalTab extends StatelessWidget {
  const HabalHabalTab({super.key});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.motorcycle, size: 80, color: AppColors.gold.withAlpha(120)),
            const SizedBox(height: 24),
            Text(
              'Habal-habal',
              style: AppTextStyles.heading.copyWith(color: AppColors.gold),
            ),
            const SizedBox(height: 12),
            Text(
              'Motorcycle taxi booking is coming soon!\n'
              'Book affordable rides around Ubay.',
              style: AppTextStyles.body,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 32),
            SugoBayCard(
              child: Column(
                children: [
                  _featureRow(Icons.location_on, 'Pin pickup & drop-off on map'),
                  const SizedBox(height: 12),
                  _featureRow(Icons.attach_money, 'Fare estimate before booking'),
                  const SizedBox(height: 12),
                  _featureRow(Icons.gps_fixed, 'Live ride tracking'),
                  const SizedBox(height: 12),
                  _featureRow(Icons.star, 'Rate your rider'),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  static Widget _featureRow(IconData icon, String text) {
    return Row(
      children: [
        Icon(icon, color: AppColors.teal, size: 20),
        const SizedBox(width: 12),
        Expanded(child: Text(text, style: AppTextStyles.body)),
      ],
    );
  }
}
