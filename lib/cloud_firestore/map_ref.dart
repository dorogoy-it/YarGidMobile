import 'package:cloud_firestore/cloud_firestore.dart';

import '../model/map_model.dart';

Future<List<MapModel>> getPlaces() async {
  var places = List<MapModel>.empty(growable: true);
  var salonRef = FirebaseFirestore.instance
      .collection('Map');
  var snapshot = await salonRef.get();
  for (var element in snapshot.docs) {
    var place = MapModel.fromJson(element.data());
    place.docId = element.id;
    place.reference = element.reference;
    places.add(place);
  }
  return places;
}