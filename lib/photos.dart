import 'dart:io';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart';
import 'package:rflutter_alert/rflutter_alert.dart';
import 'package:yar_gid_mobile/show_user_profile.dart';
import 'package:yar_gid_mobile/user_area.dart';
import 'model/photo_model.dart';

class PhotosPage extends ConsumerStatefulWidget {
  const PhotosPage({super.key});

  @override
  ConsumerState<PhotosPage> createState() => PhotoFeedScreenState();
}

class PhotoFeedScreenState extends ConsumerState<PhotosPage> {
  List<PhotoModel> photos = [];
  int _currentIndex = 1;

  @override
  void initState() {
    super.initState();
    loadPhotos();
  }

  Future<void> loadPhotos() async {
    QuerySnapshot querySnapshot = await FirebaseFirestore.instance.collection('Photos').orderBy('date', descending: true).get();
    setState(() {
      photos = querySnapshot.docs.map((doc) => PhotoModel.fromDocument(doc)).toList();
    });
  }

  void addNewPhoto() async {
    User? user = FirebaseAuth.instance.currentUser;

    if (user == null) {
      // Если пользователь не авторизован, показываем диалог авторизации
      _showLoginAlert(context);
    } else {
      // Если пользователь авторизован, продолжаем с добавлением фото
      Navigator.push(
        context,
        MaterialPageRoute(builder: (context) => AddPhotoPage(onPhotoAdded: loadPhotos)),
      );
    }
  }

  void _showLoginAlert(BuildContext context) {
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Фотолента'),
        centerTitle: true,
        actions: [
          IconButton(
            icon: const Icon(Icons.add_photo_alternate),
            onPressed: addNewPhoto,
          ),
        ],
      ),
      body: ListView.builder(
        itemCount: photos.length,
        itemBuilder: (context, index) {
          return PhotoCard(
            photo: photos[index],
            onPhotoUpdated: loadPhotos,
            onPhotoDeleted: loadPhotos,
          );
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
}

class PhotoCard extends StatefulWidget {
  final PhotoModel photo;
  final VoidCallback onPhotoUpdated;
  final VoidCallback onPhotoDeleted;

  const PhotoCard({
    super.key,
    required this.photo,
    required this.onPhotoUpdated,
    required this.onPhotoDeleted,
  });

  @override
  PhotoCardState createState() => PhotoCardState();
}

class PhotoCardState extends State<PhotoCard> {
  bool isLiked = false;
  bool _mounted = true;
  String? currentUserId;
  String uploaderLogin = '';

  @override
  void initState() {
    super.initState();
    currentUserId = FirebaseAuth.instance.currentUser?.uid;
    checkIfLiked();
    fetchUploaderLogin();
  }

  @override
  void dispose() {
    _mounted = false;
    super.dispose();
  }

  Future<void> fetchUploaderLogin() async {
    DocumentSnapshot userDoc = await FirebaseFirestore.instance
        .collection('User')
        .doc(widget.photo.uploader)
        .get();

    if (_mounted && userDoc.exists) {
      setState(() {
        uploaderLogin = userDoc.get('login') ?? 'Неизвестный пользователь';
      });
    }
  }

  Future<void> checkIfLiked() async {
    final userId = FirebaseAuth.instance.currentUser?.uid;
    if (userId != null) {
      DocumentSnapshot likeDoc = await FirebaseFirestore.instance
          .collection('Likes')
          .doc('${userId}_${widget.photo.id}')
          .get();

      DocumentSnapshot photoDoc = await FirebaseFirestore.instance
          .collection('Photos')
          .doc(widget.photo.id)
          .get();

      if (_mounted) {
        setState(() {
          isLiked = likeDoc.exists;
          if (photoDoc.exists) {
            widget.photo.likes = photoDoc.get('likes') ?? 0;
          }
        });
      }
    }
  }

  Future<void> toggleLike() async {
    final userId = FirebaseAuth.instance.currentUser?.uid;
    if (userId != null) {
      final likeRef = FirebaseFirestore.instance
          .collection('Likes')
          .doc('${userId}_${widget.photo.id}');

      final photoRef = FirebaseFirestore.instance
          .collection('Photos')
          .doc(widget.photo.id);

      await FirebaseFirestore.instance.runTransaction((transaction) async {
        DocumentSnapshot likeSnapshot = await transaction.get(likeRef);
        DocumentSnapshot photoSnapshot = await transaction.get(photoRef);

        if (likeSnapshot.exists) {
          // Пользователь уже лайкнул фото, убираем лайк
          transaction.delete(likeRef);
          if (photoSnapshot.exists) {
            int currentLikes = photoSnapshot.get('likes') ?? 0;
            transaction.update(photoRef, {'likes': currentLikes - 1});
          }
        } else {
          // Пользователь не лайкал фото, добавляем лайк
          transaction.set(likeRef, {'photoId': widget.photo.id, 'userId': userId});
          if (photoSnapshot.exists) {
            int currentLikes = photoSnapshot.get('likes') ?? 0;
            transaction.update(photoRef, {'likes': currentLikes + 1});
          }
        }
      }).then((_) {
        // После успешной транзакции обновляем локальное состояние
        setState(() {
          isLiked = !isLiked;
          widget.photo.likes = isLiked ? widget.photo.likes + 1 : widget.photo.likes - 1;
        });
      }).catchError((error) {
        // Обработка ошибок транзакции
        if (kDebugMode) {
          print('Transaction failed: $error');
        }
        // В случае ошибки не меняем локальное состояние
      });

      // Обновляем состояние после выполнения транзакции
      await checkIfLiked();
    }
  }

  void editPhoto() {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => EditPhotoPage(photo: widget.photo)),
    ).then((_) {
      widget.onPhotoUpdated();
      setState(() {});
    });
  }

