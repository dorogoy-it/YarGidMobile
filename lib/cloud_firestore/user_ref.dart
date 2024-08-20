import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../model/user_model.dart';
import '../state/state_management.dart';

Future<UserModel> getUserProfiles(WidgetRef ref, BuildContext context, String id) async {
  CollectionReference userRef = FirebaseFirestore.instance.collection('User');
  DocumentSnapshot snapshot = await userRef.doc(id).get();
  if (snapshot.exists) {
    final data = snapshot.data() as Map<String,dynamic>;
    var userModel = UserModel.fromJson(data);
    ref.read(userInformation.notifier).state = userModel;
    return userModel;
  }
  else {
    return UserModel(name: '', login: '', id: '', kilo: 0, reviews: 0, routes: 0);
  }
}