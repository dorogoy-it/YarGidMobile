import 'package:carousel_slider/carousel_slider.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:rflutter_alert/rflutter_alert.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:yar_gid_mobile/affiche.dart';
import 'package:yar_gid_mobile/photos.dart';
import 'package:yar_gid_mobile/reviews.dart';
import 'package:yar_gid_mobile/state/state_management.dart';
import 'package:yar_gid_mobile/support.dart';
import 'package:yar_gid_mobile/trip.dart';
import 'package:yar_gid_mobile/map.dart';
import 'package:yar_gid_mobile/user_area.dart';
import 'package:yar_gid_mobile/utils/utils.dart';
import 'firebase_options.dart';
import 'model/domashniya_stranitsa_model.dart';
import 'model/home_page_model.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:page_transition/page_transition.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );
  runApp(const ProviderScope(child: MyApp()));
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  // This widget is the root of your application.
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'ЯрГид',
      localizationsDelegates: const [GlobalMaterialLocalizations.delegate],
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.deepPurple),
        useMaterial3: true,
      ),
      home: const HomePageWidget(),
    );
  }
}

class HomePageWidget extends StatefulWidget {
  const HomePageWidget({super.key});

  @override
  State<HomePageWidget> createState() => _HomePageWidgetState();
}

class _HomePageWidgetState extends State<HomePageWidget> {
  late HomePageModel _model;

  final scaffoldKey = GlobalKey<ScaffoldState>();

  @override
  void initState() {
    super.initState();
    _model = HomePageModel();
  }

  @override
  void dispose() {
    _model.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => _model.unfocusNode.canRequestFocus
          ? FocusScope.of(context).requestFocus(_model.unfocusNode)
          : FocusScope.of(context).unfocus(),
      child: Scaffold(
        key: scaffoldKey,
        backgroundColor: Theme.of(context).scaffoldBackgroundColor,
        body: const SingleChildScrollView(
          child: DomashnayaStranitsaWidget(),
        ),
      ),
    );
  }
}

class DomashnayaStranitsaWidget extends StatefulWidget {
  const DomashnayaStranitsaWidget({super.key});

  @override
  State<DomashnayaStranitsaWidget> createState() => _DomashnayaStranitsaWidgetState();
}

class _DomashnayaStranitsaWidgetState extends State<DomashnayaStranitsaWidget> {
  late DomashnayaStranitsaModel _model;
  final CarouselController _carouselController = CarouselController();
  late PageController _pageViewController;
  late int _current = 0;

  @override
  void initState() {
    super.initState();
    _model = DomashnayaStranitsaModel();
    _pageViewController = PageController(initialPage: 0);
  }

