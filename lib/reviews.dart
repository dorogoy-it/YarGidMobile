import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_rating_bar/flutter_rating_bar.dart';
import 'package:yar_gid_mobile/show_user_profile.dart';
import 'package:yar_gid_mobile/user_area.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class ReviewsPage extends ConsumerStatefulWidget {
  const ReviewsPage({super.key});

  @override
  ConsumerState<ReviewsPage> createState() => _ReviewsPageState();
}

class _ReviewsPageState extends ConsumerState<ReviewsPage> {
  int _currentIndex = 4; // Индекс "Отзывы"

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Отзывы'),
      ),
      body: const ReviewsList(),
      floatingActionButton: FloatingActionButton(
        onPressed: () {
          Navigator.push(
            context,
            MaterialPageRoute(builder: (context) => const ReviewWidget()),
          );
        },
        tooltip: 'Оставить отзыв',
        child: const Icon(Icons.add),
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
}

class ReviewsList extends StatelessWidget {
  const ReviewsList({super.key});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance.collection('Reviews').snapshots(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }
        if (snapshot.hasError) {
          return Center(child: Text('Ошибка: ${snapshot.error}'));
        }
        if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
          return const Center(child: Text('Нет отзывов'));
        }

        var reviews = snapshot.data!.docs;

        return ListView.builder(
          itemCount: reviews.length,
          itemBuilder: (context, index) {
            var review = reviews[index];
            return Card(
              margin: const EdgeInsets.all(8.0),
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      review['routeName'],
                      style: Theme.of(context).textTheme.labelMedium,
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        FutureBuilder<DocumentSnapshot>(
                          future: FirebaseFirestore.instance
                              .collection('User')
                              .doc(review['userId'])
                              .get(),
                          builder: (context, userSnapshot) {
                            if (userSnapshot.connectionState == ConnectionState.waiting) {
                              return const CircularProgressIndicator();
                            }
                            if (userSnapshot.hasError || !userSnapshot.hasData) {
                              return const Text('Ошибка загрузки');
                            }
                            var userData = userSnapshot.data!.data() as Map<String, dynamic>;
                            return Row(
                              children: [
                                GestureDetector(
                                  onTap: () {
                                    User? currentUser = FirebaseAuth.instance.currentUser;
                                    String currentUserId = currentUser?.uid ?? '';

                                    if (currentUserId == review['userId']) {
                                      Navigator.push(
                                        context,
                                        MaterialPageRoute(
                                          builder: (context) => UserArea(
                                            displayName: currentUser?.displayName,
                                            email: currentUser?.email,
                                            photoURL: currentUser?.photoURL,
                                            kilo: userData['kilo'] ?? 0.0,
                                            reviews: userData['reviews'] ?? 0,
                                            routes: userData['routes'] ?? 0,
                                            showAchievements: userData['showAchievements'] ?? true,
                                            showPersonalInfo: userData['showPersonalInfo'] ?? true,
                                            showStats: userData['showStats'] ?? true,
                                          ),
                                        ),
                                      );
                                    } else {
                                      Navigator.push(
                                        context,
                                        MaterialPageRoute(
                                          builder: (context) => UserProfileView(userId: review['userId']),
                                        ),
                                      );
                                    }
                                  },
                                  child: Row(
                                    children: [
                                      CircleAvatar(
                                        backgroundImage: NetworkImage(userData['photoURL'] ?? ''),
                                        child: userData['photoURL'] == null ? const Icon(Icons.person) : null,
                                      ),
                                      const SizedBox(width: 8),
                                      Text(userData['login'] ?? 'Неизвестный пользователь', style: const TextStyle(decoration: TextDecoration.underline, decorationColor: Colors.blue, color: Colors.blue)),
                                    ],
                                  ),
                                ),
                              ],
                            );
                          },
                        ),
                        const SizedBox(width: 8),
                        const Spacer(),
                        RatingBarIndicator(
                          rating: review['rating'],
                          itemBuilder: (context, index) => const Icon(
                            Icons.star,
                            color: Colors.amber,
                          ),
                          itemCount: 5,
                          itemSize: 20.0,
                          direction: Axis.horizontal,
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Text(review['desc']),
                    const SizedBox(height: 8),
                    if (FirebaseAuth.instance.currentUser?.uid == review['userId'])
                      Row(
                        mainAxisAlignment: MainAxisAlignment.end,
                        children: [
                          IconButton(
                            icon: const Icon(Icons.edit),
                            onPressed: () {
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (context) => EditReviewWidget(review: review),
                                ),
                              );
                            },
                          ),
                          IconButton(
                            icon: const Icon(Icons.delete),
                            onPressed: () {
                              showDialog(
                                context: context,
                                builder: (BuildContext context) {
                                  return AlertDialog(
                                    title: const Text("Подтверждение"),
                                    content: const Text("Вы уверены, что хотите удалить этот отзыв?"),
                                    actions: <Widget>[
                                      TextButton(
                                        child: const Text("Отмена"),
                                        onPressed: () {
                                          Navigator.of(context).pop();
                                        },
                                      ),
                                      TextButton(
                                        child: const Text("Удалить"),
                                        onPressed: () async {
                                          Navigator.of(context).pop();

                                          // Получаем ссылку на документ пользователя
                                          DocumentReference userRef = FirebaseFirestore.instance.collection('User').doc(review['userId']);

                                          // Удаляем отзыв и обновляем количество отзывов пользователя
                                          FirebaseFirestore.instance.runTransaction((transaction) async {
                                            DocumentSnapshot userSnapshot = await transaction.get(userRef);
                                            int reviewsCount = userSnapshot['reviews'] ?? 0;
                                            transaction.update(userRef, {'reviews': reviewsCount > 0 ? reviewsCount - 1 : 0});
                                            transaction.delete(FirebaseFirestore.instance.collection('Reviews').doc(review.id));
                                          });
                                        },
                                      ),
                                    ],
                                  );
                                },
                              );
                            },
                          ),
                        ],
                      ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }
}

class EditReviewWidget extends StatefulWidget {
  final DocumentSnapshot review;

  const EditReviewWidget({super.key, required this.review});

  @override
  EditReviewWidgetState createState() => EditReviewWidgetState();
}

class EditReviewWidgetState extends State<EditReviewWidget> {
  final _formKey = GlobalKey<FormState>();
  String? _selectedRoute;
  late double _rating;
  late String _description;

  List<String> _routes = [];

  @override
  void initState() {
    super.initState();
    _loadRoutes();
    _selectedRoute = widget.review['routeName'];
    _rating = widget.review['rating'];
    _description = widget.review['desc'];
  }

  void _loadRoutes() async {
    QuerySnapshot routeSnapshot = await FirebaseFirestore.instance.collection('Trip').get();
    setState(() {
      _routes = routeSnapshot.docs.map((doc) => doc['name'] as String).toList();
    });
  }

  void _submitReview() async {
    if (_formKey.currentState!.validate()) {
      await FirebaseFirestore.instance.collection('Reviews').doc(widget.review.id).update({
        'routeName': _selectedRoute,
        'rating': _rating,
        'desc': _description,
      });
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Отзыв успешно обновлен')),
      );
      Navigator.of(context).pop();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Редактировать отзыв')),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Form(
          key: _formKey,
          child: ListView(
            children: [
              DropdownButtonFormField<String>(
                value: _selectedRoute,
                items: _routes.map((route) => DropdownMenuItem(value: route, child: Text(route))).toList(),
                onChanged: (value) => setState(() => _selectedRoute = value),
                decoration: const InputDecoration(labelText: 'Выберите маршрут'),
                validator: (value) => value == null || value.isEmpty ? 'Выберите маршрут' : null,
              ),
              const SizedBox(height: 16),
              const Text('Оценка:'),
              RatingBar.builder(
                initialRating: _rating,
                minRating: 1,
                direction: Axis.horizontal,
                allowHalfRating: true,
                itemCount: 5,
                itemBuilder: (context, _) => const Icon(
                  Icons.star,
                  color: Colors.amber,
                ),
                onRatingUpdate: (rating) {
                  setState(() {
                    _rating = rating;
                  });
                },
              ),
              const SizedBox(height: 16),
              TextFormField(
                initialValue: _description,
                maxLines: 3,
                decoration: const InputDecoration(labelText: 'Описание'),
                onChanged: (value) => _description = value,
                validator: (value) => value == null || value.isEmpty ? 'Введите описание' : null,
              ),
              const SizedBox(height: 24),
              ElevatedButton(
                onPressed: _submitReview,
                child: const Text('Обновить отзыв'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class ReviewWidget extends StatefulWidget {
  const ReviewWidget({super.key});

  @override
  ReviewWidgetState createState() => ReviewWidgetState();
}

class ReviewWidgetState extends State<ReviewWidget> {
  final _formKey = GlobalKey<FormState>();
  String? _selectedRoute;
  double _rating = 3.0;
  String _description = '';

  List<String> _routes = [];

  @override
  void initState() {
    super.initState();
    _loadRoutes();
  }

  void _loadRoutes() async {
    QuerySnapshot routeSnapshot = await FirebaseFirestore.instance.collection('Trip').get();
    setState(() {
      _routes = routeSnapshot.docs.map((doc) => doc['name'] as String).toList();
    });
  }

  void _submitReview() async {
    if (_formKey.currentState!.validate()) {
      User? currentUser = FirebaseAuth.instance.currentUser;
      if (currentUser != null) {
        DocumentReference userRef = FirebaseFirestore.instance.collection('User').doc(currentUser.uid);
        await FirebaseFirestore.instance.collection('Reviews').add({
          'routeName': _selectedRoute,
          'rating': _rating,
          'desc': _description,
          'userId': currentUser.uid,
        });

        // Обновляем количество отзывов пользователя
        FirebaseFirestore.instance.runTransaction((transaction) async {
          DocumentSnapshot userSnapshot = await transaction.get(userRef);
          int reviewsCount = userSnapshot['reviews'] ?? 0;
          transaction.update(userRef, {'reviews': reviewsCount + 1});
        });

        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Отзыв успешно отправлен')),
        );
        _formKey.currentState!.reset();
        setState(() {
          _selectedRoute = null;
          _rating = 3.0;
          _description = '';
        });
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Для отправки отзыва необходимо авторизоваться')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Оставить отзыв')),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Form(
          key: _formKey,
          child: ListView(
            children: [
              DropdownButtonFormField<String>(
                value: _selectedRoute,
                items: _routes.map((route) => DropdownMenuItem(value: route, child: Text(route))).toList(),
                onChanged: (value) => setState(() => _selectedRoute = value),
                decoration: const InputDecoration(labelText: 'Выберите маршрут'),
                validator: (value) => value == null || value.isEmpty ? 'Выберите маршрут' : null,
              ),
              const SizedBox(height: 16),
              const Text('Оценка:'),
              RatingBar.builder(
                initialRating: _rating,
                minRating: 1,
                direction: Axis.horizontal,
                allowHalfRating: true,
                itemCount: 5,
                itemBuilder: (context, _) => const Icon(
                  Icons.star,
                  color: Colors.amber,
                ),
                onRatingUpdate: (rating) {
                  setState(() {
                    _rating = rating;
                  });
                },
              ),
              const SizedBox(height: 16),
              TextFormField(
                maxLines: 3,
                decoration: const InputDecoration(labelText: 'Описание'),
                onChanged: (value) => _description = value,
                validator: (value) => value == null || value.isEmpty ? 'Введите описание' : null,
              ),
              const SizedBox(height: 24),
              ElevatedButton(
                onPressed: _submitReview,
                child: const Text('Отправить отзыв'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}