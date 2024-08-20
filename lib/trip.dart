import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:carousel_slider/carousel_slider.dart';
import 'package:intl/intl.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:yar_gid_mobile/user_area.dart';

import 'map.dart';
import 'model/map_model.dart';

class RoutesPage extends ConsumerStatefulWidget {
  const RoutesPage({super.key});

  @override
  ConsumerState<RoutesPage> createState() => RoutesPageState();
}

class RoutesPageState extends ConsumerState<RoutesPage> {
  String _sortOption = 'Все маршруты';
  int _currentIndex = 2; // Индекс "Маршруты"

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Маршруты'),
        centerTitle: true,
        actions: [
          PopupMenuButton<String>(
            icon: const Icon(Icons.sort),
            onSelected: (String result) {
              setState(() {
                _sortOption = result;
              });
            },
            itemBuilder: (BuildContext context) => <PopupMenuEntry<String>>[
              const PopupMenuItem<String>(
                value: 'Все маршруты',
                child: Text('Все маршруты'),
              ),
              const PopupMenuItem<String>(
                value: 'По популярности',
                child: Text('По популярности'),
              ),
              const PopupMenuItem<String>(
                value: 'Золотые маршруты',
                child: Text('Золотые маршруты'),
              ),
            ],
          ),
        ],
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance.collection('Trip').snapshots(),
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            return const Text('Что-то пошло не так');
          }

          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          List<DocumentSnapshot> routes = snapshot.data!.docs;

          if (_sortOption == 'По популярности') {
            return FutureBuilder<List<DocumentSnapshot>>(
              future: _sortByPopularity(routes),
              builder: (context, sortedSnapshot) {
                if (sortedSnapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }
                return _buildRoutesList(sortedSnapshot.data ?? []);
              },
            );
          }

          // Для 'Все маршруты' и 'Золотые маршруты' отображаем все маршруты без сортировки
          return _buildRoutesList(routes);
        },
      ),
      bottomNavigationBar: CustomBottomNavBar(
        currentIndex: _currentIndex,
        onTap: (index) {
          setState(() {
            _currentIndex = index;
          });
          // Здесь вы можете добавить логику для навигации по разделам
        },
        ref: ref,
      ),
    );
  }

  Widget _buildRoutesList(List<DocumentSnapshot> routes) {
    return ListView(
      children: routes.map((DocumentSnapshot document) {
        Map<String, dynamic> data = document.data() as Map<String, dynamic>;
        return RouteCard(
          routeId: document.id,
          name: data['name'],
          description: data['desc'],
          images: List<String>.from(data['images']),
        );
      }).toList(),
    );
  }

  Future<List<DocumentSnapshot>> _sortByPopularity(List<DocumentSnapshot> routes) async {
    List<Map<String, dynamic>> routesWithLikes = await Future.wait(
      routes.map((route) async {
        int likes = await _getLikesCount(route.id);
        return {'route': route, 'likes': likes};
      }),
    );

    routesWithLikes.sort((a, b) => b['likes'].compareTo(a['likes']));

    return routesWithLikes.map((item) => item['route'] as DocumentSnapshot).toList();
  }

  Future<int> _getLikesCount(String routeId) async {
    QuerySnapshot likesSnapshot = await FirebaseFirestore.instance
        .collection('TripLikes')
        .where('routeId', isEqualTo: routeId)
        .get();
    return likesSnapshot.docs.length;
  }
}

class RouteCard extends StatelessWidget {
  final String routeId;
  final String name;
  final String description;
  final List<String> images;

  const RouteCard({
    super.key,
    required this.routeId,
    required this.name,
    required this.description,
    required this.images,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.all(8.0),
      child: Column(
        children: [
          if (images.isNotEmpty) Image.network(images[0]),
          ListTile(
            title: Text(name),
            subtitle: Text(description),
          ),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              ElevatedButton(
                child: const Text('Подробнее'),
                onPressed: () {
                  if (FirebaseAuth.instance.currentUser != null) {
                    showModalBottomSheet(
                      context: context,
                      isScrollControlled: true,
                      builder: (BuildContext context) {
                        return RouteDetailsWidget(
                          routeId: routeId,
                          name: name,
                          images: images,
                        );
                      },
                    );
                  } else {
                    _showLoginAlert(context);
                  }
                },
              ),
              ElevatedButton(
                child: const Text('Отправиться'),
                onPressed: () {
                  _goToRoute(context, routeId);
                },
              ),
            ],
          ),
        ],
      ),
    );
  }

  void _goToRoute(BuildContext context, String routeId) async {
    // Получаем данные маршрута
    DocumentSnapshot routeDoc = await FirebaseFirestore.instance
        .collection('Trip')
        .doc(routeId)
        .get();

    if (routeDoc.exists) {
      Map<String, dynamic> routeData = routeDoc.data() as Map<String, dynamic>;
      List<String> placeIds = [];

      // Собираем идентификаторы мест, где значение true
      routeData.forEach((key, value) {
        if (value == true) {
          placeIds.add(key);
        }
      });

      // Получаем данные мест
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

  void _showLoginAlert(BuildContext context) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text("Требуется авторизация"),
          content: const Text(
              "Для просмотра деталей маршрута и оставления комментариев необходимо войти в систему."),
          actions: <Widget>[
            TextButton(
              child: const Text("OK"),
              onPressed: () {
                Navigator.of(context).pop();
                // Здесь можно добавить навигацию на страницу входа
              },
            ),
          ],
        );
      },
    );
  }
}

