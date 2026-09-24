import 'dart:async';

import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:geolocator/geolocator.dart';

import 'firebase_options.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );

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
            borderRadius: BorderRadius.all(
              Radius.circular(16),
            ),
            borderSide: BorderSide.none,
          ),
        ),
        bottomNavigationBarTheme:
            const BottomNavigationBarThemeData(
          backgroundColor: cardColor,
          selectedItemColor: primaryGreen,
          unselectedItemColor: Colors.white38,
          type: BottomNavigationBarType.fixed,
        ),
      ),
      home: const AuthScreen(),
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
      showMessage(
        'Password must contain at least 6 characters.',
      );
      return;
    }

    if (!isLogin && phone.length < 10) {
      showMessage('Please enter a valid phone number.');
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
        final credential =
            await _auth
                .createUserWithEmailAndPassword(
                  email: email,
                  password: password,
                )
                .timeout(
                  const Duration(seconds: 15),
                );

        final newUser = credential.user;

        if (newUser == null) {
          throw Exception(
            'Unable to create account.',
          );
        }

        await newUser.updateDisplayName(name);

        await FirebaseFirestore.instance
            .collection('users')
            .doc(newUser.uid)
            .set({
          'uid': newUser.uid,
          'name': name,
          'email': email,
          'phone': phone,
          'role': 'user',
          'createdAt':
              FieldValue.serverTimestamp(),
        })
            .timeout(
          const Duration(seconds: 15),
        );

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
            message =
                'This email is already registered. Please login.';
            break;

          case 'invalid-email':
            message =
                'The email address is invalid.';
            break;

          case 'weak-password':
            message =
                'Password is too weak.';
            break;

          case 'network-request-failed':
            message =
                'Network error. Check your internet connection.';
            break;

          default:
            message =
                e.message ?? 'Registration failed.';
        }

        showMessage(message);
      } on TimeoutException {
        if (!mounted) return;

        showMessage(
          'Request timed out. Check your internet connection.',
        );
      } catch (e) {
        if (!mounted) return;

        showMessage(
          'Unable to create account. Please try again.',
        );
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
      final credential =
          await _auth
              .signInWithEmailAndPassword(
                email: email,
                password: password,
              )
              .timeout(
                const Duration(seconds: 15),
              );

      final user = credential.user;

      // Important: stop spinner if user is null.
      if (user == null) {
        if (mounted) {
          setState(() {
            isLoading = false;
          });

          showMessage(
            'Login failed. Please try again.',
          );
        }

        return;
      }

      // ======================================================
      // GET ROLE FROM FIRESTORE
      // ======================================================

      String role = 'user';

      try {
        final userDoc =
            await FirebaseFirestore.instance
                .collection('users')
                .doc(user.uid)
                .get()
                .timeout(
                  const Duration(seconds: 10),
                );

        if (userDoc.exists) {
          final data = userDoc.data();

          if (data != null &&
              data['role'] != null) {
            role = data['role'].toString();
          }
        }
      } on TimeoutException {
        role = 'user';
      } catch (_) {
        role = 'user';
      }

      if (!mounted) return;

      // IMPORTANT:
      // Stop spinner BEFORE navigation.
      setState(() {
        isLoading = false;
      });

      // ======================================================
      // NAVIGATION
      // ======================================================

      if (role.toLowerCase() == 'admin') {
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(
            builder: (_) =>
                const AdminDashboard(),
          ),
        );
      } else {
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(
            builder: (_) =>
                const HomeScreen(),
          ),
        );
      }
    } on FirebaseAuthException catch (e) {
      if (!mounted) return;

      String message;

      switch (e.code) {
        case 'user-not-found':
          message =
              'Account not registered. Please create an account first.';
          break;

        case 'wrong-password':
          message =
              'Incorrect password.';
          break;

        case 'invalid-credential':
          message =
              'Invalid email or password.';
          break;

        case 'invalid-email':
          message =
              'The email address is invalid.';
          break;

        case 'user-disabled':
          message =
              'This account has been disabled.';
          break;

        case 'too-many-requests':
          message =
              'Too many login attempts. Please try again later.';
          break;

        case 'network-request-failed':
          message =
              'Network error. Check your internet connection.';
          break;

        default:
          message =
              e.message ??
                  'Login failed. Please try again.';
      }

      showMessage(message);
    } on TimeoutException {
      if (!mounted) return;

      showMessage(
        'Login timed out. Please check your internet connection.',
      );
    } catch (e) {
      if (!mounted) return;

      showMessage(
        'Something went wrong during login. Please try again.',
      );
    } finally {
      // FINAL SAFETY:
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

  void continueWithPhone() {
    showMessage(
      'Phone OTP authentication will be enabled next.',
    );
  }

  // ==========================================================
  // MESSAGE
  // ==========================================================

  void showMessage(
    String message, {
    bool success = false,
  }) {
    if (!mounted) return;

    ScaffoldMessenger.of(context)
        .hideCurrentSnackBar();

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor:
            success ? primaryGreen : accentRed,
        behavior:
            SnackBarBehavior.floating,
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
      style: const TextStyle(
        color: Colors.white,
      ),
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
            padding: const EdgeInsets.all(24),
            child: ConstrainedBox(
              constraints:
                  const BoxConstraints(
                maxWidth: 450,
              ),
              child: Column(
                children: [
                  Container(
                    width: 95,
                    height: 95,
                    decoration:
                        BoxDecoration(
                      gradient:
                          const LinearGradient(
                        colors: [
                          primaryGreen,
                          darkGreen,
                        ],
                      ),
                      borderRadius:
                          BorderRadius.circular(
                        30,
                      ),
                    ),
                    child: const Icon(
                      Icons.restaurant,
                      color: Colors.white,
                      size: 52,
                    ),
                  ),

                  const SizedBox(height: 20),

                  const Text(
                    'GoatKart',
                    style: TextStyle(
                      color: creamColor,
                      fontSize: 36,
                      fontWeight:
                          FontWeight.bold,
                    ),
                  ),

                  const SizedBox(height: 35),

                  Container(
                    padding:
                        const EdgeInsets.all(22),
                    decoration:
                        BoxDecoration(
                      color: cardColor,
                      borderRadius:
                          BorderRadius.circular(
                        26,
                      ),
                    ),
                    child: Column(
                      crossAxisAlignment:
                          CrossAxisAlignment.start,
                      children: [
                        Text(
                          isLogin
                              ? 'Welcome Back 👋'
                              : 'Create Account',
                          style:
                              const TextStyle(
                            color: Colors.white,
                            fontSize: 25,
                            fontWeight:
                                FontWeight.bold,
                          ),
                        ),

                        const SizedBox(height: 7),

                        Text(
                          isLogin
                              ? 'Login to order fresh mutton.'
                              : 'Create your GoatKart account.',
                          style:
                              const TextStyle(
                            color: Colors.white54,
                          ),
                        ),

                        const SizedBox(height: 25),

                        if (!isLogin) ...[
                          authField(
                            controller:
                                nameController,
                            label:
                                'Full Name',
                            icon: Icons
                                .person_outline,
                          ),
                          const SizedBox(
                            height: 15,
                          ),
                        ],

                        authField(
                          controller:
                              emailController,
                          label:
                              'Email Address',
                          icon: Icons
                              .email_outlined,
                          keyboardType:
                              TextInputType
                                  .emailAddress,
                        ),

                        const SizedBox(
                          height: 15,
                        ),

                        authField(
                          controller:
                              passwordController,
                          label: 'Password',
                          icon: Icons
                              .lock_outline,
                          obscureText:
                              obscurePassword,
                          suffixIcon:
                              IconButton(
                            onPressed:
                                isLoading
                                    ? null
                                    : () {
                                        setState(() {
                                          obscurePassword =
                                              !obscurePassword;
                                        });
                                      },
                            icon: Icon(
                              obscurePassword
                                  ? Icons
                                      .visibility_outlined
                                  : Icons
                                      .visibility_off_outlined,
                            ),
                          ),
                        ),

                        if (!isLogin) ...[
                          const SizedBox(
                            height: 15,
                          ),
                          authField(
                            controller:
                                phoneController,
                            label:
                                'Phone Number',
                            icon: Icons
                                .phone_outlined,
                            keyboardType:
                                TextInputType.phone,
                          ),
                        ],

                        const SizedBox(
                          height: 24,
                        ),

                        SizedBox(
                          width:
                              double.infinity,
                          height: 54,
                          child:
                              ElevatedButton(
                            onPressed:
                                isLoading
                                    ? null
                                    : handleAuthentication,
                            style:
                                ElevatedButton
                                    .styleFrom(
                              backgroundColor:
                                  primaryGreen,
                              foregroundColor:
                                  Colors.white,
                            ),
                            child: isLoading
                                ? const SizedBox(
                                    width: 24,
                                    height: 24,
                                    child:
                                        CircularProgressIndicator(
                                      color:
                                          Colors.white,
                                      strokeWidth:
                                          2.5,
                                    ),
                                  )
                                : Text(
                                    isLogin
                                        ? 'LOGIN'
                                        : 'CREATE ACCOUNT',
                                  ),
                          ),
                        ),

                        const SizedBox(
                          height: 18,
                        ),

                        Row(
                          children: [
                            const Expanded(
                              child: Divider(
                                color:
                                    Colors.white12,
                              ),
                            ),
                            Padding(
                              padding:
                                  const EdgeInsets
                                      .symmetric(
                                horizontal: 12,
                              ),
                              child: Text(
                                'OR',
                                style:
                                    TextStyle(
                                  color: Colors
                                      .white
                                      .withOpacity(
                                    0.4,
                                  ),
                                ),
                              ),
                            ),
                            const Expanded(
                              child: Divider(
                                color:
                                    Colors.white12,
                              ),
                            ),
                          ],
                        ),

                        const SizedBox(
                          height: 18,
                        ),

                        SizedBox(
                          width:
                              double.infinity,
                          height: 50,
                          child:
                              OutlinedButton
                                  .icon(
                            onPressed:
                                isLoading
                                    ? null
                                    : continueWithPhone,
                            icon:
                                const Icon(
                              Icons
                                  .phone_android,
                            ),
                            label:
                                const Text(
                              'Continue with Phone',
                            ),
                          ),
                        ),

                        const SizedBox(
                          height: 15,
                        ),

                        Center(
                          child:
                              TextButton(
                            onPressed:
                                isLoading
                                    ? null
                                    : () {
                                        setState(() {
                                          isLogin =
                                              !isLogin;
                                        });
                                      },
                            child: Text(
                              isLogin
                                  ? 'New to GoatKart? Create Account'
                                  : 'Already have an account? Login',
                              style:
                                  const TextStyle(
                                color:
                                    lightGreen,
                                fontWeight:
                                    FontWeight.bold,
                              ),
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
// HOME SCREEN
// ============================================================

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() =>
      _HomeScreenState();
}

class _HomeScreenState
    extends State<HomeScreen> {
  int selectedIndex = 0;

  final TextEditingController
      searchController =
      TextEditingController();

  final List<Product> products = [
    Product(
      name: 'Biryani Cut',
      weight: '500 g',
      price: 399,
      rating: 4.8,
      imageUrl:
          'https://media-assets.swiggy.com/swiggy/image/upload/fl_lossy,f_auto,q_auto,w_600,h_468/DINEOUT_ALL_RESTAURANTS/IMAGES/RESTAURANT_IMAGE_SERVICE/2025/2/24/990d2b9f-bd06-4975-9353-8716afe3f7e8_image74857fef7ab394489b12f0ec036977f16.JPG',
      description:
          'Perfectly cut mutton pieces for delicious biryani.',
    ),
    Product(
      name: 'Premium Boneless',
      weight: '500 g',
      price: 449,
      rating: 4.9,
      imageUrl:
          'https://images.unsplash.com/photo-1603360946369-dc9bb6258143?auto=format&fit=crop&w=900&q=85',
      description:
          'Tender boneless mutton for curry and grills.',
    ),
    Product(
      name: 'Curry Cut',
      weight: '500 g',
      price: 379,
      rating: 4.7,
      imageUrl:
          'https://images.unsplash.com/photo-1544025162-d76694265947?auto=format&fit=crop&w=900&q=85',
      description:
          'Bone-in pieces ideal for rich mutton curry.',
    ),
    Product(
      name: 'Mutton Keema',
      weight: '500 g',
      price: 429,
      rating: 4.8,
      imageUrl:
          'https://images.unsplash.com/photo-1529042410759-befb1204b468?auto=format&fit=crop&w=900&q=85',
      description:
          'Fresh minced mutton for keema and kebabs.',
    ),
    Product(
      name: 'Mutton Liver',
      weight: '250 g',
      price: 199,
      rating: 4.6,
      imageUrl:
          'https://images.unsplash.com/photo-1602470520998-f4a52199a3d6?auto=format&fit=crop&w=900&q=85',
      description:
          'Fresh liver perfect for fry and curry.',
    ),
    Product(
      name: 'Mutton Ribs',
      weight: '500 g',
      price: 459,
      rating: 4.8,
      imageUrl:
          'https://wolkifarm.com.au/cdn/shop/files/side-of-mutton-1_grande.jpg?v=1782687729',
      description:
          'Juicy ribs perfect for slow cooking.',
    ),
    Product(
      name: 'Mutton Chops',
      weight: '500 g',
      price: 479,
      rating: 4.9,
      imageUrl:
          'https://wolkifarm.com.au/cdn/shop/files/side-of-mutton-1_grande.jpg?v=1782687729',
      description:
          'Premium chops for grilling and roasting.',
    ),
    Product(
      name: 'Special Cuts',
      weight: '500 g',
      price: 499,
      rating: 5.0,
      imageUrl:
          'https://wolkifarm.com.au/cdn/shop/files/side-of-mutton-1_grande.jpg?v=1782687729',
      description:
          'Chef-selected premium mutton cuts.',
    ),
  ];

  final List<Product> cart = [];
  final List<Product> favourites = [];

  List<Product> get filteredProducts {
    final query =
        searchController.text.trim().toLowerCase();

    if (query.isEmpty) {
      return products;
    }

    return products
        .where(
          (product) => product.name
              .toLowerCase()
              .contains(query),
        )
        .toList();
  }

  int get cartTotal {
    return cart.fold(
      0,
      (sum, product) =>
          sum + product.price,
    );
  }

  void addToCart(Product product) {
    setState(() {
      cart.add(product);
    });

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content:
            Text('${product.name} added to cart'),
        backgroundColor: primaryGreen,
        duration:
            const Duration(seconds: 1),
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
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Row(
          children: [
            Container(
              width: 40,
              height: 40,
              decoration:
                  BoxDecoration(
                color: primaryGreen,
                borderRadius:
                    BorderRadius.circular(12),
              ),
              child: const Icon(
                Icons.restaurant,
                color: Colors.white,
              ),
            ),
            const SizedBox(width: 10),
            const Text(
              'GoatKart',
              style: TextStyle(
                fontWeight: FontWeight.bold,
              ),
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
            icon:
                const Icon(Icons.person_outline),
          ),
          Stack(
            children: [
              IconButton(
                onPressed: () {
                  setState(() {
                    selectedIndex = 2;
                  });
                },
                icon: const Icon(
                  Icons.shopping_bag_outlined,
                ),
              ),
              if (cart.isNotEmpty)
                Positioned(
                  right: 5,
                  top: 5,
                  child: Container(
                    padding:
                        const EdgeInsets.all(4),
                    decoration:
                        const BoxDecoration(
                      color: accentRed,
                      shape: BoxShape.circle,
                    ),
                    child: Text(
                      '${cart.length}',
                      style:
                          const TextStyle(
                        color: Colors.white,
                        fontSize: 9,
                        fontWeight:
                            FontWeight.bold,
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
      bottomNavigationBar:
          BottomNavigationBar(
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
            icon:
                Icon(Icons.shopping_bag_outlined),
            activeIcon:
                Icon(Icons.shopping_bag),
            label: 'Cart',
          ),
          BottomNavigationBarItem(
            icon:
                Icon(Icons.receipt_long_outlined),
            activeIcon:
                Icon(Icons.receipt_long),
            label: 'Orders',
          ),
          BottomNavigationBarItem(
            icon:
                Icon(Icons.person_outline),
            activeIcon:
                Icon(Icons.person),
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
      padding: const EdgeInsets.fromLTRB(
        16,
        10,
        16,
        25,
      ),
      child: Column(
        crossAxisAlignment:
            CrossAxisAlignment.start,
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
            style: TextStyle(
              color: Colors.white54,
            ),
          ),
          const SizedBox(height: 20),
          TextField(
            controller: searchController,
            onChanged: (_) {
              setState(() {});
            },
            style: const TextStyle(
              color: Colors.white,
            ),
            decoration: InputDecoration(
              hintText:
                  'Search mutton cuts...',
              prefixIcon:
                  const Icon(Icons.search),
              suffixIcon:
                  searchController.text.isNotEmpty
                      ? IconButton(
                          onPressed: () {
                            searchController
                                .clear();
                            setState(() {});
                          },
                          icon:
                              const Icon(Icons.close),
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
              scrollDirection:
                  Axis.horizontal,
              children: [
                category(
                  'Biryani',
                  Icons.rice_bowl,
                  'https://images.unsplash.com/photo-1589302168068-964664d93dc0?auto=format&fit=crop&w=500&q=85',
                ),
                category(
                  'Boneless',
                  Icons.restaurant,
                  'https://images.unsplash.com/photo-1603360946369-dc9bb6258143?auto=format&fit=crop&w=500&q=85',
                ),
                category(
                  'Curry Cut',
                  Icons.set_meal,
                  'https://images.unsplash.com/photo-1544025162-d76694265947?auto=format&fit=crop&w=500&q=85',
                ),
                category(
                  'Keema',
                  Icons.grain,
                  'https://images.unsplash.com/photo-1529042410759-befb1204b468?auto=format&fit=crop&w=500&q=85',
                ),
                category(
                  'Liver',
                  Icons.favorite,
                  'https://images.unsplash.com/photo-1602470520998-f4a52199a3d6?auto=format&fit=crop&w=500&q=85',
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),
          promoBanner(),
          const SizedBox(height: 28),
          const Text(
            'Popular Mutton Cuts',
            style: TextStyle(
              color: Colors.white,
              fontSize: 21,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 10),
          GridView.builder(
            shrinkWrap: true,
            physics:
                const NeverScrollableScrollPhysics(),
            itemCount:
                filteredProducts.length,
            gridDelegate:
                const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 2,
              crossAxisSpacing: 12,
              mainAxisSpacing: 15,
              childAspectRatio: 0.68,
            ),
            itemBuilder:
                (context, index) {
              return productCard(
                filteredProducts[index],
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
    String imageUrl,
  ) {
    return Container(
      width: 82,
      margin:
          const EdgeInsets.only(right: 12),
      child: Column(
        children: [
          ClipRRect(
            borderRadius:
                BorderRadius.circular(18),
            child: SizedBox(
              width: 66,
              height: 66,
              child: Image.network(
                imageUrl,
                fit: BoxFit.cover,
                errorBuilder:
                    (_, __, ___) {
                  return Container(
                    color: cardColor2,
                    child: Icon(
                      icon,
                      color: primaryGreen,
                    ),
                  );
                },
              ),
            ),
          ),
          const SizedBox(height: 6),
          Text(
            title,
            maxLines: 1,
            overflow:
                TextOverflow.ellipsis,
            textAlign: TextAlign.center,
            style: const TextStyle(
              color: Colors.white70,
              fontSize: 12,
            ),
          ),
        ],
      ),
    );
  }

  Widget promoBanner() {
    return Container(
      height: 165,
      width: double.infinity,
      padding:
          const EdgeInsets.all(22),
      decoration: BoxDecoration(
        gradient:
            const LinearGradient(
          colors: [
            Color(0xFF103D27),
            Color(0xFF176B3A),
            Color(0xFF102C20),
          ],
        ),
        borderRadius:
            BorderRadius.circular(25),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment:
                  CrossAxisAlignment.start,
              mainAxisAlignment:
                  MainAxisAlignment.center,
              children: [
                const Text(
                  "TODAY'S SPECIAL",
                  style: TextStyle(
                    color: goldColor,
                    fontWeight:
                        FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 8),
                const Text(
                  'Premium Mutton\nDelivered Fresh',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 21,
                    fontWeight:
                        FontWeight.bold,
                  ),
                ),
              ],
            ),
          ),
          const Icon(
            Icons.restaurant,
            color: goldColor,
            size: 70,
          ),
        ],
      ),
    );
  }

  Widget productCard(Product product) {
    final isFavourite =
        favourites.contains(product);

    return Container(
      decoration: BoxDecoration(
        color: cardColor,
        borderRadius:
            BorderRadius.circular(20),
      ),
      child: ClipRRect(
        borderRadius:
            BorderRadius.circular(20),
        child: Column(
          crossAxisAlignment:
              CrossAxisAlignment.start,
          children: [
            Stack(
              children: [
                SizedBox(
                  width: double.infinity,
                  height: 125,
                  child: Image.network(
                    product.imageUrl,
                    fit: BoxFit.cover,
                    errorBuilder:
                        (_, __, ___) {
                      return Container(
                        color: cardColor2,
                        child:
                            const Center(
                          child: Icon(
                            Icons.restaurant,
                            color:
                                primaryGreen,
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
                  child:
                      GestureDetector(
                    onTap: () {
                      toggleFavourite(
                          product);
                    },
                    child: Container(
                      width: 34,
                      height: 34,
                      decoration:
                          const BoxDecoration(
                        color: Colors.black54,
                        shape:
                            BoxShape.circle,
                      ),
                      child: Icon(
                        isFavourite
                            ? Icons.favorite
                            : Icons.favorite_border,
                        color: isFavourite
                            ? Colors.redAccent
                            : Colors.white,
                        size: 19,
                      ),
                    ),
                  ),
                ),
              ],
            ),
            Padding(
              padding:
                  const EdgeInsets.all(10),
              child: Column(
                crossAxisAlignment:
                    CrossAxisAlignment.start,
                children: [
                  Text(
                    product.name,
                    maxLines: 1,
                    overflow:
                        TextOverflow.ellipsis,
                    style:
                        const TextStyle(
                      color: Colors.white,
                      fontWeight:
                          FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      const Icon(
                        Icons.star,
                        color: goldColor,
                        size: 14,
                      ),
                      const SizedBox(
                          width: 3),
                      Text(
                        '${product.rating}',
                        style:
                            const TextStyle(
                          color:
                              Colors.white70,
                          fontSize: 11,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(
                    product.description,
                    maxLines: 2,
                    overflow:
                        TextOverflow.ellipsis,
                    style:
                        const TextStyle(
                      color: Colors.white54,
                      fontSize: 10,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    product.weight,
                    style:
                        const TextStyle(
                      color: Colors.white54,
                      fontSize: 11,
                    ),
                  ),
                  const SizedBox(height: 5),
                  Row(
                    mainAxisAlignment:
                        MainAxisAlignment
                            .spaceBetween,
                    children: [
                      Text(
                        '₹${product.price}',
                        style:
                            const TextStyle(
                          color:
                              creamColor,
                          fontSize: 18,
                          fontWeight:
                              FontWeight.bold,
                        ),
                      ),
                      InkWell(
                        onTap: () {
                          addToCart(product);
                        },
                        child: Container(
                          width: 36,
                          height: 36,
                          decoration:
                              BoxDecoration(
                            color:
                                primaryGreen,
                            borderRadius:
                                BorderRadius
                                    .circular(
                              11,
                            ),
                          ),
                          child:
                              const Icon(
                            Icons.add,
                            color:
                                Colors.white,
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
  // SEARCH
  // ==========================================================

  Widget buildSearch() {
    return Padding(
      padding:
          const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment:
            CrossAxisAlignment.start,
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
            decoration:
                const InputDecoration(
              hintText: 'Search cuts...',
              prefixIcon:
                  Icon(Icons.search),
            ),
          ),
          const SizedBox(height: 20),
          Expanded(
            child:
                filteredProducts.isEmpty
                    ? const Center(
                        child: Text(
                          'No mutton cut found.',
                          style:
                              TextStyle(
                            color:
                                Colors.white54,
                          ),
                        ),
                      )
                    : GridView.builder(
                        itemCount:
                            filteredProducts
                                .length,
                        gridDelegate:
                            const SliverGridDelegateWithFixedCrossAxisCount(
                          crossAxisCount: 2,
                          crossAxisSpacing:
                              12,
                          mainAxisSpacing:
                              15,
                          childAspectRatio:
                              0.68,
                        ),
                        itemBuilder:
                            (context,
                                index) {
                          return productCard(
                            filteredProducts[
                                index],
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
          mainAxisAlignment:
              MainAxisAlignment.center,
          children: [
            const Icon(
              Icons
                  .shopping_bag_outlined,
              color: Colors.white24,
              size: 80,
            ),
            const SizedBox(height: 15),
            const Text(
              'Your cart is empty',
              style: TextStyle(
                color: Colors.white,
                fontSize: 20,
                fontWeight:
                    FontWeight.bold,
              ),
            ),
            const SizedBox(height: 15),
            ElevatedButton(
              onPressed: () {
                setState(() {
                  selectedIndex = 0;
                });
              },
              child:
                  const Text('Start Shopping'),
            ),
          ],
        ),
      );
    }

    return Column(
      children: [
        Expanded(
          child:
              ListView.builder(
            padding:
                const EdgeInsets.all(16),
            itemCount: cart.length,
            itemBuilder:
                (context, index) {
              final product =
                  cart[index];

              return Container(
                margin:
                    const EdgeInsets.only(
                  bottom: 10,
                ),
                decoration:
                    BoxDecoration(
                  color: cardColor,
                  borderRadius:
                      BorderRadius.circular(
                    16,
                  ),
                ),
                child: ListTile(
                  leading:
                      ClipRRect(
                    borderRadius:
                        BorderRadius.circular(
                      10,
                    ),
                    child: SizedBox(
                      width: 58,
                      height: 58,
                      child:
                          Image.network(
                        product.imageUrl,
                        fit: BoxFit.cover,
                        errorBuilder:
                            (_, __, ___) {
                          return Container(
                            color:
                                cardColor2,
                            child:
                                const Icon(
                              Icons
                                  .restaurant,
                              color:
                                  primaryGreen,
                            ),
                          );
                        },
                      ),
                    ),
                  ),
                  title: Text(
                    product.name,
                    style:
                        const TextStyle(
                      color:
                          Colors.white,
                      fontWeight:
                          FontWeight.bold,
                    ),
                  ),
                  subtitle: Text(
                    product.weight,
                    style:
                        const TextStyle(
                      color:
                          Colors.white54,
                    ),
                  ),
                  trailing: Column(
                    mainAxisAlignment:
                        MainAxisAlignment
                            .center,
                    crossAxisAlignment:
                        CrossAxisAlignment
                            .end,
                    children: [
                      Text(
                        '₹${product.price}',
                        style:
                            const TextStyle(
                          color:
                              lightGreen,
                          fontWeight:
                              FontWeight
                                  .bold,
                        ),
                      ),
                      GestureDetector(
                        onTap: () {
                          setState(() {
                            cart.removeAt(
                                index);
                          });
                        },
                        child:
                            const Text(
                          'Remove',
                          style:
                              TextStyle(
                            color:
                                accentRed,
                            fontSize:
                                11,
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
        Container(
          padding:
              const EdgeInsets.all(20),
          decoration:
              const BoxDecoration(
            color: cardColor,
          ),
          child: Column(
            children: [
              Row(
                mainAxisAlignment:
                    MainAxisAlignment
                        .spaceBetween,
                children: [
                  const Text(
                    'Total',
                    style:
                        TextStyle(
                      color:
                          Colors.white70,
                      fontSize: 17,
                    ),
                  ),
                  Text(
                    '₹$cartTotal',
                    style:
                        const TextStyle(
                      color:
                          creamColor,
                      fontSize: 23,
                      fontWeight:
                          FontWeight.bold,
                    ),
                  ),
                ],
              ),
              const SizedBox(
                  height: 15),
              SizedBox(
                width:
                    double.infinity,
                height: 54,
                child:
                    ElevatedButton(
                  onPressed: () {
                    final items =
                        List<Product>.from(
                            cart);

                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) =>
                            CheckoutScreen(
                          cartItems: items,
                          total:
                              cartTotal,
                          onOrderPlaced:
                              () {
                            setState(() {
                              cart.clear();
                            });
                          },
                        ),
                      ),
                    );
                  },
                  style:
                      ElevatedButton
                          .styleFrom(
                    backgroundColor:
                        primaryGreen,
                    foregroundColor:
                        Colors.white,
                  ),
                  child:
                      const Text(
                    'PROCEED TO CHECKOUT',
                    style:
                        TextStyle(
                      fontWeight:
                          FontWeight.bold,
                    ),
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
    final user =
        FirebaseAuth.instance.currentUser;

    if (user == null) {
      return const Center(
        child:
            Text('Please login again.'),
      );
    }

    return StreamBuilder<
        QuerySnapshot>(
      stream: FirebaseFirestore
          .instance
          .collection('orders')
          .where(
            'userId',
            isEqualTo: user.uid,
          )
          .snapshots(),
      builder:
          (context, snapshot) {
        if (snapshot.connectionState ==
            ConnectionState.waiting) {
          return const Center(
            child:
                CircularProgressIndicator(
              color: primaryGreen,
            ),
          );
        }

        if (snapshot.hasError) {
          return const Center(
            child: Text(
              'Unable to load orders.',
              style:
                  TextStyle(
                color:
                    Colors.white70,
              ),
            ),
          );
        }

        final docs =
            snapshot.data?.docs ?? [];

        docs.sort((a, b) {
          final aData =
              a.data()
                  as Map<String, dynamic>;
          final bData =
              b.data()
                  as Map<String, dynamic>;

          final aTime =
              aData['createdAt']
                  as Timestamp?;
          final bTime =
              bData['createdAt']
                  as Timestamp?;

          return
              (bTime?.millisecondsSinceEpoch ??
                      0)
                  .compareTo(
            aTime?.millisecondsSinceEpoch ??
                0,
          );
        });

        if (docs.isEmpty) {
          return const Center(
            child: Text(
              'No orders yet.',
              style:
                  TextStyle(
                color:
                    Colors.white54,
              ),
            ),
          );
        }

        return ListView.builder(
          padding:
              const EdgeInsets.all(16),
          itemCount: docs.length,
          itemBuilder:
              (context, index) {
            final data =
                docs[index].data()
                    as Map<String,
                        dynamic>;

            return orderCard(data);
          },
        );
      },
    );
  }

  Widget orderCard(
      Map<String, dynamic> data) {
    final status =
        data['orderStatus'] ??
            'Pending Admin Approval';

    final rawItems =
        data['items'] ?? [];

    final items =
        List<Map<String, dynamic>>.from(
      rawItems.map(
        (item) =>
            Map<String, dynamic>.from(
          item,
        ),
      ),
    );

    return Container(
      margin:
          const EdgeInsets.only(
        bottom: 15,
      ),
      padding:
          const EdgeInsets.all(16),
      decoration:
          BoxDecoration(
        color: cardColor,
        borderRadius:
            BorderRadius.circular(18),
      ),
      child: Column(
        crossAxisAlignment:
            CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment:
                MainAxisAlignment
                    .spaceBetween,
            children: [
              const Text(
                'ORDER',
                style: TextStyle(
                  color: lightGreen,
                  fontWeight:
                      FontWeight.bold,
                ),
              ),
              statusBadge(
                status.toString(),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            '#${data['orderId'] ?? ''}',
            style:
                const TextStyle(
              color: Colors.white54,
              fontSize: 11,
            ),
          ),
          const SizedBox(height: 12),
          ...items.map(
            (item) => Padding(
              padding:
                  const EdgeInsets.symmetric(
                vertical: 4,
              ),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      '${item['name']} (${item['weight']})',
                      style:
                          const TextStyle(
                        color:
                            Colors.white70,
                      ),
                    ),
                  ),
                  Text(
                    'x${item['quantity'] ?? 1}',
                    style:
                        const TextStyle(
                      color:
                          lightGreen,
                    ),
                  ),
                  const SizedBox(
                      width: 15),
                  Text(
                    '₹${item['price'] ?? 0}',
                    style:
                        const TextStyle(
                      color:
                          Colors.white,
                    ),
                  ),
                ],
              ),
            ),
          ),
          const Divider(
            color: Colors.white12,
          ),
          Row(
            mainAxisAlignment:
                MainAxisAlignment
                    .spaceBetween,
            children: [
              const Text(
                'Total',
                style:
                    TextStyle(
                  color:
                      Colors.white70,
                ),
              ),
              Text(
                '₹${data['totalAmount'] ?? 0}',
                style:
                    const TextStyle(
                  color:
                      creamColor,
                  fontSize: 19,
                  fontWeight:
                      FontWeight.bold,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            statusMessage(
              status.toString(),
            ),
            style:
                const TextStyle(
              color: Colors.white70,
            ),
          ),
        ],
      ),
    );
  }

  Widget statusBadge(String status) {
    Color color = goldColor;

    if (status == 'Confirmed') {
      color = primaryGreen;
    } else if (status == 'Confirmed by Admin') {
      color = primaryGreen;
    } else if (status == 'Preparing') {
      color = Colors.orange;
    } else if (status ==
        'Out for Delivery') {
      color = Colors.blue;
    } else if (status == 'Delivered') {
      color = primaryGreen;
    } else if (status == 'Cancelled') {
      color = accentRed;
    }

    return Container(
      padding:
          const EdgeInsets.symmetric(
        horizontal: 10,
        vertical: 6,
      ),
      decoration:
          BoxDecoration(
        color:
            color.withOpacity(0.15),
        borderRadius:
            BorderRadius.circular(20),
        border: Border.all(
          color:
              color.withOpacity(0.5),
        ),
      ),
      child: Text(
        status,
        style:
            TextStyle(
          color: color,
          fontSize: 11,
          fontWeight:
              FontWeight.bold,
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
    final user =
        FirebaseAuth.instance.currentUser;

    return SingleChildScrollView(
      padding:
          const EdgeInsets.all(20),
      child: Column(
        children: [
          const SizedBox(height: 20),

          Container(
            width: 95,
            height: 95,
            decoration:
                const BoxDecoration(
              color: primaryGreen,
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.person,
              color: Colors.white,
              size: 52,
            ),
          ),

          const SizedBox(height: 15),

          Text(
            user?.displayName ??
                'GoatKart User',
            style:
                const TextStyle(
              color: Colors.white,
              fontSize: 23,
              fontWeight:
                  FontWeight.bold,
            ),
          ),

          const SizedBox(height: 5),

          Text(
            user?.email ?? '',
            style:
                const TextStyle(
              color: Colors.white54,
            ),
          ),

          const SizedBox(height: 30),

          profileOption(
            Icons.receipt_long,
            'My Orders',
            () {
              setState(() {
                selectedIndex = 3;
              });
            },
          ),

          profileOption(
            Icons.location_on_outlined,
            'Delivery Address',
            () {},
          ),

          profileOption(
            Icons.favorite_border,
            'Favourite Cuts',
            showFavourites,
          ),

          profileOption(
            Icons.help_outline,
            'Help & Support',
            () {},
          ),

          const SizedBox(height: 10),

          Container(
            width: double.infinity,
            decoration:
                BoxDecoration(
              color: cardColor,
              borderRadius:
                  BorderRadius.circular(
                16,
              ),
            ),
            child: ListTile(
              leading: const Icon(
                Icons.logout,
                color: accentRed,
              ),
              title:
                  const Text(
                'Logout',
                style:
                    TextStyle(
                  color:
                      accentRed,
                  fontWeight:
                      FontWeight.bold,
                ),
              ),
              onTap: logout,
            ),
          ),
        ],
      ),
    );
  }

  Widget profileOption(
    IconData icon,
    String title,
    VoidCallback onTap,
  ) {
    return Container(
      margin:
          const EdgeInsets.only(
        bottom: 10,
      ),
      decoration:
          BoxDecoration(
        color: cardColor,
        borderRadius:
            BorderRadius.circular(
          16,
        ),
      ),
      child: ListTile(
        leading: Icon(
          icon,
          color: lightGreen,
        ),
        title: Text(
          title,
          style:
              const TextStyle(
            color: Colors.white,
          ),
        ),
        trailing:
            const Icon(
          Icons.chevron_right,
          color: Colors.white38,
        ),
        onTap: onTap,
      ),
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
                    style:
                        TextStyle(
                      color:
                          Colors.white54,
                    ),
                  ),
                )
              : ListView.builder(
                  padding:
                      const EdgeInsets.all(
                    16,
                  ),
                  itemCount:
                      favourites.length,
                  itemBuilder:
                      (context, index) {
                    final product =
                        favourites[index];

                    return ListTile(
                      leading:
                          const Icon(
                        Icons.favorite,
                        color:
                            Colors.redAccent,
                      ),
                      title:
                          Text(
                        product.name,
                        style:
                            const TextStyle(
                          color:
                              Colors.white,
                        ),
                      ),
                      subtitle:
                          Text(
                        product.weight,
                        style:
                            const TextStyle(
                          color:
                              Colors.white54,
                        ),
                      ),
                      trailing:
                          Text(
                        '₹${product.price}',
                        style:
                            const TextStyle(
                          color:
                              lightGreen,
                        ),
                      ),
                    );
                  },
                ),
        );
      },
    );
  }

  Future<void> logout() async {
    await FirebaseAuth.instance
        .signOut();

    if (!mounted) return;

    Navigator.pushAndRemoveUntil(
      context,
      MaterialPageRoute(
        builder: (_) =>
            const AuthScreen(),
      ),
      (route) => false,
    );
  }
}

// ============================================================
// CHECKOUT SCREEN
// ============================================================

class CheckoutScreen
    extends StatefulWidget {
  final List<Product> cartItems;
  final int total;
  final VoidCallback onOrderPlaced;

  const CheckoutScreen({
    super.key,
    required this.cartItems,
    required this.total,
    required this.onOrderPlaced,
  });

  @override
  State<CheckoutScreen>
      createState() =>
          _CheckoutScreenState();
}

class _CheckoutScreenState
    extends State<CheckoutScreen> {
  final nameController =
      TextEditingController();

  final phoneController =
      TextEditingController();

  final addressController =
      TextEditingController();

  bool isGettingLocation = false;
  bool isPlacingOrder = false;

  double? latitude;
  double? longitude;

  @override
  void initState() {
    super.initState();

    final user =
        FirebaseAuth.instance.currentUser;

    nameController.text =
        user?.displayName ?? '';

    loadSavedPhone();
  }

  Future<void> loadSavedPhone() async {
    final user =
        FirebaseAuth.instance.currentUser;

    if (user == null) return;

    try {
      final doc =
          await FirebaseFirestore
              .instance
              .collection('users')
              .doc(user.uid)
              .get();

      if (!mounted) return;

      final data = doc.data();

      if (data != null &&
          data['phone'] != null) {
        phoneController.text =
            data['phone'].toString();
      }
    } catch (_) {}
  }

  @override
  void dispose() {
    nameController.dispose();
    phoneController.dispose();
    addressController.dispose();
    super.dispose();
  }

  // ==========================================================
  // CURRENT LOCATION
  // ==========================================================

  Future<void> useCurrentLocation() async {
    if (isGettingLocation) return;

    setState(() {
      isGettingLocation = true;
    });

    try {
      final serviceEnabled =
          await Geolocator
              .isLocationServiceEnabled();

      if (!serviceEnabled) {
        showMessage(
          'Please turn on Location/GPS on your device.',
        );
        return;
      }

      LocationPermission permission =
          await Geolocator
              .checkPermission();

      if (permission ==
          LocationPermission.denied) {
        permission =
            await Geolocator
                .requestPermission();
      }

      if (permission ==
              LocationPermission.denied ||
          permission ==
              LocationPermission
                  .deniedForever) {
        showMessage(
          'Location permission is required.',
        );
        return;
      }

      final position =
          await Geolocator
              .getCurrentPosition(
        locationSettings:
            const LocationSettings(
          accuracy:
              LocationAccuracy.high,
        ),
      );

      if (!mounted) return;

      setState(() {
        latitude =
            position.latitude;
        longitude =
            position.longitude;

        addressController.text =
            'Current location captured.\n'
            'Latitude: ${position.latitude.toStringAsFixed(6)}\n'
            'Longitude: ${position.longitude.toStringAsFixed(6)}\n\n'
            'Please add your house/street/landmark details.';
      });

      showMessage(
        'Current location captured successfully.',
        success: true,
      );
    } catch (e) {
      if (mounted) {
        showMessage(
          'Unable to get current location. Please enter address manually.',
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

  // ==========================================================
  // PLACE ORDER
  // ==========================================================

  Future<void> placeOrder() async {
    if (isPlacingOrder) return;

    final user =
        FirebaseAuth.instance.currentUser;

    final name =
        nameController.text.trim();

    final phone =
        phoneController.text
            .replaceAll(
          RegExp(r'\D'),
          '',
        );

    final address =
        addressController.text.trim();

    if (user == null) {
      showMessage(
        'Please login before placing an order.',
      );
      return;
    }

    if (name.isEmpty) {
      showMessage(
        'Please enter your name.',
      );
      return;
    }

    if (phone.length < 10) {
      showMessage(
        'Please enter a valid phone number.',
      );
      return;
    }

    if (address.length < 10) {
      showMessage(
        'Please enter your complete delivery address.',
      );
      return;
    }

    if (widget.cartItems.isEmpty) {
      showMessage(
        'Your cart is empty.',
      );
      return;
    }

    setState(() {
      isPlacingOrder = true;
    });

    try {
      final orderRef =
          FirebaseFirestore
              .instance
              .collection('orders')
              .doc();

      // ======================================================
      // GROUP SAME PRODUCTS
      // ======================================================

      final Map<
              String,
              Map<String, dynamic>>
          groupedItems = {};

      for (final product
          in widget.cartItems) {
        final key =
            '${product.name}_${product.weight}';

        if (groupedItems
            .containsKey(key)) {
          groupedItems[key]![
                  'quantity'] =
              (groupedItems[key]![
                          'quantity'] ??
                      0) +
                  1;
        } else {
          groupedItems[key] = {
            'name': product.name,
            'weight': product.weight,
            'price': product.price,
            'quantity': 1,
          };
        }
      }

      await orderRef.set({
        'orderId': orderRef.id,
        'userId': user.uid,
        'customerName': name,
        'email': user.email ?? '',
        'phone': phone,
        'address': address,

        // LOCATION
        'latitude': latitude,
        'longitude': longitude,
        'locationCaptured':
            latitude != null &&
                longitude != null,

        // ITEMS
        'items':
            groupedItems.values.toList(),

        // PAYMENT
        'totalAmount':
            widget.total,
        'paymentMethod':
            'Cash on Delivery',
        'paymentStatus':
            'Pending',

        // STATUS
        'orderStatus':
            'Pending Admin Approval',

        'createdAt':
            FieldValue.serverTimestamp(),
      });

      widget.onOrderPlaced();

      if (!mounted) return;

      Navigator.pushReplacement(
        context,
        MaterialPageRoute(
          builder: (_) =>
              OrderSuccessScreen(
            orderId:
                orderRef.id,
            total:
                widget.total,
          ),
        ),
      );
    } on FirebaseException catch (e) {
      if (mounted) {
        showMessage(
          'Could not place order: ${e.message ?? e.code}',
        );
      }
    } catch (e) {
      if (mounted) {
        showMessage(
          'Something went wrong. Please try again.',
        );
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

  void showMessage(
    String message, {
    bool success = false,
  }) {
    if (!mounted) return;

    ScaffoldMessenger.of(context)
        .hideCurrentSnackBar();

    ScaffoldMessenger.of(context)
        .showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor:
            success
                ? primaryGreen
                : accentRed,
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
      padding:
          const EdgeInsets.only(
        bottom: 14,
      ),
      child: TextField(
        controller: controller,
        maxLines: maxLines,
        keyboardType:
            keyboardType,
        style:
            const TextStyle(
          color: Colors.white,
        ),
        decoration:
            InputDecoration(
          labelText: label,
          prefixIcon:
              Icon(icon),
        ),
      ),
    );
  }

  // ==========================================================
  // BUILD
  // ==========================================================

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title:
            const Text('Checkout'),
      ),
      body: SafeArea(
        child: ListView(
          padding:
              const EdgeInsets.all(20),
          children: [
            const Text(
              'Delivery Details',
              style:
                  TextStyle(
                color: creamColor,
                fontSize: 23,
                fontWeight:
                    FontWeight.bold,
              ),
            ),

            const SizedBox(height: 18),

            field(
              nameController,
              'Full Name',
              Icons.person_outline,
            ),

            field(
              phoneController,
              'Phone Number',
              Icons.phone_outlined,
              keyboardType:
                  TextInputType.phone,
            ),

            field(
              addressController,
              'Full Delivery Address',
              Icons.location_on_outlined,
              maxLines: 5,
            ),

            // ==================================================
            // CURRENT LOCATION
            // ==================================================

            Container(
              padding:
                  const EdgeInsets.all(16),
              decoration:
                  BoxDecoration(
                color: cardColor,
                borderRadius:
                    BorderRadius.circular(
                  18,
                ),
                border:
                    Border.all(
                  color:
                      primaryGreen.withOpacity(
                    0.35,
                  ),
                ),
              ),
              child: Column(
                crossAxisAlignment:
                    CrossAxisAlignment.start,
                children: [
                  const Row(
                    children: [
                      Icon(
                        Icons.location_on,
                        color:
                            primaryGreen,
                      ),
                      SizedBox(
                          width: 8),
                      Text(
                        'Delivery Location',
                        style:
                            TextStyle(
                          color:
                              Colors.white,
                          fontSize: 17,
                          fontWeight:
                              FontWeight.bold,
                        ),
                      ),
                    ],
                  ),

                  const SizedBox(
                      height: 8),

                  const Text(
                    'Use your current GPS location to help GoatKart find your delivery location.',
                    style:
                        TextStyle(
                      color:
                          Colors.white54,
                    ),
                  ),

                  const SizedBox(
                      height: 12),

                  SizedBox(
                    width:
                        double.infinity,
                    height: 48,
                    child:
                        OutlinedButton.icon(
                      onPressed:
                          isGettingLocation
                              ? null
                              : useCurrentLocation,
                      icon:
                          isGettingLocation
                              ? const SizedBox(
                                  width:
                                      18,
                                  height:
                                      18,
                                  child:
                                      CircularProgressIndicator(
                                    strokeWidth:
                                        2,
                                  ),
                                )
                              : const Icon(
                                  Icons
                                      .my_location,
                                ),
                      label:
                          Text(
                        isGettingLocation
                            ? 'Getting Location...'
                            : 'USE CURRENT LOCATION',
                      ),
                    ),
                  ),

                  if (latitude != null &&
                      longitude != null) ...[
                    const SizedBox(
                        height: 10),
                    Text(
                      'Location captured ✓\n'
                      'Lat: ${latitude!.toStringAsFixed(6)}\n'
                      'Lng: ${longitude!.toStringAsFixed(6)}',
                      style:
                          const TextStyle(
                        color:
                            lightGreen,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ],
              ),
            ),

            const SizedBox(
                height: 20),

            // ==================================================
            // ORDER SUMMARY
            // ==================================================

            Container(
              padding:
                  const EdgeInsets.all(16),
              decoration:
                  BoxDecoration(
                color: cardColor,
                borderRadius:
                    BorderRadius.circular(
                  18,
                ),
              ),
              child: Column(
                crossAxisAlignment:
                    CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Order Summary',
                    style:
                        TextStyle(
                      color: creamColor,
                      fontSize: 19,
                      fontWeight:
                          FontWeight.bold,
                    ),
                  ),

                  const SizedBox(
                      height: 10),

                  ...widget.cartItems.map(
                    (product) =>
                        Padding(
                      padding:
                          const EdgeInsets
                              .symmetric(
                        vertical: 5,
                      ),
                      child: Row(
                        children: [
                          Expanded(
                            child:
                                Text(
                              '${product.name} (${product.weight})',
                              style:
                                  const TextStyle(
                                color:
                                    Colors.white70,
                              ),
                            ),
                          ),
                          Text(
                            '₹${product.price}',
                            style:
                                const TextStyle(
                              color:
                                  Colors.white,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),

                  const Divider(
                    color:
                        Colors.white24,
                  ),

                  Row(
                    mainAxisAlignment:
                        MainAxisAlignment
                            .spaceBetween,
                    children: [
                      const Text(
                        'Total',
                        style:
                            TextStyle(
                          color:
                              creamColor,
                          fontSize: 18,
                          fontWeight:
                              FontWeight
                                  .bold,
                        ),
                      ),
                      Text(
                        '₹${widget.total}',
                        style:
                            const TextStyle(
                          color:
                              lightGreen,
                          fontSize: 22,
                          fontWeight:
                              FontWeight
                                  .bold,
                        ),
                      ),
                    ],
                  ),

                  const SizedBox(
                      height: 12),

                  const Row(
                    children: [
                      Icon(
                        Icons
                            .payments_outlined,
                        color:
                            primaryGreen,
                      ),
                      SizedBox(
                          width: 8),
                      Text(
                        'Cash on Delivery',
                        style:
                            TextStyle(
                          color:
                              Colors.white,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),

            const SizedBox(
                height: 22),

            // ==================================================
            // PLACE ORDER
            // ==================================================

            SizedBox(
              height: 55,
              child:
                  ElevatedButton(
                onPressed:
                    isPlacingOrder
                        ? null
                        : placeOrder,
                style:
                    ElevatedButton
                        .styleFrom(
                  backgroundColor:
                      primaryGreen,
                  foregroundColor:
                      Colors.white,
                ),
                child:
                    isPlacingOrder
                        ? const SizedBox(
                            width: 25,
                            height: 25,
                            child:
                                CircularProgressIndicator(
                              color:
                                  Colors.white,
                              strokeWidth:
                                  2.5,
                            ),
                          )
                        : const Text(
                            'PLACE ORDER • CASH ON DELIVERY',
                            style:
                                TextStyle(
                              fontWeight:
                                  FontWeight
                                      .bold,
                            ),
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
// ORDER SUCCESS SCREEN
// ============================================================

class OrderSuccessScreen extends StatefulWidget {
  final String orderId;
  final int total;

  const OrderSuccessScreen({
    super.key,
    required this.orderId,
    required this.total,
  });

  @override
  State<OrderSuccessScreen> createState() => _OrderSuccessScreenState();
}

class _OrderSuccessScreenState extends State<OrderSuccessScreen>
    with TickerProviderStateMixin {
  late final AnimationController _circleController;
  late final AnimationController _tickController;
  late final AnimationController _contentController;

  late final Animation<double> _circleScale;
  late final Animation<double> _tickProgress;
  late final Animation<double> _contentFade;
  late final Animation<Offset> _contentSlide;

  @override
  void initState() {
    super.initState();

    _circleController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 750),
    );
    _circleScale = CurvedAnimation(
      parent: _circleController,
      curve: Curves.elasticOut,
    );

    _tickController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 550),
    );
    _tickProgress = CurvedAnimation(
      parent: _tickController,
      curve: Curves.easeOutCubic,
    );

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
    ).animate(CurvedAnimation(
      parent: _contentController,
      curve: Curves.easeOut,
    ));

    _runSuccessAnimation();
  }

  Future<void> _runSuccessAnimation() async {
    await _circleController.forward();
    if (!mounted) return;
    await _tickController.forward();
    if (!mounted) return;
    await _contentController.forward();
  }

  @override
  void dispose() {
    _circleController.dispose();
    _tickController.dispose();
    _contentController.dispose();
    super.dispose();
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
                const SizedBox(height: 32),
                FadeTransition(
                  opacity: _contentFade,
                  child: SlideTransition(
                    position: _contentSlide,
                    child: Column(
                      children: [
                        const Text(
                          'Order Placed Successfully!',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            color: creamColor,
                            fontSize: 27,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 12),
                        const Text(
                          'Your order has been received by GoatKart.',
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
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
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
                                    crossAxisAlignment: CrossAxisAlignment.start,
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
                            onPressed: () {
                              Navigator.pushAndRemoveUntil(
                                context,
                                MaterialPageRoute(
                                  builder: (_) => const HomeScreen(),
                                ),
                                (route) => false,
                              );
                            },
                            style: ElevatedButton.styleFrom(
                              backgroundColor: primaryGreen,
                              foregroundColor: Colors.white,
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
// ADMIN DASHBOARD
// ============================================================

class AdminDashboard
    extends StatefulWidget {
  const AdminDashboard({
    super.key,
  });

  @override
  State<AdminDashboard>
      createState() =>
          _AdminDashboardState();
}

class _AdminDashboardState
    extends State<AdminDashboard> {
  // ==========================================================
  // UPDATE ORDER STATUS
  // ==========================================================

  Future<void> updateOrderStatus(
    String orderId,
    String status,
  ) async {
    try {
      await FirebaseFirestore
          .instance
          .collection('orders')
          .doc(orderId)
          .update({
        'orderStatus': status,
        'updatedAt':
            FieldValue.serverTimestamp(),
      });

      if (!mounted) return;

      ScaffoldMessenger.of(context)
          .showSnackBar(
        SnackBar(
          content: Text(
            'Order updated to $status',
          ),
          backgroundColor:
              primaryGreen,
        ),
      );
    } catch (e) {
      if (!mounted) return;

      ScaffoldMessenger.of(context)
          .showSnackBar(
        const SnackBar(
          content: Text(
            'Unable to update order.',
          ),
          backgroundColor:
              accentRed,
        ),
      );
    }
  }

  // ==========================================================
  // LOGOUT
  // ==========================================================

  Future<void> logout() async {
    await FirebaseAuth.instance
        .signOut();

    if (!mounted) return;

    Navigator.pushAndRemoveUntil(
      context,
      MaterialPageRoute(
        builder: (_) =>
            const AuthScreen(),
      ),
      (route) => false,
    );
  }

  // ==========================================================
  // BUILD
  // ==========================================================

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'GoatKart Admin',
          style:
              TextStyle(
            fontWeight:
                FontWeight.bold,
          ),
        ),
        actions: [
          IconButton(
            onPressed: logout,
            icon:
                const Icon(Icons.logout),
          ),
        ],
      ),
      body: StreamBuilder<
          QuerySnapshot>(
        stream:
            FirebaseFirestore
                .instance
                .collection('orders')
                .snapshots(),
        builder:
            (context, snapshot) {
          if (snapshot
                  .connectionState ==
              ConnectionState
                  .waiting) {
            return const Center(
              child:
                  CircularProgressIndicator(
                color:
                    primaryGreen,
              ),
            );
          }

          if (snapshot.hasError) {
            return const Center(
              child: Text(
                'Unable to load orders.',
                style:
                    TextStyle(
                  color:
                      Colors.white70,
                ),
              ),
            );
          }

          final docs =
              snapshot.data?.docs ??
                  [];

          docs.sort((a, b) {
            final aData =
                a.data()
                    as Map<String,
                        dynamic>;

            final bData =
                b.data()
                    as Map<String,
                        dynamic>;

            final aTime =
                aData['createdAt']
                    as Timestamp?;

            final bTime =
                bData['createdAt']
                    as Timestamp?;

            return
                (bTime?.millisecondsSinceEpoch ??
                        0)
                    .compareTo(
              aTime?.millisecondsSinceEpoch ??
                  0,
            );
          });

          if (docs.isEmpty) {
            return const Center(
              child: Text(
                'No orders received yet.',
                style:
                    TextStyle(
                  color:
                      Colors.white54,
                ),
              ),
            );
          }

          return ListView.builder(
            padding:
                const EdgeInsets.all(16),
            itemCount:
                docs.length,
            itemBuilder:
                (context, index) {
              final data =
                  docs[index]
                          .data()
                      as Map<String,
                          dynamic>;

              return adminOrderCard(
                data,
              );
            },
          );
        },
      ),
    );
  }

  // ==========================================================
  // ADMIN ORDER CARD
  // ==========================================================

  Widget adminOrderCard(
    Map<String, dynamic> data,
  ) {
    final orderId =
        data['orderId']
                ?.toString() ??
            '';

    final status =
        data['orderStatus']
                ?.toString() ??
            'Pending Admin Approval';

    final customer =
        data['customerName']
                ?.toString() ??
            'Customer';

    final phone =
        data['phone']?.toString() ??
            '';

    final email =
        data['email']?.toString() ??
            '';

    final address =
        data['address']?.toString() ??
            '';

    final latitude =
        data['latitude'];

    final longitude =
        data['longitude'];

    final total =
        data['totalAmount'] ?? 0;

    final rawItems =
        data['items'] ?? [];

    final items =
        List<Map<String, dynamic>>.from(
      rawItems.map(
        (item) =>
            Map<String, dynamic>.from(
          item,
        ),
      ),
    );

    return Container(
      margin:
          const EdgeInsets.only(
        bottom: 18,
      ),
      padding:
          const EdgeInsets.all(18),
      decoration:
          BoxDecoration(
        color: cardColor,
        borderRadius:
            BorderRadius.circular(
          20,
        ),
        border: Border.all(
          color:
              status ==
                      'Pending Admin Approval'
                  ? goldColor.withOpacity(
                      0.4,
                    )
                  : primaryGreen
                      .withOpacity(
                      0.25,
                    ),
        ),
      ),
      child: Column(
        crossAxisAlignment:
            CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment:
                MainAxisAlignment
                    .spaceBetween,
            crossAxisAlignment:
                CrossAxisAlignment
                    .start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment:
                      CrossAxisAlignment
                          .start,
                  children: [
                    const Text(
                      'ORDER ID',
                      style:
                          TextStyle(
                        color:
                            lightGreen,
                        fontSize: 11,
                        fontWeight:
                            FontWeight
                                .bold,
                      ),
                    ),
                    const SizedBox(
                        height: 4),
                    Text(
                      orderId,
                      style:
                          const TextStyle(
                        color:
                            Colors.white70,
                        fontSize: 11,
                      ),
                    ),
                  ],
                ),
              ),
              statusBadge(
                status,
              ),
            ],
          ),

          const Divider(
            color:
                Colors.white12,
            height: 28,
          ),

          const Text(
            'Customer Details',
            style:
                TextStyle(
              color:
                  creamColor,
              fontSize: 18,
              fontWeight:
                  FontWeight.bold,
            ),
          ),

          const SizedBox(
              height: 12),

          adminInfoRow(
            Icons.person,
            customer,
          ),

          adminInfoRow(
            Icons.phone,
            phone,
          ),

          adminInfoRow(
            Icons.email,
            email,
          ),

          adminInfoRow(
            Icons.location_on,
            address,
          ),

          if (latitude != null &&
              longitude != null)
            adminInfoRow(
              Icons.gps_fixed,
              'GPS: $latitude, $longitude',
            ),

          const Divider(
            color:
                Colors.white12,
            height: 28,
          ),

          const Text(
            'Ordered Items',
            style:
                TextStyle(
              color:
                  creamColor,
              fontSize: 18,
              fontWeight:
                  FontWeight.bold,
            ),
          ),

          const SizedBox(
              height: 10),

          ...items.map(
            (item) =>
                Container(
              margin:
                  const EdgeInsets
                      .only(
                bottom: 8,
              ),
              padding:
                  const EdgeInsets
                      .all(12),
              decoration:
                  BoxDecoration(
                color:
                    cardColor2,
                borderRadius:
                    BorderRadius
                        .circular(
                  12,
                ),
              ),
              child: Row(
                children: [
                  Expanded(
                    child:
                        Text(
                      '${item['name']} (${item['weight']})',
                      style:
                          const TextStyle(
                        color:
                            Colors.white,
                        fontWeight:
                            FontWeight
                                .w600,
                      ),
                    ),
                  ),

                  Container(
                    padding:
                        const EdgeInsets
                            .symmetric(
                      horizontal: 9,
                      vertical: 5,
                    ),
                    decoration:
                        BoxDecoration(
                      color:
                          primaryGreen
                              .withOpacity(
                        0.15,
                      ),
                      borderRadius:
                          BorderRadius
                              .circular(
                        8,
                      ),
                    ),
                    child:
                        Text(
                      'Qty: ${item['quantity'] ?? 1}',
                      style:
                          const TextStyle(
                        color:
                            lightGreen,
                        fontWeight:
                            FontWeight
                                .bold,
                      ),
                    ),
                  ),

                  const SizedBox(
                      width: 12),

                  Text(
                    '₹${item['price'] ?? 0}',
                    style:
                        const TextStyle(
                      color:
                          Colors.white,
                      fontWeight:
                          FontWeight
                              .bold,
                    ),
                  ),
                ],
              ),
            ),
          ),

          const Divider(
            color:
                Colors.white12,
            height: 28,
          ),

          Row(
            mainAxisAlignment:
                MainAxisAlignment
                    .spaceBetween,
            children: [
              const Text(
                'Order Total',
                style:
                    TextStyle(
                  color:
                      Colors.white70,
                  fontSize: 16,
                ),
              ),
              Text(
                '₹$total',
                style:
                    const TextStyle(
                  color:
                      creamColor,
                  fontSize: 23,
                  fontWeight:
                      FontWeight.bold,
                ),
              ),
            ],
          ),

          const SizedBox(
              height: 8),

          const Row(
            children: [
              Icon(
                Icons
                    .payments_outlined,
                color:
                    primaryGreen,
                size: 19,
              ),
              SizedBox(width: 7),
              Text(
                'Cash on Delivery',
                style:
                    TextStyle(
                  color:
                      Colors.white70,
                ),
              ),
            ],
          ),

          const SizedBox(
              height: 18),

          // ==================================================
          // ADMIN ACTIONS
          // ==================================================

          if (status ==
              'Pending Admin Approval')
            SizedBox(
              width:
                  double.infinity,
              height: 52,
              child:
                  ElevatedButton
                      .icon(
                onPressed: () {
                  updateOrderStatus(
                    orderId,
                    'Confirmed by Admin',
                  );
                },
                icon:
                    const Icon(
                  Icons.check_circle,
                ),
                label:
                    const Text(
                  'CONFIRM ORDER',
                  style:
                      TextStyle(
                    fontWeight:
                        FontWeight
                            .bold,
                  ),
                ),
                style:
                    ElevatedButton
                        .styleFrom(
                  backgroundColor:
                      primaryGreen,
                  foregroundColor:
                      Colors.white,
                ),
              ),
            )
          else
            adminStatusButtons(
              orderId,
              status,
            ),
        ],
      ),
    );
  }

  Widget adminInfoRow(
    IconData icon,
    String value,
  ) {
    return Padding(
      padding:
          const EdgeInsets.only(
        bottom: 9,
      ),
      child: Row(
        crossAxisAlignment:
            CrossAxisAlignment
                .start,
        children: [
          Icon(
            icon,
            color:
                primaryGreen,
            size: 19,
          ),
          const SizedBox(
              width: 10),
          Expanded(
            child: Text(
              value,
              style:
                  const TextStyle(
                color:
                    Colors.white70,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget adminStatusButtons(
    String orderId,
    String status,
  ) {
    final statuses = [
      'Confirmed by Admin',
      'Preparing',
      'Out for Delivery',
      'Delivered',
      'Cancelled',
    ];

    return Column(
      crossAxisAlignment:
          CrossAxisAlignment
              .start,
      children: [
        const Text(
          'Update Order Status',
          style:
              TextStyle(
            color:
                Colors.white70,
            fontWeight:
                FontWeight.bold,
          ),
        ),

        const SizedBox(
            height: 10),

        Wrap(
          spacing: 8,
          runSpacing: 8,
          children:
              statuses.map(
            (nextStatus) {
              final selected =
                  status ==
                      nextStatus;

              return OutlinedButton(
                onPressed:
                    selected
                        ? null
                        : () {
                            updateOrderStatus(
                              orderId,
                              nextStatus,
                            );
                          },
                style:
                    OutlinedButton
                        .styleFrom(
                  foregroundColor:
                      lightGreen,
                ),
                child:
                    Text(
                  nextStatus,
                  style:
                      const TextStyle(
                    fontSize:
                        11,
                  ),
                ),
              );
            },
          ).toList(),
        ),
      ],
    );
  }

  Widget statusBadge(
      String status) {
    Color color =
        goldColor;

    if (status ==
            'Confirmed' ||
        status ==
            'Confirmed by Admin') {
      color =
          primaryGreen;
    } else if (status ==
        'Preparing') {
      color =
          Colors.orange;
    } else if (status ==
        'Out for Delivery') {
      color =
          Colors.blue;
    } else if (status ==
        'Delivered') {
      color =
          primaryGreen;
    } else if (status ==
        'Cancelled') {
      color =
          accentRed;
    }

    return Container(
      padding:
          const EdgeInsets
              .symmetric(
        horizontal: 10,
        vertical: 6,
      ),
      decoration:
          BoxDecoration(
        color:
            color.withOpacity(
          0.15,
        ),
        borderRadius:
            BorderRadius.circular(
          20,
        ),
        border:
            Border.all(
          color:
              color.withOpacity(
            0.5,
          ),
        ),
      ),
      child: Text(
        status,
        style:
            TextStyle(
          color: color,
          fontSize: 10,
          fontWeight:
              FontWeight.bold,
        ),
      ),
    );
  }
}