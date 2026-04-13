import '../core/constants.dart';

class DeliveryFeeCalculator {
  /// Calculates delivery fee based on distance in km.
  /// Applies to BOTH food orders and Pahapit errands.
  static double calculate(double distanceKm) {
    const double baseFee = AppConstants.baseDeliveryFee;

    if (distanceKm <= 0) return baseFee;
    if (distanceKm > AppConstants.maxDeliveryRadiusKm) return -1; // Out of range

    if (distanceKm <= 2) {
      return baseFee;
    } else if (distanceKm <= 5) {
      return baseFee + ((distanceKm - 2) * 5);
    } else if (distanceKm <= 10) {
      return baseFee + (3 * 5) + ((distanceKm - 5) * 7);
    } else {
      return baseFee + (3 * 5) + (5 * 7) + ((distanceKm - 10) * 10);
    }
  }

  /// Revenue split for food orders
  static Map<String, double> foodOrderSplit({
    required double orderTotal,
    required double deliveryFee,
  }) {
    final commission = orderTotal * AppConstants.commissionRate;
    final merchantShare = orderTotal - commission;
    final riderShare = deliveryFee * AppConstants.riderDeliveryFeePercent;
    final sugobayShare =
        commission + (deliveryFee * (1 - AppConstants.riderDeliveryFeePercent));
    final incentive = AppConstants.incentivePerOrder;

    return {
      'merchant': merchantShare,
      'rider': riderShare,
      'sugobay': sugobayShare - incentive,
      'incentive': incentive,
      'commission': commission,
    };
  }

  /// Revenue split for Pahapit errands
  static Map<String, double> pahapitSplit({
    required double actualItemCost,
    required double deliveryFee,
  }) {
    const errandFee = AppConstants.errandFee;
    final riderErrandShare = errandFee * (1 - AppConstants.errandFeeCutPercent);
    final sugobayErrandShare = errandFee * AppConstants.errandFeeCutPercent;
    final riderDeliveryShare =
        deliveryFee * AppConstants.riderDeliveryFeePercent;
    final sugobayDeliveryShare =
        deliveryFee * (1 - AppConstants.riderDeliveryFeePercent);
    final incentive = AppConstants.incentivePerOrder;

    return {
      'rider': actualItemCost + riderErrandShare + riderDeliveryShare,
      'sugobay': sugobayErrandShare + sugobayDeliveryShare - incentive,
      'incentive': incentive,
      'totalCustomerPays': actualItemCost + errandFee + deliveryFee,
    };
  }
}
