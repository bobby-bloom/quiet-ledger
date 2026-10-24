import 'package:flutter/material.dart';

/// Icon keys stored in the DB (`accounts.icon`, `categories.icon`, ...)
/// mapped to Material icons. Keys are stable strings so the DB never stores
/// code points.
abstract final class AppIcons {
  static const Map<String, IconData> byKey = {
    // Accounts
    'bank': Icons.account_balance_outlined,
    'wallet': Icons.account_balance_wallet_outlined,
    'savings': Icons.savings_outlined,
    'cash': Icons.payments_outlined,
    'card': Icons.credit_card_outlined,
    'investment': Icons.trending_up,
    'loan': Icons.request_quote_outlined,
    'asset': Icons.diamond_outlined,
    // Categories
    'groceries': Icons.local_grocery_store_outlined,
    'restaurant': Icons.restaurant_outlined,
    'cafe': Icons.local_cafe_outlined,
    'home': Icons.home_outlined,
    'rent': Icons.house_outlined,
    'utilities': Icons.bolt_outlined,
    'phone': Icons.smartphone_outlined,
    'internet': Icons.wifi,
    'transport': Icons.directions_bus_outlined,
    'car': Icons.directions_car_outlined,
    'fuel': Icons.local_gas_station_outlined,
    'health': Icons.favorite_border,
    'pharmacy': Icons.medication_outlined,
    'insurance': Icons.shield_outlined,
    'shopping': Icons.shopping_bag_outlined,
    'clothing': Icons.checkroom_outlined,
    'electronics': Icons.devices_outlined,
    'entertainment': Icons.movie_outlined,
    'sport': Icons.fitness_center_outlined,
    'travel': Icons.flight_outlined,
    'hotel': Icons.hotel_outlined,
    'education': Icons.school_outlined,
    'kids': Icons.child_care_outlined,
    'pets': Icons.pets_outlined,
    'gifts': Icons.card_giftcard_outlined,
    'charity': Icons.volunteer_activism_outlined,
    'subscriptions': Icons.subscriptions_outlined,
    'taxes': Icons.receipt_long_outlined,
    'fees': Icons.price_change_outlined,
    'salary': Icons.work_outline,
    'freelance': Icons.laptop_mac_outlined,
    'interest': Icons.percent,
    'refund': Icons.undo,
    'other': Icons.category_outlined,
    'transfer': Icons.swap_horiz,
    'tag': Icons.sell_outlined,
    'goal': Icons.flag_outlined,
  };

  static IconData of(
    String? key, {
    IconData fallback = Icons.category_outlined,
  }) => byKey[key] ?? fallback;
}
