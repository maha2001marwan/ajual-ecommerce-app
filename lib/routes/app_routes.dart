import 'package:get/get.dart';

import '../Screens/cart.dart';
import '../Screens/checkout/address_list_screen.dart';
import '../Screens/checkout/coupons_screen.dart';
import '../Screens/checkout/payment_methods_screen.dart';
import '../Screens/checkout_screen.dart';
import '../Screens/notifications_screen.dart';
import '../Screens/orders/order_search_screen.dart';
import '../Screens/orders_screen.dart';
import '../Screens/profile/edit_profile_screen.dart';
import '../Screens/profile/help_center_screen.dart';
import '../Screens/profile/my_reviews_screen.dart';
import '../Screens/profile/recently_viewed_screen.dart';
import '../Screens/search/search_screen.dart';

/// Named routes for screens that take no constructor arguments. Screens that
/// need data (a product, an order…) are opened with `Get.to(() => …)`.
class AppRoutes {
  AppRoutes._();

  static const String notifications = '/notifications';
  static const String checkout = '/checkout';
  static const String orders = '/orders';
  static const String cart = '/cart';
  static const String search = '/search';
  static const String addresses = '/addresses';
  static const String payments = '/payments';
  static const String coupons = '/coupons';
  static const String editProfile = '/edit-profile';
  static const String recentlyViewed = '/recently-viewed';
  static const String helpCenter = '/help-center';
  static const String customerService = '/customer-service';
  static const String myReviews = '/my-reviews';
  static const String orderSearch = '/order-search';

  static const Duration _duration = Duration(milliseconds: 320);

  static GetPage<dynamic> _page(String name, GetPageBuilder page) => GetPage(
    name: name,
    page: page,
    transition: Transition.cupertino,
    transitionDuration: _duration,
  );

  static final List<GetPage<dynamic>> pages = [
    _page(notifications, () => const NotificationsScreen()),
    _page(checkout, () => const CheckoutScreen()),
    _page(orders, () => const OrdersScreen()),
    _page(cart, () => const Cart()),
    GetPage(
      name: search,
      page: () => const SearchScreen(),
      transition: Transition.fadeIn,
      transitionDuration: const Duration(milliseconds: 220),
    ),
    _page(addresses, () => const AddressListScreen()),
    _page(payments, () => const PaymentMethodsScreen()),
    _page(coupons, () => const CouponsScreen()),
    _page(editProfile, () => const EditProfileScreen()),
    _page(recentlyViewed, () => const RecentlyViewedScreen()),
    _page(helpCenter, () => const HelpCenterScreen()),
    _page(customerService, () => const CustomerServiceScreen()),
    _page(myReviews, () => const MyReviewsScreen()),
    GetPage(
      name: orderSearch,
      page: () => const OrderSearchScreen(),
      transition: Transition.fadeIn,
      transitionDuration: const Duration(milliseconds: 220),
    ),
  ];
}