class RouteDetailsWidget extends StatefulWidget {
  final String routeId;
  final String name;
  final List<String> images;

  const RouteDetailsWidget({
    super.key,
    required this.routeId,
    required this.name,
    required this.images,
  });

  @override
  RouteDetailsWidgetState createState() => RouteDetailsWidgetState();
}

class RouteDetailsWidgetState extends State<RouteDetailsWidget> {
  final TextEditingController _commentController = TextEditingController();
  String? _userLogin;
  String? _userId;
  final List<String> _placeNames = [];

  @override
  void initState() {
    super.initState();
    _getUserInfo();
    _getPlaceNames();
  }

  Future<void> _getUserInfo() async {
    User? user = FirebaseAuth.instance.currentUser;
    if (user != null) {
      DocumentSnapshot userDoc = await FirebaseFirestore.instance
          .collection('User')
          .doc(user.uid)
          .get();
      if (userDoc.exists) {
        setState(() {
          _userLogin = userDoc['login'];
          _userId = user.uid;
        });
      }
    }
  }

  Future<void> _getPlaceNames() async {
    DocumentSnapshot routeDoc = await FirebaseFirestore.instance
        .collection('Trip')
        .doc(widget.routeId)
        .get();

    if (routeDoc.exists) {
      Map<String, dynamic> routeData = routeDoc.data() as Map<String, dynamic>;
      List<String> placeIds = [];

      routeData.forEach((key, value) {
        if (value == true) {
          placeIds.add(key);
        }
      });

      for (String id in placeIds) {
        DocumentSnapshot placeDoc = await FirebaseFirestore.instance
            .collection('Map')
            .doc(id)
            .get();
        if (placeDoc.exists) {
          setState(() {
            _placeNames.add(placeDoc['name']);
          });
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      color: Colors.white,
      child: Column(
        children: [
          // Кнопка закрытия
          Align(
            alignment: Alignment.topRight,
            child: Padding(
              padding: const EdgeInsets.only(top: 18.0, right: 18.0),
              child: IconButton(
                icon: const Icon(Icons.close),
                onPressed: () => Navigator.of(context).pop(),
              ),
            ),
          ),
          // Основное содержимое
          Expanded(
            child: DraggableScrollableSheet(
              initialChildSize: 1.0,
              minChildSize: 1.0,
              maxChildSize: 1.0,
              builder: (_, controller) {
                return ListView(
                  controller: controller,
                  children: [
                    CarouselSlider(
                      options: CarouselOptions(height: 200.0),
                      items: widget.images.map((imageUrl) {
                        return Builder(
                          builder: (BuildContext context) {
                            return Container(
                              width: MediaQuery
                                  .of(context)
                                  .size
                                  .width,
                              margin: const EdgeInsets.symmetric(
                                  horizontal: 5.0),
                              decoration: const BoxDecoration(
                                  color: Colors.grey),
                              child: Image.network(imageUrl, fit: BoxFit.cover),
                            );
                          },
                        );
                      }).toList(),
                    ),
                    Padding(
                      padding: const EdgeInsets.all(8.0),
                      child: Text(
                        widget.name,
                        style: Theme
                            .of(context)
                            .textTheme
                            .labelMedium,
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.all(8.0),
                      child: Text(
                        'Места маршрута:',
                        style: Theme
                            .of(context)
                            .textTheme
                            .labelMedium,
                      ),
                    ),
                    if (_placeNames.isEmpty)
                      const Padding(
                        padding: EdgeInsets.all(8.0),
                        child: CircularProgressIndicator(),
                      )
                    else
                      ..._placeNames.map((name) =>
                          Padding(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 16.0, vertical: 4.0),
                            child: Text('• $name'),
                          )),
                    Padding(
                      padding: const EdgeInsets.all(8.0),
                      child: Text('Комментарии:',
                          style: Theme
                              .of(context)
                              .textTheme
                              .labelMedium),
                    ),
                    StreamBuilder<QuerySnapshot>(
                      stream: FirebaseFirestore.instance
                          .collection('Comments')
                          .where('routeId', isEqualTo: widget.routeId)
                          .snapshots(),
                      builder: (context, snapshot) {
                        if (snapshot.hasError) {
                          return const Text('Что-то пошло не так');
                        }

                        if (snapshot.connectionState ==
                            ConnectionState.waiting) {
                          return const Center(
                              child: CircularProgressIndicator());
                        }

                        return Column(
                          children: snapshot.data!.docs
                              .map((DocumentSnapshot document) {
                            Map<String, dynamic> data =
                            document.data() as Map<String, dynamic>;
                            return FutureBuilder<DocumentSnapshot>(
                              future: FirebaseFirestore.instance
                                  .collection('User')
                                  .doc(data['userId'])
                                  .get(),
                              builder: (context, userSnapshot) {
                                if (userSnapshot.connectionState ==
                                    ConnectionState.waiting) {
                                  return const CircularProgressIndicator();
                                }

                                String photoURL =
                                    userSnapshot.data?['photoURL'] ?? '';

                                return ListTile(
                                  leading: CircleAvatar(
                                    backgroundImage: photoURL.isNotEmpty
                                        ? NetworkImage(photoURL)
                                        : null,
                                    child: photoURL.isEmpty
                                        ? const Icon(Icons.person)
                                        : null,
                                  ),
                                  title: Text(data['userLogin'],
                                      style: const TextStyle(fontSize: 14)),
                                  subtitle: Text(data['comment']),
                                  trailing: Text(
                                      DateFormat('dd.MM.yyyy HH:mm:ss').format(
                                          (data['date'] as Timestamp)
                                              .toDate())),
                                );
                              },
                            );
                          }).toList(),
                        );
                      },
                    ),
                    Padding(
                      padding: const EdgeInsets.all(8.0),
                      child: TextField(
                        controller: _commentController,
                        decoration: const InputDecoration(
                          hintText: 'Напишите комментарий',
                        ),
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.all(8.0),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          // Кнопка "Отправить" на всю ширину
                          ElevatedButton(
                            onPressed: _userLogin != null
                                ? () {
                              if (_commentController.text.isNotEmpty) {
                                FirebaseFirestore.instance.collection('Comments').add({
                                  'userLogin': _userLogin,
                                  'userId': _userId,
                                  'comment': _commentController.text,
                                  'date': FieldValue.serverTimestamp(),
                                  'routeId': widget.routeId,
                                });
                                _commentController.clear();
                              }
                            }
                                : null,
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.blue,
                            ),
                            child: const Text('Отправить', style: TextStyle(color: Colors.white)),
                          ),
                          // Кнопки "Начать" и "Лайк" под кнопкой "Отправить"
                          Row(
                            mainAxisAlignment: MainAxisAlignment.end,
                            children: [
                              StreamBuilder<DocumentSnapshot>(
                                stream: FirebaseFirestore.instance
                                    .collection('TripLikes')
                                    .doc('${widget.routeId}_$_userId')
                                    .snapshots(),
                                builder: (context, snapshot) {
                                  bool isLiked = false;
                                  if (snapshot.hasData && snapshot.data!.exists) {
                                    isLiked = true;
                                  }
                                  return IconButton(
                                    icon: Icon(
                                      isLiked ? Icons.favorite : Icons.favorite_border,
                                      color: isLiked ? Colors.red : null,
                                    ),
                                    onPressed: _userId != null
                                        ? () => _toggleLike(widget.routeId, _userId!)
                                        : null,
                                  );
                                },
                              ),
                              ElevatedButton(
                                onPressed: () {
                                  _goToRouteButton(context, widget.routeId);
                                },
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: Colors.black,
                                ),
                                child: const Text('Начать', style: TextStyle(color: Colors.white)),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ],
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  void _goToRouteButton(BuildContext context, String routeId) async {
  // Получаем данные маршрута
    DocumentSnapshot routeDoc = await FirebaseFirestore.instance
        .collection('Trip')
        .doc(routeId)
        .get();

    if (routeDoc.exists) {
      Map<String, dynamic> routeData = routeDoc.data() as Map<String, dynamic>;
      List<String> placeIds = [];

      // Собираем идентификаторы мест, где значение true
      routeData.forEach((key, value) {
        if (value == true) {
          placeIds.add(key);
        }
      });

      // Получаем данные мест
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

void _toggleLike(String routeId, String userId) {
  final docRef = FirebaseFirestore.instance
      .collection('TripLikes')
      .doc('${routeId}_$userId');

  FirebaseFirestore.instance.runTransaction((transaction) async {
    final snapshot = await transaction.get(docRef);
    if (snapshot.exists) {
      transaction.delete(docRef);
    } else {
      transaction.set(docRef, {
        'userId': userId,
        'routeId': routeId,
        'timestamp': FieldValue.serverTimestamp(),
      });
    }
  });
}