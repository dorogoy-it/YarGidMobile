import 'package:cloud_firestore/cloud_firestore.dart';

class PhotoModel {
  final String id;
  final String name;
  final String desc;
  final String image;
  final String uploader;
  final DateTime date;
  int likes;

  PhotoModel({
    required this.id,
    required this.name,
    required this.desc,
    required this.image,
    required this.uploader,
    required this.date,
    required this.likes,
  });

  factory PhotoModel.fromDocument(DocumentSnapshot doc) {
    return PhotoModel(
      id: doc.id,
      name: doc['name'],
      desc: doc['desc'],
      image: doc['image'],
      uploader: doc['uploader'],
      date: (doc['date'] as Timestamp).toDate(),
      likes: doc['likes'],
    );
  }
}