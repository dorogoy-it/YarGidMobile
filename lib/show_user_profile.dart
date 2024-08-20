import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:yar_gid_mobile/trip.dart';
import 'package:yar_gid_mobile/user_area.dart';

import 'map.dart';
import 'model/map_model.dart';

class UserProfileView extends StatefulWidget {
  final String userId;

  const UserProfileView({super.key, required this.userId});

  @override
  UserProfileViewState createState() => UserProfileViewState();
}

class UserProfileViewState extends State<UserProfileView> with SingleTickerProviderStateMixin {
  late Future<DocumentSnapshot> _userDataFuture;
  late TabController _tabController;
  List<String> userPhotos = [];
  List<String> achievementIcons = [];
  int achievementsCount = 0;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _userDataFuture = FirebaseFirestore.instance.collection('User').doc(widget.userId).get();
    _fetchLikedRoutes();
    _fetchUserPhotos();
    _fetchUserAchievements();
  }

  List<Map<String, dynamic>> likedRoutes = [];

  void _fetchLikedRoutes() async {

    final likesSnapshot = await FirebaseFirestore.instance
        .collection('TripLikes')
        .where('userId', isEqualTo: widget.userId)
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
    final photosSnapshot = await FirebaseFirestore.instance
        .collection('Photos')
        .where('uploader', isEqualTo: widget.userId)
        .get();

    setState(() {
      userPhotos = photosSnapshot.docs
          .map((doc) => doc['image'] as String)
          .toList();
    });
  }

  void _fetchUserAchievements() async {
    final achievementsSnapshot = await FirebaseFirestore.instance
        .collection('UserAchievements')
        .where('userId', isEqualTo: widget.userId)
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
      ),
      body: FutureBuilder<DocumentSnapshot>(
        future: _userDataFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) {
            return Center(child: Text('Ошибка: ${snapshot.error}'));
          }
          if (!snapshot.hasData || !snapshot.data!.exists) {
            return const Center(child: Text('Пользователь не найден'));
          }

          var userData = snapshot.data!.data() as Map<String, dynamic>;


          return SingleChildScrollView(
            child: Column(
              children: [
                CircleAvatar(
                  backgroundImage: NetworkImage(userData['photoURL'] ?? ''),
                  radius: 50,
                ),
                const SizedBox(height: 20),
                userData['showPersonalInfo']
                    ? Column(
                  children: [
                    Text('Имя: ${userData['name']}', style: const TextStyle(fontSize: 18)),
                    const SizedBox(height: 10),
                    Text('Логин: ${userData['login']}', style: const TextStyle(fontSize: 18)),
                  ],
                )
                    : const Text('Этот пользователь скрыл свои личные данные', style: TextStyle(fontSize: 16)),
                const SizedBox(height: 20),
                const Text('Статистика', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                const SizedBox(height: 10),
                userData['showStats']
                    ? Column(
                  children: [
                    Text('Пройдено километров: ${userData['kilo']}', style: const TextStyle(fontSize: 18)),
                    Text('Пройдено маршрутов: ${userData['routes']}', style: const TextStyle(fontSize: 18)),
                    Text('Опубликовано отзывов: ${userData['reviews']}', style: const TextStyle(fontSize: 18)),
                  ],
                )
                    : const Text('Этот пользователь скрыл свою статистику', style: TextStyle(fontSize: 16)),
                const SizedBox(height: 20),
                const Text('Достижения', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                const SizedBox(height: 10),
                userData['showAchievements']
                    ? Column(
                  children: [
                    Text(
                      '${userData['name']} получил $achievementsCount из 4 достижений',
                      style: const TextStyle(fontSize: 18),
                    ),
                    const SizedBox(height: 10),
                    LinearProgressIndicator(value: achievementsCount / 4),
                    const SizedBox(height: 10),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                      children: List.generate(4, (index) {
                        if (index < achievementIcons.length) {
                          return Image.network(achievementIcons[index], width: 40, height: 40);
                        } else {
                          return const Icon(Icons.lock, size: 40, color: Colors.grey);
                        }
                      }),
                    ),
                  ],
                )
                    : const Text('Этот пользователь скрыл свои достижения', style: TextStyle(fontSize: 16)),
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
                                    style: const TextStyle(fontWeight: FontWeight.bold),
                                  ),
                                  subtitle: Text(route['description']),
                                ),
                                Row(
                                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                                  children: [
                                    ElevatedButton(
                                      child: const Text('Подробнее'),
                                      onPressed: () {
                                        Navigator.push(
                                          context,
                                          MaterialPageRoute(
                                            builder: (context) => const RoutesPage(),
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
                      // Вкладка "События"
                      FutureBuilder<List<Event>>(
                        future: _getUserEvents(),
                        builder: (context, snapshot) {
                          if (snapshot.connectionState == ConnectionState.waiting) {
                            return const Center(child: CircularProgressIndicator());
                          } else if (snapshot.hasError) {
                            return Center(child: Text('Ошибка: ${snapshot.error}'));
                          } else if (!snapshot.hasData || snapshot.data!.isEmpty) {
                            return const Center(
                              child: Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Text('Этот пользователь пока не добавлял никаких событий'),
                                  SizedBox(height: 20),
                                ],
                              ),
                            );
                          } else {
                            final events = snapshot.data!;
                            return SingleChildScrollView(
                              child: Column(
                                children: [
                                  // Отображение первого события
                                  EventCard(event: events.first),
                                  const SizedBox(height: 20),
                                ],
                              ),
                            );
                          }
                        },
                      ),
                      // Вкладка "Фото"
                      GridView.builder(
                        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                          crossAxisCount: 3,
                          crossAxisSpacing: 4,
                          mainAxisSpacing: 4,
                        ),
                        itemCount: userPhotos.length,
                        itemBuilder: (context, index) {
                          return Image.network(userPhotos[index], fit: BoxFit.cover);
                        },
                      ),
                    ],
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  Future<List<Event>> _getUserEvents() async {
    final snapshot = await FirebaseFirestore.instance
        .collection('Events')
        .where('userId', isEqualTo: widget.userId)
        .get();

    return snapshot.docs.map((doc) => Event.fromFirestore(doc)).toList();
  }

  void _goToRoute(BuildContext context, String routeId) async {
    DocumentSnapshot routeDoc = await FirebaseFirestore.instance
        .collection('Trip')
        .doc(routeId)
        .get();

    if (routeDoc.exists) {
      Map<String, dynamic> routeData = routeDoc.data() as Map<String, dynamic>;
      List<String> placeIds = [];

      routeData.forEach((key, value) {
        if (value == true) {
          placeIds.add(key);
        }
      });

      List<MapModel> places = (await Future.wait(placeIds.map((id) async {
        DocumentSnapshot placeDoc = await FirebaseFirestore.instance
            .collection('Map')
            .doc(id)
            .get();
        if (placeDoc.exists) {
          Map<String, dynamic> placeData = placeDoc.data() as Map<String, dynamic>;
          return MapModel.fromJson(placeData);
        }
        return null;
      }))).whereType<MapModel>().toList();

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
}