  void deletePhoto() async {
    bool confirm = await showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Удалить фото?'),
        content: const Text('Вы уверены, что хотите удалить это фото?'),
        actions: [
          TextButton(
            child: const Text('Отмена'),
            onPressed: () => Navigator.of(context).pop(false),
          ),
          TextButton(
            child: const Text('Удалить'),
            onPressed: () => Navigator.of(context).pop(true),
          ),
        ],
      ),
    );

    if (confirm) {
      // Удаление фото из Firestore
      await FirebaseFirestore.instance.collection('Photos').doc(widget.photo.id).delete();

      // Удаление фото из Firebase Storage
      try {
        await FirebaseStorage.instance.refFromURL(widget.photo.image).delete();
      } catch (e) {
        print("Error deleting photo from storage: $e");
      }

      widget.onPhotoDeleted();
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Фото удалено')));
    }
  }


  @override
  Widget build(BuildContext context) {
    bool isCurrentUserUploader = widget.photo.uploader == currentUserId;

    return Card(
      margin: const EdgeInsets.all(10),
      child: Padding(
        padding: const EdgeInsets.all(10),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Image.network(widget.photo.image),
            const SizedBox(height: 10),
            Text(
              widget.photo.name,
              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            Text(widget.photo.desc),
            GestureDetector(
              onTap: () async {
                CollectionReference userRef = FirebaseFirestore.instance.collection('User');
                User? currentUser = FirebaseAuth.instance.currentUser;
                DocumentSnapshot snapshotUser = await userRef.doc(currentUser?.uid).get();

                Map<String, dynamic> userData = snapshotUser.data() as Map<String, dynamic>? ?? {};

                if (widget.photo.uploader == currentUserId) {
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
                      builder: (context) => UserProfileView(userId: widget.photo.uploader),
                    ),
                  );
                }
              },
              child: Row(
                children: [
                  const Text('Загружено: '),
                  Text(uploaderLogin, style: const TextStyle(decoration: TextDecoration.underline, decorationColor: Colors.blue, color: Colors.blue)),
                ],
              ),
            ),
            Text('Дата загрузки: ${DateFormat('dd.MM.yyyy', 'ru').format(widget.photo.date)}'),
            Text('Лайков: ${widget.photo.likes}'),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                IconButton(
                  icon: Icon(
                    isLiked ? Icons.favorite : Icons.favorite_border,
                    color: isLiked ? Colors.red : Colors.grey,
                  ),
                  onPressed: toggleLike,
                ),
                if (isCurrentUserUploader) ...[
                  IconButton(
                    icon: const Icon(Icons.edit),
                    onPressed: editPhoto,
                  ),
                  IconButton(
                    icon: const Icon(Icons.delete),
                    onPressed: deletePhoto,
                  ),
                ],
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class AddPhotoPage extends StatefulWidget {
  final VoidCallback onPhotoAdded;

  const AddPhotoPage({super.key, required this.onPhotoAdded});

  @override
  AddPhotoPageState createState() => AddPhotoPageState();
}

class AddPhotoPageState extends State<AddPhotoPage> {
  final _formKey = GlobalKey<FormState>();
  String name = '';
  String description = '';
  File? _image;

  Future getImage() async {
    final pickedFile = await ImagePicker().pickImage(source: ImageSource.gallery);

    setState(() {
      if (pickedFile != null) {
        _image = File(pickedFile.path);
      }
    });
  }

  void _submitForm() async {
    if (_formKey.currentState!.validate() && _image != null) {
      _formKey.currentState!.save();

      String userId = FirebaseAuth.instance.currentUser!.uid;
      String fileName = '${DateTime.now().millisecondsSinceEpoch}.jpg';

      Reference ref = FirebaseStorage.instance.ref().child('photos/$fileName');
      UploadTask uploadTask = ref.putFile(_image!);

      TaskSnapshot taskSnapshot = await uploadTask;
      String downloadUrl = await taskSnapshot.ref.getDownloadURL();

      await FirebaseFirestore.instance.collection('Photos').add({
        'name': name,
        'desc': description,
        'image': downloadUrl,
        'uploader': userId,
        'date': DateTime.now(),
        'likes': 0,
      });

      widget.onPhotoAdded();
      Navigator.of(context).pop();
    }
  }


  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Добавить новое фото')),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            if (_image != null) Image.file(_image!),
            ElevatedButton(
              onPressed: getImage,
              child: const Text('Выбрать фото'),
            ),
            TextFormField(
              decoration: const InputDecoration(labelText: 'Название'),
              validator: (value) {
                if (value == null || value.isEmpty) {
                  return 'Пожалуйста, введите название';
                }
                return null;
              },
              onSaved: (value) => name = value!,
            ),
            TextFormField(
              decoration: const InputDecoration(labelText: 'Описание'),
              validator: (value) {
                if (value == null || value.isEmpty) {
                  return 'Пожалуйста, введите описание';
                }
                return null;
              },
              onSaved: (value) => description = value!,
            ),
            ElevatedButton(
              onPressed: _submitForm,
              child: const Text('Добавить фото'),
            ),
          ],
        ),
      ),
    );
  }
}

