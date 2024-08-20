import 'package:cloud_firestore/cloud_firestore.dart';

class MapModel {
  String name = '', address = '', category = '', subcategory = '', desc = '';
  String? docId = '';
  DocumentReference? reference;
  double latitude = 0.0;
  double longitude = 0.0;

  MapModel({
    required this.name,
    required this.address,
    this.latitude = 0.0,
    this.longitude = 0.0,
    required this.subcategory,
    required this.category,
  });

  MapModel.fromJson(Map<String,dynamic> json) {
    address = json['address'] ?? '';
    name = json['name'] ?? '';
    latitude = (json['latitude'] ?? 0.0).toDouble();
    longitude = (json['longitude'] ?? 0.0).toDouble();
    subcategory = json['subcategory'] ?? '';
    category = json['category'] ?? '';
    desc = json['desc'] ?? '';
    docId = json['docId'];
  }

  Map<String, dynamic> toJson(){
    final Map<String, dynamic> data = <String, dynamic>{};
    data['address'] = address;
    data['name'] = name;
    data['latitude'] = latitude;
    data['longitude'] = longitude;
    data['subcategory'] = subcategory;
    data['category'] = category;
    return data;
  }
}