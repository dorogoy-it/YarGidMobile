import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../model/user_model.dart';

final userLogged = StateProvider<User?>((ref) => FirebaseAuth.instance.currentUser);
final userToken = StateProvider<String>((ref) => '');
final forceReload = StateProvider<bool>((ref) => false);

final userInformation = StateProvider<UserModel>((ref) => UserModel(name: '', login: '', id: '', kilo: 0, reviews: 0, routes: 0));