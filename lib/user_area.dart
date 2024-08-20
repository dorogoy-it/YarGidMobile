import 'dart:io';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:geocoding/geocoding.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:image_picker/image_picker.dart';
import 'package:page_transition/page_transition.dart';
import 'package:rflutter_alert/rflutter_alert.dart';
import 'package:yar_gid_mobile/photos.dart';
import 'package:yar_gid_mobile/reviews.dart';
import 'package:yar_gid_mobile/support.dart';
import 'package:yar_gid_mobile/trip.dart';

import 'affiche.dart';
import 'main.dart';
import 'map.dart';
import 'model/map_model.dart';
import 'model/user_model.dart';

class UserArea extends ConsumerStatefulWidget {
  final String? displayName;
  final String? email;
  final String? photoURL;
  final double kilo;
  final int reviews;
  final int routes;

  const UserArea({
    super.key,
    this.displayName,
    this.email,
    this.photoURL,
    required this.kilo,
    required this.reviews,
    required this.routes,
    required showAchievements,
    required showPersonalInfo,
    required showStats,
  });

  @override
  ConsumerState<UserArea> createState() => UserAreaState();
}

class UserAreaState extends ConsumerState<UserArea>
    with SingleTickerProviderStateMixin {
  late int reviews;
  late double kilo;
  late int routes;
  late String displayName;
  late String email;
  late String photoURL;
  late TabController _tabController;
  List<String> userPhotos = [];
  List<String> achievementIcons = [];
  int achievementsCount = 0;
  late Future<DocumentSnapshot> _userDataFuture;
  late int _currentIndex;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    reviews = widget.reviews;
    kilo = widget.kilo;
    routes = widget.routes;
    displayName = widget.displayName!;
    email = widget.email!;
    photoURL = widget.photoURL!;
    _fetchReviewsCount();
    _fetchLikedRoutes();
    _fetchUserPhotos();
    _fetchUserAchievements();
    _fetchUserKilometres();
    _fetchUserRoutes();
    _fetchUserName();
    _fetchUserLogin();
    _fetchUserAvatar();
    _currentIndex = 0;
  }

  void _fetchUserName() async {
    final userId = FirebaseAuth.instance.currentUser?.uid;
    if (userId == null) return;

    final userDoc =
        await FirebaseFirestore.instance.collection('User').doc(userId).get();

    if (userDoc.exists) {
      setState(() {
        displayName = userDoc.data()?['name'] ?? '';
      });
    }
  }

  void _fetchUserLogin() async {
    final userId = FirebaseAuth.instance.currentUser?.uid;
    if (userId == null) return;

    final userDoc =
        await FirebaseFirestore.instance.collection('User').doc(userId).get();

    if (userDoc.exists) {
      setState(() {
        email = userDoc.data()?['login'] ?? '';
      });
    }
  }

  void _fetchUserAvatar() async {
    final userId = FirebaseAuth.instance.currentUser?.uid;
    if (userId == null) return;

    final userDoc =
        await FirebaseFirestore.instance.collection('User').doc(userId).get();

    if (userDoc.exists) {
      setState(() {
        photoURL = userDoc.data()?['photoURL'] ?? '';
      });
    }
  }

  void _fetchReviewsCount() async {
    final userId = FirebaseAuth.instance.currentUser?.uid;
    if (userId == null) return;

    final userDoc =
        await FirebaseFirestore.instance.collection('User').doc(userId).get();

    if (userDoc.exists) {
      setState(() {
        reviews = userDoc.data()?['reviews'] ?? 0;
      });
    }
  }

  void _fetchUserRoutes() async {
    final userId = FirebaseAuth.instance.currentUser?.uid;
    if (userId == null) return;

    final userDoc =
        await FirebaseFirestore.instance.collection('User').doc(userId).get();

    if (userDoc.exists) {
      setState(() {
        routes = userDoc.data()?['routes'] ?? 0;
      });
    }
  }

  void _fetchUserKilometres() async {
    final userId = FirebaseAuth.instance.currentUser?.uid;
    if (userId == null) return;

    final userDoc =
        await FirebaseFirestore.instance.collection('User').doc(userId).get();

    if (userDoc.exists) {
      setState(() {
        kilo = userDoc.data()?['kilo'] ?? 0.0;
      });
    }
  }

  List<Map<String, dynamic>> likedRoutes = [];

  void _fetchLikedRoutes() async {
    final userId = FirebaseAuth.instance.currentUser?.uid;
    if (userId == null) return;

    final likesSnapshot = await FirebaseFirestore.instance
        .collection('TripLikes')
        .where('userId', isEqualTo: userId)
        .get();

    for (var doc in likesSnapshot.docs) {
      final routeId = doc['routeId'] as String;
      final tripDoc = await FirebaseFirestore.instance
          .collection('Trip')
          .doc(routeId)
          .get();

      if (tripDoc.exists) {
        final data = tripDoc.data() as Map<String, dynamic>;
        setState(() {
          likedRoutes.add({
            'id': tripDoc.id,
            'name': data['name'],
            'description': data['desc'],
            'images': List<String>.from(data['images']),
          });
        });
      }
    }
  }

  void _fetchUserPhotos() async {
    final userId = FirebaseAuth.instance.currentUser?.uid;
    if (userId == null) return;

    final photosSnapshot = await FirebaseFirestore.instance
        .collection('Photos')
        .where('uploader', isEqualTo: userId)
        .get();

    setState(() {
      userPhotos =
          photosSnapshot.docs.map((doc) => doc['image'] as String).toList();
    });
  }

  void _fetchUserAchievements() async {
    final userId = FirebaseAuth.instance.currentUser?.uid;
    if (userId == null) return;

    // Получаем достижения пользователя
    final achievementsSnapshot = await FirebaseFirestore.instance
        .collection('UserAchievements')
        .where('userId', isEqualTo: userId)
        .get();

    List<String> icons = [];

    for (var doc in achievementsSnapshot.docs) {
      final achievementId = doc['achievementId'] as String;

      // Получаем данные достижения
      final achievementDoc = await FirebaseFirestore.instance
          .collection('Achievements')
          .doc(achievementId)
          .get();

      if (achievementDoc.exists) {
        final achievementData = achievementDoc.data() as Map<String, dynamic>;
        icons.add(achievementData['image'] as String);
      }
    }

    // Обновляем состояние иконок достижений и количество достижений
    setState(() {
      achievementIcons = icons;
      achievementsCount = icons.length;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
        appBar: AppBar(
          title: const Text('Профиль пользователя'),
          actions: [
            IconButton(
              icon: const Icon(Icons.settings),
              onPressed: _showSettingsDialog,
            ),
            IconButton(
              icon: const Icon(Icons.exit_to_app),
              onPressed: () => _signOut(context),
            ),
          ],
        ),
        body: SingleChildScrollView(
          child: Column(
            children: [
              if (widget.photoURL != null)
                CircleAvatar(
                  backgroundImage: NetworkImage(photoURL),
                  radius: 50,
                ),
              const SizedBox(height: 20),
              if (widget.displayName != null)
                Text('Имя: $displayName', style: const TextStyle(fontSize: 18)),
              const SizedBox(height: 10),
              if (widget.email != null)
                Text('Email: $email', style: const TextStyle(fontSize: 18)),
              const SizedBox(height: 10),
              const Text('Статистика',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
              const SizedBox(height: 10),
              Text('Пройдено километров: $kilo',
                  style: const TextStyle(fontSize: 18)),
              const SizedBox(height: 10),
              Text('Пройдено маршрутов: $routes',
                  style: const TextStyle(fontSize: 18)),
              const SizedBox(height: 10),
              Text('Опубликовано отзывов: $reviews',
                  style: const TextStyle(fontSize: 18)),
              const SizedBox(height: 20),
              const Text('Достижения',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
              const SizedBox(height: 10),
              // Текст с количеством достижений
              Text(
                'Вы получили $achievementsCount из 4 достижений',
                style: const TextStyle(fontSize: 18),
              ),
              const SizedBox(height: 10),
              // Прогресс-бар
              LinearProgressIndicator(value: achievementsCount / 4),
              const SizedBox(height: 10),
              // Отображение достижений
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: List.generate(4, (index) {
                  if (index < achievementIcons.length) {
                    return Image.network(achievementIcons[index],
                        width: 40, height: 40);
                  } else {
                    return const Icon(Icons.lock, size: 40, color: Colors.grey);
                  }
                }),
              ),
              const SizedBox(height: 20),
              TabBar(
                controller: _tabController,
                tabs: const [
                  Tab(text: 'Маршруты'),
                  Tab(text: 'События'),
                  Tab(text: 'Фото'),
                ],
              ),
              SizedBox(
                height: 300, // Задайте нужную высоту
                child: TabBarView(
                  controller: _tabController,
                  children: [
                    // Вкладка "Маршруты"
                    ListView.builder(
                      itemCount: likedRoutes.length,
                      itemBuilder: (context, index) {
                        final route = likedRoutes[index];
                        return Card(
                          margin: const EdgeInsets.all(8.0),
                          child: Column(
                            children: [
                              if (route['images'].isNotEmpty)
                                Image.network(route['images'][0]),
                              ListTile(
                                title: Text(
                                  route['name'],
                                  style: const TextStyle(
                                      fontWeight: FontWeight.bold),
                                ),
                                subtitle: Text(route['description']),
                              ),
                              Row(
                                mainAxisAlignment:
                                    MainAxisAlignment.spaceEvenly,
                                children: [
                                  ElevatedButton(
                                    child: const Text('Подробнее'),
                                    onPressed: () {
                                      Navigator.push(
                                        context,
                                        MaterialPageRoute(
                                          builder: (context) =>
                                              const RoutesPage(),
                                        ),
                                      );
                                    },
                                  ),
                                  ElevatedButton(
                                    child: const Text('Отправиться'),
                                    onPressed: () {
                                      _goToRoute(context, route['id']);
                                    },
                                  ),
                                ],
                              ),
                            ],
                          ),
                        );
                      },
                    ),
                    // Вкладка "События"
                    StreamBuilder<List<Event>>(
                      stream: _getUserEvents(),
                      builder: (context, snapshot) {
                        if (snapshot.connectionState ==
                            ConnectionState.waiting) {
                          return const Center(
                              child: CircularProgressIndicator());
                        } else if (snapshot.hasError) {
                          return Center(
                              child: Text('Ошибка: ${snapshot.error}'));
                        } else if (!snapshot.hasData ||
                            snapshot.data!.isEmpty) {
                          return Center(
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                const Text('У вас пока нет событий'),
                                const SizedBox(height: 20),
                                ElevatedButton(
                                  child: const Text('Создать событие'),
                                  onPressed: () =>
                                      _showCreateEventDialog(context),
                                ),
                              ],
                            ),
                          );
                        } else {
                          final events = snapshot.data!;
                          return SingleChildScrollView(
                            child: Column(
                              children: [
                                ElevatedButton(
                                  child: const Text('Создать событие'),
                                  onPressed: () =>
                                      _showCreateEventDialog(context),
                                ),
                                // Отображение всех событий
                                ...events
                                    .map((event) => EventCard(event: event)),
                                const SizedBox(height: 20),
                              ],
                            ),
                          );
                        }
                      },
                    ),
                    // Вкладка "Фото"
                    GridView.builder(
                      gridDelegate:
                          const SliverGridDelegateWithFixedCrossAxisCount(
                        crossAxisCount: 3,
                        crossAxisSpacing: 4,
                        mainAxisSpacing: 4,
                      ),
                      itemCount: userPhotos.length,
                      itemBuilder: (context, index) {
                        return Image.network(userPhotos[index],
                            fit: BoxFit.cover);
                      },
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      bottomNavigationBar: CustomBottomNavBar(
        currentIndex: 6, // Индекс "Профиль"
        onTap: (index) {
          // Обработка нажатия, если необходимо
        },
        ref: ref, // Передайте ссылку на WidgetRef
      ),
    );
  }

  void _signOut(BuildContext context) async {
    try {
      // Выход из Firebase
      await FirebaseAuth.instance.signOut();

      // Выход из Google
      final GoogleSignIn googleSignIn = GoogleSignIn();
      await googleSignIn.signOut();

      // Перенаправление на HomePageWidget
      Navigator.of(context).pushAndRemoveUntil(
        MaterialPageRoute(builder: (context) => const HomePageWidget()),
        (Route<dynamic> route) => false,
      );
    } catch (e) {
      print('Ошибка при выходе: $e');
      // Здесь можно добавить обработку ошибок, например, показать сообщение пользователю
    }
  }

  void _showSettingsDialog() {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('Настройки'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ListTile(
                title: const Text('Информация'),
                onTap: () {
                  Navigator.pop(context);
                  _showInfoSettingsDialog();
                },
              ),
              ListTile(
                title: const Text('Приватность'),
                onTap: () {
                  Navigator.pop(context);
                  _showPrivacySettingsDialog();
                },
              ),
            ],
          ),
        );
      },
    );
  }

  void _showInfoSettingsDialog() {
    TextEditingController nameController =
        TextEditingController(text: displayName);
    TextEditingController loginController = TextEditingController(text: email);
    String? newPhotoURL;

    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('Информация'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: nameController,
                decoration: const InputDecoration(labelText: 'Имя'),
              ),
              TextField(
                controller: loginController,
                decoration: const InputDecoration(labelText: 'Логин'),
              ),
              ElevatedButton(
                child: const Text('Изменить аватар'),
                onPressed: () async {
                  File? imageFile = await _pickImage();
                  if (imageFile != null) {
                    String? newPhotoURL = await _uploadImage(imageFile);
                    if (newPhotoURL != null) {
                      _saveUserInfo(displayName, email, newPhotoURL);
                    }
                  }
                },
              ),
            ],
          ),
          actions: [
            TextButton(
              child: const Text('Отмена'),
              onPressed: () {
                Navigator.of(context).pop();
              },
            ),
            TextButton(
              child: const Text('Сохранить'),
              onPressed: () {
                _saveUserInfo(
                    nameController.text, loginController.text, newPhotoURL);
                Navigator.of(context).pop();
              },
            ),
          ],
        );
      },
    );
  }

  Future<File?> _pickImage() async {
    final picker = ImagePicker();
    final pickedFile = await picker.pickImage(source: ImageSource.gallery);
    if (pickedFile != null) {
      return File(pickedFile.path);
    }
    return null;
  }

  Future<String?> _uploadImage(File imageFile) async {
    try {
      final userId = FirebaseAuth.instance.currentUser?.uid;
      if (userId == null) return null;

      final ref = FirebaseStorage.instance.ref().child('avatars/$userId.jpg');
      await ref.putFile(imageFile);
      return await ref.getDownloadURL();
    } catch (e) {
      print('Ошибка при загрузке изображения: $e');
      return null;
    }
  }

  void _saveUserInfo(
      String newName, String newLogin, String? newPhotoURL) async {
    final userId = FirebaseAuth.instance.currentUser?.uid;
    if (userId == null) return;

    final userRef = FirebaseFirestore.instance.collection('User').doc(userId);

    bool changed = false;

    if (newName != displayName) {
      await userRef.update({'name': newName});
      changed = true;
    }

    if (newLogin != email) {
      await userRef.update({'login': newLogin});
      changed = true;
    }

    if (newPhotoURL != null) {
      await userRef.update({'photoURL': newPhotoURL});
      changed = true;
    }

    if (changed) {
      _grantAchievement('Дорогой дневник...');
    }

    // Обновляем состояние виджета
    setState(() {
      displayName = newName;
      email = newLogin;
      if (newPhotoURL != null) {
        photoURL = newPhotoURL;
      }
    });

    // Обновляем данные пользователя
    _fetchUserName();
    _fetchUserLogin();
    _fetchUserAvatar();
  }

  void _grantAchievement(String achievementName) async {
    final userId = FirebaseAuth.instance.currentUser?.uid;
    if (userId == null) return;

    // Найдем достижение по имени
    final achievementSnapshot = await FirebaseFirestore.instance
        .collection('Achievements')
        .where('name', isEqualTo: achievementName)
        .get();

    if (achievementSnapshot.docs.isEmpty) return;

    final achievementId = achievementSnapshot.docs.first.id;

    // Проверим, не получено ли уже это достижение
    final existingAchievement = await FirebaseFirestore.instance
        .collection('UserAchievements')
        .doc('${achievementId}_$userId')
        .get();

    if (!existingAchievement.exists) {
      // Если достижение еще не получено, добавляем его
      await FirebaseFirestore.instance
          .collection('UserAchievements')
          .doc('${achievementId}_$userId')
          .set({
        'achievementId': achievementId,
        'userId': userId,
        'gotAt': FieldValue.serverTimestamp(),
      });
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Ура! У вас новое достижение!')),
      );

      // Обновляем список достижений пользователя
      _fetchUserAchievements();
    }
  }

  void _showPrivacySettingsDialog() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      // Если пользователь не авторизован, показываем сообщение об ошибке
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Пользователь не авторизован')),
      );
      return;
    }

    try {
      final userDoc = await FirebaseFirestore.instance
          .collection('User')
          .doc(user.uid)
          .get();
      final userData = UserModel.fromJson(userDoc.data());

      bool showAchievements = userData.showAchievements;
      bool showStats = userData.showStats;
      bool showPersonalInfo = userData.showPersonalInfo;

      showDialog(
        context: context,
        builder: (BuildContext context) {
          return StatefulBuilder(
            builder: (BuildContext context, StateSetter setState) {
              return AlertDialog(
                title: const Text('Настройки приватности'),
                content: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    SwitchListTile(
                      title: const Text('Показывать достижения'),
                      value: showAchievements,
                      onChanged: (bool value) {
                        setState(() {
                          showAchievements = value;
                        });
                      },
                    ),
                    SwitchListTile(
                      title: const Text('Показывать статистику'),
                      value: showStats,
                      onChanged: (bool value) {
                        setState(() {
                          showStats = value;
                        });
                      },
                    ),
                    SwitchListTile(
                      title: const Text('Показывать личную информацию'),
                      value: showPersonalInfo,
                      onChanged: (bool value) {
                        setState(() {
                          showPersonalInfo = value;
                        });
                      },
                    ),
                  ],
                ),
                actions: [
                  TextButton(
                    child: const Text('Сохранить'),
                    onPressed: () async {
                      await FirebaseFirestore.instance
                          .collection('User')
                          .doc(user.uid)
                          .update({
                        'showAchievements': showAchievements,
                        'showStats': showStats,
                        'showPersonalInfo': showPersonalInfo,
                      });
                      Navigator.of(context).pop();
                      setState(() {
                        // Обновляем состояние виджета, чтобы отразить изменения
                        _userDataFuture = FirebaseFirestore.instance
                            .collection('User')
                            .doc(user.uid)
                            .get();
                      });
                    },
                  ),
                  TextButton(
                    child: const Text('Отмена'),
                    onPressed: () {
                      Navigator.of(context).pop();
                    },
                  ),
                ],
              );
            },
          );
        },
      );
    } catch (e) {
      // Если произошла ошибка при получении данных, показываем сообщение об ошибке
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Ошибка при загрузке настроек: $e')),
      );
    }
  }

  Future<void> _showCreateEventDialog(BuildContext context) async {
    final formKey = GlobalKey<FormState>();
    String name = '';
    String description = '';
    String address = '';
    File? image;
    List<String> selectedSubcategories = [];
    final subcategories =
        await FirebaseFirestore.instance.collection('Subcategories').get();

    showDialog(
      context: context,
      builder: (BuildContext context) {
        return StatefulBuilder(
          builder: (context, setState) {
            return AlertDialog(
              title: const Text('Создать событие'),
              content: SingleChildScrollView(
                child: Form(
                  key: formKey,
                  child: Column(
                    children: [
                      TextFormField(
                        decoration:
                            const InputDecoration(labelText: 'Название'),
                        validator: (value) =>
                            value!.isEmpty ? 'Введите название' : null,
                        onSaved: (value) => name = value!,
                      ),
                      TextFormField(
                        decoration:
                            const InputDecoration(labelText: 'Описание'),
                        validator: (value) =>
                            value!.isEmpty ? 'Введите описание' : null,
                        onSaved: (value) => description = value!,
                      ),
                      TextFormField(
                        decoration: const InputDecoration(labelText: 'Адрес'),
                        validator: (value) =>
                            value!.isEmpty ? 'Введите адрес' : null,
                        onSaved: (value) => address = 'Красноярск, $value',
                      ),
                      ElevatedButton(
                        child: const Text('Выбрать фото'),
                        onPressed: () async {
                          final pickedFile = await ImagePicker()
                              .pickImage(source: ImageSource.gallery);
                          if (pickedFile != null) {
                            setState(() {
                              image = File(pickedFile.path);
                            });
                          }
                        },
                      ),
                      ...subcategories.docs.map((doc) => CheckboxListTile(
                            title: Text(doc['name']),
                            value: selectedSubcategories.contains(doc['name']),
                            onChanged: (bool? value) {
                              setState(() {
                                if (value!) {
                                  selectedSubcategories.add(doc['name']);
                                } else {
                                  selectedSubcategories.remove(doc['name']);
                                }
                              });
                            },
                          )),
                    ],
                  ),
                ),
              ),
              actions: [
                TextButton(
                  child: const Text('Отмена'),
                  onPressed: () => Navigator.of(context).pop(),
                ),
                TextButton(
                  child: const Text('Создать'),
                  onPressed: () async {
                    if (formKey.currentState!.validate() &&
                        image != null &&
                        selectedSubcategories.isNotEmpty) {
                      formKey.currentState!.save();

                      // Проверка адреса и получение координат
                      final addressInfo = await _getAddressInfo(address);
                      if (addressInfo == null) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                              content: Text('Такого адреса в Красноярске нет')),
                        );
                        return;
                      }

                      // Загрузка изображения в Firebase Storage
                      final storageRef = FirebaseStorage.instance.ref().child(
                          'events/${DateTime.now().toIso8601String()}.jpg');
                      await storageRef.putFile(image!);
                      final imageUrl = await storageRef.getDownloadURL();

                      // Создание события в Firestore
                      await FirebaseFirestore.instance
                          .collection('Events')
                          .add({
                        'name': name,
                        'desc': description,
                        'address': addressInfo.address,
                        'latitude': addressInfo.latitude,
                        'longitude': addressInfo.longitude,
                        'image': imageUrl,
                        'subcategory': selectedSubcategories.join(', '),
                        'userId': FirebaseAuth.instance.currentUser!.uid,
                      });

                      Navigator.of(context).pop();
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                            content: Text('Событие успешно добавлено!')),
                      );
                    }
                  },
                ),
              ],
            );
          },
        );
      },
    );
  }

  Future<AddressInfo?> _getAddressInfo(String address) async {
    try {
      List<Location> locations =
          await locationFromAddress("Красноярск, $address");
      if (locations.isNotEmpty) {
        Location location = locations.first;
        return AddressInfo(
          address: "Красноярск, $address",
          latitude: location.latitude,
          longitude: location.longitude,
        );
      }
    } catch (e) {
      print("Error getting location: $e");
    }
    return null;
  }

  Stream<List<Event>> _getUserEvents() {
    final userId = FirebaseAuth.instance.currentUser!.uid;
    return FirebaseFirestore.instance
        .collection('Events')
        .where('userId', isEqualTo: userId)
        .snapshots()
        .map((snapshot) =>
            snapshot.docs.map((doc) => Event.fromFirestore(doc)).toList());
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }
}

