import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../features/customer/food/merchant_detail_screen.dart';

class CartState {
  final Map<String, CartItem> cart;
  final String merchantId;
  final String merchantName;

  const CartState({
    this.cart = const {},
    this.merchantId = '',
    this.merchantName = '',
  });

  CartState copyWith({
    Map<String, CartItem>? cart,
    String? merchantId,
    String? merchantName,
  }) {
    return CartState(
      cart: cart ?? this.cart,
      merchantId: merchantId ?? this.merchantId,
      merchantName: merchantName ?? this.merchantName,
    );
  }

  int get totalItems => cart.values.fold(0, (sum, item) => sum + item.quantity);
  double get totalPrice => cart.values.fold(0.0, (sum, item) => sum + item.totalPrice);
}

class CartNotifier extends StateNotifier<CartState> {
  CartNotifier() : super(const CartState());

  void setCart(Map<String, CartItem> cart, String merchantId, String merchantName) {
    state = CartState(cart: Map.from(cart), merchantId: merchantId, merchantName: merchantName);
  }

  void clear() {
    state = const CartState();
  }
}

final cartProvider = StateNotifierProvider<CartNotifier, CartState>((ref) {
  return CartNotifier();
});