  @override
  void dispose() {
    _model.dispose();
    _pageViewController.dispose();
    super.dispose();
  }


  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
        child: Column(
      mainAxisSize: MainAxisSize.max,
      children: [
        Row(
          mainAxisSize: MainAxisSize.max,
          children: [
            Expanded(
              child: SizedBox(
                width: double.infinity,
                height: MediaQuery.sizeOf(context).height * 1,
                child: Stack(
                  children: [
                    CarouselSlider(
                      carouselController: _carouselController,
                      options: CarouselOptions(
                        height: MediaQuery.of(context).size.height,
                        viewportFraction: 1.0,
                        enlargeCenterPage: false,
                        autoPlay: true,
                        autoPlayInterval: const Duration(seconds: 3),
                        autoPlayAnimationDuration:
                            const Duration(milliseconds: 800),
                        autoPlayCurve: Curves.fastOutSlowIn,
                        pauseAutoPlayOnTouch: true,
                        aspectRatio: 2.0,
                        onPageChanged: (index, reason) {
                          setState(() {
                            _current = index;
                          });
                        },
                      ),
                      items: [
                        _buildSliderItem(context, 'assets/images/slider-1.jpg'),
                        _buildSliderItem(context, 'assets/images/slider-2.jpg'),
                        _buildSliderItem(context, 'assets/images/slider-3.jpg'),
                        _buildSliderItem(context, 'assets/images/slider-4.jpg'),
                        _buildSliderItem(context, 'assets/images/slider-5.jpg'),
                        _buildSliderItem(context, 'assets/images/slider-6.jpg'),
                      ],
                    ),
                    Positioned(
                      bottom: 16.0,
                      left: 16.0,
                      right: 16.0,
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: List.generate(6, (index) {
                          return AnimatedContainer(
                            duration: const Duration(milliseconds: 300),
                            width: _current == index ? 12.0 : 8.0,
                            height: _current == index ? 12.0 : 8.0,
                            margin: const EdgeInsets.symmetric(horizontal: 4.0),
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: _current == index
                                  ? Colors.yellow
                                  : Colors.grey,
                            ),
                          );
                        }),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
        SizedBox(
          height: 400,
          child: Stack(
            children: [
              Image.network(
                'https://images.unsplash.com/photo-1585943764927-c903dff55885?crop=entropy&cs=tinysrgb&fit=max&fm=jpg&ixid=M3w0NTYyMDF8MHwxfHNlYXJjaHwzfHx0b3VyaXN0c3xlbnwwfHx8fDE3MjA4NTEyMDZ8MA&ixlib=rb-4.0.3&q=80&w=1080',
                width: double.infinity,
                height: 400,
                fit: BoxFit.cover,
              ),
              Center(
                child: Container(
                  margin: const EdgeInsets.symmetric(horizontal: 16),
                  padding: const EdgeInsets.all(16),
                  color: const Color(0xCC094D2A),
                  child: const Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      Text(
                        'Красноярский край',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 24,
                          fontWeight: FontWeight.bold,
                          fontFamily: 'Readex Pro',
                        ),
                      ),
                      SizedBox(height: 8),
                      Text(
                        'Красноярский край — жемчужина Сибири, где удивительно сочетаются дикая природа, культурные сокровища и гостеприимство. Здесь можно прогуляться по заповеднику Красноярские Столбы, насладиться видами на Енисей в Красноярске, исследовать плато Путорана с его водопадами и озерами, а также покататься на лыжах в "Бобровом логу". Национальные парки и заповедники, такие как Таймырский и Ергаки, предлагают уникальную возможность увидеть редкие виды животных и растений. Гостеприимство местных жителей и разнообразие культурной жизни делают край идеальным местом для путешествий, где каждый найдет что-то для себя.',
                        style: TextStyle(
                          color: Colors.white,
                          fontFamily: 'Readex Pro',
                        ),
                        textAlign: TextAlign.center,
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
        GridView.count(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          crossAxisCount: 2,
          children: [
            _buildSectionContainer(
                context,
                'https://images.unsplash.com/photo-1549451371-64aa98a6f660?crop=entropy&cs=tinysrgb&fit=max&fm=jpg&ixid=M3w0NTYyMDF8MHwxfHNlYXJjaHwxfHxldmVudHN8ZW58MHx8fHwxNzIwODUyMzQwfDA&ixlib=rb-4.0.3&q=80&w=1080',
                'События'),
            _buildSectionContainer(
                context,
                'https://images.unsplash.com/photo-1480365501497-199581be0e66?crop=entropy&cs=tinysrgb&fit=max&fm=jpg&ixid=M3w0NTYyMDF8MHwxfHNlYXJjaHw3fHxwaG90b3N8ZW58MHx8fHwxNzIwODQ3OTEyfDA&ixlib=rb-4.0.3&q=80&w=1080',
                'Фото'),
            _buildSectionContainer(
                context,
                'https://images.unsplash.com/photo-1587331050712-38404c50a01b?crop=entropy&cs=tinysrgb&fit=max&fm=jpg&ixid=M3w0NTYyMDF8MHwxfHNlYXJjaHw0fHxyb3V0ZXN8ZW58MHx8fHwxNzIwODUyMzc5fDA&ixlib=rb-4.0.3&q=80&w=1080',
                'Маршруты'),
            _buildSectionContainer(
                context,
                'https://images.unsplash.com/photo-1548345680-f5475ea5df84?crop=entropy&cs=tinysrgb&fit=max&fm=jpg&ixid=M3w0NTYyMDF8MHwxfHNlYXJjaHw2fHxtYXBzfGVufDB8fHx8MTcyMDg1MjQwNXww&ixlib=rb-4.0.3&q=80&w=1080',
                'Карты'),
            _buildSectionContainer(
                context,
                'https://images.unsplash.com/photo-1633613286991-611fe299c4be?crop=entropy&cs=tinysrgb&fit=max&fm=jpg&ixid=M3w0NTYyMDF8MHwxfHNlYXJjaHwxfHxyZXZpZXdzfGVufDB8fHx8MTcyMDg1MjQyNXww&ixlib=rb-4.0.3&q=80&w=1080',
                'Отзывы'),
            _buildSectionContainer(
                context,
                'https://images.unsplash.com/photo-1531482615713-2afd69097998?crop=entropy&cs=tinysrgb&fit=max&fm=jpg&ixid=M3w0NTYyMDF8MHwxfHNlYXJjaHw1fHx0ZWNoJTIwc3VwcG9ydHxlbnwwfHx8fDE3MjA4NTI0NDV8MA&ixlib=rb-4.0.3&q=80&w=1080',
                'Поддержка'),
            _buildSectionContainer(
                context,
                'https://images.unsplash.com/photo-1500648767791-00dcc994a43e?crop=entropy&cs=tinysrgb&fit=max&fm=jpg&ixid=M3w0NTYyMDF8MHwxfHNlYXJjaHwxN3x8cHJvZmlsZXxlbnwwfHx8fDE3MjA4MDgwNjl8MA&ixlib=rb-4.0.3&q=80&w=1080',
                'Профиль'),
          ],
        ),
        Container(
          padding: const EdgeInsets.all(16),
          color: Colors.black,
          child: Center(
            child: RichText(
              text: TextSpan(
                style: const TextStyle(
                  fontFamily: 'Readex Pro',
                  color: Colors.white,
                ),
                children: [
                  const TextSpan(text: 'Почта для связи: '),
                  TextSpan(
                    text: 'yargid@inbox.ru',
                    style: const TextStyle(
                      decoration: TextDecoration.underline,
                    ),
                    recognizer: TapGestureRecognizer()
                      ..onTap = () async {
                        final Uri emailLaunchUri = Uri(
                          scheme: 'mailto',
                          path: 'yargid@inbox.ru',
                        );
                        if (await canLaunchUrl(emailLaunchUri)) {
                          await launchUrl(emailLaunchUri);
                        } else {
                          // Обработка ошибки, если URL не может быть запущен
                          if (kDebugMode) {
                            print('Не удалось открыть почтовый клиент');
                          }
                        }
                      },
                  ),
                ],
              ),
            ),
          ),
        ),
      ],
    ));
  }

  Widget _buildSectionContainer(
      BuildContext context, String imageUrl, String title) {
    return Consumer(builder: (context, ref, child) {
      final loginState = ref.watch(checkLoginStateProvider);
      return GestureDetector(
        onTap: () {
          loginState.when(
            data: (state) {
              if (state == LoginState.logged ||
                  (title != 'Профиль' &&
                      title != 'Отзывы' &&
                      title != 'Маршруты')) {
                _navigateToSection(ref, context, title);
              } else {
                _showLoginAlert(ref, context);
              }
            },
            error: (_, __) => _showLoginAlert(ref, context),
            loading: () => {}, // Можно добавить индикатор загрузки
          );
        },
        child: Container(
          margin: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(8),
            image: DecorationImage(
              image: NetworkImage(imageUrl),
              fit: BoxFit.cover,
            ),
          ),
          child: Container(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(8),
              color: Colors.black.withOpacity(0.5),
            ),
            child: Center(
              child: Text(
                title,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ),
        ),
      );
    });
  }
}

void _showLoginAlert(WidgetRef ref, BuildContext context) {
  showDialog(
    context: context,
    builder: (BuildContext context) {
      return PopScope(
        child: AlertDialog(
          title: const Text("Требуется авторизация"),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              DialogButton(
                onPressed: () async {
                  // Perform Google Sign-In
                  GoogleSignInAccount? googleUser = await GoogleSignIn().signIn();
                  if (googleUser == null) {
                    // The user canceled the sign-in
                    return;
                  }

                  GoogleSignInAuthentication googleAuth =
                  await googleUser.authentication;
                  AuthCredential credential = GoogleAuthProvider.credential(
                    accessToken: googleAuth.accessToken,
                    idToken: googleAuth.idToken,
                  );

                  // Sign in with the credential
                  UserCredential userCredential =
                  await FirebaseAuth.instance.signInWithCredential(credential);
                  var user = userCredential.user;

                  if (user != null) {
                    // Check if user exists in Firestore
                    CollectionReference userRef = FirebaseFirestore.instance.collection('User');
                    DocumentSnapshot snapshotUser = await userRef.doc(user.uid).get();

                    // Initialize userData as an empty Map if the document doesn't exist
                    Map<String, dynamic> userData = snapshotUser.data() as Map<String, dynamic>? ?? {};

                    if (!snapshotUser.exists) {
                      // User is new, add to Firestore
                      await userRef.doc(user.uid).set({
                        'name': user.displayName,
                        'login': user.email,
                        'id': user.uid,
                        'photoURL': user.photoURL,
                        'kilo': 0.0,
                        'reviews': 0,
                        'routes': 0,
                        'showAchievements': true,
                        'showPersonalInfo': true,
                        'showStats': true,
                      });

                      // Check for the achievement "Новое начало"
                      CollectionReference achievementsRef = FirebaseFirestore.instance.collection('Achievements');
                      QuerySnapshot achievementSnapshot = await achievementsRef.where('name', isEqualTo: 'Новое начало').get();

                      if (achievementSnapshot.docs.isNotEmpty) {
                        var achievementDoc = achievementSnapshot.docs.first;
                        String achievementId = achievementDoc.id;

                        // Add the achievement to UserAchievements
                        CollectionReference userAchievementsRef = FirebaseFirestore.instance.collection('UserAchievements');
                        await userAchievementsRef.doc('${achievementId}_${user.uid}').set({
                          'achievementId': achievementId,
                          'userId': user.uid,
                          'gotAt': FieldValue.serverTimestamp(),
                        });

                        // Show notification to the user
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('Ура! У вас новое достижение!')),
                        );
                      }
                    }

                    // Navigate to UserArea
                    Navigator.of(context).pushAndRemoveUntil(
                      MaterialPageRoute(
                        builder: (context) => UserArea(
                          displayName: user.displayName,
                          email: user.email,
                          photoURL: user.photoURL,
                          kilo: userData['kilo'] ?? 0.0,
                          reviews: userData['reviews'] ?? 0,
                          routes: userData['routes'] ?? 0,
                          showAchievements: userData['showAchievements'] ?? true,
                          showPersonalInfo: userData['showPersonalInfo'] ?? true,
                          showStats: userData['showStats'] ?? true,
                        ),
                      ),
                          (Route<dynamic> route) => false,
                    );

                    if (kDebugMode) {
                      print(user.photoURL);
                    }
                  }
                },
                color: Colors.white,
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Image.asset('assets/icons/google.png',
                        height: 24, width: 24),
                    const SizedBox(width: 10),
                    const Text("Войти через Google",
                        style: TextStyle(color: Colors.black)),
                  ],
                ),
              ),
            ],
          ),
        ),
      );
    },
  );
}

Future<void> _navigateToSection(WidgetRef ref, BuildContext context, String title) async {
  final user = FirebaseAuth.instance.currentUser;

  if ((title == 'Профиль' || title == 'Отзывы' || title == 'Маршруты') && user == null) {
    _showLoginAlert(ref, context);
    return;
  }
  switch (title) {
    case 'События':
      Navigator.push(
        context,
        PageTransition(
          type: PageTransitionType.fade,
          child: const AffichePage(),
        ),
      );
      break;
    case 'Фото':
      Navigator.push(
        context,
        PageTransition(
          type: PageTransitionType.fade,
          child: const PhotosPage(),
        ),
      );
      break;
    case 'Карты':
      await _checkAndGrantAchievement(context);
      Navigator.push(
        context,
        PageTransition(
          type: PageTransitionType.fade,
          child: const MapPage(),
        ),
      );
      break;
    case 'Поддержка':
      Navigator.push(
        context,
        PageTransition(
          type: PageTransitionType.fade,
          child: const SupportPage(),
        ),
      );
    case 'Профиль':
      if (user != null) {
        final userDoc = await FirebaseFirestore.instance.collection('User').doc(user.uid).get();
        final userData = userDoc.data() ?? {};
        Navigator.push(
          context,
          PageTransition(
            type: PageTransitionType.fade,
            child: UserArea(
              displayName: user.displayName ?? '',
              email: user.email ?? '',
              photoURL: user.photoURL ?? '',
              kilo: userData['kilo'] ?? 0.0,
              reviews: userData['reviews'] ?? 0,
              routes: userData['routes'] ?? 0,
              showAchievements: userData['showAchievements'] ?? true,
              showPersonalInfo: userData['showPersonalInfo'] ?? true,
              showStats: userData['showStats'] ?? true,
            ),
          ),
        );
      }
      break;
    case 'Маршруты':
      Navigator.push(
        context,
        PageTransition(
          type: PageTransitionType.fade,
          child: const RoutesPage(),
        ),
      );
      break;
    case 'Отзывы':
      Navigator.push(
        context,
        PageTransition(
          type: PageTransitionType.fade,
          child: const ReviewsPage(),
        ),
      );
      break;
    default:
      return;
  }
}

Future<void> _checkAndGrantAchievement(BuildContext context) async {
  final user = FirebaseAuth.instance.currentUser;
  if (user == null) return;

  final achievementDoc = await FirebaseFirestore.instance
      .collection('Achievements')
      .where('name', isEqualTo: 'В добрый путь')
      .get();

  if (achievementDoc.docs.isEmpty) return;

  final achievementId = achievementDoc.docs.first.id;
  final userAchievementId = '${achievementId}_${user.uid}';

  final userAchievementDoc = await FirebaseFirestore.instance
      .collection('UserAchievements')
      .doc(userAchievementId)
      .get();

  if (!userAchievementDoc.exists) {
    await FirebaseFirestore.instance
        .collection('UserAchievements')
        .doc(userAchievementId)
        .set({
      'achievementId': achievementId,
      'userId': user.uid,
      'gotAt': FieldValue.serverTimestamp(),
    });

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Ура! У вас новое достижение!'),
        duration: Duration(seconds: 3),
      ),
    );
  }
}

Widget _buildSliderItem(BuildContext context, String imagePath) {
  final screenWidth = MediaQuery.of(context).size.width;
  final fontSize = screenWidth * 0.12; // Адаптивный размер шрифта

  return Container(
    width: screenWidth,
    decoration: BoxDecoration(
      image: DecorationImage(
        fit: BoxFit.cover,
        image: AssetImage(imagePath),
      ),
    ),
    child: Stack(
      children: [
        Container(
          color: Colors.black.withOpacity(0.5),
        ),
        Center(
          child: Column(
            mainAxisSize: MainAxisSize.max,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                'Н А Ч А Т Ь  П У Т Е Ш Е С Т В И Е',
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: Colors.yellow,
                      letterSpacing: 0,
                      fontWeight: FontWeight.w600,
                    ),
              ),
              Text(
                'КРАСНОЯРСК',
                style: GoogleFonts.poppins(
                  textStyle: Theme.of(context).textTheme.displayLarge,
                  color: Colors.white,
                  fontSize: fontSize,
                  letterSpacing: 0,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ],
          ),
        ),
      ],
    ),
  );
}

final checkLoginStateProvider = FutureProvider<LoginState>((ref) async {
  try {
    var user = FirebaseAuth.instance.currentUser;
    if (user != null) {
      var token = await user.getIdToken();
      ref.read(userToken.notifier).state = token!;
      CollectionReference userRef =
          FirebaseFirestore.instance.collection('User');
      DocumentSnapshot snapshotUser = await userRef.doc(user.uid).get();
      // Force reload state
      ref.read(forceReload.notifier).state = true;
      return snapshotUser.exists ? LoginState.logged : LoginState.notLogged;
    } else {
      return LoginState.notLogged;
    }
  } catch (e) {
    return LoginState.notLogged;
  }
});