class CustomBottomNavBar extends StatelessWidget {
  final int currentIndex;
  final Function(int) onTap;
  final WidgetRef ref;

  const CustomBottomNavBar({
    super.key,
    required this.currentIndex,
    required this.onTap,
    required this.ref,
  });

  @override
  Widget build(BuildContext context) {
    return Stack(
      clipBehavior: Clip.none,
      alignment: Alignment.topCenter,
      children: [
        BottomNavigationBar(
          currentIndex: currentIndex,
          onTap: (index) => _handleNavigation(context, index),
          type: BottomNavigationBarType.fixed,
          selectedFontSize: 10, // Размер шрифта для выбранного элемента
          unselectedFontSize: 10, // Размер шрифта для невыбранных элементов
          items: [
            _buildNavItem(Icons.event, 'События', 0),
            _buildNavItem(Icons.photo, 'Фото', 1),
            _buildNavItem(Icons.route, 'Маршруты', 2),
            _buildNavItem(Icons.map, 'Карты', 3),
            _buildNavItem(Icons.star, 'Отзывы', 4),
            _buildNavItem(Icons.question_answer, 'Поддержка', 5),
            _buildNavItem(Icons.person, 'Профиль', 6),
          ],
        ),
        Positioned(
          top: -25,
          child: GestureDetector(
            onTap: () => _handleNavigation(context, 6),
            child: Container(
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: Colors.white,
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.2),
                    blurRadius: 6,
                    offset: const Offset(0, 3),
                  ),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }

  BottomNavigationBarItem _buildNavItem(IconData icon, String label, int index) {
    return BottomNavigationBarItem(
      icon: Icon(
        icon,
        color: currentIndex == index ? Colors.purple : Colors.grey,
      ),
      label: label,
    );
  }

  void _handleNavigation(BuildContext context, int index) {
    onTap(index);
    final titles = ['События', 'Фото', 'Маршруты', 'Карты', 'Отзывы', 'Поддержка', 'Профиль'];
    _navigateToSection(ref, context, titles[index]);
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

void _goToRoute(BuildContext context, String routeId) async {
  DocumentSnapshot routeDoc =
      await FirebaseFirestore.instance.collection('Trip').doc(routeId).get();

  if (routeDoc.exists) {
    Map<String, dynamic> routeData = routeDoc.data() as Map<String, dynamic>;
    List<String> placeIds = [];

    routeData.forEach((key, value) {
      if (value == true) {
        placeIds.add(key);
      }
    });

    List<MapModel> places = (await Future.wait(placeIds.map((id) async {
      DocumentSnapshot placeDoc =
          await FirebaseFirestore.instance.collection('Map').doc(id).get();
      if (placeDoc.exists) {
        Map<String, dynamic> placeData =
            placeDoc.data() as Map<String, dynamic>;
        return MapModel.fromJson(placeData);
      }
      return null;
    })))
        .whereType<MapModel>()
        .toList();

    places = places.where((place) => place != null).toList();

    // Переходим на MapPage с данными маршрута
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => MapPage(routePlaces: places, tripId: routeId),
      ),
    );
  }
}

class Event {
  final String id;
  final String name;
  final String description;
  final String address;
  final String imageUrl;
  final List<String> subcategories;
  final double latitude;
  final double longitude;

  Event({
    required this.id,
    required this.name,
    required this.description,
    required this.address,
    required this.imageUrl,
    required this.subcategories,
    required this.latitude,
    required this.longitude,
  });

  factory Event.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return Event(
      id: doc.id,
      name: data['name'],
      description: data['desc'],
      address: data['address'],
      imageUrl: data['image'],
      subcategories: (data['subcategory'] as String).split(', '),
      latitude: data['latitude'],
      longitude: data['longitude'],
    );
  }
}

class EventCard extends StatelessWidget {
  final Event event;

  const EventCard({super.key, required this.event});

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Column(
        children: [
          Image.network(event.imageUrl),
          ListTile(
            title: Text(event.name,
                style: const TextStyle(fontWeight: FontWeight.bold)),
            subtitle: Text(event.description),
          ),
          ElevatedButton(
            child: const Text('Перейти к событию'),
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => MapPage(
                    eventPlaces: [
                      MapModel(
                        latitude: event.latitude,
                        longitude: event.longitude,
                        address: event.address,
                        name: event.name,
                        subcategory: '',
                        category: '',
                      )
                    ],
                  ),
                ),
              );
            },
          ),
        ],
      ),
    );
  }
}

class AddressInfo {
  final String address;
  final double latitude;
  final double longitude;

  AddressInfo(
      {required this.address, required this.latitude, required this.longitude});
}
