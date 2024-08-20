import 'package:cloud_firestore/cloud_firestore.dart';

class ReviewModel {
  final String userId;
  final String reviewComment;
  final double mark;
  String? userPhotoURL;
  String? userLogin;

  ReviewModel({
    required this.userId,
    required this.reviewComment,
    required this.mark,
    this.userPhotoURL,
    this.userLogin,
  });

  factory ReviewModel.fromDocument(DocumentSnapshot doc) {
    Map<String, dynamic> data = doc.data() as Map<String, dynamic>;
    return ReviewModel(
      userId: data['userId'],
      reviewComment: data['reviewComment'],
      mark: data['mark'].toDouble(),
    );
  }
}