class EditPhotoPage extends StatefulWidget {
  final PhotoModel photo;

  const EditPhotoPage({super.key, required this.photo});

  @override
  EditPhotoPageState createState() => EditPhotoPageState();
}

class EditPhotoPageState extends State<EditPhotoPage> {
  final _formKey = GlobalKey<FormState>();
  late String name;
  late String description;

  @override
  void initState() {
    super.initState();
    name = widget.photo.name;
    description = widget.photo.desc;
  }

  void _submitForm() async {
    if (_formKey.currentState!.validate()) {
      _formKey.currentState!.save();
      await FirebaseFirestore.instance.collection('Photos').doc(widget.photo.id).update({
        'name': name,
        'desc': description,
      });
      Navigator.of(context).pop();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Редактировать фото')),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            Image.network(widget.photo.image),
            TextFormField(
              initialValue: name,
              decoration: const InputDecoration(labelText: 'Название'),
              validator: (value) {
                if (value == null || value.isEmpty) {
                  return 'Пожалуйста, введите название';
                }
                return null;
              },
              onSaved: (value) => name = value!,
            ),
            TextFormField(
              initialValue: description,
              decoration: const InputDecoration(labelText: 'Описание'),
              validator: (value) {
                if (value == null || value.isEmpty) {
                  return 'Пожалуйста, введите описание';
                }
                return null;
              },
              onSaved: (value) => description = value!,
            ),
            ElevatedButton(
              onPressed: _submitForm,
              child: const Text('Сохранить изменения'),
            ),
          ],
        ),
      ),
    );
  }
}