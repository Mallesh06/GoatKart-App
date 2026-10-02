import 'dart:async';
import 'dart:convert';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:geolocator/geolocator.dart';
import 'package:http/http.dart' as http;
import 'package:url_launcher/url_launcher.dart';

import 'firebase_options.dart';

@pragma('vm:entry-point')
Future<void> _firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );
}

final FlutterLocalNotificationsPlugin flutterLocalNotificationsPlugin =
    FlutterLocalNotificationsPlugin();

const AndroidNotificationChannel channel = AndroidNotificationChannel(
  'high_importance_channel',
  'High Importance Notifications',
  description: 'This channel is used for important GoatKart order notifications.',
  importance: Importance.max,
);

Future<void> setupNotifications() async {
  try {
    FirebaseMessaging messaging = FirebaseMessaging.instance;
    await messaging.requestPermission(
      alert: true,
      badge: true,
      sound: true,
    );

    const AndroidInitializationSettings initializationSettingsAndroid =
        AndroidInitializationSettings('@mipmap/ic_launcher');
    const InitializationSettings initializationSettings =
        InitializationSettings(android: initializationSettingsAndroid);

    await flutterLocalNotificationsPlugin.initialize(initializationSettings);

    await flutterLocalNotificationsPlugin
        .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin>()
        ?.createNotificationChannel(channel);

    FirebaseMessaging.onMessage.listen((RemoteMessage message) {
      RemoteNotification? notification = message.notification;
      if (notification != null) {
        flutterLocalNotificationsPlugin.show(
          notification.hashCode,
          notification.title,
          notification.body,
          NotificationDetails(
            android: AndroidNotificationDetails(
              channel.id,
              channel.name,
              channelDescription: channel.description,
              icon: '@mipmap/ic_launcher',
              importance: Importance.max,
              priority: Priority.high,
            ),
          ),
        );
      }
    });
  } catch (_) {}
}

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );

  FirebaseMessaging.onBackgroundMessage(_firebaseMessagingBackgroundHandler);
  await setupNotifications();

  runApp(const GoatKartApp());
}

// ============================================================
// COLORS
// ============================================================

const Color bgColor = Color(0xFF0B0F0D);
const Color cardColor = Color(0xFF151A17);
const Color cardColor2 = Color(0xFF1B211D);
const Color inputColor = Color(0xFF202621);

const Color primaryGreen = Color(0xFF35A866);
const Color darkGreen = Color(0xFF176B3A);
const Color lightGreen = Color(0xFF75D89B);

const Color goldColor = Color(0xFFD9A441);
const Color creamColor = Color(0xFFF4EBDD);
const Color accentRed = Color(0xFFE53935);

// ============================================================
// ADMIN / TEAM SETTINGS
// ------------------------------------------------------------
// IMPORTANT: put your real GoatKart startup email here.
// The SAME email must be used inside the Firestore rules.
// Keep it lowercase.
// ============================================================

const String kAdminEmail = 'admingoatkart03@gmail.com';

// ============================================================
// LOGO
// ------------------------------------------------------------
// Copy your logo file to:  assets/images/logo.png
// and declare it in pubspec.yaml under flutter > assets.
// ============================================================

const String kLogoAsset = 'assets/images/logo.png';

/// GoatKart circular logo (unique ring + glow around your logo image).
class GoatKartLogo extends StatelessWidget {
  final double size;
  final bool glow;
  final Color ringColor;

  const GoatKartLogo({
    super.key,
    this.size = 60,
    this.glow = true,
    this.ringColor = primaryGreen,
  });

  @override
  Widget build(BuildContext context) {
    final ringWidth = size >= 70 ? 3.0 : 2.0;

    return Container(
      width: size,
      height: size,
      padding: EdgeInsets.all(ringWidth),
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [ringColor, goldColor],
        ),
        boxShadow: glow
            ? [
                BoxShadow(
                  color: ringColor.withOpacity(0.35),
                  blurRadius: size * 0.28,
                  spreadRadius: 1,
                ),
              ]
            : null,
      ),
      child: Container(
        decoration: const BoxDecoration(
          shape: BoxShape.circle,
          color: Colors.white,
        ),
        child: ClipOval(
          child: Padding(
            padding: EdgeInsets.all(size * 0.06),
            child: Image.asset(
              kLogoAsset,
              fit: BoxFit.contain,
              width: size,
              height: size,
              errorBuilder: (_, __, ___) => Container(
                color: primaryGreen,
                child: Icon(
                  Icons.restaurant,
                  color: Colors.white,
                  size: size * 0.5,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

// ============================================================
// SKELETON SCREEN & SHIMMER LOADING (SLOW NETWORK SUPPORT)
// ============================================================

/// Shimmer container with animated gradient pulse for slow network loading.
class ShimmerContainer extends StatefulWidget {
  final double? width;
  final double? height;
  final BorderRadius? borderRadius;
  final BoxShape shape;

  const ShimmerContainer({
    super.key,
    this.width,
    this.height,
    this.borderRadius,
    this.shape = BoxShape.rectangle,
  });

  @override
  State<ShimmerContainer> createState() => _ShimmerContainerState();
}

class _ShimmerContainerState extends State<ShimmerContainer>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _animation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1100),
    )..repeat();
    _animation = Tween<double>(begin: -1.5, end: 1.5).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _animation,
      builder: (context, child) {
        return Container(
          width: widget.width,
          height: widget.height,
          decoration: BoxDecoration(
            shape: widget.shape,
            borderRadius: widget.shape == BoxShape.circle
                ? null
                : (widget.borderRadius ?? BorderRadius.circular(12)),
            gradient: LinearGradient(
              begin: Alignment(_animation.value - 1, -0.2),
              end: Alignment(_animation.value + 1, 0.2),
              colors: const [
                Color(0xFF151A17),
                Color(0xFF2B332E),
                Color(0xFF151A17),
              ],
              stops: const [0.1, 0.5, 0.9],
            ),
          ),
        );
      },
    );
  }
}

/// Product card skeleton for grid view during slow network loading.
class ProductCardSkeleton extends StatelessWidget {
  const ProductCardSkeleton({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: cardColor,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: Colors.white10),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const ShimmerContainer(
            height: 125,
            width: double.infinity,
            borderRadius: BorderRadius.vertical(top: Radius.circular(22)),
          ),
          Padding(
            padding: const EdgeInsets.all(12.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const ShimmerContainer(height: 16, width: 110),
                const SizedBox(height: 8),
                const ShimmerContainer(height: 12, width: 60),
                const SizedBox(height: 14),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: const [
                    ShimmerContainer(height: 18, width: 65),
                    ShimmerContainer(
                      height: 32,
                      width: 32,
                      borderRadius: BorderRadius.all(Radius.circular(10)),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// Grid of product skeletons for main store view.
class ProductsGridSkeleton extends StatelessWidget {
  final int itemCount;
  const ProductsGridSkeleton({super.key, this.itemCount = 6});

  @override
  Widget build(BuildContext context) {
    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: itemCount,
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        childAspectRatio: 0.58,
        crossAxisSpacing: 14,
        mainAxisSpacing: 14,
      ),
      itemBuilder: (_, __) => const ProductCardSkeleton(),
    );
  }
}

/// Skeleton card for orders list (customer order history or admin dashboard).
class OrderCardSkeleton extends StatelessWidget {
  const OrderCardSkeleton({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: cardColor,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: Colors.white10),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: const [
              ShimmerContainer(width: 110, height: 16),
              ShimmerContainer(
                width: 90,
                height: 24,
                borderRadius: BorderRadius.all(Radius.circular(20)),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Row(
            children: const [
              ShimmerContainer(
                width: 48,
                height: 48,
                borderRadius: BorderRadius.all(Radius.circular(12)),
              ),
              SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    ShimmerContainer(width: 140, height: 14),
                    SizedBox(height: 8),
                    ShimmerContainer(width: 80, height: 12),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          const Divider(color: Colors.white10),
          const SizedBox(height: 8),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: const [
              ShimmerContainer(width: 100, height: 14),
              ShimmerContainer(width: 75, height: 18),
            ],
          ),
        ],
      ),
    );
  }
}

/// List of order skeletons.
class OrdersListSkeleton extends StatelessWidget {
  final int itemCount;
  const OrdersListSkeleton({super.key, this.itemCount = 3});

  @override
  Widget build(BuildContext context) {
    return ListView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: itemCount,
      itemBuilder: (_, __) => const OrderCardSkeleton(),
    );
  }
}

/// Image.network with automatic skeleton shimmer loading for slow network speeds.
class SkeletonNetworkImage extends StatelessWidget {
  final String imageUrl;
  final BoxFit fit;
  final double? width;
  final double? height;
  final Widget Function(BuildContext, Object, StackTrace?)? errorBuilder;

  const SkeletonNetworkImage({
    super.key,
    required this.imageUrl,
    this.fit = BoxFit.cover,
    this.width,
    this.height,
    this.errorBuilder,
  });

  @override
  Widget build(BuildContext context) {
    return Image.network(
      imageUrl,
      fit: fit,
      width: width,
      height: height,
      loadingBuilder: (context, child, loadingProgress) {
        if (loadingProgress == null) return child;
        return ShimmerContainer(
          width: width,
          height: height,
        );
      },
      errorBuilder: errorBuilder ??
          (_, __, ___) => Container(
                width: width,
                height: height,
                color: cardColor2,
                child: const Center(
                  child: Icon(
                    Icons.restaurant,
                    color: primaryGreen,
                    size: 32,
                  ),
                ),
              ),
    );
  }
}

// ============================================================
// ORDER STATUS NAMES
// ============================================================

const String kPending = 'Pending Admin Approval';
const String kConfirmed = 'Confirmed by Admin';
const String kPreparing = 'Preparing';
const String kOutForDelivery = 'Out for Delivery';
const String kDelivered = 'Delivered';
const String kCancelled = 'Cancelled';

// ============================================================
// SHARED HELPERS
// ============================================================

int toInt(dynamic value, [int fallback = 0]) {
  if (value is int) return value;
  if (value is num) return value.round();
  return int.tryParse(value?.toString() ?? '') ?? fallback;
}

/// Formats money in the Indian style: ₹1,23,456
String inr(num value) {
  final n = value.round();
  final digits = n.abs().toString();

  String grouped;

  if (digits.length <= 3) {
    grouped = digits;
  } else {
    final last3 = digits.substring(digits.length - 3);
    var rest = digits.substring(0, digits.length - 3);
    final parts = <String>[];

    while (rest.length > 2) {
      parts.insert(0, rest.substring(rest.length - 2));
      rest = rest.substring(0, rest.length - 2);
    }

    if (rest.isNotEmpty) parts.insert(0, rest);

    grouped = '${parts.join(',')},$last3';
  }

  return '₹${n < 0 ? '-' : ''}$grouped';
}

/// Short form for chart labels: 1.2k, 3.4L
String compactMoney(int value) {
  if (value >= 100000) {
    return '${(value / 100000).toStringAsFixed(1)}L';
  }
  if (value >= 1000) {
    return '${(value / 1000).toStringAsFixed(1)}k';
  }
  return '$value';
}

const List<String> _monthNames = [
  'Jan',
  'Feb',
  'Mar',
  'Apr',
  'May',
  'Jun',
  'Jul',
  'Aug',
  'Sep',
  'Oct',
  'Nov',
  'Dec',
];

const List<String> _weekDayNames = [
  'Mon',
  'Tue',
  'Wed',
  'Thu',
  'Fri',
  'Sat',
  'Sun',
];

String formatDate(DateTime d) =>
    '${d.day} ${_monthNames[d.month - 1]} ${d.year}';

String formatTime(DateTime d) {
  var hour = d.hour % 12;
  if (hour == 0) hour = 12;
  final minute = d.minute.toString().padLeft(2, '0');
  final period = d.hour >= 12 ? 'PM' : 'AM';
  return '$hour:$minute $period';
}

String formatDateTime(DateTime d) => '${formatDate(d)}, ${formatTime(d)}';

String timeAgo(DateTime d) {
  final diff = DateTime.now().difference(d);

  if (diff.inSeconds < 60) return 'Just now';
  if (diff.inMinutes < 60) return '${diff.inMinutes} min ago';
  if (diff.inHours < 24) return '${diff.inHours} hr ago';
  if (diff.inDays < 7) {
    return '${diff.inDays} day${diff.inDays == 1 ? '' : 's'} ago';
  }
  return formatDate(d);
}

/// Firestore server timestamps are null for a moment on the device that
/// just wrote them, so treat null as "now".
DateTime timeOf(dynamic value) {
  if (value is Timestamp) return value.toDate();
  return DateTime.now();
}

DateTime orderTime(Map<String, dynamic> order) => timeOf(order['createdAt']);

bool sameDay(DateTime a, DateTime b) =>
    a.year == b.year && a.month == b.month && a.day == b.day;

bool sameMonth(DateTime a, DateTime b) =>
    a.year == b.year && a.month == b.month;

String shortId(String id) {
  if (id.length <= 6) return id.toUpperCase();
  return id.substring(id.length - 6).toUpperCase();
}

// ============================================================
// STRUCTURED ADDRESS (house, village, mandal, district, state, pincode)
// ============================================================

class AddressFields {
  final TextEditingController house = TextEditingController();
  final TextEditingController village = TextEditingController();
  final TextEditingController mandal = TextEditingController();
  final TextEditingController district = TextEditingController();
  final TextEditingController state = TextEditingController();
  final TextEditingController pincode = TextEditingController();

  void dispose() {
    house.dispose();
    village.dispose();
    mandal.dispose();
    district.dispose();
    state.dispose();
    pincode.dispose();
  }

  void fill(Map<String, dynamic>? m) {
    if (m == null) return;

    house.text = (m['house'] ?? '').toString();
    village.text = (m['village'] ?? '').toString();
    mandal.text = (m['mandal'] ?? '').toString();
    district.text = (m['district'] ?? '').toString();
    state.text = (m['state'] ?? '').toString();
    pincode.text = (m['pincode'] ?? '').toString();
  }

  Map<String, String> toMap() => {
        'house': house.text.trim(),
        'village': village.text.trim(),
        'mandal': mandal.text.trim(),
        'district': district.text.trim(),
        'state': state.text.trim(),
        'pincode': pincode.text.trim(),
      };

  bool get isEmpty =>
      house.text.trim().isEmpty &&
      village.text.trim().isEmpty &&
      mandal.text.trim().isEmpty &&
      district.text.trim().isEmpty &&
      state.text.trim().isEmpty &&
      pincode.text.trim().isEmpty;

  static String _stripWord(String value, String word) {
    final t = value.trim();

    if (t.toLowerCase().endsWith(word.toLowerCase())) {
      return t.substring(0, t.length - word.length).trim();
    }

    return t;
  }

  /// One readable line, e.g.
  /// "12-3, Main Road, Kovvur, Kovvur Mandal, West Godavari District,
  /// Andhra Pradesh - 534350"
  String get full {
    final parts = <String>[];

    void add(String v) {
      if (v.trim().isNotEmpty) parts.add(v.trim());
    }

    add(house.text);
    add(village.text);

    final m = _stripWord(mandal.text, 'mandal');
    if (m.isNotEmpty) parts.add('$m Mandal');

    final d = _stripWord(district.text, 'district');
    if (d.isNotEmpty) parts.add('$d District');

    add(state.text);

    var result = parts.join(', ');

    if (pincode.text.trim().isNotEmpty) {
      result = '$result - ${pincode.text.trim()}';
    }

    return result;
  }

  /// Returns an error message, or null when the address is complete.
  String? validate() {
    if (house.text.trim().length < 3) {
      return 'Please enter your house / door number and street.';
    }
    if (village.text.trim().isEmpty) {
      return 'Please enter your village / town.';
    }
    if (district.text.trim().isEmpty) {
      return 'Please enter your district.';
    }
    if (state.text.trim().isEmpty) {
      return 'Please enter your state.';
    }
    if (!RegExp(r'^\d{6}$').hasMatch(pincode.text.trim())) {
      return 'Please enter a valid 6-digit pincode.';
    }
    return null;
  }
}

Widget addressTextField(
  TextEditingController controller,
  String label, {
  IconData? icon,
  TextInputType? keyboardType,
  int maxLines = 1,
  int? maxLength,
  List<TextInputFormatter>? formatters,
}) {
  return TextField(
    controller: controller,
    maxLines: maxLines,
    maxLength: maxLength,
    keyboardType: keyboardType,
    inputFormatters: formatters,
    textCapitalization: TextCapitalization.words,
    style: const TextStyle(color: Colors.white),
    decoration: InputDecoration(
      labelText: label,
      counterText: '',
      prefixIcon: icon == null ? null : Icon(icon),
    ),
  );
}

/// The complete address form used by Checkout and Profile.
Widget buildAddressForm(AddressFields f) {
  return Column(
    children: [
      addressTextField(
        f.house,
        'House / Door No, Street, Landmark',
        icon: Icons.home_outlined,
        maxLines: 2,
      ),
      const SizedBox(height: 12),
      addressTextField(
        f.village,
        'Village / Town / Area',
        icon: Icons.location_city_outlined,
      ),
      const SizedBox(height: 12),
      Row(
        children: [
          Expanded(child: addressTextField(f.mandal, 'Mandal')),
          const SizedBox(width: 12),
          Expanded(
            child: addressTextField(
              f.pincode,
              'Pincode',
              keyboardType: TextInputType.number,
              maxLength: 6,
              formatters: [FilteringTextInputFormatter.digitsOnly],
            ),
          ),
        ],
      ),
      const SizedBox(height: 12),
      Row(
        children: [
          Expanded(child: addressTextField(f.district, 'District')),
          const SizedBox(width: 12),
          Expanded(child: addressTextField(f.state, 'State')),
        ],
      ),
    ],
  );
}

/// Looks up the address of a GPS point and splits it into
/// house / village / mandal / district / state / pincode.
Future<Map<String, String>?> reverseGeocode(double lat, double lon) async {
  try {
    final uri = Uri.https(
      'nominatim.openstreetmap.org',
      '/reverse',
      {
        'format': 'jsonv2',
        'lat': lat.toString(),
        'lon': lon.toString(),
        'zoom': '18',
        'addressdetails': '1',
        'accept-language': 'en',
      },
    );

    final response = await http.get(
      uri,
      headers: const {
        'User-Agent': 'GoatKartApp/1.0 (contact@goatkart.app)',
      },
    ).timeout(const Duration(seconds: 10));

    if (response.statusCode == 200) {
      final data = jsonDecode(response.body);
      if (data is Map<String, dynamic>) {
        final a = data['address'];
        if (a is Map) {
          final house = [a['house_number'], a['road'], a['suburb'], a['neighbourhood']]
              .where((e) => e != null && e.toString().trim().isNotEmpty)
              .join(', ');
          final village = a['village'] ?? a['town'] ?? a['city'] ?? a['suburb'] ?? a['hamlet'] ?? a['municipality'] ?? '';
          final mandal = a['subdistrict'] ?? a['county'] ?? a['taluk'] ?? a['city_district'] ?? '';
          final district = a['state_district'] ?? a['district'] ?? a['city'] ?? '';
          final state = a['state'] ?? '';
          final pincode = (a['postcode'] ?? '').toString().replaceAll(RegExp(r'\D'), '');

          return {
            'house': house.isNotEmpty ? house : (data['display_name'] ?? '').toString().split(',').first,
            'village': village.toString(),
            'mandal': mandal.toString(),
            'district': district.toString(),
            'state': state.toString(),
            'pincode': pincode,
          };
        }
      }
    }
  } catch (_) {}

  // Guaranteed fallback so form is always filled out successfully
  return {
    'house': 'GPS Location',
    'village': 'Area near Lat: ${lat.toStringAsFixed(3)}, Lon: ${lon.toStringAsFixed(3)}',
    'mandal': '',
    'district': '',
    'state': '',
    'pincode': '',
  };
}

// ============================================================
// SPLASH SCREEN (OPENING LOGO ANIMATION)
// ============================================================

/// Animated opening screen with GoatKart logo scaling up,
/// zooming backward, and dissolving into the main app.
class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _scaleAnimation;
  late Animation<double> _fadeAnimation;
  late Animation<double> _textFadeAnimation;
  late Animation<double> _exitScaleAnimation;
  late Animation<double> _exitFadeAnimation;

  @override
  void initState() {
    super.initState();

    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2200),
    );

    // Entry phase (0ms - 1000ms): Scale up & fade in
    _scaleAnimation = Tween<double>(begin: 0.3, end: 1.0).animate(
      CurvedAnimation(
        parent: _controller,
        curve: const Interval(0.0, 0.45, curve: Curves.elasticOut),
      ),
    );

    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _controller,
        curve: const Interval(0.0, 0.3, curve: Curves.easeIn),
      ),
    );

    _textFadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _controller,
        curve: const Interval(0.3, 0.65, curve: Curves.easeIn),
      ),
    );

    // Exit phase (1500ms - 2200ms): Logo zooms backward into distance & dissolves
    _exitScaleAnimation = Tween<double>(begin: 1.0, end: 0.15).animate(
      CurvedAnimation(
        parent: _controller,
        curve: const Interval(0.68, 1.0, curve: Curves.easeInOutBack),
      ),
    );

    _exitFadeAnimation = Tween<double>(begin: 1.0, end: 0.0).animate(
      CurvedAnimation(
        parent: _controller,
        curve: const Interval(0.75, 1.0, curve: Curves.easeInOut),
      ),
    );

    _controller.forward().then((_) {
      _navigateToNextScreen();
    });
  }

  void _navigateToNextScreen() {
    if (!mounted) return;
    final user = FirebaseAuth.instance.currentUser;
    final Widget targetScreen =
        user != null ? const HomeScreen() : const AuthScreen();

    Navigator.of(context).pushReplacement(
      PageRouteBuilder(
        transitionDuration: const Duration(milliseconds: 650),
        pageBuilder: (_, animation, __) {
          return FadeTransition(
            opacity: animation,
            child: targetScreen,
          );
        },
      ),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: bgColor,
      body: SafeArea(
        child: AnimatedBuilder(
          animation: _controller,
          builder: (context, child) {
            final isExitPhase = _controller.value >= 0.68;
            final currentScale = isExitPhase
                ? _exitScaleAnimation.value
                : _scaleAnimation.value;
            final currentFade = isExitPhase
                ? _exitFadeAnimation.value
                : _fadeAnimation.value;

            return Opacity(
              opacity: currentFade.clamp(0.0, 1.0),
              child: Center(
                child: SingleChildScrollView(
                  physics: const ClampingScrollPhysics(),
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Transform.scale(
                        scale: currentScale.clamp(0.01, 3.0),
                        child: Container(
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            boxShadow: [
                              BoxShadow(
                                color: primaryGreen.withValues(alpha: 0.4),
                                blurRadius: 40 * currentScale.clamp(0.1, 2.0),
                                spreadRadius: 4,
                              ),
                            ],
                          ),
                          child: const GoatKartLogo(
                            size: 120,
                            glow: true,
                            ringColor: primaryGreen,
                          ),
                        ),
                      ),
                      const SizedBox(height: 22),
                      Opacity(
                        opacity: (isExitPhase
                                ? _exitFadeAnimation.value
                                : _textFadeAnimation.value)
                            .clamp(0.0, 1.0),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: const [
                            Text(
                              'GoatKart',
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 32,
                                fontWeight: FontWeight.bold,
                                letterSpacing: 1.5,
                              ),
                            ),
                            SizedBox(height: 6),
                            Text(
                              'Fresh Mutton, Your Way 🥩',
                              style: TextStyle(
                                color: lightGreen,
                                fontSize: 14,
                                letterSpacing: 0.8,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}

// ============================================================
// GOATKART APP
// ============================================================

class GoatKartApp extends StatelessWidget {
  const GoatKartApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'GoatKart',
      theme: ThemeData(
        useMaterial3: true,
        scaffoldBackgroundColor: bgColor,
        colorScheme: const ColorScheme.dark(
          primary: primaryGreen,
          secondary: goldColor,
          surface: cardColor,
        ),
        appBarTheme: const AppBarTheme(
          backgroundColor: bgColor,
          foregroundColor: Colors.white,
          elevation: 0,
        ),
        inputDecorationTheme: const InputDecorationTheme(
          filled: true,
          fillColor: inputColor,
          labelStyle: TextStyle(color: Colors.white70),
          hintStyle: TextStyle(color: Colors.white38),
          prefixIconColor: primaryGreen,
          border: OutlineInputBorder(
            borderRadius: BorderRadius.all(Radius.circular(16)),
            borderSide: BorderSide.none,
          ),
        ),
        bottomNavigationBarTheme: const BottomNavigationBarThemeData(
          backgroundColor: cardColor,
          selectedItemColor: primaryGreen,
          unselectedItemColor: Colors.white38,
          type: BottomNavigationBarType.fixed,
        ),
      ),
      home: const SplashScreen(),
    );
  }
}

// ============================================================
// AUTH SCREEN
// ============================================================

class AuthScreen extends StatefulWidget {
  const AuthScreen({super.key});

  @override
  State<AuthScreen> createState() => _AuthScreenState();
}

class _AuthScreenState extends State<AuthScreen> {
  bool isLogin = true;
  bool obscurePassword = true;
  bool isLoading = false;

  final FirebaseAuth _auth = FirebaseAuth.instance;

  final nameController = TextEditingController();
  final emailController = TextEditingController();
  final phoneController = TextEditingController();
  final passwordController = TextEditingController();

  @override
  void dispose() {
    nameController.dispose();
    emailController.dispose();
    phoneController.dispose();
    passwordController.dispose();
    super.dispose();
  }

  // ==========================================================
  // AUTHENTICATION
  // ==========================================================

  Future<void> handleAuthentication() async {
    if (isLoading) return;

    final name = nameController.text.trim();
    final email = emailController.text.trim();
    final phone = phoneController.text.trim();
    final password = passwordController.text.trim();

    // ---------------- VALIDATION ----------------

    if (!isLogin && name.isEmpty) {
      showMessage('Please enter your full name.');
      return;
    }

    if (email.isEmpty) {
      showMessage('Please enter your email address.');
      return;
    }

    if (!email.contains('@') || !email.contains('.')) {
      showMessage('Please enter a valid email address.');
      return;
    }

    if (password.length < 6) {
      showMessage('Password must contain at least 6 characters.');
      return;
    }

    if (!isLogin && phone.length < 10) {
      showMessage('Please enter a valid phone number.');
      return;
    }

    if (!isLogin && email.toLowerCase() == kAdminEmail.toLowerCase()) {
      showMessage('This email is reserved. Please use another email address.');
      return;
    }

    setState(() {
      isLoading = true;
    });

    // ========================================================
    // REGISTER
    // ========================================================

    if (!isLogin) {
      try {
        final credential = await _auth
            .createUserWithEmailAndPassword(
              email: email,
              password: password,
            )
            .timeout(const Duration(seconds: 15));

        final newUser = credential.user;

        if (newUser == null) {
          throw Exception('Unable to create account.');
        }

        await newUser.updateDisplayName(name);

        final db = FirebaseFirestore.instance;
        final regBatch = db.batch();

        regBatch.set(db.collection('users').doc(newUser.uid), {
          'uid': newUser.uid,
          'name': name,
          'email': email,
          'phone': phone,
          'role': 'user',
          'createdAt': FieldValue.serverTimestamp(),
        });

        // Shows up in the admin "Activity" tab.
        regBatch.set(db.collection('activity').doc(), {
          'type': 'customer_registered',
          'title': 'New customer registered',
          'message': '$name • $email',
          'userId': newUser.uid,
          'actor': 'customer',
          'createdAt': FieldValue.serverTimestamp(),
        });

        await regBatch.commit().timeout(const Duration(seconds: 15));

        // User must login manually after registration.
        await _auth.signOut();

        if (!mounted) return;

        setState(() {
          isLoading = false;
          isLogin = true;
        });

        passwordController.clear();

        showMessage(
          'Account created successfully. Please login.',
          success: true,
        );

        return;
      } on FirebaseAuthException catch (e) {
        if (!mounted) return;

        String message;

        switch (e.code) {
          case 'email-already-in-use':
            message = 'This email is already registered. Please login.';
            break;
          case 'invalid-email':
            message = 'The email address is invalid.';
            break;
          case 'weak-password':
            message = 'Password is too weak.';
            break;
          case 'network-request-failed':
            message = 'Network error. Check your internet connection.';
            break;
          default:
            message = e.message ?? 'Registration failed.';
        }

        showMessage(message);
      } on TimeoutException {
        if (!mounted) return;

        showMessage('Request timed out. Check your internet connection.');
      } catch (e) {
        if (!mounted) return;

        showMessage('Unable to create account. Please try again.');
      } finally {
        if (mounted) {
          setState(() {
            isLoading = false;
          });
        }
      }

      return;
    }

    // ========================================================
    // LOGIN
    // ========================================================

    try {
      final credential = await _auth
          .signInWithEmailAndPassword(
            email: email,
            password: password,
          )
          .timeout(const Duration(seconds: 15));

      final user = credential.user;

      if (user == null) {
        if (mounted) {
          setState(() {
            isLoading = false;
          });

          showMessage('Login failed. Please try again.');
        }

        return;
      }

      // ======================================================
      // TEAM ACCOUNTS MUST USE THE ADMIN LOGIN
      // ======================================================

      bool isTeamAccount = false;

      try {
        final adminDoc = await FirebaseFirestore.instance
            .collection('admins')
            .doc(user.uid)
            .get()
            .timeout(const Duration(seconds: 10));

        isTeamAccount = adminDoc.exists;
      } catch (_) {
        isTeamAccount = false;
      }

      if (!mounted) return;

      if (isTeamAccount) {
        await _auth.signOut();

        if (!mounted) return;

        setState(() {
          isLoading = false;
        });

        showMessage(
          'This is a team account. Please use the Admin Login option.',
        );
        return;
      }

      setState(() {
        isLoading = false;
      });

      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (_) => const HomeScreen()),
      );
    } on FirebaseAuthException catch (e) {
      if (!mounted) return;

      String message;

      switch (e.code) {
        case 'user-not-found':
          message = 'Account not registered. Please create an account first.';
          break;
        case 'wrong-password':
          message = 'Incorrect password.';
          break;
        case 'invalid-credential':
          message = 'Invalid email or password.';
          break;
        case 'invalid-email':
          message = 'The email address is invalid.';
          break;
        case 'user-disabled':
          message = 'This account has been disabled.';
          break;
        case 'too-many-requests':
          message = 'Too many login attempts. Please try again later.';
          break;
        case 'network-request-failed':
          message = 'Network error. Check your internet connection.';
          break;
        default:
          message = e.message ?? 'Login failed. Please try again.';
      }

      showMessage(message);
    } on TimeoutException {
      if (!mounted) return;

      showMessage('Login timed out. Please check your internet connection.');
    } catch (e) {
      if (!mounted) return;

      showMessage('Something went wrong during login. Please try again.');
    } finally {
      // Spinner cannot remain active after authentication.
      if (mounted && isLoading) {
        setState(() {
          isLoading = false;
        });
      }
    }
  }

  // ==========================================================
  // PHONE LOGIN PLACEHOLDER
  // ==========================================================

  void openAdmin() {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const AdminAuthScreen()),
    );
  }

  void continueWithPhone() {
    showMessage('Phone OTP authentication will be enabled in future,use mail to login!.');
  }

  // ==========================================================
  // MESSAGE
  // ==========================================================

  void showMessage(String message, {bool success = false}) {
    if (!mounted) return;

    ScaffoldMessenger.of(context).hideCurrentSnackBar();

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: success ? primaryGreen : accentRed,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  // ==========================================================
  // AUTH FIELD
  // ==========================================================

  Widget authField({
    required TextEditingController controller,
    required String label,
    required IconData icon,
    bool obscureText = false,
    Widget? suffixIcon,
    TextInputType? keyboardType,
  }) {
    return TextField(
      controller: controller,
      obscureText: obscureText,
      keyboardType: keyboardType,
      enabled: !isLoading,
      style: const TextStyle(color: Colors.white),
      decoration: InputDecoration(
        labelText: label,
        prefixIcon: Icon(icon),
        suffixIcon: suffixIcon,
      ),
    );
  }

  // ==========================================================
  // BUILD
  // ==========================================================

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: EdgeInsets.fromLTRB(
              24,
              24,
              24,
              24 + MediaQuery.of(context).viewInsets.bottom,
            ),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 450),
              child: Column(
                children: [
                  const GoatKartLogo(size: 110),
                  const SizedBox(height: 20),
                  const Text(
                    'GoatKart',
                    style: TextStyle(
                      color: creamColor,
                      fontSize: 36,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 35),
                  Container(
                    padding: const EdgeInsets.all(22),
                    decoration: BoxDecoration(
                      color: cardColor,
                      borderRadius: BorderRadius.circular(26),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          isLogin ? 'Welcome Back 👋' : 'Create Account',
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 25,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 7),
                        Text(
                          isLogin
                              ? 'Login to order fresh mutton.'
                              : 'Create your GoatKart account.',
                          style: const TextStyle(color: Colors.white54),
                        ),
                        const SizedBox(height: 25),
                        if (!isLogin) ...[
                          authField(
                            controller: nameController,
                            label: 'Full Name',
                            icon: Icons.person_outline,
                          ),
                          const SizedBox(height: 15),
                        ],
                        authField(
                          controller: emailController,
                          label: 'Email Address',
                          icon: Icons.email_outlined,
                          keyboardType: TextInputType.emailAddress,
                        ),
                        const SizedBox(height: 15),
                        authField(
                          controller: passwordController,
                          label: 'Password',
                          icon: Icons.lock_outline,
                          obscureText: obscurePassword,
                          suffixIcon: IconButton(
                            onPressed: isLoading
                                ? null
                                : () {
                                    setState(() {
                                      obscurePassword = !obscurePassword;
                                    });
                                  },
                            icon: Icon(
                              obscurePassword
                                  ? Icons.visibility_outlined
                                  : Icons.visibility_off_outlined,
                            ),
                          ),
                        ),
                        if (!isLogin) ...[
                          const SizedBox(height: 15),
                          authField(
                            controller: phoneController,
                            label: 'Phone Number',
                            icon: Icons.phone_outlined,
                            keyboardType: TextInputType.phone,
                          ),
                        ],
                        const SizedBox(height: 24),
                        SizedBox(
                          width: double.infinity,
                          height: 54,
                          child: ElevatedButton(
                            onPressed: isLoading ? null : handleAuthentication,
                            style: ElevatedButton.styleFrom(
                              backgroundColor: primaryGreen,
                              foregroundColor: Colors.white,
                            ),
                            child: isLoading
                                ? const SizedBox(
                                    width: 24,
                                    height: 24,
                                    child: CircularProgressIndicator(
                                      color: Colors.white,
                                      strokeWidth: 2.5,
                                    ),
                                  )
                                : Text(isLogin ? 'LOGIN' : 'CREATE ACCOUNT'),
                          ),
                        ),
                        const SizedBox(height: 18),
                        Row(
                          children: [
                            const Expanded(
                              child: Divider(color: Colors.white12),
                            ),
                            Padding(
                              padding:
                                  const EdgeInsets.symmetric(horizontal: 12),
                              child: Text(
                                'OR',
                                style: TextStyle(
                                  color: Colors.white.withOpacity(0.4),
                                ),
                              ),
                            ),
                            const Expanded(
                              child: Divider(color: Colors.white12),
                            ),
                          ],
                        ),
                        const SizedBox(height: 18),
                        SizedBox(
                          width: double.infinity,
                          height: 50,
                          child: OutlinedButton.icon(
                            onPressed: isLoading ? null : continueWithPhone,
                            icon: const Icon(Icons.phone_android),
                            label: const Text('Continue with Phone'),
                          ),
                        ),
                        const SizedBox(height: 15),
                        Center(
                          child: TextButton(
                            onPressed: isLoading
                                ? null
                                : () {
                                    setState(() {
                                      isLogin = !isLogin;
                                    });
                                  },
                            child: Text(
                              isLogin
                                  ? 'New to GoatKart? Create Account'
                                  : 'Already have an account? Login',
                              style: const TextStyle(
                                color: lightGreen,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(height: 6),
                        const Divider(color: Colors.white12),
                        Center(
                          child: TextButton.icon(
                            onPressed: isLoading ? null : openAdmin,
                            icon: const Icon(
                              Icons.admin_panel_settings_outlined,
                              size: 19,
                            ),
                            label: const Text('Admin / Team Login'),
                            style: TextButton.styleFrom(
                              foregroundColor: goldColor,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

// ============================================================
// PRODUCT MODEL
// ============================================================

class Product {
  final String name;
  final String weight;
  final int price;
  final double rating;
  final String imageUrl;
  final String description;

  const Product({
    required this.name,
    required this.weight,
    required this.price,
    required this.rating,
    required this.imageUrl,
    required this.description,
  });
}

// ============================================================
// DEFAULT PRODUCTS FALLBACK
// ============================================================

final List<Product> defaultProducts = [
  Product(
    name: 'Biryani Cut',
    weight: '500 g',
    price: 399,
    rating: 4.8,
    imageUrl:
        'https://media-assets.swiggy.com/swiggy/image/upload/fl_lossy,f_auto,q_auto,w_600,h_468/DINEOUT_ALL_RESTAURANTS/IMAGES/RESTAURANT_IMAGE_SERVICE/2025/2/24/990d2b9f-bd06-4975-9353-8716afe3f7e8_image74857fef7ab394489b12f0ec036977f16.JPG',
    description: 'Perfectly cut mutton pieces for delicious biryani.',
  ),
  Product(
    name: 'Premium Boneless',
    weight: '500 g',
    price: 449,
    rating: 4.9,
    imageUrl:
        'https://images.unsplash.com/photo-1603360946369-dc9bb6258143?auto=format&fit=crop&w=900&q=85',
    description: 'Tender boneless mutton for curry and grills.',
  ),
  Product(
    name: 'Curry Cut',
    weight: '500 g',
    price: 379,
    rating: 4.7,
    imageUrl:
        'https://images.unsplash.com/photo-1544025162-d76694265947?auto=format&fit=crop&w=900&q=85',
    description: 'Bone-in pieces ideal for rich mutton curry.',
  ),
  Product(
    name: 'Mutton Keema',
    weight: '500 g',
    price: 429,
    rating: 4.8,
    imageUrl:
        'https://images.unsplash.com/photo-1529042410759-befb1204b468?auto=format&fit=crop&w=900&q=85',
    description: 'Fresh minced mutton for keema and kebabs.',
  ),
  Product(
    name: 'Mutton Liver',
    weight: '250 g',
    price: 199,
    rating: 4.6,
    imageUrl:
        'https://images.unsplash.com/photo-1602470520998-f4a52199a3d6?auto=format&fit=crop&w=900&q=85',
    description: 'Fresh liver perfect for fry and curry.',
  ),
  Product(
    name: 'Mutton Ribs',
    weight: '500 g',
    price: 459,
    rating: 4.8,
    imageUrl:
        'https://wolkifarm.com.au/cdn/shop/files/side-of-mutton-1_grande.jpg?v=1782687729',
    description: 'Juicy ribs perfect for slow cooking.',
  ),
  Product(
    name: 'Mutton Chops',
    weight: '500 g',
    price: 479,
    rating: 4.9,
    imageUrl:
        'https://wolkifarm.com.au/cdn/shop/files/side-of-mutton-1_grande.jpg?v=1782687729',
    description: 'Premium chops for grilling and roasting.',
  ),
  Product(
    name: 'Special Cuts',
    weight: '500 g',
    price: 499,
    rating: 5.0,
    imageUrl:
        'https://wolkifarm.com.au/cdn/shop/files/side-of-mutton-1_grande.jpg?v=1782687729',
    description: 'Chef-selected premium mutton cuts.',
  ),
];

// ============================================================
// HOME SCREEN
// ============================================================

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  int selectedIndex = 0;

  final TextEditingController searchController = TextEditingController();

  // Shop by Cut support
  final ScrollController homeScroll = ScrollController();
  final GlobalKey productsKey = GlobalKey();
  String? selectedCategory; // keyword, e.g. 'biryani'

  final List<Product> cart = [];
  final List<Product> favourites = [];

  List<Product> get products => defaultProducts;

  List<Product> parseProducts(AsyncSnapshot<QuerySnapshot> snapshot) {
    final docs = snapshot.data?.docs ?? [];
    if (docs.isEmpty) return defaultProducts;
    return docs.map((doc) {
      final data = doc.data() as Map<String, dynamic>;
      return Product(
        name: data['name'] ?? '',
        weight: data['weight'] ?? '500 g',
        price: toInt(data['price']),
        rating: (data['rating'] ?? 4.8).toDouble(),
        imageUrl: data['imageUrl'] ?? '',
        description: data['description'] ?? '',
      );
    }).toList();
  }
  List<Product> get homeProducts {
    if (selectedCategory == null) return defaultProducts;

    return defaultProducts
        .where((p) => p.name.toLowerCase().contains(selectedCategory!))
        .toList();
  }

  void selectCategory(String keyword) {
    setState(() {
      // tapping the same cut again clears the filter
      selectedCategory = selectedCategory == keyword ? null : keyword;
      searchController.clear();
    });

    WidgetsBinding.instance.addPostFrameCallback((_) {
      final ctx = productsKey.currentContext;

      if (ctx != null) {
        Scrollable.ensureVisible(
          ctx,
          duration: const Duration(milliseconds: 400),
          curve: Curves.easeOut,
        );
      }
    });
  }

  int get cartTotal {
    return cart.fold(0, (sum, product) => sum + product.price);
  }

  void addToCart(Product product) {
    setState(() {
      cart.add(product);
    });

    ScaffoldMessenger.of(context).hideCurrentSnackBar();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('${product.name} added to cart'),
        backgroundColor: primaryGreen,
        duration: const Duration(seconds: 1),
      ),
    );
  }

  void toggleFavourite(Product product) {
    setState(() {
      if (favourites.contains(product)) {
        favourites.remove(product);
      } else {
        favourites.add(product);
      }
    });
  }

  @override
  void dispose() {
    searchController.dispose();
    homeScroll.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Row(
          children: [
            const GoatKartLogo(size: 42, glow: false),
            const SizedBox(width: 10),
            const Text(
              'GoatKart',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
          ],
        ),
        actions: [
          IconButton(
            onPressed: () {
              setState(() {
                selectedIndex = 4;
              });
            },
            icon: const Icon(Icons.person_outline),
          ),
          Stack(
            children: [
              IconButton(
                onPressed: () {
                  setState(() {
                    selectedIndex = 2;
                  });
                },
                icon: const Icon(Icons.shopping_bag_outlined),
              ),
              if (cart.isNotEmpty)
                Positioned(
                  right: 5,
                  top: 5,
                  child: Container(
                    padding: const EdgeInsets.all(4),
                    decoration: const BoxDecoration(
                      color: accentRed,
                      shape: BoxShape.circle,
                    ),
                    child: Text(
                      '${cart.length}',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 9,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ],
      ),
      body: selectedIndex == 0
          ? buildHome()
          : selectedIndex == 1
              ? buildSearch()
              : selectedIndex == 2
                  ? buildCartPage()
                  : selectedIndex == 3
                      ? buildOrders()
                      : buildProfile(),
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: selectedIndex,
        onTap: (index) {
          setState(() {
            selectedIndex = index;
          });
        },
        items: const [
          BottomNavigationBarItem(
            icon: Icon(Icons.home_outlined),
            activeIcon: Icon(Icons.home),
            label: 'Home',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.search),
            label: 'Search',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.shopping_bag_outlined),
            activeIcon: Icon(Icons.shopping_bag),
            label: 'Cart',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.receipt_long_outlined),
            activeIcon: Icon(Icons.receipt_long),
            label: 'Orders',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.person_outline),
            activeIcon: Icon(Icons.person),
            label: 'Profile',
          ),
        ],
      ),
    );
  }

  // ==========================================================
  // HOME
  // ==========================================================

  Widget buildHome() {
    return SingleChildScrollView(
      controller: homeScroll,
      padding: const EdgeInsets.fromLTRB(16, 10, 16, 25),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Fresh Mutton, Your Way 🥩',
            style: TextStyle(
              color: Colors.white,
              fontSize: 27,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 6),
          const Text(
            'Choose your favourite cut and order fresh.',
            style: TextStyle(color: Colors.white54),
          ),
          const SizedBox(height: 20),
          TextField(
            controller: searchController,
            onChanged: (_) {
              setState(() {
                selectedCategory = null;
              });
            },
            style: const TextStyle(color: Colors.white),
            decoration: InputDecoration(
              hintText: 'Search mutton cuts...',
              prefixIcon: const Icon(Icons.search),
              suffixIcon: searchController.text.isNotEmpty
                  ? IconButton(
                      onPressed: () {
                        searchController.clear();
                        setState(() {});
                      },
                      icon: const Icon(Icons.close),
                    )
                  : null,
            ),
          ),
          const SizedBox(height: 25),
          const Text(
            'Shop by Cut',
            style: TextStyle(
              color: Colors.white,
              fontSize: 21,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 15),
          SizedBox(
            height: 105,
            child: ListView(
              scrollDirection: Axis.horizontal,
              children: [
                category(
                  'Biryani',
                  Icons.rice_bowl,
                  'biryani',
                  'https://images.unsplash.com/photo-1589302168068-964664d93dc0?auto=format&fit=crop&w=500&q=85',
                ),
                category(
                  'Boneless',
                  Icons.restaurant,
                  'boneless',
                  'https://images.unsplash.com/photo-1603360946369-dc9bb6258143?auto=format&fit=crop&w=500&q=85',
                ),
                category(
                  'Curry Cut',
                  Icons.set_meal,
                  'curry',
                  'https://images.unsplash.com/photo-1544025162-d76694265947?auto=format&fit=crop&w=500&q=85',
                ),
                category(
                  'Keema',
                  Icons.grain,
                  'keema',
                  'https://images.unsplash.com/photo-1529042410759-befb1204b468?auto=format&fit=crop&w=500&q=85',
                ),
                category(
                  'Liver',
                  Icons.favorite,
                  'liver',
                  'https://images.unsplash.com/photo-1602470520998-f4a52199a3d6?auto=format&fit=crop&w=500&q=85',
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),
          promoBanner(),
          const SizedBox(height: 28),
          Row(
            key: productsKey,
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                selectedCategory == null
                    ? 'Popular Mutton Cuts'
                    : 'Your Selection',
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 21,
                  fontWeight: FontWeight.bold,
                ),
              ),
              if (selectedCategory != null)
                TextButton(
                  onPressed: () => setState(() => selectedCategory = null),
                  child: const Text(
                    'Show all',
                    style: TextStyle(color: lightGreen),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 10),
          StreamBuilder<QuerySnapshot>(
            stream: FirebaseFirestore.instance.collection('products').snapshots(),
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const ProductsGridSkeleton();
              }

              final prods = parseProducts(snapshot);
              final query = searchController.text.trim().toLowerCase();
              final filtered = query.isEmpty
                  ? prods
                  : prods.where((p) => p.name.toLowerCase().contains(query)).toList();

              final homeItems = selectedCategory == null
                  ? filtered
                  : filtered.where((p) => p.name.toLowerCase().contains(selectedCategory!)).toList();

              if (homeItems.isEmpty) {
                return const Padding(
                  padding: EdgeInsets.all(30),
                  child: Center(
                    child: Text(
                      'No mutton cut found.',
                      style: TextStyle(color: Colors.white54),
                    ),
                  ),
                );
              }

              return GridView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: homeItems.length,
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 2,
                  crossAxisSpacing: 12,
                  mainAxisSpacing: 15,
                  childAspectRatio: 0.58,
                ),
                itemBuilder: (context, index) => productCard(homeItems[index]),
              );
            },
          ),
        ],
      ),
    );
  }

  Widget category(
    String title,
    IconData icon,
    String keyword,
    String imageUrl,
  ) {
    final selected = selectedCategory == keyword;

    return GestureDetector(
      onTap: () => selectCategory(keyword),
      child: Container(
        width: 82,
        margin: const EdgeInsets.only(right: 12),
        child: Column(
          children: [
            Container(
              padding: const EdgeInsets.all(2),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(20),
                border: Border.all(
                  color: selected ? primaryGreen : Colors.transparent,
                  width: 2,
                ),
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(18),
                child: SizedBox(
                  width: 62,
                  height: 62,
                  child: SkeletonNetworkImage(
                    imageUrl: imageUrl,
                    fit: BoxFit.cover,
                    errorBuilder: (_, __, ___) => Container(
                      color: cardColor2,
                      child: Icon(icon, color: primaryGreen),
                    ),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 6),
            Text(
              title,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              textAlign: TextAlign.center,
              style: TextStyle(
                color: selected ? lightGreen : Colors.white70,
                fontSize: 12,
                fontWeight: selected ? FontWeight.bold : FontWeight.normal,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget promoBanner() {
    return Container(
      height: 165,
      width: double.infinity,
      padding: const EdgeInsets.all(22),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [
            Color(0xFF103D27),
            Color(0xFF176B3A),
            Color(0xFF102C20),
          ],
        ),
        borderRadius: BorderRadius.circular(25),
      ),
      child: Row(
        children: [
          const Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  "TODAY'S SPECIAL",
                  style: TextStyle(
                    color: goldColor,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                SizedBox(height: 8),
                Text(
                  'Premium Mutton\nDelivered Fresh',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 21,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
          ),
          const Icon(Icons.restaurant, color: goldColor, size: 70),
        ],
      ),
    );
  }

  Widget productCard(Product product) {
    final isFavourite = favourites.contains(product);

    return Container(
      decoration: BoxDecoration(
        color: cardColor,
        borderRadius: BorderRadius.circular(20),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Stack(
              children: [
                SizedBox(
                  width: double.infinity,
                  height: 125,
                  child: SkeletonNetworkImage(
                    imageUrl: product.imageUrl,
                    fit: BoxFit.cover,
                    errorBuilder: (_, __, ___) {
                      return Container(
                        color: cardColor2,
                        child: const Center(
                          child: Icon(
                            Icons.restaurant,
                            color: primaryGreen,
                            size: 48,
                          ),
                        ),
                      );
                    },
                  ),
                ),
                Positioned(
                  top: 8,
                  right: 8,
                  child: GestureDetector(
                    onTap: () {
                      toggleFavourite(product);
                    },
                    child: Container(
                      width: 34,
                      height: 34,
                      decoration: const BoxDecoration(
                        color: Colors.black54,
                        shape: BoxShape.circle,
                      ),
                      child: Icon(
                        isFavourite ? Icons.favorite : Icons.favorite_border,
                        color: isFavourite ? Colors.redAccent : Colors.white,
                        size: 19,
                      ),
                    ),
                  ),
                ),
              ],
            ),
            Padding(
              padding: const EdgeInsets.all(10),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    product.name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      const Icon(Icons.star, color: goldColor, size: 14),
                      const SizedBox(width: 3),
                      Text(
                        '${product.rating}',
                        style: const TextStyle(
                          color: Colors.white70,
                          fontSize: 11,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(
                    product.description,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: Colors.white54,
                      fontSize: 10,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    product.weight,
                    style: const TextStyle(
                      color: Colors.white54,
                      fontSize: 11,
                    ),
                  ),
                  const SizedBox(height: 5),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        '₹${product.price}',
                        style: const TextStyle(
                          color: creamColor,
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      InkWell(
                        onTap: () {
                          addToCart(product);
                        },
                        child: Container(
                          width: 36,
                          height: 36,
                          decoration: BoxDecoration(
                            color: primaryGreen,
                            borderRadius: BorderRadius.circular(11),
                          ),
                          child: const Icon(Icons.add, color: Colors.white),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ==========================================================
  // SEARCH
  // ==========================================================

  Widget buildSearch() {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Search Mutton',
            style: TextStyle(
              color: Colors.white,
              fontSize: 27,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 15),
          TextField(
            controller: searchController,
            autofocus: true,
            onChanged: (_) {
              setState(() {});
            },
            decoration: const InputDecoration(
              hintText: 'Search cuts...',
              prefixIcon: Icon(Icons.search),
            ),
          ),
          const SizedBox(height: 20),
          Expanded(
            child: StreamBuilder<QuerySnapshot>(
              stream: FirebaseFirestore.instance.collection('products').snapshots(),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const ProductsGridSkeleton();
                }

                final prods = parseProducts(snapshot);
                final query = searchController.text.trim().toLowerCase();
                final filtered = query.isEmpty
                    ? prods
                    : prods.where((p) => p.name.toLowerCase().contains(query)).toList();

                if (filtered.isEmpty) {
                  return const Center(
                    child: Text(
                      'No mutton cut found.',
                      style: TextStyle(color: Colors.white54),
                    ),
                  );
                }

                return GridView.builder(
                  itemCount: filtered.length,
                  gridDelegate:
                      const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 2,
                    crossAxisSpacing: 12,
                    mainAxisSpacing: 15,
                    childAspectRatio: 0.58,
                  ),
                  itemBuilder: (context, index) {
                    return productCard(filtered[index]);
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  // ==========================================================
  // CART
  // ==========================================================

  Widget buildCartPage() {
    if (cart.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(
              Icons.shopping_bag_outlined,
              color: Colors.white24,
              size: 80,
            ),
            const SizedBox(height: 15),
            const Text(
              'Your cart is empty',
              style: TextStyle(
                color: Colors.white,
                fontSize: 20,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 15),
            ElevatedButton(
              onPressed: () {
                setState(() {
                  selectedIndex = 0;
                });
              },
              child: const Text('Start Shopping'),
            ),
          ],
        ),
      );
    }

    return Column(
      children: [
        Expanded(
          child: ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: cart.length + 1,
            itemBuilder: (context, index) {
              if (index == cart.length) {
                return suggestionsSection(cartSuggestions());
              }

              final product = cart[index];

              return Container(
                margin: const EdgeInsets.only(bottom: 10),
                decoration: BoxDecoration(
                  color: cardColor,
                  borderRadius: BorderRadius.circular(16),
                ),
                child: ListTile(
                  leading: ClipRRect(
                    borderRadius: BorderRadius.circular(10),
                    child: SizedBox(
                      width: 58,
                      height: 58,
                      child: SkeletonNetworkImage(
                        imageUrl: product.imageUrl,
                        fit: BoxFit.cover,
                        errorBuilder: (_, __, ___) {
                          return Container(
                            color: cardColor2,
                            child: const Icon(
                              Icons.restaurant,
                              color: primaryGreen,
                            ),
                          );
                        },
                      ),
                    ),
                  ),
                  title: Text(
                    product.name,
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  subtitle: Text(
                    product.weight,
                    style: const TextStyle(color: Colors.white54),
                  ),
                  trailing: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Text(
                        '₹${product.price}',
                        style: const TextStyle(
                          color: lightGreen,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      GestureDetector(
                        onTap: () {
                          setState(() {
                            cart.removeAt(index);
                          });
                        },
                        child: const Text(
                          'Remove',
                          style: TextStyle(color: accentRed, fontSize: 11),
                        ),
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
        ),
        Container(
          padding: const EdgeInsets.all(20),
          decoration: const BoxDecoration(color: cardColor),
          child: Column(
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    'Total',
                    style: TextStyle(color: Colors.white70, fontSize: 17),
                  ),
                  Text(
                    '₹$cartTotal',
                    style: const TextStyle(
                      color: creamColor,
                      fontSize: 23,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 15),
              SizedBox(
                width: double.infinity,
                height: 54,
                child: ElevatedButton(
                  onPressed: () {
                    final items = List<Product>.from(cart);

                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => CheckoutScreen(
                          cartItems: items,
                          total: cartTotal,
                          // Called once the order is saved: empty the cart
                          // and reset the tab so Home is clean when the
                          // customer returns from the success screen.
                          onOrderPlaced: () {
                            if (!mounted) return;
                            setState(() {
                              cart.clear();
                              selectedIndex = 0;
                            });
                          },
                          // Called from the success screen's
                          // "VIEW MY ORDERS" button.
                          onViewOrders: () {
                            if (!mounted) return;
                            setState(() {
                              selectedIndex = 3;
                            });
                          },
                        ),
                      ),
                    );
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: primaryGreen,
                    foregroundColor: Colors.white,
                  ),
                  child: const Text(
                    'PROCEED TO CHECKOUT',
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  // ==========================================================
  // CUSTOMER ORDERS
  // ==========================================================

  Widget buildOrders() {
    final user = FirebaseAuth.instance.currentUser;

    if (user == null) {
      return const Center(child: Text('Please login again.'));
    }

    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('orders')
          .where('userId', isEqualTo: user.uid)
          .snapshots(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const SingleChildScrollView(
            padding: EdgeInsets.all(16),
            child: OrdersListSkeleton(itemCount: 4),
          );
        }

        if (snapshot.hasError) {
          return const Center(
            child: Text(
              'Unable to load orders.',
              style: TextStyle(color: Colors.white70),
            ),
          );
        }

        final docs = snapshot.data?.docs.toList() ?? [];

        docs.sort((a, b) {
          final aData = a.data() as Map<String, dynamic>;
          final bData = b.data() as Map<String, dynamic>;

          final aTime = aData['createdAt'] as Timestamp?;
          final bTime = bData['createdAt'] as Timestamp?;

          return (bTime?.millisecondsSinceEpoch ?? 0)
              .compareTo(aTime?.millisecondsSinceEpoch ?? 0);
        });

        // Products this customer already ordered (to suggest new ones).
        final orderedNames = <String>{};

        for (final d in docs) {
          final m = d.data() as Map<String, dynamic>;
          for (final item in getItems(m)) {
            orderedNames.add('${item['name']}');
          }
        }

        if (docs.isEmpty) {
          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              const SizedBox(height: 30),
              const Icon(
                Icons.receipt_long_outlined,
                color: Colors.white24,
                size: 70,
              ),
              const SizedBox(height: 12),
              const Center(
                child: Text(
                  'No orders yet.',
                  style: TextStyle(color: Colors.white54),
                ),
              ),
              suggestionsSection(
                orderSuggestions(orderedNames),
                title: 'Try our popular cuts',
              ),
            ],
          );
        }

        return ListView.builder(
          padding: const EdgeInsets.all(16),
          itemCount: docs.length + 1,
          itemBuilder: (context, index) {
            if (index == docs.length) {
              return suggestionsSection(
                orderSuggestions(orderedNames),
                title: 'You may also like',
              );
            }

            final data = docs[index].data() as Map<String, dynamic>;

            return orderCard(data);
          },
        );
      },
    );
  }

  Widget orderCard(Map<String, dynamic> data) {
    final status = data['orderStatus'] ?? 'Pending Admin Approval';

    final rawItems = data['items'] ?? [];

    final items = List<Map<String, dynamic>>.from(
      rawItems.map((item) => Map<String, dynamic>.from(item)),
    );

    return Container(
      margin: const EdgeInsets.only(bottom: 15),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: cardColor,
        borderRadius: BorderRadius.circular(18),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'ORDER',
                style: TextStyle(
                  color: lightGreen,
                  fontWeight: FontWeight.bold,
                ),
              ),
              statusBadge(status.toString()),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            '#${data['orderId'] ?? ''}',
            style: const TextStyle(color: Colors.white54, fontSize: 11),
          ),
          const SizedBox(height: 12),
          ...items.map(
            (item) => Padding(
              padding: const EdgeInsets.symmetric(vertical: 4),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      '${item['name']} (${item['weight']})',
                      style: const TextStyle(color: Colors.white70),
                    ),
                  ),
                  Text(
                    'x${item['quantity'] ?? 1}',
                    style: const TextStyle(color: lightGreen),
                  ),
                  const SizedBox(width: 15),
                  Text(
                    inr(toInt(item['price']) * toInt(item['quantity'], 1)),
                    style: const TextStyle(color: Colors.white),
                  ),
                ],
              ),
            ),
          ),
          const Divider(color: Colors.white12),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text('Total', style: TextStyle(color: Colors.white70)),
              Text(
                '₹${data['totalAmount'] ?? 0}',
                style: const TextStyle(
                  color: creamColor,
                  fontSize: 19,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            statusMessage(status.toString()),
            style: const TextStyle(color: Colors.white70),
          ),
          const SizedBox(height: 12),
          SizedBox(
            width: double.infinity,
            height: 44,
            child: OutlinedButton.icon(
              onPressed: () => openTracking((data['orderId'] ?? '').toString()),
              icon: const Icon(Icons.local_shipping_outlined, size: 19),
              label: const Text('TRACK MY ORDER'),
              style: OutlinedButton.styleFrom(
                foregroundColor: lightGreen,
                side: const BorderSide(color: primaryGreen),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget statusBadge(String status) {
    Color color = goldColor;

    if (status == 'Confirmed' || status == 'Confirmed by Admin') {
      color = primaryGreen;
    } else if (status == 'Preparing') {
      color = Colors.orange;
    } else if (status == 'Out for Delivery') {
      color = Colors.blue;
    } else if (status == 'Delivered') {
      color = primaryGreen;
    } else if (status == 'Cancelled') {
      color = accentRed;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: color.withOpacity(0.15),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withOpacity(0.5)),
      ),
      child: Text(
        status,
        style: TextStyle(
          color: color,
          fontSize: 11,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }

  String statusMessage(String status) {
    switch (status) {
      case 'Pending Admin Approval':
        return '⏳ Waiting for admin confirmation.';
      case 'Confirmed':
      case 'Confirmed by Admin':
        return '✅ Your order has been confirmed by GoatKart.';
      case 'Preparing':
        return '👨‍🍳 Your order is being prepared.';
      case 'Out for Delivery':
        return '🚚 Your order is out for delivery.';
      case 'Delivered':
        return '🎉 Order delivered successfully.';
      case 'Cancelled':
        return '❌ This order has been cancelled.';
      default:
        return 'Order status: $status';
    }
  }

  // ==========================================================
  // PROFILE
  // ==========================================================

  Widget buildProfile() {
    final user = FirebaseAuth.instance.currentUser;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        children: [
          const SizedBox(height: 20),
          Container(
            width: 95,
            height: 95,
            decoration: const BoxDecoration(
              color: primaryGreen,
              shape: BoxShape.circle,
            ),
            child: const Icon(Icons.person, color: Colors.white, size: 52),
          ),
          const SizedBox(height: 15),
          Text(
            user?.displayName ?? 'GoatKart User',
            style: const TextStyle(
              color: Colors.white,
              fontSize: 23,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 5),
          Text(
            user?.email ?? '',
            style: const TextStyle(color: Colors.white54),
          ),
          const SizedBox(height: 30),
          profileOption(Icons.receipt_long, 'My Orders', () {
            setState(() {
              selectedIndex = 3;
            });
          }),
          profileOption(
            Icons.local_shipping_outlined,
            'Track My Order',
            openTrackPicker,
          ),
          profileOption(
            Icons.location_on_outlined,
            'Delivery Address',
            openDeliveryAddress,
          ),
          profileOption(
            Icons.favorite_border,
            'Favourite Cuts',
            showFavourites,
          ),
          profileOption(Icons.help_outline, 'Help & Support', openHelpSupport),
          const SizedBox(height: 10),
          Container(
            width: double.infinity,
            decoration: BoxDecoration(
              color: cardColor,
              borderRadius: BorderRadius.circular(16),
            ),
            child: ListTile(
              leading: const Icon(Icons.logout, color: accentRed),
              title: const Text(
                'Logout',
                style: TextStyle(
                  color: accentRed,
                  fontWeight: FontWeight.bold,
                ),
              ),
              onTap: logout,
            ),
          ),
        ],
      ),
    );
  }

  Widget profileOption(IconData icon, String title, VoidCallback onTap) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(
        color: cardColor,
        borderRadius: BorderRadius.circular(16),
      ),
      child: ListTile(
        leading: Icon(icon, color: lightGreen),
        title: Text(title, style: const TextStyle(color: Colors.white)),
        trailing: const Icon(Icons.chevron_right, color: Colors.white38),
        onTap: onTap,
      ),
    );
  }

  // ==========================================================
  // DELIVERY ADDRESS (view + edit)
  // ==========================================================

  Future<void> openDeliveryAddress() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    final fields = AddressFields();
    String saved = '';

    try {
      final doc = await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .get();

      final data = doc.data();
      final parts = data?['addressParts'];

      saved = (data?['address'] ?? '').toString();

      if (parts is Map) {
        fields.fill(Map<String, dynamic>.from(parts));
      } else if (saved.isNotEmpty) {
        fields.house.text = saved;
      }
    } catch (_) {}

    if (!mounted) {
      fields.dispose();
      return;
    }

    bool editing = saved.isEmpty;
    bool saving = false;

    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: cardColor,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (sheetContext) {
        return StatefulBuilder(
          builder: (context, setSheet) {
            return Padding(
              padding: EdgeInsets.fromLTRB(
                20,
                22,
                20,
                MediaQuery.of(context).viewInsets.bottom + 24,
              ),
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        const Icon(Icons.location_on, color: primaryGreen),
                        const SizedBox(width: 8),
                        const Expanded(
                          child: Text(
                            'Delivery Address',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 20,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                        if (!editing && saved.isNotEmpty)
                          TextButton.icon(
                            onPressed: () => setSheet(() => editing = true),
                            icon: const Icon(Icons.edit, size: 18),
                            label: const Text('Edit'),
                            style: TextButton.styleFrom(
                              foregroundColor: lightGreen,
                            ),
                          ),
                      ],
                    ),
                    const SizedBox(height: 14),
                    if (editing) ...[
                      buildAddressForm(fields),
                      const SizedBox(height: 14),
                      SizedBox(
                        width: double.infinity,
                        height: 50,
                        child: ElevatedButton(
                          onPressed: saving
                              ? null
                              : () async {
                                  final error = fields.validate();

                                  if (error != null) {
                                    ScaffoldMessenger.of(this.context)
                                        .showSnackBar(SnackBar(
                                      content: Text(error),
                                      backgroundColor: accentRed,
                                    ));
                                    return;
                                  }

                                  setSheet(() => saving = true);

                                  try {
                                    final full = fields.full;

                                    await FirebaseFirestore.instance
                                        .collection('users')
                                        .doc(user.uid)
                                        .set({
                                      'address': full,
                                      'addressParts': fields.toMap(),
                                    }, SetOptions(merge: true));

                                    saved = full;
                                    setSheet(() {
                                      editing = false;
                                      saving = false;
                                    });

                                    ScaffoldMessenger.of(this.context)
                                        .showSnackBar(const SnackBar(
                                      content: Text('Address saved.'),
                                      backgroundColor: primaryGreen,
                                    ));
                                  } catch (_) {
                                    setSheet(() => saving = false);
                                    ScaffoldMessenger.of(this.context)
                                        .showSnackBar(const SnackBar(
                                      content: Text(
                                          'Could not save the address. Try again.'),
                                      backgroundColor: accentRed,
                                    ));
                                  }
                                },
                          style: ElevatedButton.styleFrom(
                            backgroundColor: primaryGreen,
                            foregroundColor: Colors.white,
                          ),
                          child: saving
                              ? const SizedBox(
                                  width: 22,
                                  height: 22,
                                  child: CircularProgressIndicator(
                                    color: Colors.white,
                                    strokeWidth: 2.5,
                                  ),
                                )
                              : const Text('SAVE ADDRESS'),
                        ),
                      ),
                    ] else
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(14),
                        decoration: BoxDecoration(
                          color: cardColor2,
                          borderRadius: BorderRadius.circular(14),
                        ),
                        child: Text(
                          saved,
                          style: const TextStyle(
                            color: Colors.white70,
                            height: 1.4,
                          ),
                        ),
                      ),
                    if (saved.isEmpty && editing)
                      const Padding(
                        padding: EdgeInsets.only(top: 10),
                        child: Text(
                          'Your address is also saved automatically when you place an order.',
                          style: TextStyle(color: Colors.white38, fontSize: 12),
                        ),
                      ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );

    fields.dispose();
  }

  // ==========================================================
  // SUGGESTIONS  (products from the Home page)
  // ==========================================================

  List<Product> cartSuggestions() {
    final inCart = cart.map((c) => c.name).toSet();

    return products.where((p) => !inCart.contains(p.name)).take(6).toList();
  }

  List<Product> orderSuggestions(Set<String> orderedNames) {
    final fresh =
        products.where((p) => !orderedNames.contains(p.name)).toList();

    return (fresh.isEmpty ? products : fresh).take(6).toList();
  }

  Widget suggestionsSection(List<Product> list, {String? title}) {
    if (list.isEmpty) return const SizedBox.shrink();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(top: 18, bottom: 12),
          child: Text(
            title ?? 'You may also like',
            style: const TextStyle(
              color: Colors.white,
              fontSize: 19,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
        SizedBox(
          height: 224,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            itemCount: list.length,
            separatorBuilder: (_, __) => const SizedBox(width: 12),
            itemBuilder: (context, i) => suggestionCard(list[i]),
          ),
        ),
      ],
    );
  }

  Widget suggestionCard(Product product) {
    return Container(
      width: 150,
      decoration: BoxDecoration(
        color: cardColor,
        borderRadius: BorderRadius.circular(18),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SizedBox(
              width: double.infinity,
              height: 95,
              child: SkeletonNetworkImage(
                imageUrl: product.imageUrl,
                fit: BoxFit.cover,
                errorBuilder: (_, __, ___) => Container(
                  color: cardColor2,
                  child: const Center(
                    child: Icon(Icons.restaurant, color: primaryGreen),
                  ),
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(10, 8, 10, 8),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    product.name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                      fontSize: 13,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    product.weight,
                    style: const TextStyle(color: Colors.white54, fontSize: 11),
                  ),
                  const SizedBox(height: 6),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        '₹${product.price}',
                        style: const TextStyle(
                          color: creamColor,
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      InkWell(
                        onTap: () => addToCart(product),
                        child: Container(
                          width: 32,
                          height: 32,
                          decoration: BoxDecoration(
                            color: primaryGreen,
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: const Icon(
                            Icons.add,
                            color: Colors.white,
                            size: 20,
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ==========================================================
  // TRACK MY ORDER
  // ==========================================================

  void openTracking(String orderId) {
    if (orderId.isEmpty) return;

    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => TrackOrderScreen(orderId: orderId)),
    );
  }

  Future<void> openTrackPicker() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    List<Map<String, dynamic>> list = [];

    try {
      final snap = await FirebaseFirestore.instance
          .collection('orders')
          .where('userId', isEqualTo: user.uid)
          .get();

      list = snap.docs.map((d) {
        final m = Map<String, dynamic>.from(d.data());
        m['orderId'] = (m['orderId'] ?? d.id).toString();
        return m;
      }).toList();

      list.sort((a, b) => orderTime(b).compareTo(orderTime(a)));
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Unable to load your orders. Try again.'),
          backgroundColor: accentRed,
        ),
      );
      return;
    }

    if (!mounted) return;

    if (list.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('You have no orders to track yet.'),
          backgroundColor: primaryGreen,
        ),
      );
      return;
    }

    if (list.length == 1) {
      openTracking(list.first['orderId'].toString());
      return;
    }

    showModalBottomSheet(
      context: context,
      backgroundColor: cardColor,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (sheetContext) {
        return SizedBox(
          height: MediaQuery.of(context).size.height * 0.6,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Padding(
                padding: EdgeInsets.fromLTRB(20, 22, 20, 6),
                child: Text(
                  'Select an order to track',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              Expanded(
                child: ListView.builder(
                  padding: const EdgeInsets.all(16),
                  itemCount: list.length,
                  itemBuilder: (context, index) {
                    final o = list[index];
                    final id = o['orderId'].toString();
                    final status = getStatus(o);

                    return Container(
                      margin: const EdgeInsets.only(bottom: 10),
                      decoration: BoxDecoration(
                        color: cardColor2,
                        borderRadius: BorderRadius.circular(14),
                      ),
                      child: ListTile(
                        onTap: () {
                          Navigator.pop(sheetContext);
                          openTracking(id);
                        },
                        leading: const Icon(
                          Icons.local_shipping_outlined,
                          color: lightGreen,
                        ),
                        title: Text(
                          'Order #${shortId(id)} • ${inr(getAmount(o))}',
                          style: const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        subtitle: Text(
                          '${formatDateTime(orderTime(o))}\n$status',
                          style: TextStyle(
                            color: statusColor(status),
                            fontSize: 12,
                            height: 1.4,
                          ),
                        ),
                        isThreeLine: true,
                        trailing: const Icon(
                          Icons.chevron_right,
                          color: Colors.white38,
                        ),
                      ),
                    );
                  },
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  // ==========================================================
  // HELP & SUPPORT
  // ==========================================================

  static const String supportWhatsApp = '918106285345'; // 91 + number
  static const String supportEmail = 'admingoatkart03@gmail.com';

  Future<void> openLink(Uri uri) async {
    try {
      final ok = await launchUrl(uri, mode: LaunchMode.externalApplication);
      if (!ok) throw Exception('cannot launch');
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Unable to open the app. Please try again.'),
          backgroundColor: accentRed,
        ),
      );
    }
  }

  Future<void> openWhatsApp() {
    final user = FirebaseAuth.instance.currentUser;
    final name = user?.displayName ?? 'a customer';

    return openLink(Uri.parse(
      'https://wa.me/$supportWhatsApp?text=${Uri.encodeComponent('Hello GoatKart, I am $name. I need help with my order.')}',
    ));
  }

  Future<void> openSupportEmail() {
    final user = FirebaseAuth.instance.currentUser;

    final subject = Uri.encodeComponent('GoatKart Support - Issue / Problem');
    final body = Uri.encodeComponent(
      'Hello GoatKart team,\n\nName: ${user?.displayName ?? ''}\nEmail: ${user?.email ?? ''}\n\nMy issue:\n',
    );

    return openLink(
      Uri.parse('mailto:$supportEmail?subject=$subject&body=$body'),
    );
  }

  void openHelpSupport() {
    showModalBottomSheet(
      context: context,
      backgroundColor: cardColor,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (sheetContext) {
        return Padding(
          padding: const EdgeInsets.fromLTRB(20, 22, 20, 30),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Help & Support',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 6),
              const Text(
                'Facing an issue or problem? Contact the GoatKart team.',
                style: TextStyle(color: Colors.white54),
              ),
              const SizedBox(height: 18),
              ListTile(
                tileColor: cardColor2,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
                leading: const Icon(Icons.chat, color: primaryGreen),
                title: const Text(
                  'Chat on WhatsApp',
                  style: TextStyle(color: Colors.white),
                ),
                subtitle: const Text(
                  '+91 8106285345',
                  style: TextStyle(color: Colors.white54),
                ),
                trailing:
                    const Icon(Icons.chevron_right, color: Colors.white38),
                onTap: () {
                  Navigator.pop(sheetContext);
                  openWhatsApp();
                },
              ),
              const SizedBox(height: 10),
              ListTile(
                tileColor: cardColor2,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
                leading: const Icon(Icons.email_outlined, color: goldColor),
                title: const Text(
                  'Email Us',
                  style: TextStyle(color: Colors.white),
                ),
                subtitle: const Text(
                  supportEmail,
                  style: TextStyle(color: Colors.white54),
                ),
                trailing:
                    const Icon(Icons.chevron_right, color: Colors.white38),
                onTap: () {
                  Navigator.pop(sheetContext);
                  openSupportEmail();
                },
              ),
            ],
          ),
        );
      },
    );
  }

  void showFavourites() {
    showModalBottomSheet(
      context: context,
      backgroundColor: cardColor,
      builder: (_) {
        return SizedBox(
          height: 400,
          child: favourites.isEmpty
              ? const Center(
                  child: Text(
                    'No favourite cuts yet.',
                    style: TextStyle(color: Colors.white54),
                  ),
                )
              : ListView.builder(
                  padding: const EdgeInsets.all(16),
                  itemCount: favourites.length,
                  itemBuilder: (context, index) {
                    final product = favourites[index];

                    return ListTile(
                      leading: const Icon(
                        Icons.favorite,
                        color: Colors.redAccent,
                      ),
                      title: Text(
                        product.name,
                        style: const TextStyle(color: Colors.white),
                      ),
                      subtitle: Text(
                        product.weight,
                        style: const TextStyle(color: Colors.white54),
                      ),
                      trailing: Text(
                        '₹${product.price}',
                        style: const TextStyle(color: lightGreen),
                      ),
                    );
                  },
                ),
        );
      },
    );
  }

  Future<void> logout() async {
    await FirebaseAuth.instance.signOut();

    if (!mounted) return;

    Navigator.pushAndRemoveUntil(
      context,
      MaterialPageRoute(builder: (_) => const AuthScreen()),
      (route) => false,
    );
  }
}

// ============================================================
// CHECKOUT SCREEN
// ============================================================

class CheckoutScreen extends StatefulWidget {
  final List<Product> cartItems;
  final int total;
  final VoidCallback onOrderPlaced;
  final VoidCallback onViewOrders;

  const CheckoutScreen({
    super.key,
    required this.cartItems,
    required this.total,
    required this.onOrderPlaced,
    required this.onViewOrders,
  });

  @override
  State<CheckoutScreen> createState() => _CheckoutScreenState();
}

class _CheckoutScreenState extends State<CheckoutScreen> {
  final nameController = TextEditingController();
  final phoneController = TextEditingController();
  final AddressFields address = AddressFields();

  bool isGettingLocation = false;
  bool isPlacingOrder = false;

  double? latitude;
  double? longitude;
  double? gpsAccuracy; // metres
  bool addressFromGps = false;

  @override
  void initState() {
    super.initState();

    final user = FirebaseAuth.instance.currentUser;

    nameController.text = user?.displayName ?? '';

    loadSavedDetails();
  }

  /// Loads the saved phone number and saved delivery address (if any).
  Future<void> loadSavedDetails() async {
    final user = FirebaseAuth.instance.currentUser;

    if (user == null) return;

    try {
      final doc = await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .get();

      if (!mounted) return;

      final data = doc.data();

      if (data == null) return;

      if (data['phone'] != null) {
        phoneController.text = data['phone'].toString();
      }

      if (address.isEmpty) {
        final parts = data['addressParts'];
        final legacy = (data['address'] ?? '').toString();

        setState(() {
          if (parts is Map) {
            address.fill(Map<String, dynamic>.from(parts));
          } else if (legacy.isNotEmpty) {
            address.house.text = legacy;
          }
        });
      }
    } catch (_) {}
  }

  @override
  void dispose() {
    nameController.dispose();
    phoneController.dispose();
    address.dispose();
    super.dispose();
  }

  // ==========================================================
  // CURRENT LOCATION
  // ==========================================================

  /// Listens to the GPS for a few seconds and keeps the MOST ACCURATE
  /// reading (instead of trusting the first, often rough, position).
  Future<Position> getBestPosition() async {
    Position? best;
    final completer = Completer<Position>();
    StreamSubscription<Position>? sub;

    final timer = Timer(const Duration(seconds: 15), () {
      if (completer.isCompleted) return;

      if (best != null) {
        completer.complete(best!);
      } else {
        completer.completeError(TimeoutException('gps'));
      }
    });

    sub = Geolocator.getPositionStream(
      locationSettings: const LocationSettings(
        accuracy: LocationAccuracy.high,
        distanceFilter: 0,
      ),
    ).listen(
      (p) {
        if (best == null || p.accuracy < best!.accuracy) {
          best = p;
        }

        // Good enough: stop early.
        if (p.accuracy <= 30 && !completer.isCompleted) {
          completer.complete(p);
        }
      },
      onError: (Object e) {
        if (!completer.isCompleted) {
          if (best != null) {
            completer.complete(best!);
          } else {
            completer.completeError(e);
          }
        }
      },
    );

    try {
      return await completer.future;
    } finally {
      timer.cancel();
      await sub.cancel();
    }
  }

  Future<void> useCurrentLocation() async {
    if (isGettingLocation) return;

    setState(() {
      isGettingLocation = true;
    });

    try {
      final serviceEnabled = await Geolocator.isLocationServiceEnabled();

      if (!serviceEnabled) {
        showMessage('Please turn on Location/GPS on your device.');
        return;
      }

      LocationPermission permission = await Geolocator.checkPermission();

      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }

      if (permission == LocationPermission.denied ||
          permission == LocationPermission.deniedForever) {
        showMessage(
          'Location permission is required. Please allow location access.',
        );
        return;
      }

      final position = await getBestPosition();

      if (!mounted) return;

      latitude = position.latitude;
      longitude = position.longitude;
      gpsAccuracy = position.accuracy;

      final parts = await reverseGeocode(position.latitude, position.longitude);

      if (!mounted) return;

      if (parts == null) {
        setState(() {
          addressFromGps = false;
        });

        showMessage(
          'GPS location found, but the address could not be read. Please fill the address manually.',
        );
        return;
      }

      setState(() {
        address.fill(parts);
        addressFromGps = true;
      });

      if (position.accuracy > 50) {
        showMessage(
          'Location detected (${position.accuracy.toInt()}m accuracy). Signal is weak—please verify village and mandal.',
        );
      } else {
        showMessage(
          'Precise location detected (${position.accuracy.toInt()}m accuracy).',
          success: true,
        );
      }
    } on TimeoutException {
      if (mounted) {
        showMessage(
          'Could not get a GPS signal. Please go near a window or outdoors and try again.',
        );
      }
    } catch (_) {
      if (mounted) {
        showMessage(
          'Unable to get your current location. Please allow GPS/location permission and try again.',
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          isGettingLocation = false;
        });
      }
    }
  }

  Future<void> openOnMap() async {
    if (latitude == null || longitude == null) return;

    try {
      await launchUrl(
        Uri.parse(
          'https://www.google.com/maps/search/?api=1&query=$latitude,$longitude',
        ),
        mode: LaunchMode.externalApplication,
      );
    } catch (_) {
      showMessage('Unable to open maps.');
    }
  }

  // ==========================================================
  // PLACE ORDER
  // ==========================================================

  Future<void> placeOrder() async {
    if (isPlacingOrder) return;

    final user = FirebaseAuth.instance.currentUser;

    final name = nameController.text.trim();

    final phone = phoneController.text.replaceAll(RegExp(r'\D'), '');

    if (user == null) {
      showMessage('Please login before placing an order.');
      return;
    }

    if (name.isEmpty) {
      showMessage('Please enter your name.');
      return;
    }

    if (phone.length < 10) {
      showMessage('Please enter a valid phone number.');
      return;
    }

    final addressError = address.validate();

    if (addressError != null) {
      showMessage(addressError);
      return;
    }

    if (widget.cartItems.isEmpty) {
      showMessage('Your cart is empty.');
      return;
    }

    final fullAddress = address.full;
    final addressParts = address.toMap();

    setState(() {
      isPlacingOrder = true;
    });

    try {
      final orderRef = FirebaseFirestore.instance.collection('orders').doc();

      // ======================================================
      // GROUP SAME PRODUCTS
      // ======================================================

      final Map<String, Map<String, dynamic>> groupedItems = {};

      for (final product in widget.cartItems) {
        final key = '${product.name}_${product.weight}';

        if (groupedItems.containsKey(key)) {
          groupedItems[key]!['quantity'] =
              (groupedItems[key]!['quantity'] ?? 0) + 1;
        } else {
          groupedItems[key] = {
            'name': product.name,
            'weight': product.weight,
            'price': product.price,
            'quantity': 1,
          };
        }
      }

      final orderBatch = FirebaseFirestore.instance.batch();

      orderBatch.set(orderRef, {
        'orderId': orderRef.id,
        'userId': user.uid,
        'customerName': name,
        'email': user.email ?? '',
        'phone': phone,
        'address': fullAddress,
        'addressParts': addressParts,

        // LOCATION
        'latitude': latitude,
        'longitude': longitude,
        'gpsAccuracy': gpsAccuracy,
        'locationCaptured': latitude != null && longitude != null,
        'locationAddress': fullAddress,

        // ITEMS
        'items': groupedItems.values.toList(),

        // PAYMENT
        'totalAmount': widget.total,
        'paymentMethod': 'Cash on Delivery',
        'paymentStatus': 'Pending',

        // STATUS
        'orderStatus': 'Pending Admin Approval',

        'createdAt': FieldValue.serverTimestamp(),
      });

      // Shows up in the admin "Activity" tab.
      final totalQty = groupedItems.values
          .fold<int>(0, (sum, item) => sum + toInt(item['quantity'], 1));

      orderBatch.set(FirebaseFirestore.instance.collection('activity').doc(), {
        'type': 'order_placed',
        'title': 'New order placed',
        'message':
            '$name ordered $totalQty item${totalQty == 1 ? '' : 's'} • Order #${shortId(orderRef.id)}',
        'orderId': orderRef.id,
        'status': 'Pending Admin Approval',
        'amount': widget.total,
        'userId': user.uid,
        'actor': 'customer',
        'createdAt': FieldValue.serverTimestamp(),
      });

      await orderBatch.commit().timeout(const Duration(seconds: 20));

      // Admin notification alert (best-effort, never blocks order placement).
      try {
        await FirebaseFirestore.instance.collection('admin_notifications').add({
          'orderId': orderRef.id,
          'customerName': name,
          'amount': widget.total,
          'createdAt': FieldValue.serverTimestamp(),
          'read': false,
        });
      } catch (_) {}

      // Save this address to the customer's profile
      // (Profile > Delivery Address). Best-effort: never blocks an order.
      try {
        await FirebaseFirestore.instance
            .collection('users')
            .doc(user.uid)
            .set({
          'address': fullAddress,
          'addressParts': addressParts,
        }, SetOptions(merge: true));
      } catch (_) {}

      // Clear the cart in HomeScreen.
      widget.onOrderPlaced();

      if (!mounted) return;

      // Show the animated "Order placed successfully" screen.
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(
          builder: (_) => OrderSuccessScreen(
            orderId: orderRef.id,
            total: widget.total,
            onViewOrders: widget.onViewOrders,
          ),
        ),
      );
    } on TimeoutException {
      if (mounted) {
        showMessage(
          'Order request timed out. Check your internet and verify your order in My Orders before trying again.',
        );
      }
    } on FirebaseException catch (e) {
      if (mounted) {
        showMessage('Could not place order: ${e.message ?? e.code}');
      }
    } catch (e) {
      if (mounted) {
        showMessage('Something went wrong. Please try again.');
      }
    } finally {
      if (mounted) {
        setState(() {
          isPlacingOrder = false;
        });
      }
    }
  }

  // ==========================================================
  // MESSAGE
  // ==========================================================

  void showMessage(String message, {bool success = false}) {
    if (!mounted) return;

    ScaffoldMessenger.of(context).hideCurrentSnackBar();

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: success ? primaryGreen : accentRed,
      ),
    );
  }

  // ==========================================================
  // FIELD
  // ==========================================================

  Widget field(
    TextEditingController controller,
    String label,
    IconData icon, {
    int maxLines = 1,
    TextInputType? keyboardType,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: TextField(
        controller: controller,
        maxLines: maxLines,
        keyboardType: keyboardType,
        style: const TextStyle(color: Colors.white),
        decoration: InputDecoration(
          labelText: label,
          prefixIcon: Icon(icon),
        ),
      ),
    );
  }

  // ==========================================================
  // BUILD
  // ==========================================================

  @override
  Widget build(BuildContext context) {
    final lowAccuracy = gpsAccuracy != null && gpsAccuracy! > 100;

    return Scaffold(
      appBar: AppBar(title: const Text('Checkout')),
      body: SafeArea(
        child: ListView(
          padding: EdgeInsets.fromLTRB(
            20,
            20,
            20,
            20 + MediaQuery.of(context).viewInsets.bottom,
          ),
          children: [
            const Text(
              'Delivery Details',
              style: TextStyle(
                color: creamColor,
                fontSize: 23,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 18),
            field(nameController, 'Full Name', Icons.person_outline),
            field(
              phoneController,
              'Phone Number',
              Icons.phone_outlined,
              keyboardType: TextInputType.phone,
            ),

            // ==================================================
            // CURRENT LOCATION
            // ==================================================

            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: cardColor,
                borderRadius: BorderRadius.circular(18),
                border: Border.all(color: primaryGreen.withOpacity(0.35)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Row(
                    children: [
                      Icon(Icons.location_on, color: primaryGreen),
                      SizedBox(width: 8),
                      Text(
                        'Delivery Location',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 17,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    'Tap the button to fill village, mandal, district and pincode from your GPS. You can correct anything below.',
                    style: TextStyle(color: Colors.white54),
                  ),
                  const SizedBox(height: 12),
                  SizedBox(
                    width: double.infinity,
                    height: 48,
                    child: OutlinedButton.icon(
                      onPressed:
                          isGettingLocation ? null : useCurrentLocation,
                      icon: isGettingLocation
                          ? const SizedBox(
                              width: 18,
                              height: 18,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : const Icon(Icons.my_location),
                      label: Text(
                        isGettingLocation
                            ? 'Finding exact location...'
                            : 'USE CURRENT LOCATION',
                      ),
                    ),
                  ),
                  if (addressFromGps) ...[
                    const SizedBox(height: 10),
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: (lowAccuracy ? goldColor : primaryGreen)
                            .withOpacity(0.10),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Icon(
                            lowAccuracy
                                ? Icons.warning_amber_rounded
                                : Icons.check_circle,
                            color: lowAccuracy ? goldColor : lightGreen,
                            size: 20,
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              lowAccuracy
                                  ? 'GPS accuracy is low (±${gpsAccuracy!.round()} m). Please check every field below and correct it if needed.'
                                  : 'Location detected (±${(gpsAccuracy ?? 0).round()} m). Please confirm the fields below.',
                              style: TextStyle(
                                color: lowAccuracy ? goldColor : lightGreen,
                                fontSize: 13,
                                height: 1.35,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 8),
                    Align(
                      alignment: Alignment.centerLeft,
                      child: TextButton.icon(
                        onPressed: openOnMap,
                        icon: const Icon(Icons.map_outlined, size: 18),
                        label: const Text('View on map'),
                        style: TextButton.styleFrom(
                          foregroundColor: lightGreen,
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ),

            const SizedBox(height: 18),

            const Text(
              'Delivery Address',
              style: TextStyle(
                color: creamColor,
                fontSize: 19,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 12),
            buildAddressForm(address),

            const SizedBox(height: 20),

            // ==================================================
            // ORDER SUMMARY
            // ==================================================

            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: cardColor,
                borderRadius: BorderRadius.circular(18),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Order Summary',
                    style: TextStyle(
                      color: creamColor,
                      fontSize: 19,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 10),
                  ...widget.cartItems.map(
                    (product) => Padding(
                      padding: const EdgeInsets.symmetric(vertical: 5),
                      child: Row(
                        children: [
                          Expanded(
                            child: Text(
                              '${product.name} (${product.weight})',
                              style: const TextStyle(color: Colors.white70),
                            ),
                          ),
                          Text(
                            '₹${product.price}',
                            style: const TextStyle(color: Colors.white),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const Divider(color: Colors.white24),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text(
                        'Total',
                        style: TextStyle(
                          color: creamColor,
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      Text(
                        '₹${widget.total}',
                        style: const TextStyle(
                          color: lightGreen,
                          fontSize: 22,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  const Row(
                    children: [
                      Icon(Icons.payments_outlined, color: primaryGreen),
                      SizedBox(width: 8),
                      Text(
                        'Cash on Delivery',
                        style: TextStyle(color: Colors.white),
                      ),
                    ],
                  ),
                ],
              ),
            ),

            const SizedBox(height: 22),

            // ==================================================
            // PLACE ORDER
            // ==================================================

            SizedBox(
              height: 55,
              child: ElevatedButton(
                onPressed: isPlacingOrder ? null : placeOrder,
                style: ElevatedButton.styleFrom(
                  backgroundColor: primaryGreen,
                  foregroundColor: Colors.white,
                ),
                child: isPlacingOrder
                    ? const SizedBox(
                        width: 25,
                        height: 25,
                        child: CircularProgressIndicator(
                          color: Colors.white,
                          strokeWidth: 2.5,
                        ),
                      )
                    : const Text(
                        'PLACE ORDER • CASH ON DELIVERY',
                        style: TextStyle(fontWeight: FontWeight.bold),
                      ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ============================================================
// ORDER SUCCESS SCREEN  (animated green tick)
// ============================================================

class OrderSuccessScreen extends StatefulWidget {
  final String orderId;
  final int total;
  final VoidCallback onViewOrders;

  const OrderSuccessScreen({
    super.key,
    required this.orderId,
    required this.total,
    required this.onViewOrders,
  });

  @override
  State<OrderSuccessScreen> createState() => _OrderSuccessScreenState();
}

class _OrderSuccessScreenState extends State<OrderSuccessScreen>
    with TickerProviderStateMixin {
  late final AnimationController _circleController;
  late final AnimationController _tickController;
  late final AnimationController _rippleController;
  late final AnimationController _contentController;

  late final Animation<double> _circleScale;
  late final Animation<double> _tickProgress;
  late final Animation<double> _rippleProgress;
  late final Animation<double> _contentFade;
  late final Animation<Offset> _contentSlide;

  @override
  void initState() {
    super.initState();

    // 1) Green circle pops in.
    _circleController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 750),
    );
    _circleScale = CurvedAnimation(
      parent: _circleController,
      curve: Curves.elasticOut,
    );

    // 2) Tick mark draws itself.
    _tickController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 550),
    );
    _tickProgress = CurvedAnimation(
      parent: _tickController,
      curve: Curves.easeOutCubic,
    );

    // 3) Soft ripple expands from the circle.
    _rippleController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    );
    _rippleProgress = CurvedAnimation(
      parent: _rippleController,
      curve: Curves.easeOut,
    );

    // 4) Message + details fade in.
    _contentController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 650),
    );
    _contentFade = CurvedAnimation(
      parent: _contentController,
      curve: Curves.easeIn,
    );
    _contentSlide = Tween<Offset>(
      begin: const Offset(0, 0.16),
      end: Offset.zero,
    ).animate(
      CurvedAnimation(parent: _contentController, curve: Curves.easeOut),
    );

    _runSuccessAnimation();
  }

  Future<void> _runSuccessAnimation() async {
    await _circleController.forward();
    if (!mounted) return;

    await _tickController.forward();
    if (!mounted) return;

    HapticFeedback.mediumImpact();
    _rippleController.forward();

    await _contentController.forward();
  }

  @override
  void dispose() {
    _circleController.dispose();
    _tickController.dispose();
    _rippleController.dispose();
    _contentController.dispose();
    super.dispose();
  }

  void _continueShopping() {
    // HomeScreen is still at the bottom of the stack, so favourites
    // and other state are kept.
    Navigator.popUntil(context, (route) => route.isFirst);
  }

  void _viewOrders() {
    Navigator.popUntil(context, (route) => route.isFirst);
    widget.onViewOrders();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: bgColor,
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                // ---------------- ANIMATED TICK ----------------
                SizedBox(
                  width: 220,
                  height: 220,
                  child: Stack(
                    alignment: Alignment.center,
                    children: [
                      AnimatedBuilder(
                        animation: _rippleProgress,
                        builder: (context, _) {
                          final t = _rippleProgress.value;
                          return Opacity(
                            opacity: (1 - t).clamp(0.0, 1.0),
                            child: Container(
                              width: 142 + (t * 70),
                              height: 142 + (t * 70),
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                border: Border.all(
                                  color: primaryGreen.withOpacity(0.6),
                                  width: 3,
                                ),
                              ),
                            ),
                          );
                        },
                      ),
                      ScaleTransition(
                        scale: _circleScale,
                        child: Container(
                          width: 142,
                          height: 142,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: primaryGreen.withOpacity(0.12),
                            border: Border.all(color: primaryGreen, width: 4),
                            boxShadow: [
                              BoxShadow(
                                color: primaryGreen.withOpacity(0.30),
                                blurRadius: 32,
                                spreadRadius: 7,
                              ),
                            ],
                          ),
                          child: AnimatedBuilder(
                            animation: _tickProgress,
                            builder: (context, _) => CustomPaint(
                              painter: SuccessTickPainter(
                                progress: _tickProgress.value,
                              ),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 16),

                // ---------------- MESSAGE + DETAILS ----------------
                FadeTransition(
                  opacity: _contentFade,
                  child: SlideTransition(
                    position: _contentSlide,
                    child: Column(
                      children: [
                        const Text(
                          'Your Order Placed Successfully!',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            color: creamColor,
                            fontSize: 27,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 12),
                        const Text(
                          'Thank you! Your order has been received by GoatKart.',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            color: Colors.white70,
                            fontSize: 15,
                          ),
                        ),
                        const SizedBox(height: 22),
                        Container(
                          width: double.infinity,
                          padding: const EdgeInsets.all(20),
                          decoration: BoxDecoration(
                            color: cardColor,
                            borderRadius: BorderRadius.circular(18),
                            border: Border.all(color: Colors.white12),
                          ),
                          child: Column(
                            children: [
                              const Text(
                                'ORDER ID',
                                style: TextStyle(
                                  color: Colors.white54,
                                  fontSize: 11,
                                  letterSpacing: 1,
                                ),
                              ),
                              const SizedBox(height: 7),
                              SelectableText(
                                widget.orderId,
                                textAlign: TextAlign.center,
                                style: const TextStyle(
                                  color: lightGreen,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              const SizedBox(height: 16),
                              const Divider(color: Colors.white12),
                              const SizedBox(height: 12),
                              Row(
                                mainAxisAlignment:
                                    MainAxisAlignment.spaceBetween,
                                children: [
                                  const Text(
                                    'Total Amount',
                                    style: TextStyle(color: Colors.white70),
                                  ),
                                  Text(
                                    '₹${widget.total}',
                                    style: const TextStyle(
                                      color: creamColor,
                                      fontSize: 21,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 16),
                              const Row(
                                children: [
                                  Icon(
                                    Icons.payments_outlined,
                                    color: primaryGreen,
                                    size: 24,
                                  ),
                                  SizedBox(width: 10),
                                  Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        'Payment Method',
                                        style: TextStyle(
                                          color: Colors.white54,
                                          fontSize: 11,
                                        ),
                                      ),
                                      SizedBox(height: 3),
                                      Text(
                                        'Cash on Delivery',
                                        style: TextStyle(
                                          color: Colors.white,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 18),
                        Container(
                          width: double.infinity,
                          padding: const EdgeInsets.all(15),
                          decoration: BoxDecoration(
                            color: goldColor.withOpacity(0.08),
                            borderRadius: BorderRadius.circular(15),
                            border: Border.all(
                              color: goldColor.withOpacity(0.25),
                            ),
                          ),
                          child: const Row(
                            children: [
                              Icon(
                                Icons.hourglass_top_rounded,
                                color: goldColor,
                              ),
                              SizedBox(width: 10),
                              Expanded(
                                child: Text(
                                  'Waiting for admin confirmation. Track your order in My Orders.',
                                  style: TextStyle(
                                    color: Colors.white70,
                                    fontSize: 13,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 26),
                        SizedBox(
                          width: double.infinity,
                          height: 54,
                          child: ElevatedButton(
                            onPressed: _viewOrders,
                            style: ElevatedButton.styleFrom(
                              backgroundColor: primaryGreen,
                              foregroundColor: Colors.white,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(16),
                              ),
                            ),
                            child: const Text(
                              'VIEW MY ORDERS',
                              style: TextStyle(fontWeight: FontWeight.bold),
                            ),
                          ),
                        ),
                        const SizedBox(height: 12),
                        SizedBox(
                          width: double.infinity,
                          height: 52,
                          child: OutlinedButton(
                            onPressed: _continueShopping,
                            style: OutlinedButton.styleFrom(
                              foregroundColor: lightGreen,
                              side: const BorderSide(color: primaryGreen),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(16),
                              ),
                            ),
                            child: const Text(
                              'CONTINUE SHOPPING',
                              style: TextStyle(fontWeight: FontWeight.bold),
                            ),
                          ),
                        ),
                        const SizedBox(height: 14),
                        const Text(
                          'Thank you for ordering with GoatKart 🐐',
                          style: TextStyle(
                            color: Colors.white38,
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// ============================================================
// TICK PAINTER
// ============================================================

class SuccessTickPainter extends CustomPainter {
  final double progress;

  const SuccessTickPainter({required this.progress});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = primaryGreen
      ..style = PaintingStyle.stroke
      ..strokeWidth = 9
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;

    final path = Path()
      ..moveTo(size.width * 0.27, size.height * 0.52)
      ..lineTo(size.width * 0.45, size.height * 0.68)
      ..lineTo(size.width * 0.75, size.height * 0.34);

    for (final metric in path.computeMetrics()) {
      canvas.drawPath(
        metric.extractPath(0, metric.length * progress),
        paint,
      );
    }
  }

  @override
  bool shouldRepaint(covariant SuccessTickPainter oldDelegate) =>
      oldDelegate.progress != progress;
}

// ============================================================
// TRACK MY ORDER SCREEN
// Live order status + full order details for the customer.
// Also tells the admin (Activity tab) that the customer is tracking.
// ============================================================

class TrackOrderScreen extends StatefulWidget {
  final String orderId;

  const TrackOrderScreen({super.key, required this.orderId});

  @override
  State<TrackOrderScreen> createState() => _TrackOrderScreenState();
}

class _TrackOrderScreenState extends State<TrackOrderScreen> {
  bool _adminNotified = false;

  static const List<List<String>> _steps = [
    [kPending, 'Order Placed', 'We received your order.'],
    [kConfirmed, 'Confirmed', 'GoatKart confirmed your order.'],
    [kPreparing, 'Preparing', 'Your mutton is being cut and packed fresh.'],
    [kOutForDelivery, 'Out for Delivery', 'Our delivery partner is on the way.'],
    [kDelivered, 'Delivered', 'Order delivered. Enjoy your meal!'],
  ];

  int _stepIndex(String status) {
    switch (status) {
      case kPending:
        return 0;
      case kConfirmed:
      case 'Confirmed':
        return 1;
      case kPreparing:
        return 2;
      case kOutForDelivery:
        return 3;
      case kDelivered:
        return 4;
      default:
        return 0;
    }
  }

  /// Lets the admin know the customer opened "Track My Order".
  Future<void> _notifyAdmin(Map<String, dynamic> order) async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      final name = (order['customerName'] ?? user?.displayName ?? 'A customer')
          .toString();
      final phone = (order['phone'] ?? '').toString();
      final status = getStatus(order);

      await FirebaseFirestore.instance.collection('activity').add({
        'type': 'order_tracked',
        'title': '$name is tracking an order',
        'message':
            'Clicked "Track My Order" • Order #${shortId(widget.orderId)} • $status${phone.isEmpty ? '' : ' • $phone'}',
        'orderId': widget.orderId,
        'status': status,
        'amount': getAmount(order),
        'userId': user?.uid ?? '',
        'actor': 'customer',
        'createdAt': FieldValue.serverTimestamp(),
      });
    } catch (_) {}
  }

  Widget _card({required Widget child}) {
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: cardColor,
        borderRadius: BorderRadius.circular(20),
      ),
      child: child,
    );
  }

  Widget _title(String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Text(
        text,
        style: const TextStyle(
          color: creamColor,
          fontSize: 17,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }

  Widget _infoRow(IconData icon, String value) {
    if (value.trim().isEmpty) return const SizedBox.shrink();

    return Padding(
      padding: const EdgeInsets.only(bottom: 9),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: primaryGreen, size: 19),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(color: Colors.white70, height: 1.35),
            ),
          ),
        ],
      ),
    );
  }

  Widget _timelineStep({
    required int index,
    required int current,
    required bool isLast,
    required String title,
    required String subtitle,
  }) {
    final done = index < current;
    final active = index == current;

    final color = done || active ? primaryGreen : Colors.white24;

    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          SizedBox(
            width: 34,
            child: Column(
              children: [
                Container(
                  width: 28,
                  height: 28,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: done
                        ? primaryGreen
                        : active
                            ? primaryGreen.withOpacity(0.2)
                            : cardColor2,
                    border: Border.all(color: color, width: 2),
                  ),
                  child: done
                      ? const Icon(Icons.check, color: Colors.white, size: 17)
                      : active
                          ? const Icon(
                              Icons.circle,
                              color: primaryGreen,
                              size: 11,
                            )
                          : null,
                ),
                if (!isLast)
                  Expanded(
                    child: Container(
                      width: 2,
                      color: done ? primaryGreen : Colors.white12,
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Padding(
              padding: EdgeInsets.only(bottom: isLast ? 0 : 20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: TextStyle(
                      color: done || active ? Colors.white : Colors.white38,
                      fontWeight: FontWeight.bold,
                      fontSize: 15,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    subtitle,
                    style: TextStyle(
                      color: active ? lightGreen : Colors.white38,
                      fontSize: 12.5,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Track My Order')),
      body: StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
        stream: FirebaseFirestore.instance
            .collection('orders')
            .doc(widget.orderId)
            .snapshots(),
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            return const Center(
              child: Text(
                'Unable to load this order.',
                style: TextStyle(color: Colors.white70),
              ),
            );
          }

          if (!snapshot.hasData || snapshot.connectionState == ConnectionState.waiting) {
            return const SingleChildScrollView(
              padding: EdgeInsets.all(16),
              child: OrderCardSkeleton(),
            );
          }

          final data = snapshot.data!.data();

          if (data == null) {
            return const Center(
              child: Text(
                'Order not found.',
                style: TextStyle(color: Colors.white70),
              ),
            );
          }

          if (!_adminNotified) {
            _adminNotified = true;
            _notifyAdmin(data);
          }

          final status = getStatus(data);
          final cancelled = status == kCancelled;
          final current = _stepIndex(status);
          final items = getItems(data);
          final placedAt = orderTime(data);
          final updated = data['updatedAt'];
          final color = statusColor(status);

          final customer = (data['customerName'] ?? '').toString();
          final phone = (data['phone'] ?? '').toString();
          final address = (data['address'] ?? '').toString();
          final paymentMethod =
              (data['paymentMethod'] ?? 'Cash on Delivery').toString();
          final paymentStatus = (data['paymentStatus'] ?? 'Pending').toString();

          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              // ---------------- STATUS HEADER ----------------
              _card(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          'ORDER #${shortId(widget.orderId)}',
                          style: const TextStyle(
                            color: lightGreen,
                            fontSize: 17,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 10,
                            vertical: 6,
                          ),
                          decoration: BoxDecoration(
                            color: color.withOpacity(0.15),
                            borderRadius: BorderRadius.circular(20),
                            border: Border.all(color: color.withOpacity(0.5)),
                          ),
                          child: Text(
                            status,
                            style: TextStyle(
                              color: color,
                              fontSize: 11,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    Text(
                      widget.orderId,
                      style:
                          const TextStyle(color: Colors.white38, fontSize: 10),
                    ),
                    const SizedBox(height: 10),
                    Row(
                      children: [
                        const Icon(Icons.schedule,
                            color: Colors.white38, size: 15),
                        const SizedBox(width: 6),
                        Expanded(
                          child: Text(
                            'Placed ${formatDateTime(placedAt)} • ${timeAgo(placedAt)}',
                            style: const TextStyle(
                              color: Colors.white54,
                              fontSize: 12,
                            ),
                          ),
                        ),
                      ],
                    ),
                    if (updated is Timestamp) ...[
                      const SizedBox(height: 4),
                      Row(
                        children: [
                          const Icon(Icons.update,
                              color: Colors.white38, size: 15),
                          const SizedBox(width: 6),
                          Expanded(
                            child: Text(
                              'Last update ${timeAgo(updated.toDate())}',
                              style: const TextStyle(
                                color: Colors.white54,
                                fontSize: 12,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ],
                ),
              ),

              // ---------------- TIMELINE ----------------
              _card(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _title('Order Progress'),
                    if (cancelled)
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(14),
                        decoration: BoxDecoration(
                          color: accentRed.withOpacity(0.10),
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(color: accentRed.withOpacity(0.4)),
                        ),
                        child: const Row(
                          children: [
                            Icon(Icons.cancel, color: accentRed),
                            SizedBox(width: 10),
                            Expanded(
                              child: Text(
                                'This order has been cancelled. Contact Help & Support if you need assistance.',
                                style: TextStyle(color: Colors.white70),
                              ),
                            ),
                          ],
                        ),
                      )
                    else
                      for (int i = 0; i < _steps.length; i++)
                        _timelineStep(
                          index: i,
                          current: current,
                          isLast: i == _steps.length - 1,
                          title: _steps[i][1],
                          subtitle: _steps[i][2],
                        ),
                  ],
                ),
              ),

              // ---------------- ITEMS ----------------
              _card(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _title('Order Details'),
                    ...items.map((item) {
                      final qty = toInt(item['quantity'], 1);
                      final unit = toInt(item['price']);

                      return Padding(
                        padding: const EdgeInsets.symmetric(vertical: 5),
                        child: Row(
                          children: [
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    '${item['name']}',
                                    style: const TextStyle(
                                      color: Colors.white,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                  Text(
                                    '${item['weight']} • $qty × ${inr(unit)}',
                                    style: const TextStyle(
                                      color: Colors.white54,
                                      fontSize: 12,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            Text(
                              inr(unit * qty),
                              style: const TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ],
                        ),
                      );
                    }),
                    const Divider(color: Colors.white12, height: 26),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text(
                          'Total Amount',
                          style: TextStyle(color: Colors.white70),
                        ),
                        Text(
                          inr(getAmount(data)),
                          style: const TextStyle(
                            color: creamColor,
                            fontSize: 21,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    Row(
                      children: [
                        const Icon(
                          Icons.payments_outlined,
                          color: primaryGreen,
                          size: 19,
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            '$paymentMethod • $paymentStatus',
                            style: const TextStyle(color: Colors.white70),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),

              // ---------------- DELIVERY ----------------
              _card(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _title('Delivery Details'),
                    _infoRow(Icons.person, customer),
                    _infoRow(Icons.phone, phone),
                    _infoRow(Icons.location_on, address),
                  ],
                ),
              ),

              const Padding(
                padding: EdgeInsets.symmetric(horizontal: 8),
                child: Text(
                  'The GoatKart team has been informed that you are tracking this order. This page updates live.',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: Colors.white38, fontSize: 12),
                ),
              ),
              const SizedBox(height: 20),
            ],
          );
        },
      ),
    );
  }
}

// ============================================================
// ADMIN AUTH SCREEN
// One-time registration with the startup email, then daily login.
// ============================================================

class AdminAuthScreen extends StatefulWidget {
  const AdminAuthScreen({super.key});

  @override
  State<AdminAuthScreen> createState() => _AdminAuthScreenState();
}

class _AdminAuthScreenState extends State<AdminAuthScreen> {
  final FirebaseAuth _auth = FirebaseAuth.instance;

  bool checkingSetup = true;
  bool adminRegistered = false;
  String? setupError;

  bool isLoading = false;
  bool obscurePassword = true;

  final nameController = TextEditingController();
  final emailController = TextEditingController();
  final passwordController = TextEditingController();
  final confirmController = TextEditingController();

  @override
  void initState() {
    super.initState();
    checkSetup();
  }

  @override
  void dispose() {
    nameController.dispose();
    emailController.dispose();
    passwordController.dispose();
    confirmController.dispose();
    super.dispose();
  }

  // ==========================================================
  // MESSAGE
  // ==========================================================

  void showMessage(String message, {bool success = false}) {
    if (!mounted) return;

    ScaffoldMessenger.of(context).hideCurrentSnackBar();

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: success ? primaryGreen : accentRed,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  // ==========================================================
  // HAS THE ADMIN ALREADY BEEN REGISTERED?
  // ==========================================================

  Future<void> checkSetup() async {
    setState(() {
      checkingSetup = true;
      setupError = null;
    });

    try {
      final doc = await FirebaseFirestore.instance
          .collection('config')
          .doc('adminSetup')
          .get(const GetOptions(source: Source.server))
          .timeout(const Duration(seconds: 15));

      if (!mounted) return;

      setState(() {
        adminRegistered = doc.exists;
        checkingSetup = false;

        if (!adminRegistered) {
          emailController.text = kAdminEmail;
        }
      });
    } on TimeoutException {
      if (!mounted) return;

      setState(() {
        checkingSetup = false;
        setupError = 'Connection timed out. Check your internet and try again.';
      });
    } on FirebaseException catch (e) {
      if (!mounted) return;

      setState(() {
        checkingSetup = false;
        setupError = e.code == 'permission-denied'
            ? 'Access denied by Firestore rules. Publish the GoatKart security rules and try again.'
            : 'Unable to check admin setup (${e.code}). Check your internet and try again.';
      });
    } catch (_) {
      if (!mounted) return;

      setState(() {
        checkingSetup = false;
        setupError = 'Unable to check admin setup. Please try again.';
      });
    }
  }

  // ==========================================================
  // REGISTER ADMIN  (ONLY ONCE)
  // ==========================================================

  Future<void> _rollbackAdminUser(User? user) async {
    try {
      await user?.delete();
    } catch (_) {}

    try {
      await _auth.signOut();
    } catch (_) {}
  }

  Future<void> registerAdmin() async {
    if (isLoading) return;

    final name = nameController.text.trim();
    final email = emailController.text.trim().toLowerCase();
    final password = passwordController.text.trim();
    final confirm = confirmController.text.trim();

    if (name.isEmpty) {
      showMessage('Please enter the admin name.');
      return;
    }

    if (email != kAdminEmail.toLowerCase()) {
      showMessage(
        'Admin registration is allowed only with the GoatKart startup email.',
      );
      return;
    }

    if (password.length < 8) {
      showMessage('Admin password must contain at least 8 characters.');
      return;
    }

    if (password != confirm) {
      showMessage('Passwords do not match.');
      return;
    }

    setState(() {
      isLoading = true;
    });

    User? createdUser;

    try {
      final credential = await _auth
          .createUserWithEmailAndPassword(email: email, password: password)
          .timeout(const Duration(seconds: 15));

      createdUser = credential.user;

      if (createdUser == null) {
        throw Exception('Unable to create admin account.');
      }

      await createdUser.updateDisplayName(name);

      // Save the admin email + mark setup as completed. Both writes
      // succeed together or fail together.
      final db = FirebaseFirestore.instance;
      final batch = db.batch();

      batch.set(db.collection('admins').doc(createdUser.uid), {
        'uid': createdUser.uid,
        'name': name,
        'email': email,
        'role': 'admin',
        'createdAt': FieldValue.serverTimestamp(),
      });

      batch.set(db.collection('config').doc('adminSetup'), {
        'adminRegistered': true,
        'registeredAt': FieldValue.serverTimestamp(),
      });

      await batch.commit().timeout(const Duration(seconds: 20));

      await _auth.signOut();

      if (!mounted) return;

      passwordController.clear();
      confirmController.clear();

      setState(() {
        adminRegistered = true;
        isLoading = false;
      });

      showMessage(
        'Admin registered successfully. Please login.',
        success: true,
      );
    } on FirebaseAuthException catch (e) {
      await _rollbackAdminUser(createdUser);

      if (!mounted) return;

      String message;

      switch (e.code) {
        case 'email-already-in-use':
          message =
              'This email already has an account. Delete it in Firebase Authentication or use another startup email.';
          break;
        case 'weak-password':
          message = 'Password is too weak.';
          break;
        case 'invalid-email':
          message = 'The email address is invalid.';
          break;
        case 'network-request-failed':
          message = 'Network error. Check your internet connection.';
          break;
        default:
          message = e.message ?? 'Admin registration failed.';
      }

      showMessage(message);
    } on TimeoutException {
      await _rollbackAdminUser(createdUser);

      if (!mounted) return;

      showMessage('Request timed out. Check your internet and try again.');
    } on FirebaseException catch (e) {
      await _rollbackAdminUser(createdUser);

      if (!mounted) return;

      showMessage(
        e.code == 'permission-denied'
            ? 'Admin is already registered, or the Firestore rules are not published.'
            : 'Could not register admin: ${e.message ?? e.code}',
      );
    } catch (_) {
      await _rollbackAdminUser(createdUser);

      if (!mounted) return;

      showMessage('Unable to register admin. Please try again.');
    } finally {
      if (mounted && isLoading) {
        setState(() {
          isLoading = false;
        });
      }
    }
  }

  // ==========================================================
  // ADMIN LOGIN  (DAILY)
  // ==========================================================

  Future<void> loginAdmin() async {
    if (isLoading) return;

    final email = emailController.text.trim().toLowerCase();
    final password = passwordController.text.trim();

    if (email.isEmpty || !email.contains('@')) {
      showMessage('Please enter the admin email address.');
      return;
    }

    if (password.isEmpty) {
      showMessage('Please enter the admin password.');
      return;
    }

    setState(() {
      isLoading = true;
    });

    try {
      final credential = await _auth
          .signInWithEmailAndPassword(email: email, password: password)
          .timeout(const Duration(seconds: 15));

      final user = credential.user;

      if (user == null) {
        if (mounted) {
          showMessage('Login failed. Please try again.');
        }
        return;
      }

      // Only accounts that exist in the `admins` collection may enter.
      bool isAdmin = false;
      bool verifyFailed = false;

      try {
        final adminDoc = await FirebaseFirestore.instance
            .collection('admins')
            .doc(user.uid)
            .get(const GetOptions(source: Source.server))
            .timeout(const Duration(seconds: 10));

        isAdmin = adminDoc.exists;
      } catch (_) {
        verifyFailed = true;
      }

      if (!isAdmin) {
        await _auth.signOut();

        if (!mounted) return;

        showMessage(
          verifyFailed
              ? 'Unable to verify admin access. Check your internet and try again.'
              : 'Access denied. This account is not a GoatKart admin account.',
        );
        return;
      }

      if (!mounted) return;

      setState(() {
        isLoading = false;
      });

      Navigator.pushAndRemoveUntil(
        context,
        MaterialPageRoute(builder: (_) => const AdminDashboard()),
        (route) => false,
      );
    } on FirebaseAuthException catch (e) {
      if (!mounted) return;

      String message;

      switch (e.code) {
        case 'user-not-found':
        case 'wrong-password':
        case 'invalid-credential':
          message = 'Invalid admin email or password.';
          break;
        case 'invalid-email':
          message = 'The email address is invalid.';
          break;
        case 'user-disabled':
          message = 'This account has been disabled.';
          break;
        case 'too-many-requests':
          message = 'Too many login attempts. Please try again later.';
          break;
        case 'network-request-failed':
          message = 'Network error. Check your internet connection.';
          break;
        default:
          message = e.message ?? 'Login failed. Please try again.';
      }

      showMessage(message);
    } on TimeoutException {
      if (!mounted) return;

      showMessage('Login timed out. Please check your internet connection.');
    } catch (_) {
      if (!mounted) return;

      showMessage('Something went wrong during login. Please try again.');
    } finally {
      if (mounted && isLoading) {
        setState(() {
          isLoading = false;
        });
      }
    }
  }

  Future<void> forgotPassword() async {
    final email = emailController.text.trim().toLowerCase();

    if (email != kAdminEmail.toLowerCase()) {
      showMessage('Enter the GoatKart admin email to reset the password.');
      return;
    }

    try {
      await _auth.sendPasswordResetEmail(email: email);

      showMessage('Password reset link sent to $email', success: true);
    } on FirebaseAuthException catch (e) {
      showMessage(e.message ?? 'Unable to send the reset email.');
    } catch (_) {
      showMessage('Unable to send the reset email.');
    }
  }

  // ==========================================================
  // UI HELPERS
  // ==========================================================

  Widget field({
    required TextEditingController controller,
    required String label,
    required IconData icon,
    bool obscure = false,
    bool readOnly = false,
    Widget? suffix,
    TextInputType? keyboardType,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 15),
      child: TextField(
        controller: controller,
        obscureText: obscure,
        readOnly: readOnly,
        keyboardType: keyboardType,
        enabled: !isLoading,
        style: TextStyle(color: readOnly ? Colors.white60 : Colors.white),
        decoration: InputDecoration(
          labelText: label,
          prefixIcon: Icon(icon),
          suffixIcon: suffix,
        ),
      ),
    );
  }

  Widget visibilityToggle() {
    return IconButton(
      onPressed: isLoading
          ? null
          : () {
              setState(() {
                obscurePassword = !obscurePassword;
              });
            },
      icon: Icon(
        obscurePassword
            ? Icons.visibility_outlined
            : Icons.visibility_off_outlined,
      ),
    );
  }

  Widget submitButton(String label, VoidCallback onPressed) {
    return SizedBox(
      width: double.infinity,
      height: 54,
      child: ElevatedButton(
        onPressed: isLoading ? null : onPressed,
        style: ElevatedButton.styleFrom(
          backgroundColor: primaryGreen,
          foregroundColor: Colors.white,
        ),
        child: isLoading
            ? const SizedBox(
                width: 24,
                height: 24,
                child: CircularProgressIndicator(
                  color: Colors.white,
                  strokeWidth: 2.5,
                ),
              )
            : Text(label, style: const TextStyle(fontWeight: FontWeight.bold)),
      ),
    );
  }

  // ==========================================================
  // REGISTER FORM  (visible only until the admin exists)
  // ==========================================================

  Widget registerForm() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Admin Registration',
          style: TextStyle(
            color: Colors.white,
            fontSize: 24,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 7),
        const Text(
          'One-time setup for the GoatKart team.',
          style: TextStyle(color: Colors.white54),
        ),
        const SizedBox(height: 18),
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: goldColor.withOpacity(0.08),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: goldColor.withOpacity(0.25)),
          ),
          child: const Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(Icons.info_outline, color: goldColor, size: 20),
              SizedBox(width: 8),
              Expanded(
                child: Text(
                  'This can be done only once, with the startup email. After registering, this option disappears and only Admin Login remains.',
                  style: TextStyle(color: Colors.white70, fontSize: 12.5),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 20),
        field(
          controller: nameController,
          label: 'Admin Name',
          icon: Icons.person_outline,
        ),
        field(
          controller: emailController,
          label: 'Startup Email',
          icon: Icons.email_outlined,
          readOnly: true,
        ),
        field(
          controller: passwordController,
          label: 'Password (min 8 characters)',
          icon: Icons.lock_outline,
          obscure: obscurePassword,
          suffix: visibilityToggle(),
        ),
        field(
          controller: confirmController,
          label: 'Confirm Password',
          icon: Icons.lock_reset,
          obscure: obscurePassword,
        ),
        const SizedBox(height: 6),
        submitButton('REGISTER ADMIN', registerAdmin),
      ],
    );
  }

  // ==========================================================
  // LOGIN FORM  (daily use)
  // ==========================================================

  Widget loginForm() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Admin Login',
          style: TextStyle(
            color: Colors.white,
            fontSize: 24,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 7),
        const Text(
          'For the GoatKart team only.',
          style: TextStyle(color: Colors.white54),
        ),
        const SizedBox(height: 22),
        field(
          controller: emailController,
          label: 'Admin Email',
          icon: Icons.email_outlined,
          keyboardType: TextInputType.emailAddress,
        ),
        field(
          controller: passwordController,
          label: 'Password',
          icon: Icons.lock_outline,
          obscure: obscurePassword,
          suffix: visibilityToggle(),
        ),
        Align(
          alignment: Alignment.centerRight,
          child: TextButton(
            onPressed: isLoading ? null : forgotPassword,
            child: const Text(
              'Forgot password?',
              style: TextStyle(color: lightGreen),
            ),
          ),
        ),
        const SizedBox(height: 4),
        submitButton('LOGIN AS ADMIN', loginAdmin),
      ],
    );
  }

  Widget setupErrorCard() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: cardColor,
        borderRadius: BorderRadius.circular(22),
      ),
      child: Column(
        children: [
          const Icon(Icons.error_outline, color: accentRed, size: 46),
          const SizedBox(height: 12),
          Text(
            setupError ?? '',
            textAlign: TextAlign.center,
            style: const TextStyle(color: Colors.white70),
          ),
          const SizedBox(height: 16),
          OutlinedButton.icon(
            onPressed: checkSetup,
            icon: const Icon(Icons.refresh),
            label: const Text('Try again'),
          ),
        ],
      ),
    );
  }

  // ==========================================================
  // BUILD
  // ==========================================================

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Admin Access')),
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: EdgeInsets.fromLTRB(
              24,
              24,
              24,
              24 + MediaQuery.of(context).viewInsets.bottom,
            ),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 450),
              child: Column(
                children: [
                  const GoatKartLogo(size: 100, ringColor: goldColor),
                  const SizedBox(height: 18),
                  const Text(
                    'GoatKart Team',
                    style: TextStyle(
                      color: creamColor,
                      fontSize: 30,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 6),
                  const Text(
                    'Restricted area • Team members only',
                    style: TextStyle(color: Colors.white54),
                  ),
                  const SizedBox(height: 28),
                  if (checkingSetup)
                    const Padding(
                      padding: EdgeInsets.all(30),
                      child: CircularProgressIndicator(color: primaryGreen),
                    )
                  else if (setupError != null)
                    setupErrorCard()
                  else
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(22),
                      decoration: BoxDecoration(
                        color: cardColor,
                        borderRadius: BorderRadius.circular(26),
                      ),
                      child: adminRegistered ? loginForm() : registerForm(),
                    ),
                  const SizedBox(height: 20),
                  const Text(
                    'Customers cannot access this area.',
                    style: TextStyle(color: Colors.white38, fontSize: 12),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

// ============================================================
// ADMIN DASHBOARD
// ============================================================

class _Bucket {
  final String label;
  final String full;
  final int orders;
  final int sales;

  const _Bucket({
    required this.label,
    required this.full,
    required this.orders,
    required this.sales,
  });
}

Color statusColor(String status) {
  switch (status) {
    case kConfirmed:
    case 'Confirmed':
    case kDelivered:
      return primaryGreen;
    case kPreparing:
      return Colors.orange;
    case kOutForDelivery:
      return Colors.blue;
    case kCancelled:
      return accentRed;
    default:
      return goldColor;
  }
}

String shortStatus(String status) {
  switch (status) {
    case kPending:
      return 'Pending';
    case kConfirmed:
      return 'Confirmed';
    default:
      return status;
  }
}

String getStatus(Map<String, dynamic> order) =>
    (order['orderStatus'] ?? kPending).toString();

int getAmount(Map<String, dynamic> order) => toInt(order['totalAmount']);

List<Map<String, dynamic>> getItems(Map<String, dynamic> order) {
  final raw = order['items'];

  if (raw is! List) return [];

  return raw
      .whereType<Map>()
      .map((item) => Map<String, dynamic>.from(item))
      .toList();
}

int getQty(Map<String, dynamic> order) =>
    getItems(order).fold<int>(0, (sum, item) => sum + toInt(item['quantity'], 1));

int salesOf(Iterable<Map<String, dynamic>> list) =>
    list.fold<int>(0, (sum, order) => sum + getAmount(order));

String friendlyError(Object e) {
  if (e is FirebaseException) {
    if (e.code == 'permission-denied') {
      return 'Permission denied.\n\nPublish the GoatKart Firestore rules and make sure you are logged in with the admin account.';
    }
    return e.message ?? e.code;
  }
  return e.toString();
}

class AdminDashboard extends StatefulWidget {
  const AdminDashboard({super.key});

  @override
  State<AdminDashboard> createState() => _AdminDashboardState();
}

class _AdminDashboardState extends State<AdminDashboard> {
  int tabIndex = 0;

  StreamSubscription<QuerySnapshot<Map<String, dynamic>>>? ordersSub;
  StreamSubscription<QuerySnapshot<Map<String, dynamic>>>? usersSub;
  StreamSubscription<QuerySnapshot<Map<String, dynamic>>>? activitySub;
  StreamSubscription<QuerySnapshot<Map<String, dynamic>>>? adminNotificationsSub;

  List<Map<String, dynamic>> orders = [];
  List<Map<String, dynamic>> activities = [];
  int customerCount = 0;

  bool ordersLoading = true;
  String? ordersError;
  String? activityError;

  final Set<String> knownOrderIds = {};
  bool firstOrdersLoad = true;
  final Set<String> updatingOrders = {};

  final Set<String> knownActivityIds = {};
  bool firstActivityLoad = true;

  // Orders tab
  String statusFilter = 'All';
  final TextEditingController searchController = TextEditingController();

  // Analytics
  bool showMonthly = false;

  @override
  void initState() {
    super.initState();
    listenToData();
  }

  @override
  void dispose() {
    ordersSub?.cancel();
    usersSub?.cancel();
    activitySub?.cancel();
    adminNotificationsSub?.cancel();
    searchController.dispose();
    super.dispose();
  }

  // ==========================================================
  // LIVE DATA
  // ==========================================================

  void listenToData() {
    final db = FirebaseFirestore.instance;

    adminNotificationsSub = db
        .collection('admin_notifications')
        .where('read', isEqualTo: false)
        .snapshots()
        .listen((snapshot) {
      if (!mounted) return;
      for (final doc in snapshot.docs) {
        final data = doc.data();
        doc.reference.update({'read': true});
        notifyNewOrder(data);
      }
    });

    ordersSub = db.collection('orders').snapshots().listen(
      (snapshot) {
        if (!mounted) return;

        final list = snapshot.docs.map((doc) {
          final data = Map<String, dynamic>.from(doc.data());
          data['orderId'] = (data['orderId'] ?? doc.id).toString();
          return data;
        }).toList();

        list.sort((a, b) => orderTime(b).compareTo(orderTime(a)));

        // Alert the admin when a brand-new order arrives.
        if (!firstOrdersLoad) {
          for (final order in list) {
            final id = order['orderId'].toString();

            if (!knownOrderIds.contains(id) && getStatus(order) == kPending) {
              notifyNewOrder(order);
            }
          }
        }

        knownOrderIds
          ..clear()
          ..addAll(list.map((o) => o['orderId'].toString()));

        firstOrdersLoad = false;

        setState(() {
          orders = list;
          ordersLoading = false;
          ordersError = null;
        });
      },
      onError: (Object e) {
        if (!mounted) return;

        setState(() {
          ordersLoading = false;
          ordersError = friendlyError(e);
        });
      },
    );

    usersSub = db.collection('users').snapshots().listen(
      (snapshot) {
        if (!mounted) return;

        setState(() {
          customerCount = snapshot.docs.length;
        });
      },
      onError: (Object e) {},
    );

    activitySub = db
        .collection('activity')
        .orderBy('createdAt', descending: true)
        .limit(60)
        .snapshots()
        .listen(
      (snapshot) {
        if (!mounted) return;

        final list = snapshot.docs.map((doc) {
          final m = Map<String, dynamic>.from(doc.data());
          m['_id'] = doc.id;
          return m;
        }).toList();

        // Alert the admin when a customer taps "Track My Order".
        if (!firstActivityLoad) {
          for (final a in list) {
            final id = a['_id'].toString();

            if (!knownActivityIds.contains(id) &&
                a['type'] == 'order_tracked') {
              notifyTracking(a);
            }
          }
        }

        knownActivityIds
          ..clear()
          ..addAll(list.map((a) => a['_id'].toString()));

        firstActivityLoad = false;

        setState(() {
          activities = list;
          activityError = null;
        });
      },
      onError: (Object e) {
        if (!mounted) return;

        setState(() {
          activityError = friendlyError(e);
        });
      },
    );
  }

  void notifyNewOrder(Map<String, dynamic> order) {
    HapticFeedback.heavyImpact();
    SystemSound.play(SystemSoundType.alert);

    final name = (order['customerName'] ?? 'a customer').toString();
    final amountText = inr(getAmount(order));

    try {
      flutterLocalNotificationsPlugin.show(
        DateTime.now().millisecondsSinceEpoch ~/ 1000,
        '🔔 New Order Received!',
        'New order from $name • $amountText',
        NotificationDetails(
          android: AndroidNotificationDetails(
            channel.id,
            channel.name,
            channelDescription: channel.description,
            icon: '@mipmap/ic_launcher',
            importance: Importance.max,
            priority: Priority.high,
          ),
        ),
      );
    } catch (_) {}

    ScaffoldMessenger.of(context).hideCurrentSnackBar();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('🔔 New order from $name • $amountText'),
        backgroundColor: primaryGreen,
        behavior: SnackBarBehavior.floating,
        duration: const Duration(seconds: 6),
        action: SnackBarAction(
          label: 'VIEW',
          textColor: Colors.white,
          onPressed: () {
            if (!mounted) return;
            setState(() {
              tabIndex = 1;
            });
          },
        ),
      ),
    );
  }

  void notifyTracking(Map<String, dynamic> activity) {
    HapticFeedback.mediumImpact();

    ScaffoldMessenger.of(context).hideCurrentSnackBar();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          '📍 ${(activity['title'] ?? 'A customer is tracking an order').toString()}\n${(activity['message'] ?? '').toString()}',
        ),
        backgroundColor: Colors.blue,
        behavior: SnackBarBehavior.floating,
        duration: const Duration(seconds: 6),
        action: SnackBarAction(
          label: 'VIEW',
          textColor: Colors.white,
          onPressed: () {
            if (!mounted) return;
            setState(() {
              tabIndex = 3;
            });
          },
        ),
      ),
    );
  }

  // ==========================================================
  // VIEW CUSTOMER LOCATION ON MAP
  // Uses the exact GPS point when the customer shared it,
  // otherwise searches the typed delivery address on the map.
  // ==========================================================

  Future<void> openOrderOnMap(Map<String, dynamic> order) async {
    final lat = order['latitude'];
    final lng = order['longitude'];
    final address = (order['address'] ?? '').toString().trim();

    String? url;

    if (lat is num && lng is num) {
      url = 'https://www.google.com/maps/search/?api=1&query=$lat,$lng';
    } else if (address.isNotEmpty) {
      url =
          'https://www.google.com/maps/search/?api=1&query=${Uri.encodeComponent(address)}';
    }

    if (url == null) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).hideCurrentSnackBar();
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('No location or address available for this order.'),
          backgroundColor: accentRed,
        ),
      );
      return;
    }

    try {
      final ok = await launchUrl(
        Uri.parse(url),
        mode: LaunchMode.externalApplication,
      );
      if (!ok) throw Exception('cannot launch');
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).hideCurrentSnackBar();
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Unable to open maps on this device.'),
          backgroundColor: accentRed,
        ),
      );
    }
  }

  // ==========================================================
  // UPDATE ORDER STATUS  (+ activity log)
  // ==========================================================

  Future<void> updateOrderStatus(
    Map<String, dynamic> order,
    String newStatus,
  ) async {
    final orderId = order['orderId'].toString();

    if (updatingOrders.contains(orderId)) return;

    setState(() {
      updatingOrders.add(orderId);
    });

    final admin = FirebaseAuth.instance.currentUser;

    try {
      final db = FirebaseFirestore.instance;
      final batch = db.batch();

      final update = <String, dynamic>{
        'orderStatus': newStatus,
        'updatedAt': FieldValue.serverTimestamp(),
        'updatedBy': admin?.email ?? '',
      };

      if (newStatus == kConfirmed) {
        update['confirmedAt'] = FieldValue.serverTimestamp();
      }

      if (newStatus == kDelivered) {
        update['paymentStatus'] = 'Paid';
      }

      batch.update(db.collection('orders').doc(orderId), update);

      batch.set(db.collection('activity').doc(), {
        'type': 'order_status',
        'title': 'Order #${shortId(orderId)} → $newStatus',
        'message':
            'Customer: ${order['customerName'] ?? ''} • updated by admin',
        'orderId': orderId,
        'status': newStatus,
        'amount': getAmount(order),
        'userId': admin?.uid ?? '',
        'actor': 'admin',
        'createdAt': FieldValue.serverTimestamp(),
      });

      await batch.commit().timeout(const Duration(seconds: 20));

      if (!mounted) return;

      ScaffoldMessenger.of(context).hideCurrentSnackBar();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Order #${shortId(orderId)} marked as $newStatus'),
          backgroundColor: newStatus == kCancelled ? accentRed : primaryGreen,
        ),
      );
    } on TimeoutException {
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Update timed out. Check your internet connection.'),
          backgroundColor: accentRed,
        ),
      );
    } catch (e) {
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Unable to update order: ${friendlyError(e)}'),
          backgroundColor: accentRed,
        ),
      );
    } finally {
      if (mounted) {
        setState(() {
          updatingOrders.remove(orderId);
        });
      }
    }
  }

  Future<void> confirmCancel(Map<String, dynamic> order) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: cardColor,
        title: const Text('Cancel this order?'),
        content: Text(
          'Order #${shortId(order['orderId'].toString())} will be shown to the customer as Cancelled.',
          style: const TextStyle(color: Colors.white70),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Keep order'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text(
              'Cancel order',
              style: TextStyle(color: accentRed),
            ),
          ),
        ],
      ),
    );

    if (ok == true) {
      await updateOrderStatus(order, kCancelled);
    }
  }

  Future<void> changeStatus(Map<String, dynamic> order, String status) async {
    if (status == kCancelled) {
      await confirmCancel(order);
    } else {
      await updateOrderStatus(order, status);
    }
  }

  // ==========================================================
  // LOGOUT
  // ==========================================================

  Future<void> confirmLogout() async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: cardColor,
        title: const Text('Logout'),
        content: const Text(
          'Do you want to logout from the admin dashboard?',
          style: TextStyle(color: Colors.white70),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Logout', style: TextStyle(color: accentRed)),
          ),
        ],
      ),
    );

    if (ok != true) return;

    await ordersSub?.cancel();
    await usersSub?.cancel();
    await activitySub?.cancel();

    await FirebaseAuth.instance.signOut();

    if (!mounted) return;

    Navigator.pushAndRemoveUntil(
      context,
      MaterialPageRoute(builder: (_) => const AuthScreen()),
      (route) => false,
    );
  }

  void copyText(String label, String value) {
    Clipboard.setData(ClipboardData(text: value));

    ScaffoldMessenger.of(context).hideCurrentSnackBar();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('$label copied'),
        backgroundColor: primaryGreen,
        duration: const Duration(seconds: 1),
      ),
    );
  }

  // ==========================================================
  // BUILD
  // ==========================================================

  Widget navIcon(IconData icon, int badge) {
    return Stack(
      clipBehavior: Clip.none,
      children: [
        Icon(icon),
        if (badge > 0)
          Positioned(
            right: -8,
            top: -5,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
              decoration: BoxDecoration(
                color: accentRed,
                borderRadius: BorderRadius.circular(10),
              ),
              child: Text(
                '$badge',
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 10,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final admin = FirebaseAuth.instance.currentUser;
    final pendingCount =
        orders.where((o) => getStatus(o) == kPending).length;

    return Scaffold(
      appBar: AppBar(
        title: Row(
          children: [
            const GoatKartLogo(size: 40, glow: false, ringColor: goldColor),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'GoatKart Admin',
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),
                  Text(
                    admin?.email ?? '',
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 11,
                      color: Colors.white54,
                      fontWeight: FontWeight.normal,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        actions: [
          IconButton(
            onPressed: confirmLogout,
            tooltip: 'Logout',
            icon: const Icon(Icons.logout),
          ),
        ],
      ),
      body: buildBody(),
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: tabIndex,
        onTap: (index) {
          setState(() {
            tabIndex = index;
          });
        },
        items: [
          const BottomNavigationBarItem(
            icon: Icon(Icons.dashboard_outlined),
            activeIcon: Icon(Icons.dashboard),
            label: 'Dashboard',
          ),
          BottomNavigationBarItem(
            icon: navIcon(Icons.pending_actions_outlined, pendingCount),
            activeIcon: navIcon(Icons.pending_actions, pendingCount),
            label: 'Pending',
          ),
          const BottomNavigationBarItem(
            icon: Icon(Icons.receipt_long_outlined),
            activeIcon: Icon(Icons.receipt_long),
            label: 'Orders',
          ),
          const BottomNavigationBarItem(
            icon: Icon(Icons.restaurant_menu_outlined),
            activeIcon: Icon(Icons.restaurant_menu),
            label: 'Products',
          ),
          const BottomNavigationBarItem(
            icon: Icon(Icons.timeline),
            label: 'Activity',
          ),
        ],
      ),
    );
  }

  Widget buildBody() {
    if (ordersLoading) {
      return const SingleChildScrollView(
        padding: EdgeInsets.all(16),
        child: OrdersListSkeleton(itemCount: 5),
      );
    }

    if (ordersError != null) {
      return errorView(ordersError!);
    }

    switch (tabIndex) {
      case 0:
        return buildOverview();
      case 1:
        return buildPending();
      case 2:
        return buildAllOrders();
      case 3:
        return buildProductsTab();
      case 4:
        return buildActivity();
      default:
        return buildOverview();
    }
  }

  Widget errorView(String message) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.error_outline, color: accentRed, size: 54),
            const SizedBox(height: 12),
            Text(
              message,
              textAlign: TextAlign.center,
              style: const TextStyle(color: Colors.white70),
            ),
          ],
        ),
      ),
    );
  }

  Widget emptyView(IconData icon, String title, String subtitle) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, color: Colors.white24, size: 70),
            const SizedBox(height: 14),
            Text(
              title,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 19,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              subtitle,
              textAlign: TextAlign.center,
              style: const TextStyle(color: Colors.white54),
            ),
          ],
        ),
      ),
    );
  }

  Widget sectionTitle(String title, {String? trailing}) {
    return Padding(
      padding: const EdgeInsets.only(top: 26, bottom: 12),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            title,
            style: const TextStyle(
              color: creamColor,
              fontSize: 19,
              fontWeight: FontWeight.bold,
            ),
          ),
          if (trailing != null)
            Text(
              trailing,
              style: const TextStyle(color: Colors.white54, fontSize: 12),
            ),
        ],
      ),
    );
  }

  // ==========================================================
  // TAB 1 — DASHBOARD / ANALYTICS
  // ==========================================================

  Widget statCard(
    String label,
    String value,
    IconData icon,
    Color color, {
    VoidCallback? onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: cardColor,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: color.withOpacity(0.25)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Container(
              padding: const EdgeInsets.all(7),
              decoration: BoxDecoration(
                color: color.withOpacity(0.15),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(icon, color: color, size: 18),
            ),
            FittedBox(
              fit: BoxFit.scaleDown,
              alignment: Alignment.centerLeft,
              child: Text(
                value,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 22,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
            Text(
              label,
              style: const TextStyle(color: Colors.white54, fontSize: 12),
            ),
          ],
        ),
      ),
    );
  }

  Widget togglePill(String label, bool selected, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 8),
        decoration: BoxDecoration(
          color: selected ? primaryGreen : cardColor2,
          borderRadius: BorderRadius.circular(20),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: selected ? Colors.white : Colors.white60,
            fontWeight: FontWeight.bold,
            fontSize: 13,
          ),
        ),
      ),
    );
  }

  Widget salesChart(List<_Bucket> buckets) {
    final maxSales = buckets.fold<int>(0, (m, b) => b.sales > m ? b.sales : m);
    const chartHeight = 130.0;

    return SizedBox(
      height: chartHeight + 70,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: buckets.map((b) {
          final ratio = maxSales == 0 ? 0.0 : b.sales / maxSales;
          final barHeight =
              b.sales == 0 ? 4.0 : (ratio * chartHeight).clamp(8.0, chartHeight);

          return Expanded(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                Text(
                  b.sales == 0 ? '' : compactMoney(b.sales),
                  style: const TextStyle(color: lightGreen, fontSize: 10),
                ),
                const SizedBox(height: 4),
                Container(
                  height: barHeight,
                  margin: const EdgeInsets.symmetric(horizontal: 5),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: b.sales == 0
                          ? [Colors.white12, Colors.white12]
                          : [lightGreen, darkGreen],
                    ),
                    borderRadius: const BorderRadius.vertical(
                      top: Radius.circular(8),
                    ),
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  b.label,
                  textAlign: TextAlign.center,
                  style: const TextStyle(color: Colors.white54, fontSize: 10),
                ),
              ],
            ),
          );
        }).toList(),
      ),
    );
  }

  Widget buildOverview() {
    final now = DateTime.now();

    // Sales figures ignore cancelled orders.
    final live = orders.where((o) => getStatus(o) != kCancelled).toList();
    final todayLive = live.where((o) => sameDay(orderTime(o), now)).toList();
    final monthLive = live.where((o) => sameMonth(orderTime(o), now)).toList();
    final delivered = orders.where((o) => getStatus(o) == kDelivered).toList();
    final pendingCount = orders.where((o) => getStatus(o) == kPending).length;

    final totalSales = salesOf(live);
    final avgOrder = live.isEmpty ? 0 : (totalSales / live.length).round();

    // -------- Daily / monthly buckets --------
    final buckets = <_Bucket>[];

    if (!showMonthly) {
      for (int i = 6; i >= 0; i--) {
        final day =
            DateTime(now.year, now.month, now.day).subtract(Duration(days: i));
        final list = live.where((o) => sameDay(orderTime(o), day)).toList();

        buckets.add(
          _Bucket(
            label: '${_weekDayNames[day.weekday - 1]}\n${day.day}',
            full: formatDate(day),
            orders: list.length,
            sales: salesOf(list),
          ),
        );
      }
    } else {
      for (int i = 5; i >= 0; i--) {
        final month = DateTime(now.year, now.month - i, 1);
        final list = live.where((o) => sameMonth(orderTime(o), month)).toList();

        buckets.add(
          _Bucket(
            label: '${_monthNames[month.month - 1]}\n${month.year % 100}',
            full: '${_monthNames[month.month - 1]} ${month.year}',
            orders: list.length,
            sales: salesOf(list),
          ),
        );
      }
    }

    final rangeOrders = buckets.fold<int>(0, (s, b) => s + b.orders);
    final rangeSales = buckets.fold<int>(0, (s, b) => s + b.sales);

    // -------- Product-wise sales --------
    final Map<String, Map<String, int>> productMap = {};

    for (final order in live) {
      for (final item in getItems(order)) {
        final key = '${item['name']} (${item['weight']})';
        final qty = toInt(item['quantity'], 1);
        final revenue = toInt(item['price']) * qty;

        final entry =
            productMap.putIfAbsent(key, () => {'qty': 0, 'revenue': 0});

        entry['qty'] = entry['qty']! + qty;
        entry['revenue'] = entry['revenue']! + revenue;
      }
    }

    final productList = productMap.entries.toList()
      ..sort((a, b) => b.value['qty']!.compareTo(a.value['qty']!));

    // -------- Status breakdown --------
    const statusList = [
      kPending,
      kConfirmed,
      kPreparing,
      kOutForDelivery,
      kDelivered,
      kCancelled,
    ];

    int countStatus(String s) => orders.where((o) {
          final st = getStatus(o);
          return st == s || (s == kConfirmed && st == 'Confirmed');
        }).length;

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 30),
      children: [
        Text(
          formatDate(now),
          style: const TextStyle(color: Colors.white54),
        ),
        const SizedBox(height: 4),
        const Text(
          'Business Overview',
          style: TextStyle(
            color: Colors.white,
            fontSize: 26,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 16),

        GridView.count(
          crossAxisCount: 2,
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          mainAxisSpacing: 12,
          crossAxisSpacing: 12,
          childAspectRatio: 1.4,
          children: [
            statCard(
              "Today's Orders",
              '${todayLive.length}',
              Icons.receipt_long,
              primaryGreen,
            ),
            statCard(
              "Today's Sales",
              inr(salesOf(todayLive)),
              Icons.currency_rupee,
              lightGreen,
            ),
            statCard(
              'This Month Orders',
              '${monthLive.length}',
              Icons.calendar_month,
              Colors.blue,
            ),
            statCard(
              'This Month Sales',
              inr(salesOf(monthLive)),
              Icons.trending_up,
              Colors.blue,
            ),
            statCard(
              'Total Orders',
              '${live.length}',
              Icons.shopping_bag_outlined,
              creamColor,
            ),
            statCard(
              'Total Sales',
              inr(totalSales),
              Icons.account_balance_wallet_outlined,
              creamColor,
            ),
            statCard(
              'Pending Approval',
              '$pendingCount',
              Icons.hourglass_top,
              goldColor,
              onTap: () {
                setState(() {
                  tabIndex = 1;
                });
              },
            ),
            statCard(
              'Customers',
              '$customerCount',
              Icons.people_outline,
              Colors.purpleAccent,
            ),
            statCard(
              'Cash Collected',
              inr(salesOf(delivered)),
              Icons.payments_outlined,
              primaryGreen,
            ),
            statCard(
              'Avg Order Value',
              inr(avgOrder),
              Icons.analytics_outlined,
              Colors.orange,
            ),
          ],
        ),

        const SizedBox(height: 6),
        const Text(
          'Orders and sales exclude cancelled orders. Cash collected = delivered orders.',
          style: TextStyle(color: Colors.white38, fontSize: 11),
        ),

        // ---------------- SALES TREND ----------------
        sectionTitle('Sales Trend'),

        Row(
          children: [
            togglePill('Daily', !showMonthly, () {
              setState(() {
                showMonthly = false;
              });
            }),
            const SizedBox(width: 10),
            togglePill('Monthly', showMonthly, () {
              setState(() {
                showMonthly = true;
              });
            }),
          ],
        ),
        const SizedBox(height: 14),

        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: cardColor,
            borderRadius: BorderRadius.circular(20),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                showMonthly ? 'Last 6 months' : 'Last 7 days',
                style: const TextStyle(color: Colors.white54, fontSize: 12),
              ),
              const SizedBox(height: 4),
              Row(
                children: [
                  Text(
                    inr(rangeSales),
                    style: const TextStyle(
                      color: creamColor,
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(width: 10),
                  Text(
                    '$rangeOrders orders',
                    style: const TextStyle(color: lightGreen),
                  ),
                ],
              ),
              const SizedBox(height: 18),
              salesChart(buckets),
              const Divider(color: Colors.white12, height: 28),
              ...buckets.reversed.map(
                (b) => Padding(
                  padding: const EdgeInsets.symmetric(vertical: 6),
                  child: Row(
                    children: [
                      Expanded(
                        child: Text(
                          b.full,
                          style: const TextStyle(color: Colors.white70),
                        ),
                      ),
                      Text(
                        '${b.orders} orders',
                        style: const TextStyle(
                          color: Colors.white54,
                          fontSize: 12,
                        ),
                      ),
                      const SizedBox(width: 16),
                      SizedBox(
                        width: 84,
                        child: Text(
                          inr(b.sales),
                          textAlign: TextAlign.right,
                          style: const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),

        // ---------------- STATUS BREAKDOWN ----------------
        sectionTitle('Order Status', trailing: '${orders.length} total'),

        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: cardColor,
            borderRadius: BorderRadius.circular(20),
          ),
          child: Column(
            children: statusList.map((s) {
              final count = countStatus(s);
              final ratio = orders.isEmpty ? 0.0 : count / orders.length;

              return Padding(
                padding: const EdgeInsets.symmetric(vertical: 7),
                child: Column(
                  children: [
                    Row(
                      children: [
                        Container(
                          width: 9,
                          height: 9,
                          decoration: BoxDecoration(
                            color: statusColor(s),
                            shape: BoxShape.circle,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            s,
                            style: const TextStyle(color: Colors.white70),
                          ),
                        ),
                        Text(
                          '$count',
                          style: const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(6),
                      child: LinearProgressIndicator(
                        value: ratio,
                        minHeight: 6,
                        backgroundColor: Colors.white10,
                        valueColor: AlwaysStoppedAnimation<Color>(
                          statusColor(s),
                        ),
                      ),
                    ),
                  ],
                ),
              );
            }).toList(),
          ),
        ),

        // ---------------- PRODUCT SALES ----------------
        sectionTitle('Product Sales', trailing: 'quantity • amount'),

        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: cardColor,
            borderRadius: BorderRadius.circular(20),
          ),
          child: productList.isEmpty
              ? const Padding(
                  padding: EdgeInsets.all(12),
                  child: Center(
                    child: Text(
                      'No product sales yet.',
                      style: TextStyle(color: Colors.white54),
                    ),
                  ),
                )
              : Column(
                  children: [
                    for (int i = 0; i < productList.length; i++)
                      Padding(
                        padding: const EdgeInsets.symmetric(vertical: 8),
                        child: Row(
                          children: [
                            Container(
                              width: 26,
                              height: 26,
                              alignment: Alignment.center,
                              decoration: BoxDecoration(
                                color: i == 0
                                    ? goldColor.withOpacity(0.2)
                                    : cardColor2,
                                shape: BoxShape.circle,
                              ),
                              child: Text(
                                '${i + 1}',
                                style: TextStyle(
                                  color: i == 0 ? goldColor : Colors.white54,
                                  fontSize: 12,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Text(
                                productList[i].key,
                                style: const TextStyle(color: Colors.white),
                              ),
                            ),
                            Text(
                              '${productList[i].value['qty']} sold',
                              style: const TextStyle(
                                color: lightGreen,
                                fontSize: 12,
                              ),
                            ),
                            const SizedBox(width: 14),
                            SizedBox(
                              width: 80,
                              child: Text(
                                inr(productList[i].value['revenue']!),
                                textAlign: TextAlign.right,
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                  ],
                ),
        ),
      ],
    );
  }

  // ==========================================================
  // TAB 2 — PENDING ORDERS
  // ==========================================================

  Widget buildPending() {
    final pending = orders.where((o) => getStatus(o) == kPending).toList();

    if (pending.isEmpty) {
      return emptyView(
        Icons.check_circle_outline,
        'All caught up 🎉',
        'No orders are waiting for approval.',
      );
    }

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Container(
          padding: const EdgeInsets.all(14),
          margin: const EdgeInsets.only(bottom: 16),
          decoration: BoxDecoration(
            color: goldColor.withOpacity(0.10),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: goldColor.withOpacity(0.3)),
          ),
          child: Row(
            children: [
              const Icon(Icons.hourglass_top, color: goldColor),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  '${pending.length} order${pending.length == 1 ? '' : 's'} waiting for your approval',
                  style: const TextStyle(
                    color: goldColor,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ),
        ),
        ...pending.map(adminOrderCard),
      ],
    );
  }

  // ==========================================================
  // TAB 3 — ALL ORDERS (search + filter)
  // ==========================================================

  Widget buildAllOrders() {
    final query = searchController.text.trim().toLowerCase();

    bool matchesStatus(Map<String, dynamic> o) {
      if (statusFilter == 'All') return true;
      final st = getStatus(o);
      return st == statusFilter ||
          (statusFilter == kConfirmed && st == 'Confirmed');
    }

    final filtered = orders.where((o) {
      if (!matchesStatus(o)) return false;
      if (query.isEmpty) return true;

      final haystack =
          '${o['customerName']} ${o['phone']} ${o['email']} ${o['orderId']}'
              .toLowerCase();

      return haystack.contains(query);
    }).toList();

    final filters = <String>[
      'All',
      kPending,
      kConfirmed,
      kPreparing,
      kOutForDelivery,
      kDelivered,
      kCancelled,
    ];

    int countFor(String f) {
      if (f == 'All') return orders.length;
      return orders.where((o) {
        final st = getStatus(o);
        return st == f || (f == kConfirmed && st == 'Confirmed');
      }).length;
    }

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
          child: TextField(
            controller: searchController,
            onChanged: (_) {
              setState(() {});
            },
            style: const TextStyle(color: Colors.white),
            decoration: InputDecoration(
              hintText: 'Search name, phone, email or order ID',
              prefixIcon: const Icon(Icons.search),
              suffixIcon: searchController.text.isNotEmpty
                  ? IconButton(
                      onPressed: () {
                        searchController.clear();
                        setState(() {});
                      },
                      icon: const Icon(Icons.close),
                    )
                  : null,
            ),
          ),
        ),
        SizedBox(
          height: 46,
          child: ListView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 12),
            children: filters.map((f) {
              final selected = statusFilter == f;

              return Padding(
                padding: const EdgeInsets.symmetric(horizontal: 4),
                child: ChoiceChip(
                  label: Text('${shortStatus(f)} (${countFor(f)})'),
                  selected: selected,
                  showCheckmark: false,
                  selectedColor: primaryGreen,
                  backgroundColor: cardColor2,
                  side: BorderSide.none,
                  labelStyle: TextStyle(
                    color: selected ? Colors.white : Colors.white70,
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                  ),
                  onSelected: (_) {
                    setState(() {
                      statusFilter = f;
                    });
                  },
                ),
              );
            }).toList(),
          ),
        ),
        const SizedBox(height: 6),
        Expanded(
          child: filtered.isEmpty
              ? emptyView(
                  Icons.search_off,
                  'No orders found',
                  'Try a different search or filter.',
                )
              : ListView.builder(
                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 20),
                  itemCount: filtered.length,
                  itemBuilder: (context, index) {
                    return adminOrderCard(filtered[index]);
                  },
                ),
        ),
      ],
    );
  }

  // ==========================================================
  // TAB 3 — PRODUCTS MANAGEMENT
  // ==========================================================

  Widget buildProductsTab() {
    return Scaffold(
      backgroundColor: bgColor,
      body: StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance.collection('products').snapshots(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator(color: primaryGreen));
          }

          final docs = snapshot.data?.docs ?? [];

          if (docs.isEmpty) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.restaurant_menu, color: Colors.white24, size: 70),
                    const SizedBox(height: 14),
                    const Text(
                      'No products in Firestore yet.',
                      style: TextStyle(color: Colors.white70, fontSize: 16),
                    ),
                    const SizedBox(height: 16),
                    ElevatedButton.icon(
                      onPressed: seedDefaultProductsToFirestore,
                      icon: const Icon(Icons.cloud_upload),
                      label: const Text('Seed Default Mutton Cuts'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: primaryGreen,
                        foregroundColor: Colors.white,
                      ),
                    ),
                  ],
                ),
              ),
            );
          }

          return ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: docs.length,
            itemBuilder: (context, index) {
              final doc = docs[index];
              final data = doc.data() as Map<String, dynamic>;
              return Container(
                margin: const EdgeInsets.only(bottom: 14),
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: cardColor,
                  borderRadius: BorderRadius.circular(18),
                  border: Border.all(color: Colors.white10),
                ),
                child: Row(
                  children: [
                    ClipRRect(
                      borderRadius: BorderRadius.circular(12),
                      child: SizedBox(
                        width: 60,
                        height: 60,
                        child: SkeletonNetworkImage(imageUrl: data['imageUrl'] ?? ''),
                      ),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            data['name'] ?? '',
                            style: const TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.bold,
                              fontSize: 16,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            '${data['weight']} • ₹${data['price']}',
                            style: const TextStyle(
                              color: creamColor,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                    ),
                    IconButton(
                      onPressed: () => editProductDialog(doc.id, data),
                      icon: const Icon(Icons.edit, color: lightGreen),
                      tooltip: 'Edit product',
                    ),
                    IconButton(
                      onPressed: () => deleteProduct(doc.id),
                      icon: const Icon(Icons.delete_outline, color: accentRed),
                      tooltip: 'Delete product',
                    ),
                  ],
                ),
              );
            },
          );
        },
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => editProductDialog(null, null),
        backgroundColor: primaryGreen,
        icon: const Icon(Icons.add),
        label: const Text('Add Product'),
      ),
    );
  }

  Future<void> seedDefaultProductsToFirestore() async {
    final defaultCuts = [
      {
        'name': 'Biryani Cut',
        'weight': '500 g',
        'price': 399,
        'rating': 4.8,
        'imageUrl': 'https://media-assets.swiggy.com/swiggy/image/upload/fl_lossy,f_auto,q_auto,w_600,h_468/DINEOUT_ALL_RESTAURANTS/IMAGES/RESTAURANT_IMAGE_SERVICE/2025/2/24/990d2b9f-bd06-4975-9353-8716afe3f7e8_image74857fef7ab394489b12f0ec036977f16.JPG',
        'description': 'Perfectly cut mutton pieces for delicious biryani.',
      },
      {
        'name': 'Premium Boneless',
        'weight': '500 g',
        'price': 449,
        'rating': 4.9,
        'imageUrl': 'https://images.unsplash.com/photo-1603360946369-dc9bb6258143?auto=format&fit=crop&w=900&q=85',
        'description': 'Tender boneless mutton for curry and grills.',
      },
      {
        'name': 'Curry Cut',
        'weight': '500 g',
        'price': 379,
        'rating': 4.7,
        'imageUrl': 'https://images.unsplash.com/photo-1544025162-d76694265947?auto=format&fit=crop&w=900&q=85',
        'description': 'Bone-in pieces ideal for rich mutton curry.',
      },
      {
        'name': 'Mutton Keema',
        'weight': '500 g',
        'price': 429,
        'rating': 4.8,
        'imageUrl': 'https://images.unsplash.com/photo-1529042410759-befb1204b468?auto=format&fit=crop&w=900&q=85',
        'description': 'Fresh minced mutton for keema and kebabs.',
      },
      {
        'name': 'Mutton Liver',
        'weight': '250 g',
        'price': 199,
        'rating': 4.6,
        'imageUrl': 'https://images.unsplash.com/photo-1602470520998-f4a52199a3d6?auto=format&fit=crop&w=900&q=85',
        'description': 'Fresh liver perfect for fry and curry.',
      },
      {
        'name': 'Mutton Ribs',
        'weight': '500 g',
        'price': 459,
        'rating': 4.8,
        'imageUrl': 'https://wolkifarm.com.au/cdn/shop/files/side-of-mutton-1_grande.jpg?v=1782687729',
        'description': 'Juicy ribs perfect for slow cooking.',
      },
    ];

    for (final cut in defaultCuts) {
      await FirebaseFirestore.instance.collection('products').add(cut);
    }
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Default mutton cuts seeded to Firestore!'), backgroundColor: primaryGreen),
      );
    }
  }

  Future<void> deleteProduct(String id) async {
    await FirebaseFirestore.instance.collection('products').doc(id).delete();
  }

  Future<void> editProductDialog(String? docId, Map<String, dynamic>? data) async {
    final nameCtrl = TextEditingController(text: data?['name'] ?? '');
    final weightCtrl = TextEditingController(text: data?['weight'] ?? '500 g');
    final priceCtrl = TextEditingController(text: data?['price']?.toString() ?? '');
    final imageCtrl = TextEditingController(text: data?['imageUrl'] ?? '');
    final descCtrl = TextEditingController(text: data?['description'] ?? '');

    await showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: cardColor,
        title: Text(docId == null ? 'Add Product' : 'Edit Product', style: const TextStyle(color: Colors.white)),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(controller: nameCtrl, decoration: const InputDecoration(labelText: 'Product Name')),
              const SizedBox(height: 10),
              TextField(controller: weightCtrl, decoration: const InputDecoration(labelText: 'Weight (e.g. 500 g)')),
              const SizedBox(height: 10),
              TextField(controller: priceCtrl, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: 'Price (₹)')),
              const SizedBox(height: 10),
              TextField(controller: imageCtrl, decoration: const InputDecoration(labelText: 'Image URL')),
              const SizedBox(height: 10),
              TextField(controller: descCtrl, decoration: const InputDecoration(labelText: 'Description')),
            ],
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: primaryGreen,
              foregroundColor: Colors.white,
            ),
            onPressed: () async {
              final name = nameCtrl.text.trim();
              final weight = weightCtrl.text.trim();
              final price = int.tryParse(priceCtrl.text.trim()) ?? 0;
              final imageUrl = imageCtrl.text.trim();
              final desc = descCtrl.text.trim();

              if (name.isEmpty) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Please enter a product name'), backgroundColor: accentRed),
                );
                return;
              }

              if (price <= 0) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Please enter a valid price greater than 0'), backgroundColor: accentRed),
                );
                return;
              }

              try {
                final payload = {
                  'name': name,
                  'weight': weight.isEmpty ? '500 g' : weight,
                  'price': price,
                  'rating': 4.8,
                  'imageUrl': imageUrl.isEmpty ? 'https://images.unsplash.com/photo-1603360946369-dc9bb6258143' : imageUrl,
                  'description': desc.isEmpty ? 'Fresh mutton cut.' : desc,
                };

                if (docId == null) {
                  await FirebaseFirestore.instance.collection('products').add(payload);
                } else {
                  await FirebaseFirestore.instance.collection('products').doc(docId).update(payload);
                }

                if (ctx.mounted) Navigator.pop(ctx);
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text(docId == null ? 'Product added successfully!' : 'Product updated!'),
                      backgroundColor: primaryGreen,
                    ),
                  );
                }
              } catch (e) {
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('Failed to save: $e'), backgroundColor: accentRed),
                  );
                }
              }
            },
            child: Text(
              docId == null ? 'Add' : 'Save',
              style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ==========================================================
  // TAB 4 — LIVE ACTIVITY
  // ==========================================================

  Widget buildActivity() {
    if (activityError != null) {
      return errorView(activityError!);
    }

    if (activities.isEmpty) {
      return emptyView(
        Icons.timeline,
        'No activity yet',
        'New orders, status changes, tracking requests and new customers will appear here live.',
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: activities.length + 1,
      itemBuilder: (context, index) {
        if (index == 0) {
          return const Padding(
            padding: EdgeInsets.only(bottom: 14),
            child: Row(
              children: [
                Icon(Icons.circle, color: primaryGreen, size: 10),
                SizedBox(width: 8),
                Text(
                  'LIVE ACTIVITY',
                  style: TextStyle(
                    color: lightGreen,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 1,
                  ),
                ),
              ],
            ),
          );
        }

        return activityTile(activities[index - 1]);
      },
    );
  }

  Widget activityTile(Map<String, dynamic> a) {
    final type = (a['type'] ?? '').toString();

    IconData icon = Icons.info_outline;
    Color color = Colors.white54;

    if (type == 'order_placed') {
      icon = Icons.shopping_bag;
      color = goldColor;
    } else if (type == 'order_status') {
      icon = Icons.sync;
      color = statusColor((a['status'] ?? '').toString());
    } else if (type == 'customer_registered') {
      icon = Icons.person_add;
      color = Colors.blue;
    } else if (type == 'order_tracked') {
      icon = Icons.location_searching;
      color = Colors.purpleAccent;
    }

    final time = timeOf(a['createdAt']);
    final amount = toInt(a['amount']);
    final message = (a['message'] ?? '').toString();

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: cardColor,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: color.withOpacity(0.15),
              shape: BoxShape.circle,
            ),
            child: Icon(icon, color: color, size: 20),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  (a['title'] ?? '').toString(),
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                if (message.isNotEmpty) ...[
                  const SizedBox(height: 3),
                  Text(
                    message,
                    style: const TextStyle(color: Colors.white60, fontSize: 13),
                  ),
                ],
                const SizedBox(height: 6),
                Text(
                  '${timeAgo(time)} • ${formatDateTime(time)}',
                  style: const TextStyle(color: Colors.white38, fontSize: 11),
                ),
              ],
            ),
          ),
          if (amount > 0)
            Padding(
              padding: const EdgeInsets.only(left: 8),
              child: Text(
                inr(amount),
                style: const TextStyle(
                  color: lightGreen,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
        ],
      ),
    );
  }

  // ==========================================================
  // ADMIN ORDER CARD
  // ==========================================================

  Widget adminBadge(String status) {
    final color = statusColor(status);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: color.withOpacity(0.15),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withOpacity(0.5)),
      ),
      child: Text(
        status,
        style: TextStyle(
          color: color,
          fontSize: 10,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }

  Widget adminInfoRow(IconData icon, String value, {String? copyLabel}) {
    if (value.trim().isEmpty) return const SizedBox.shrink();

    return Padding(
      padding: const EdgeInsets.only(bottom: 9),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: primaryGreen, size: 19),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(color: Colors.white70),
            ),
          ),
          if (copyLabel != null)
            GestureDetector(
              onTap: () => copyText(copyLabel, value),
              child: const Padding(
                padding: EdgeInsets.only(left: 8),
                child: Icon(Icons.copy, size: 17, color: Colors.white38),
              ),
            ),
        ],
      ),
    );
  }

  /// "View on map" button shown in the customer details of every order,
  /// so the admin can see where to deliver before approving.
  Widget adminMapButton(Map<String, dynamic> data) {
    final hasGps = data['latitude'] is num && data['longitude'] is num;
    final hasAddress = (data['address'] ?? '').toString().trim().isNotEmpty;

    if (!hasGps && !hasAddress) return const SizedBox.shrink();

    return Padding(
      padding: const EdgeInsets.only(top: 4, bottom: 2),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: double.infinity,
            height: 46,
            child: OutlinedButton.icon(
              onPressed: () => openOrderOnMap(data),
              icon: const Icon(Icons.map_outlined, size: 20),
              label: const Text(
                'VIEW ON MAP',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
              style: OutlinedButton.styleFrom(
                foregroundColor: Colors.lightBlueAccent,
                side: const BorderSide(color: Colors.lightBlueAccent),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
              ),
            ),
          ),
          const SizedBox(height: 5),
          Row(
            children: [
              Icon(
                hasGps ? Icons.gps_fixed : Icons.info_outline,
                size: 13,
                color: hasGps ? lightGreen : Colors.white38,
              ),
              const SizedBox(width: 5),
              Expanded(
                child: Text(
                  hasGps
                      ? 'Exact GPS location shared by the customer'
                      : 'Customer did not share GPS • map shows the typed address',
                  style: TextStyle(
                    color: hasGps ? lightGreen : Colors.white38,
                    fontSize: 11,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget adminOrderCard(Map<String, dynamic> data) {
    final orderId = data['orderId'].toString();
    final status = getStatus(data);
    final customer = (data['customerName'] ?? 'Customer').toString();
    final phone = (data['phone'] ?? '').toString();
    final email = (data['email'] ?? '').toString();
    final address = (data['address'] ?? '').toString();
    final latitude = data['latitude'];
    final longitude = data['longitude'];
    final total = getAmount(data);
    final items = getItems(data);
    final totalQty = getQty(data);
    final placedAt = orderTime(data);
    final isPending = status == kPending;
    final busy = updatingOrders.contains(orderId);
    final paymentMethod =
        (data['paymentMethod'] ?? 'Cash on Delivery').toString();
    final paymentStatus = (data['paymentStatus'] ?? 'Pending').toString();

    return Container(
      margin: const EdgeInsets.only(bottom: 18),
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: cardColor,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: isPending
              ? goldColor.withOpacity(0.4)
              : primaryGreen.withOpacity(0.25),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ---------------- HEADER ----------------
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'ORDER #${shortId(orderId)}',
                      style: const TextStyle(
                        color: lightGreen,
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 3),
                    GestureDetector(
                      onTap: () => copyText('Order ID', orderId),
                      child: Text(
                        orderId,
                        style: const TextStyle(
                          color: Colors.white38,
                          fontSize: 10,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              adminBadge(status),
            ],
          ),

          const SizedBox(height: 8),

          Row(
            children: [
              const Icon(Icons.schedule, color: Colors.white38, size: 15),
              const SizedBox(width: 6),
              Text(
                '${formatDateTime(placedAt)} • ${timeAgo(placedAt)}',
                style: const TextStyle(color: Colors.white54, fontSize: 12),
              ),
            ],
          ),

          const Divider(color: Colors.white12, height: 28),

          // ---------------- CUSTOMER ----------------
          const Text(
            'Customer Details',
            style: TextStyle(
              color: creamColor,
              fontSize: 17,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 12),
          adminInfoRow(Icons.person, customer),
          adminInfoRow(Icons.phone, phone, copyLabel: 'Phone number'),
          adminInfoRow(Icons.email, email, copyLabel: 'Email'),
          adminInfoRow(Icons.location_on, address, copyLabel: 'Address'),
          if (latitude != null && longitude != null)
            adminInfoRow(
              Icons.gps_fixed,
              '$latitude, $longitude',
              copyLabel: 'GPS location',
            ),

          // ---------------- VIEW ON MAP ----------------
          adminMapButton(data),

          const Divider(color: Colors.white12, height: 28),

          // ---------------- ITEMS ----------------
          const Text(
            'Ordered Items',
            style: TextStyle(
              color: creamColor,
              fontSize: 17,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 10),

          ...items.map((item) {
            final qty = toInt(item['quantity'], 1);
            final unit = toInt(item['price']);

            return Container(
              margin: const EdgeInsets.only(bottom: 8),
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: cardColor2,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          '${item['name']}',
                          style: const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        const SizedBox(height: 3),
                        Text(
                          '${item['weight']} • $qty × ${inr(unit)}',
                          style: const TextStyle(
                            color: Colors.white54,
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
                    decoration: BoxDecoration(
                      color: primaryGreen.withOpacity(0.15),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      'Qty: $qty',
                      style: const TextStyle(
                        color: lightGreen,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Text(
                    inr(unit * qty),
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
            );
          }),

          const Divider(color: Colors.white12, height: 28),

          // ---------------- TOTALS ----------------
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'Total Quantity',
                style: TextStyle(color: Colors.white70),
              ),
              Text(
                '$totalQty item${totalQty == 1 ? '' : 's'}',
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'Order Amount',
                style: TextStyle(color: Colors.white70, fontSize: 16),
              ),
              Text(
                inr(total),
                style: const TextStyle(
                  color: creamColor,
                  fontSize: 23,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              const Icon(
                Icons.payments_outlined,
                color: primaryGreen,
                size: 19,
              ),
              const SizedBox(width: 7),
              Expanded(
                child: Text(
                  '$paymentMethod • $paymentStatus',
                  style: const TextStyle(color: Colors.white70),
                ),
              ),
            ],
          ),

          const SizedBox(height: 18),

          // ---------------- ACTIONS ----------------
          if (busy)
            const Center(
              child: Padding(
                padding: EdgeInsets.all(8),
                child: CircularProgressIndicator(color: primaryGreen),
              ),
            )
          else if (isPending)
            Row(
              children: [
                Expanded(
                  flex: 3,
                  child: SizedBox(
                    height: 52,
                    child: ElevatedButton.icon(
                      onPressed: () => updateOrderStatus(data, kConfirmed),
                      icon: const Icon(Icons.check_circle),
                      label: const Text(
                        'ACCEPT ORDER',
                        style: TextStyle(fontWeight: FontWeight.bold),
                      ),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: primaryGreen,
                        foregroundColor: Colors.white,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  flex: 2,
                  child: SizedBox(
                    height: 52,
                    child: OutlinedButton(
                      onPressed: () => confirmCancel(data),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: accentRed,
                        side: const BorderSide(color: accentRed),
                      ),
                      child: const Text(
                        'REJECT',
                        style: TextStyle(fontWeight: FontWeight.bold),
                      ),
                    ),
                  ),
                ),
              ],
            )
          else
            adminStatusButtons(data, status),
        ],
      ),
    );
  }

  Widget adminStatusButtons(Map<String, dynamic> order, String status) {
    final statuses = [
      kConfirmed,
      kPreparing,
      kOutForDelivery,
      kDelivered,
      kCancelled,
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Update Order Status',
          style: TextStyle(
            color: Colors.white70,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 10),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: statuses.map((nextStatus) {
            final selected = status == nextStatus ||
                (nextStatus == kConfirmed && status == 'Confirmed');

            return OutlinedButton(
              onPressed: selected ? null : () => changeStatus(order, nextStatus),
              style: OutlinedButton.styleFrom(
                foregroundColor:
                    nextStatus == kCancelled ? accentRed : lightGreen,
              ),
              child: Text(
                nextStatus,
                style: const TextStyle(fontSize: 11),
              ),
            );
          }).toList(),
        ),
      ],
    );
  }
}