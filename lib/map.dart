import 'dart:async';
import 'dart:convert';
import 'dart:math';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_rating_bar/flutter_rating_bar.dart';
import 'package:geocoding/geocoding.dart';
import 'package:geolocator/geolocator.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:intl/intl.dart';
import 'package:rflutter_alert/rflutter_alert.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:yandex_mapkit/yandex_mapkit.dart';
import 'package:yar_gid_mobile/show_user_profile.dart';
import 'package:yar_gid_mobile/user_area.dart';
import 'cloud_firestore/map_ref.dart';
import 'model/map_model.dart';
import 'model/review_model.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class MapPage extends ConsumerStatefulWidget {
  final List<MapModel>? routePlaces;
  final List<MapModel>? eventPlaces;
  final String? tripId;

  const MapPage({super.key, this.routePlaces, this.eventPlaces, this.tripId});

  @override
  ConsumerState<MapPage> createState() => MapPageState();
}

class MapPageState extends ConsumerState<MapPage> {
  late YandexMapController _mapController;
  List<MapModel> _places = [];
  late List<PlacemarkMapObject> _placemarks = [];
  final bool _isRouteMenuOpen = false;
  bool _returnToStart = false;
  bool _addAddressByTap = false;
  String _selectedTransportMode = 'Пешком';
  List<String> _userAddresses = [];
  late List<PlacemarkMapObject> _routePlacemarks = [];

  late List<TextEditingController> _addressControllers = [];

  final List<PolylineMapObject> _routePolylines = [];
  List<String> _routeAddresses = [];
  final List<PlacemarkMapObject> _originalPlacemarks = [];
  Point? _lastTapPosition;

  Point? _startPoint;

  double _totalDistance = 0.0;
  bool _isRouteActive = false;
  List<MapModel> _eventPlaces = [];
  final List<PlacemarkMapObject> _eventPlacemarks = [];

  int _currentIndex = 3;

  @override
  void initState() {
    super.initState();
    _eventPlaces = widget.eventPlaces ?? [];
    _loadPlaces();
    _loadTransportMode();
    loadRoute().then((currentIndex) {
      if (_routePlacemarks.isNotEmpty) {
        _showRouteProgressMenu();
      } else {
        if (kDebugMode) {
          print("No route loaded in initState");
        }
      }
    }).catchError((error) {
      if (kDebugMode) {
        print("Error loading route: $error");
      }
    });
  }

  Future<Point?> _getCurrentUserLocation() async {
    try {
      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.denied) {
          return null;
        }
      }

      Position position = await Geolocator.getCurrentPosition();
      return Point(latitude: position.latitude, longitude: position.longitude);
    } catch (e) {
      if (kDebugMode) {
        print("Error getting current location: $e");
      }
      return null;
    }
  }

  Future<void> _showRouteOnMap(List<MapModel> routePlaces) async {
    _routePlacemarks.clear();
    _routePolylines.clear();

    // Получаем текущее местоположение пользователя
    Point? userLocation = await _getCurrentUserLocation();

    List<RequestPoint> routePoints = [];

    if (userLocation != null) {
      routePoints.add(RequestPoint(
          point: userLocation,
          requestPointType: RequestPointType.wayPoint
      ));
    }

    for (int i = 0; i < routePlaces.length; i++) {
      MapModel place = routePlaces[i];
      routePoints.add(RequestPoint(
          point: Point(latitude: place.latitude, longitude: place.longitude),
          requestPointType: i == routePlaces.length - 1 ? RequestPointType.wayPoint : RequestPointType.viaPoint
      ));
    }

    if (routePoints.length > 1) {
      try {
        if (_selectedTransportMode == 'Пешком') {
          var resultWithSession = await YandexPedestrian.requestRoutes(
            points: routePoints,
            avoidSteep: true,
            timeOptions: TimeOptions(departureTime: DateTime.now()),
          );

          PedestrianSessionResult result = await resultWithSession.$2;

          if (result.routes != null && result.routes!.isNotEmpty) {
            PedestrianRoute route = result.routes!.first;

            _routePolylines.add(
              PolylineMapObject(
                mapId: const MapObjectId('route_polyline'),
                polyline: route.geometry,
                strokeColor: Colors.orange,
                strokeWidth: 3.0,
              ),
            );

            await _saveRouteGeometry(route.geometry);
          } else {
            print("No pedestrian routes returned from Yandex");
            return;
          }
        } else {
          var resultWithSession = await YandexDriving.requestRoutes(
            points: routePoints,
            drivingOptions: const DrivingOptions(
              initialAzimuth: 0,
              routesCount: 1,
              avoidTolls: true,
            ),
          );

          DrivingSessionResult result = await resultWithSession.$2;

          if (result.routes != null && result.routes!.isNotEmpty) {
            DrivingRoute route = result.routes!.first;

            _routePolylines.add(
              PolylineMapObject(
                mapId: const MapObjectId('route_polyline'),
                polyline: route.geometry,
                strokeColor: Colors.blue,
                strokeWidth: 3.0,
              ),
            );

            await _saveRouteGeometry(route.geometry);
          } else {
            print("No driving routes returned from Yandex");
            return;
          }
        }

        // Создаем метки для каждой точки маршрута
        for (int i = 0; i < routePoints.length; i++) {
          _routePlacemarks.add(
            PlacemarkMapObject(
              mapId: MapObjectId('route_place_$i'),
              point: routePoints[i].point,
              icon: PlacemarkIcon.single(PlacemarkIconStyle(
                image: BitmapDescriptor.fromAssetImage(
                    'assets/images/green_metka.png'),
              )),
            ),
          );
        }

        setState(() {
          _placemarks.addAll(_routePlacemarks);
        });

        _mapController.moveCamera(
          CameraUpdate.newGeometry(
            Geometry.fromBoundingBox(BoundingBox(
              northEast: _routePolylines.first.polyline.points.reduce((a, b) => Point(
                latitude: max(a.latitude, b.latitude),
                longitude: max(a.longitude, b.longitude),
              )),
              southWest: _routePolylines.first.polyline.points.reduce((a, b) => Point(
                latitude: min(a.latitude, b.latitude),
                longitude: min(a.longitude, b.longitude),
              )),
            )),
          ),
        );

        // Заполняем текстовые поля адресами
        setState(() {
          _addressControllers.clear();
          if (userLocation != null) {
            _addressControllers.add(TextEditingController(text: "Ваше местоположение"));
          }
          for (var place in routePlaces) {
            _addressControllers.add(TextEditingController(text: place.address));
          }
          _routeAddresses = _addressControllers.map((controller) => controller.text).toList();
        });

        _saveAddresses();
        _saveTransportMode(); // Сохраняем выбранный режим транспорта
      } catch (e) {
        print("Error showing route on map: $e");
      }
    } else {
      if (kDebugMode) {
        print('Недостаточно точек для построения маршрута');
      }
    }
  }

  Future<void> _loadPlaces() async {
    _places = await getPlaces();
    _getCurrentUserLocation();
    _createPlacemarks();
    _createEventPlacemarks();
    setState(() {});
    _mapController.moveCamera(
      CameraUpdate.newCameraPosition(
        const CameraPosition(
          target: Point(
            latitude: 56.010569,
            longitude: 92.852572,
          ),
          zoom: 9.0,
        ),
      ),
    );
  }

  void _createPlacemarks() {
    _originalPlacemarks.clear(); // Очищаем список перед заполнением
    for (var place in _places) {
      var placemark = PlacemarkMapObject(
        mapId: MapObjectId(place.docId ?? ''),
        point: Point(latitude: place.latitude, longitude: place.longitude),
        onTap: (_, __) => _showPlaceInfo(place),
        icon: PlacemarkIcon.single(PlacemarkIconStyle(
          image: BitmapDescriptor.fromAssetImage('assets/images/metka.png'),
        )),
      );
      _placemarks.add(placemark);
      _originalPlacemarks.add(placemark); // Сохраняем оригинальную метку
    }
  }

  void _createEventPlacemarks() {
    for (var eventPlace in _eventPlaces) {
      var eventPlacemark = PlacemarkMapObject(
        mapId: MapObjectId('event_${eventPlace.docId ?? ''}'),
        point: Point(latitude: eventPlace.latitude, longitude: eventPlace.longitude),
        icon: PlacemarkIcon.single(PlacemarkIconStyle(
          image: BitmapDescriptor.fromAssetImage('assets/images/event_metka.png'),
        )),
      );
      _eventPlacemarks.add(eventPlacemark);
    }
  }

  void _showRouteMenu() {
    _loadAddresses().then((_) {
      // Если _addressControllers уже заполнен из _showRouteOnMap, используем его
      if (_addressControllers.isEmpty) {
        // Если _addressControllers пуст, заполняем его сохраненными адресами
        for (var address in _routeAddresses) {
          _addressControllers.add(TextEditingController(text: address));
        }
      }
      showModalBottomSheet(
        context: context,
        isScrollControlled: true,
        builder: (BuildContext context) {
          return StatefulBuilder(
            builder: (BuildContext context, StateSetter setModalState) {
              return SizedBox(
                height: MediaQuery.of(context).size.height * 0.9,
                child: Column(
                  children: [
                    AppBar(
                      title: const Text('Составить маршрут'),
                      leading: IconButton(
                        icon: const Icon(Icons.close),
                        onPressed: () => Navigator.of(context).pop(),
                      ),
                    ),
                    Expanded(
                      child: ListView(
                        padding: const EdgeInsets.all(16),
                        children: [
                          ElevatedButton(
                            onPressed: () {
                              setModalState(() {
                                _addAddressField();
                              });
                            },
                            child: const Text('Добавить адрес'),
                          ),
                          ..._addressControllers.asMap().entries.map((entry) {
                            int index = entry.key;
                            var controller = entry.value;
                            return Padding(
                              padding: const EdgeInsets.symmetric(vertical: 8.0),
                              child: Row(
                                children: [
                                  Expanded(
                                    child: TextField(
                                      controller: controller,
                                      decoration: const InputDecoration(
                                        hintText: 'Введите адрес',
                                      ),
                                      onChanged: (value) {
                                        _routeAddresses[index] = value;
                                      },
                                    ),
                                  ),
                                  IconButton(
                                    icon: const Icon(Icons.delete),
                                    onPressed: () {
                                      setModalState(() {
                                        _removeAddressField(index);
                                      });
                                    },
                                  ),
                                ],
                              ),
                            );
                          }),
                          CheckboxListTile(
                            title: const Text('Возвращение на начальную точку'),
                            value: _returnToStart,
                            onChanged: (value) {
                              setModalState(() {
                                _toggleReturnToStart(value);
                              });
                            },
                          ),
                          CheckboxListTile(
                            title:
                            const Text('Добавление адреса нажатием на карту'),
                            value: _addAddressByTap,
                            onChanged: (value) {
                              setModalState(() {
                                _toggleAddAddressByTap(value);
                              });
                            },
                          ),
                          DropdownButton<String>(
                            value: _selectedTransportMode,
                            items: [
                              'Пешком',
                              'Автомобиль',
                            ].map((String value) {
                              return DropdownMenuItem<String>(
                                value: value,
                                child: Text(value),
                              );
                            }).toList(),
                            onChanged: (value) {
                              setModalState(() {
                                _setTransportMode(value);
                              });
                            },
                          ),
                          ElevatedButton(
                            onPressed: () {
                              _userAddresses = _addressControllers
                                  .map((controller) => controller.text)
                                  .where((text) => text.isNotEmpty)
                                  .toList();

                              if (_userAddresses.isEmpty) {
                                showDialog(
                                  context: context,
                                  builder: (BuildContext context) {
                                    return AlertDialog(
                                      title: const Text('Предупреждение'),
                                      content: const Text('Пожалуйста, введите хотя бы один адрес.'),
                                      actions: <Widget>[
                                        TextButton(
                                          child: const Text('OK'),
                                          onPressed: () {
                                            Navigator.of(context).pop();
                                          },
                                        ),
                                      ],
                                    );
                                  },
                                );
                              } else {
                                _createRoute();
                                Navigator.of(context).pop();
                              }
                            },
                            child: const Text('Составить'),
                          ),
                          ElevatedButton(
                            onPressed: () {
                              bool anyTagSelected = selectedSubcategories.values
                                  .any((subcategories) => subcategories.isNotEmpty);

                              if (!anyTagSelected) {
                                showDialog(
                                  context: context,
                                  builder: (BuildContext context) {
                                    return AlertDialog(
                                      title: const Text('Предупреждение'),
                                      content: const Text('Пожалуйста, выберите хотя бы один тег.'),
                                      actions: <Widget>[
                                        TextButton(
                                          child: const Text('OK'),
                                          onPressed: () {
                                            Navigator.of(context).pop();
                                          },
                                        ),
                                      ],
                                    );
                                  },
                                );
                              } else {
                                _createAutomaticRoute();
                                Navigator.of(context).pop();
                              }
                            },
                            child: const Text('Составить автоматически'),
                          ),
                          ElevatedButton(
                            onPressed: _showCategorySelection,
                            child: const Text('Выбрать теги'),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              );
            },
          );
        },
      ).whenComplete(() {
        _saveAddresses(); // Сохраняем адреса при закрытии меню
      });
    });
  }

  void _addAddressField() {
    setState(() {
      _routeAddresses.add('');
      TextEditingController controller = TextEditingController();
      if (_addAddressByTap && _lastTapPosition != null) {
        _getAddressFromCoordinates(_lastTapPosition!).then((address) {
          controller.text = address;
          _routeAddresses[_routeAddresses.length - 1] = address;
        });
      }
      _addressControllers.add(controller);
    });
  }

  Future<String> _getAddressFromCoordinates(Point point) async {
    try {
      List<Placemark> placemarks = await placemarkFromCoordinates(
        point.latitude,
        point.longitude,
      );
      if (placemarks.isNotEmpty) {
        return '${placemarks.first.street}, ${placemarks.first.name}, ${placemarks.first.subAdministrativeArea}, ${placemarks.first.administrativeArea}, ${placemarks.first.country}';
      }
    } catch (e) {
      if (kDebugMode) {
        print("Error getting address from coordinates: $e");
      }
    }
    return '';
  }

  void _removeAddressField(int index) {
    setState(() {
      _routeAddresses.removeAt(index);
      _addressControllers.removeAt(index);
    });
  }

  void _toggleReturnToStart(bool? value) {
    setState(() {
      _returnToStart = value ?? false;
    });
    if (_returnToStart) {
      _getCurrentUserLocation().then((_) {
        int lastIndex = _addressControllers.length;
        _addressControllers.insert(
          lastIndex,
          TextEditingController(text: ''),
        );
      });
    }
  }

  void _toggleAddAddressByTap(bool? value) {
    setState(() {
      _addAddressByTap = value ?? false;
    });
  }

  void _setTransportMode(String? mode) {
    setState(() {
      _selectedTransportMode = mode ?? 'Пешком';
      if (_isRouteActive) {
        _rebuildRouteFromCurrentIndex(0, _routePlacemarks);
      }
    });
  }

  Future<void> _createRoute() async {
    _routePlacemarks.clear();
    _routePolylines.clear();
    _routeAddresses.clear();
    _totalDistance = 0.0;

    List<RequestPoint> routePoints = [];
    List<PlacemarkMapObject> tempPlacemarks = [];

    // Добавляем текущее местоположение
    try {
      Position position = await Geolocator.getCurrentPosition();
      _startPoint =
          Point(latitude: position.latitude, longitude: position.longitude);
      routePoints.add(RequestPoint(
          point: _startPoint!, requestPointType: RequestPointType.wayPoint));
      _routeAddresses.add("Текущее местоположение");

      tempPlacemarks.add(
        PlacemarkMapObject(
          mapId: const MapObjectId('current_location'),
          point: _startPoint!,
          icon: PlacemarkIcon.single(
            PlacemarkIconStyle(
              image: BitmapDescriptor.fromAssetImage(
                  'assets/images/green_metka.png'),
            ),
          ),
        ),
      );
    } catch (e) {
      if (kDebugMode) {
        print("Error getting current location: $e");
      }
      return;
    }

    // Добавляем введенные адреса
    for (int i = 0; i < _userAddresses.length; i++) {
      try {
        String address = _userAddresses[i];
        if (!address.toLowerCase().contains('красноярск')) {
          address = 'Красноярск, $address';
        }
        List<Location> locations = await locationFromAddress(address);
        if (locations.isNotEmpty) {
          Point point = Point(
              latitude: locations.first.latitude,
              longitude: locations.first.longitude);
          routePoints.add(RequestPoint(
              point: point, requestPointType: RequestPointType.viaPoint));
          _routeAddresses.add(address);

          tempPlacemarks.add(
            PlacemarkMapObject(
              mapId: MapObjectId('address_$i'),
              point: point,
              icon: PlacemarkIcon.single(
                PlacemarkIconStyle(
                  image: BitmapDescriptor.fromAssetImage(
                      'assets/images/green_metka.png'),
                ),
              ),
            ),
          );
        } else {
          print("Could not geocode address: $address");
        }
      } catch (e) {
        if (kDebugMode) {
          print("Error geocoding address: $e");
        }
      }
    }

    // Если возвращение на начальную точку включено, добавляем ее в конец маршрута
    if (_returnToStart && _startPoint != null) {
      routePoints.add(RequestPoint(
          point: _startPoint!, requestPointType: RequestPointType.wayPoint));
      _routeAddresses.add("Возврат к начальной точке");

      tempPlacemarks.add(
        PlacemarkMapObject(
          mapId: const MapObjectId('start_location'),
          point: _startPoint!,
          icon: PlacemarkIcon.single(
            PlacemarkIconStyle(
              image: BitmapDescriptor.fromAssetImage(
                  'assets/images/green_metka.png'),
            ),
          ),
        ),
      );
    }

    // Убедитесь, что первый и последний RequestPoint имеют тип wayPoint
    if (routePoints.isNotEmpty) {
      if (routePoints.first.requestPointType != RequestPointType.wayPoint) {
        routePoints[0] = RequestPoint(
          point: routePoints.first.point,
          requestPointType: RequestPointType.wayPoint,
        );
      }
      if (routePoints.last.requestPointType != RequestPointType.wayPoint) {
        routePoints[routePoints.length - 1] = RequestPoint(
          point: routePoints.last.point,
          requestPointType: RequestPointType.wayPoint,
        );
      }
    }

    // Запрашиваем маршрут у Яндекс.Карт
    try {
      if (_selectedTransportMode == 'Пешком') {
        var resultWithSession = await YandexPedestrian.requestRoutes(
          points: routePoints,
          avoidSteep: true,
          timeOptions: TimeOptions(departureTime: DateTime.now()),
        );

        PedestrianSessionResult result = await resultWithSession.$2;

        if (result.routes != null && result.routes!.isNotEmpty) {
          PedestrianRoute route = result.routes!.first;

          PolylineMapObject polyline = PolylineMapObject(
            mapId: const MapObjectId('route_polyline'),
            polyline: route.geometry,
            strokeColor: Colors.orange,
            strokeWidth: 3.0,
          );

          _routePolylines.add(polyline);
          await _saveRouteGeometry(route.geometry);
        } else {
          print("No pedestrian routes returned from Yandex");
          return;
        }
      } else {
        var resultWithSession = await YandexDriving.requestRoutes(
          points: routePoints,
          drivingOptions: const DrivingOptions(
            initialAzimuth: 0,
            routesCount: 1,
            avoidTolls: true,
          ),
        );

        DrivingSessionResult result = await resultWithSession.$2;

        if (result.routes != null && result.routes!.isNotEmpty) {
          DrivingRoute route = result.routes!.first;

          PolylineMapObject polyline = PolylineMapObject(
            mapId: const MapObjectId('route_polyline'),
            polyline: route.geometry,
            strokeColor: Colors.blue,
            strokeWidth: 3.0,
          );

          _routePolylines.add(polyline);
          await _saveRouteGeometry(route.geometry);
        } else {
          print("No driving routes returned from Yandex");
          return;
        }
      }

      // Обновляем состояние
      setState(() {
        _routePlacemarks.addAll(tempPlacemarks);
        _isRouteActive = true;
        _placemarks.clear(); // Очищаем все обычные метки
      });

      // Перемещаем камеру, чтобы показать весь маршрут
      _mapController.moveCamera(
        CameraUpdate.newGeometry(
          Geometry.fromBoundingBox(
            BoundingBox(
              northEast: _routePolylines.first.polyline.points.reduce((a, b) => Point(
                latitude: max(a.latitude, b.latitude),
                longitude: max(a.longitude, b.longitude),
              )),
              southWest: _routePolylines.first.polyline.points.reduce((a, b) => Point(
                latitude: min(a.latitude, b.latitude),
                longitude: min(a.longitude, b.longitude),
              )),
            ),
          ),
        ),
      );

      _showRouteConfirmationMenu();
      _saveAddresses();
      _saveTransportMode(); // Сохраняем выбранный режим транспорта
    } catch (e) {
      print("Error creating route: $e");
    }
  }

  Future<void> _saveRouteGeometry(Polyline polyline) async {
    final prefs = await SharedPreferences.getInstance();
    List<Map<String, double>> polylineData = polyline.points
        .map((point) => {
      'latitude': point.latitude,
      'longitude': point.longitude,
    })
        .toList();
    await prefs.setString('route_geometry', jsonEncode(polylineData));
  }

  // Добавьте эту функцию для сохранения режима транспорта
  Future<void> _saveTransportMode() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('selected_transport_mode', _selectedTransportMode);
  }

// Добавьте эту функцию для загрузки режима транспорта
  Future<void> _loadTransportMode() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _selectedTransportMode = prefs.getString('selected_transport_mode') ?? 'Пешком';
    });
  }

  Future<void> _createAutomaticRoute() async {
    _placemarks.clear();
    _routeAddresses.clear();
    _routePlacemarks.clear();
    _routePolylines.clear();

    Point? userLocation = await _getCurrentUserLocation();

    if (userLocation == null) {
      if (kDebugMode) {
        print("Не получилось получить текущее местоположение");
      }
      return;
    }

    _routeAddresses.add("Текущее местоположение");
    List<RequestPoint> routePoints = [
      RequestPoint(point: userLocation, requestPointType: RequestPointType.wayPoint)
    ];

    for (var place in _places) {
      List<String> placeSubcategories = place.subcategory.split(', ');

      bool shouldAdd = false;
      for (var subcategories in selectedSubcategories.values) {
        for (var subcategory in subcategories) {
          if (placeSubcategories.any((placeSub) =>
          placeSub.trim().toLowerCase() == subcategory.toLowerCase())) {
            shouldAdd = true;
            break;
          }
        }
        if (shouldAdd) break;
      }

      if (shouldAdd) {
        routePoints.add(RequestPoint(
            point: Point(latitude: place.latitude, longitude: place.longitude),
            requestPointType: RequestPointType.viaPoint
        ));
        _routeAddresses.add(place.address);
      }
    }

    if (_returnToStart) {
      routePoints.add(RequestPoint(point: userLocation, requestPointType: RequestPointType.wayPoint));
      _routeAddresses.add("Возврат к начальной точке");
    }

    if (routePoints.length > 1) {
      // Убедитесь, что первый и последний RequestPoint имеют тип wayPoint
      routePoints.first = RequestPoint(
        point: routePoints.first.point,
        requestPointType: RequestPointType.wayPoint,
      );
      routePoints.last = RequestPoint(
        point: routePoints.last.point,
        requestPointType: RequestPointType.wayPoint,
      );

      try {
        if (_selectedTransportMode == 'Пешком') {
          var resultWithSession = await YandexPedestrian.requestRoutes(
            points: routePoints,
            avoidSteep: true,
            timeOptions: TimeOptions(departureTime: DateTime.now()),
          );

          PedestrianSessionResult result = await resultWithSession.$2;

          if (result.routes != null && result.routes!.isNotEmpty) {
            PedestrianRoute route = result.routes!.first;

            PolylineMapObject routePolyline = PolylineMapObject(
              mapId: const MapObjectId("route_polyline"),
              polyline: route.geometry,
              strokeColor: Colors.orange,
              strokeWidth: 5.0,
            );

            setState(() {
              _routePolylines.clear();
              _routePolylines.add(routePolyline);
            });

            await _saveRouteGeometry(route.geometry);
          } else {
            print("No pedestrian routes returned from Yandex");
            return;
          }
        } else {
          var resultWithSession = await YandexDriving.requestRoutes(
            points: routePoints,
            drivingOptions: const DrivingOptions(
              initialAzimuth: 0,
              routesCount: 1,
              avoidTolls: true,
            ),
          );

          DrivingSessionResult result = await resultWithSession.$2;

          if (result.routes != null && result.routes!.isNotEmpty) {
            DrivingRoute route = result.routes!.first;

            PolylineMapObject routePolyline = PolylineMapObject(
              mapId: const MapObjectId("route_polyline"),
              polyline: route.geometry,
              strokeColor: Colors.blue,
              strokeWidth: 5.0,
            );

            setState(() {
              _routePolylines.clear();
              _routePolylines.add(routePolyline);
            });

            await _saveRouteGeometry(route.geometry);
          } else {
            print("No driving routes returned from Yandex");
            return;
          }
        }

        _routePlacemarks = routePoints.map((point) {
          return PlacemarkMapObject(
            mapId: MapObjectId('placemark_${point.point.latitude}_${point.point.longitude}'),
            point: point.point,
            icon: PlacemarkIcon.single(PlacemarkIconStyle(
              image: BitmapDescriptor.fromAssetImage('assets/images/green_metka.png'),
            )),
          );
        }).toList();

        setState(() {
          _placemarks.clear();
          _placemarks.addAll(_routePlacemarks);
        });

        _mapController.moveCamera(
          CameraUpdate.newGeometry(
            Geometry.fromBoundingBox(
              BoundingBox(
                northEast: _routePolylines.first.polyline.points.reduce((a, b) => Point(
                  latitude: max(a.latitude, b.latitude),
                  longitude: max(a.longitude, b.longitude),
                )),
                southWest: _routePolylines.first.polyline.points.reduce((a, b) => Point(
                  latitude: min(a.latitude, b.latitude),
                  longitude: min(a.longitude, b.longitude),
                )),
              ),
            ),
          ),
        );

        // Сохраняем маршрут
        await saveRoute(0);

        // Показываем диалог подтверждения маршрута
        _showRouteConfirmationMenu();
        _saveAddresses();
        _saveTransportMode(); // Сохраняем выбранный режим транспорта
      } catch (e) {
        print("Error creating automatic route: $e");
      }
    } else {
      if (kDebugMode) {
        print("Нет точек для построения маршрута");
      }
    }
  }

  Map<String, List<String>> selectedSubcategories = {};

  void _showCategorySelection() {
    final List<String> categories = ['Спорт', 'История', 'Другое'];
    final Map<String, List<String>> subcategories = {
      'Спорт': ['Вело прогулка', 'Спорт комплекс'],
      'История': [
        'История краеведения',
        'История живописи',
        'История промышленности',
        'История спорта',
        'Памятники'
      ],
      'Другое': [
        'Арт-объекты',
        'Пешая прогулка',
        'Религия',
        'Смотровые площадки',
        'Здания',
        'Открытые места',
        'Представления',
        'Музыка'
      ],
    };

    showDialog(
      context: context,
      builder: (BuildContext context) {
        return StatefulBuilder(
          builder: (BuildContext context, StateSetter setState) {
            return AlertDialog(
              title: const Text('Выбор точек по категории'),
              content: SingleChildScrollView(
                child: ListBody(
                  children: categories.map((category) {
                    return ExpansionTile(
                      title: Text(category),
                      children: subcategories[category]!.map((subcategory) {
                        return CheckboxListTile(
                          title: Text(subcategory),
                          value: selectedSubcategories[category]
                              ?.contains(subcategory) ??
                              false,
                          onChanged: (bool? value) {
                            setState(() {
                              if (value == true) {
                                selectedSubcategories
                                    .putIfAbsent(category, () => [])
                                    .add(subcategory);
                              } else {
                                selectedSubcategories[category]
                                    ?.remove(subcategory);
                                if (selectedSubcategories[category]?.isEmpty ??
                                    false) {
                                  selectedSubcategories.remove(category);
                                }
                              }
                            });
                          },
                        );
                      }).toList(),
                    );
                  }).toList(),
                ),
              ),
              actions: <Widget>[
                TextButton(
                  child: const Text('Отмена'),
                  onPressed: () {
                    Navigator.of(context).pop();
                  },
                ),
                TextButton(
                  child: const Text('Показать точки'),
                  onPressed: () {
                    Navigator.of(context).pop();
                    _showSelectedPoints(selectedSubcategories);
                  },
                ),
              ],
            );
          },
        );
      },
    );
  }

  void _showSelectedPoints(Map<String, List<String>> selectedSubcategories) {
    List<PlacemarkMapObject> placemarks = [];

    // Если нет выбранных подкатегорий, показываем все метки
    if (selectedSubcategories.isEmpty) {
      placemarks = _originalPlacemarks;
    } else {
      for (var place in _places) {
        List<String> placeSubcategories = place.subcategory.split(', ');

        bool shouldAdd = false;
        for (var subcategories in selectedSubcategories.values) {
          for (var subcategory in subcategories) {
            if (placeSubcategories.any((placeSub) =>
            placeSub.trim().toLowerCase() == subcategory.toLowerCase())) {
              shouldAdd = true;
              break;
            }
          }
          if (shouldAdd) break;
        }

        if (shouldAdd) {
          placemarks.add(
            PlacemarkMapObject(
              mapId: MapObjectId(place.docId ?? ''),
              point:
              Point(latitude: place.latitude, longitude: place.longitude),
              onTap: (_, __) => _showPlaceInfo(place),
              icon: PlacemarkIcon.single(PlacemarkIconStyle(
                image:
                BitmapDescriptor.fromAssetImage('assets/images/metka.png'),
              )),
            ),
          );
        }
      }
    }

    setState(() {
      _placemarks.clear();
      _placemarks.addAll(placemarks);
    });

    if (placemarks.isNotEmpty) {
      _mapController.moveCamera(
        CameraUpdate.newGeometry(
          Geometry.fromBoundingBox(
            BoundingBox(
              northEast: placemarks.map((p) => p.point).reduce((a, b) => Point(
                latitude: max(a.latitude, b.latitude),
                longitude: max(a.longitude, b.longitude),
              )),
              southWest: placemarks.map((p) => p.point).reduce((a, b) => Point(
                latitude: min(a.latitude, b.latitude),
                longitude: min(a.longitude, b.longitude),
              )),
            ),
          ),
        ),
      );
    }
  }

  Future<String> _getAddressFromPoint(Point point) async {
    final resultWithSession = await YandexSearch.searchByPoint(
      point: point,
      searchOptions: const SearchOptions(
        searchType: SearchType.geo,
        resultPageSize: 1,
      ),
    );

    final results = await resultWithSession.$2;
    if (results.items != null && results.items!.isNotEmpty) {
      return results.items!.first.name;
    }
    return 'Неизвестный адрес';
  }

  void _showPlaceInfo(MapModel place) async {
    // Получаем список отзывов из Firestore
    QuerySnapshot reviewsSnapshot = await FirebaseFirestore.instance
        .collection('PlaceReviews')
        .where('placeId', isEqualTo: place.docId)
        .get();

    List<ReviewModel> reviews = await Future.wait(reviewsSnapshot.docs.map((doc) async {
      ReviewModel review = ReviewModel.fromDocument(doc);
      DocumentSnapshot userDoc = await FirebaseFirestore.instance
          .collection('User')
          .doc(review.userId)
          .get();
      review.userPhotoURL = userDoc['photoURL'];
      review.userLogin = userDoc['login'];
      return review;
    }));

    double averageRating = reviews.isNotEmpty
        ? reviews.map((r) => r.mark).reduce((a, b) => a + b) / reviews.length
        : 0.0;

    showModalBottomSheet(
      context: context,
      builder: (context) => Container(
        padding: const EdgeInsets.all(16),
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(place.name,
                  style:
                  const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
              const SizedBox(height: 8),
              Text(place.address),
              const SizedBox(height: 8),
              Text(place.desc),
              const SizedBox(height: 8),
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text("Категории: ",
                      style: TextStyle(fontWeight: FontWeight.bold)),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(place.category),
                      ],
                    ),
                  ),
                ],
              ),
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text("Подкатегории: ",
                      style: TextStyle(fontWeight: FontWeight.bold)),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(place.subcategory),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              const Text("Отзывы о точке",
                  style: TextStyle(fontWeight: FontWeight.bold)),
              const SizedBox(height: 8),
              const Text("Средняя оценка:"),
              Row(
                children: [
                  Text(averageRating.toStringAsFixed(1),
                      style: (const TextStyle(fontSize: 48))),
                  const SizedBox(width: 4),
                  _buildRatingStars(averageRating),
                ],
              ),
              const SizedBox(height: 8),
              ...reviews.map((review) => _buildReviewBlock(review)),
              const SizedBox(height: 16),
              ElevatedButton(
                onPressed: () async {
                  User? user = FirebaseAuth.instance.currentUser;
                  if (user == null) {
                    _showLoginAlert(context);
                  } else {
                    _showReviewDialog(context, place.docId!, user.uid);
                  }
                },
                child: const Text("Написать отзыв"),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildRatingStars(double rating) {
    return RatingBarIndicator(
      rating: rating,
      direction: Axis.horizontal,
      itemCount: 5,
      itemPadding: const EdgeInsets.symmetric(horizontal: 4.0),
      itemBuilder: (context, _) => const Icon(
        Icons.star,
        color: Colors.orange,
      ),
    );
  }

  Widget _buildReviewBlock(ReviewModel review) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8.0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          GestureDetector(
            onTap: () async {
              CollectionReference userRef = FirebaseFirestore.instance.collection('User');
              User? currentUser = FirebaseAuth.instance.currentUser;
              DocumentSnapshot snapshotUser = await userRef.doc(currentUser?.uid).get();

              Map<String, dynamic> userData = snapshotUser.data() as Map<String, dynamic>? ?? {};

              if (review.userId == currentUser?.uid) {
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
                    builder: (context) => UserProfileView(userId: review.userId),
                  ),
                );
              }
            },
            child: CircleAvatar(
              backgroundImage: review.userPhotoURL != null
                  ? NetworkImage(review.userPhotoURL!)
                  : null,
              child: review.userPhotoURL == null ? Text(review.userLogin![0]) : null,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                GestureDetector(
                  onTap: () async {
                    CollectionReference userRef = FirebaseFirestore.instance.collection('User');
                    User? currentUser = FirebaseAuth.instance.currentUser;
                    DocumentSnapshot snapshotUser = await userRef.doc(currentUser?.uid).get();

                    Map<String, dynamic> userData = snapshotUser.data() as Map<String, dynamic>? ?? {};

                    if (review.userId == currentUser?.uid) {
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
                          builder: (context) => UserProfileView(userId: review.userId),
                        ),
                      );
                    }
                  },
                  child: Text(
                    review.userLogin ?? 'Неизвестный пользователь',
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                ),
                const SizedBox(height: 2),
                _buildSmallRatingStars(review.mark.toDouble()),
                const SizedBox(height: 4),
                Text(review.reviewComment),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSmallRatingStars(double rating) {
    return RatingBar.builder(
      initialRating: rating,
      minRating: 1,
      direction: Axis.horizontal,
      allowHalfRating: true,
      itemCount: 5,
      itemSize: 14, // Уменьшенный размер звезд
      itemPadding: const EdgeInsets.symmetric(horizontal: 1.0),
      itemBuilder: (context, _) => const Icon(
        Icons.star,
        color: Colors.orange,
      ),
      onRatingUpdate: (_) {}, // Пустая функция, так как это только для отображения
    );
  }

  void _showReviewDialog(BuildContext context, String placeId, String userId) {
    final TextEditingController reviewController = TextEditingController();
    double rating = 0.0;

    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text("Отзыв"),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text("Оценка"),
              const SizedBox(height: 8),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  RatingBar.builder(
                    initialRating: rating,
                    minRating: 1,
                    direction: Axis.horizontal,
                    allowHalfRating: true,
                    itemCount: 5,
                    itemPadding: const EdgeInsets.symmetric(horizontal: 4.0),
                    itemBuilder: (context, _) => const Icon(
                      Icons.star,
                      color: Colors.orange,
                    ),
                    onRatingUpdate: (newRating) {
                      rating = newRating; // Обновляем rating
                    },
                  ),
                ],
              ),
              const SizedBox(height: 16),
              TextField(
                controller: reviewController,
                decoration: const InputDecoration(
                  labelText: 'Ваш отзыв',
                  border: OutlineInputBorder(),
                ),
                maxLines: 3,
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.of(context).pop();
              },
              child: const Text("Отменить"),
            ),
            ElevatedButton(
              onPressed: () async {
                if (rating > 0 && reviewController.text.isNotEmpty) {
                  await FirebaseFirestore.instance
                      .collection('PlaceReviews')
                      .doc('${placeId}_$userId')
                      .set({
                    'placeId': placeId,
                    'userId': userId,
                    'reviewComment': reviewController.text,
                    'mark': rating,
                  });

                  Navigator.of(context).pop();
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Ваш отзыв был добавлен')),
                  );
                } else {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Пожалуйста, оставьте отзыв и выберите оценку')),
                  );
                }
              },
              child: const Text("Отправить"),
            ),
          ],
        );
      },
    );
  }

  void _showRouteConfirmationMenu() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (BuildContext context) {
        return StatefulBuilder(
          builder: (BuildContext context, StateSetter setModalState) {
            return SizedBox(
              height: MediaQuery.of(context).size.height * 0.9,
              child: Column(
                children: [
                  AppBar(
                    title: const Text('Подтверждение маршрута'),
                    leading: IconButton(
                      icon: const Icon(Icons.close),
                      onPressed: () => Navigator.of(context).pop(),
                    ),
                  ),
                  Expanded(
                    child: ListView(
                      padding: const EdgeInsets.all(16),
                      children: [
                        ..._routeAddresses.map((address) => Padding(
                          padding:
                          const EdgeInsets.symmetric(vertical: 8.0),
                          child: TextField(
                            readOnly: true,
                            decoration: InputDecoration(
                              labelText: address,
                              border: const OutlineInputBorder(),
                            ),
                          ),
                        )),
                      ],
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                      children: [
                        ElevatedButton(
                          onPressed: () {
                            Navigator.of(context).pop();
                            _startRoute();
                          },
                          child: const Text('Начать'),
                        ),
                        ElevatedButton(
                          onPressed: () async {
                            // Сбрасываем пройденное расстояние
                            await saveTotalDistance(0.0);

                            // Очищаем маршрут и все связанные данные
                            setState(() {
                              _placemarks.clear();
                              _placemarks.addAll(_originalPlacemarks);
                              clearRoute();
                            });

                            // Очищаем список адресов
                            _routeAddresses.clear();
                            _addressControllers.clear();
                            await _saveAddresses();
                            Navigator.of(context).pop();
                          },
                          child: const Text('Отменить'),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  void _showRouteProgressMenu() {
    loadRoute().then((currentIndex) {
      if (_routePlacemarks.isEmpty) {
        if (kDebugMode) {
          print("No route loaded");
        }
        return;
      }
      showModalBottomSheet(
        context: context,
        isScrollControlled: true,
        builder: (BuildContext context) {
          return StatefulBuilder(
            builder: (BuildContext context, StateSetter setModalState) {
              return SizedBox(
                height: MediaQuery.of(context).size.height * 0.5,
                child: Column(
                  children: [
                    AppBar(
                      title: const Text('Прохождение маршрута'),
                      leading: IconButton(
                        icon: const Icon(Icons.close),
                        onPressed: () => Navigator.of(context).pop(),
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.all(16.0),
                      child: Text(_getDistanceToNextPoint(currentIndex)),
                    ),
                    Padding(
                      padding: const EdgeInsets.all(16.0),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                        children: [
                          ElevatedButton(
                            onPressed: () {
                              Navigator.of(context).pop();
                              _showRouteMenu();
                            },
                            child: const Text('Редактировать маршрут'),
                          ),
                          ElevatedButton(
                            onPressed: () async {
                              Point? userLocation = await _getCurrentUserLocation();
                              if (userLocation == null) {
                                // Обработка ошибки получения местоположения пользователя
                                return;
                              }

                              // Проверяем расстояние до следующей точки (индекс 1)
                              double distanceToNextPoint = calculateDistance(
                                userLocation.latitude,
                                userLocation.longitude,
                                _routePlacemarks[currentIndex + 1].point.latitude,
                                _routePlacemarks[currentIndex + 1].point.longitude,
                              );

                              if (distanceToNextPoint <= 0.1) { // 0.1 км = 100 метров
                                setModalState(() {
                                  currentIndex++;
                                  _updatePassedPoints(currentIndex);
                                });
                                await saveRoute(currentIndex);
                                if (currentIndex >= _routePlacemarks.length - 1) {
                                  _finishRoute();
                                  Navigator.of(context).pop();
                                } else {
                                  await _rebuildRouteFromCurrentIndex(currentIndex, _routePlacemarks);

                                  // Показываем диалог об успешном прохождении точки
                                  showDialog(
                                    context: context,
                                    builder: (BuildContext context) {
                                      return AlertDialog(
                                        title: const Text('Успешно!'),
                                        content: const Text('Вы успешно прошли точку маршрута!'),
                                        actions: <Widget>[
                                          TextButton(
                                            child: const Text('OK'),
                                            onPressed: () {
                                              Navigator.of(context).pop();
                                            },
                                          ),
                                        ],
                                      );
                                    },
                                  );
                                }
                              } else {
                                showDialog(
                                  context: context,
                                  builder: (BuildContext context) {
                                    return AlertDialog(
                                      title: const Text('Предупреждение'),
                                      content: const Text('Вы ещё не дошли до следующей точки! Дойдите до следующей точки, чтобы продолжить маршрут!'),
                                      actions: <Widget>[
                                        TextButton(
                                          child: const Text('OK'),
                                          onPressed: () {
                                            Navigator.of(context).pop();
                                          },
                                        ),
                                      ],
                                    );
                                  },
                                );
                              }
                            },
                            child: const Text('Я дошёл до этой точки'),
                          ),
                          ElevatedButton(
                            onPressed: () {
                              showDialog(
                                context: context,
                                builder: (BuildContext context) {
                                  return AlertDialog(
                                    title: const Text('Подтверждение'),
                                    content: const Text('Вы действительно хотите завершить маршрут досрочно? Непройденный прогресс будет утерян.'),
                                    actions: <Widget>[
                                      TextButton(
                                        onPressed: () async {
                                          // Сбрасываем пройденное расстояние
                                          await saveTotalDistance(0.0);

                                          // Очищаем маршрут и все связанные данные
                                          setState(() {
                                            _placemarks.clear();
                                            _placemarks.addAll(_originalPlacemarks);
                                            clearRoute();
                                          });

                                          // Очищаем список адресов
                                          _routeAddresses.clear();
                                          _addressControllers.clear();
                                          await _saveAddresses(); // Сохраняем пустой список адресов

                                          // Закрываем диалог и возвращаемся назад
                                          Navigator.of(context).pop();
                                          Navigator.of(context).pop();// Закрыть диалог
                                        },
                                        child: const Text('Завершить'),
                                      ),
                                    ],
                                  );
                                },
                              );
                            },
                            child: const Text('Завершить принудительно'),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              );
            },
          );
        },
      );
    });
  }

  String _getDistanceToNextPoint(int currentIndex) {
    if (kDebugMode) {
      print("Current index: $currentIndex");
    }
    if (kDebugMode) {
      print("Number of route placemarks: ${_routePlacemarks.length}");
    }

    if (currentIndex >= _routePlacemarks.length - 1) {
      return 'Маршрут завершен';
    }

    Point currentPoint = _routePlacemarks[currentIndex].point;
    Point nextPoint = _routePlacemarks[currentIndex + 1].point;

    // Получаем текущее местоположение пользователя
    _getCurrentUserLocation().then((userLocation) {
      if (userLocation != null) {
        currentPoint = userLocation;
      }
    });

    double distance = calculateDistance(currentPoint.latitude,
        currentPoint.longitude, nextPoint.latitude, nextPoint.longitude);

    return 'До следующей точки: ${distance.toStringAsFixed(2)} км';
  }

  double calculateDistance(double lat1, double lon1, double lat2, double lon2) {
    const double earthRadius = 6371; // Радиус Земли в километрах

    double dLat = _degreesToRadians(lat2 - lat1);
    double dLon = _degreesToRadians(lon2 - lon1);

    double a = sin(dLat / 2) * sin(dLat / 2) +
        cos(_degreesToRadians(lat1)) *
            cos(_degreesToRadians(lat2)) *
            sin(dLon / 2) *
            sin(dLon / 2);
    double c = 2 * atan2(sqrt(a), sqrt(1 - a));

    return earthRadius * c;
  }

  double _degreesToRadians(double degrees) {
    return degrees * pi / 180;
  }

  void _startRoute() {
    saveRoute(0); // Сохраняем маршрут с начальным индексом 0
    _showRouteProgressMenu();
  }

  Future saveRoute(int currentIndex) async {
    final prefs = await SharedPreferences.getInstance();
    List<Map<String, dynamic>> routeData = _routePlacemarks
        .asMap()
        .entries
        .map((entry) => {
      'index': entry.key,
      'latitude': entry.value.point.latitude,
      'longitude': entry.value.point.longitude,
      'passed': entry.key < currentIndex,
      'type': entry.key == 0 || entry.key == _routePlacemarks.length - 1
          ? 'wayPoint'
          : 'viaPoint',
    })
        .toList();
    await prefs.setString('current_route', jsonEncode(routeData));
    await prefs.setInt('current_route_index', currentIndex);

    // Сохраняем адреса
    await prefs.setStringList('route_addresses', _routeAddresses);
  }

  Future _saveAddresses() async {
    final prefs = await SharedPreferences.getInstance();
    List<String> addressesToSave = _routeAddresses.where((address) {
      return address != 'Текущее местоположение' &&
          address != 'Ваше местоположение' &&
          address != 'Возврат к начальной точке';
    }).toList();
    await prefs.setStringList('route_addresses', addressesToSave);
  }

  Future _loadAddresses() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _routeAddresses = prefs.getStringList('route_addresses') ?? [];
      _addressControllers = _routeAddresses
          .map((address) => TextEditingController(text: address))
          .toList();
    });
  }

  Future<void> saveTotalDistance(double distance) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setDouble('total_route_distance', distance);
  }

  Future<double> loadTotalDistance() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getDouble('total_route_distance') ?? 0.0;
  }

  Future<int> loadRoute() async {
    final prefs = await SharedPreferences.getInstance();
    String? routeJson = prefs.getString('current_route');
    int currentIndex = prefs.getInt('current_route_index') ?? 0;
    _totalDistance = await loadTotalDistance();
    await _loadTransportMode(); // Загружаем сохраненный режим транспорта

    if (routeJson != null) {
      List<dynamic> routeData = jsonDecode(routeJson);
      _isRouteActive = true;
      _routePlacemarks = routeData
          .map((data) => PlacemarkMapObject(
        mapId: MapObjectId('route_${data['latitude']}_${data['longitude']}'),
        point: Point(latitude: data['latitude'], longitude: data['longitude']),
        icon: PlacemarkIcon.single(PlacemarkIconStyle(
          image: BitmapDescriptor.fromAssetImage(
              data['passed'] ? 'assets/images/passed_metka.png' : 'assets/images/green_metka.png'),
        )),
      ))
          .toList();

      _routeAddresses = prefs.getStringList('route_addresses') ?? [];

      currentIndex = min(currentIndex, _routePlacemarks.length - 1);

      // Перестраиваем маршрут с учетом пройденных точек и выбранного режима транспорта
      await _rebuildRouteFromCurrentIndex(currentIndex, _routePlacemarks);

      // Приближаем камеру к точкам маршрута
      await _moveMapToShowRoute();
    }

    if (kDebugMode) {
      print("Loaded route with ${_routePlacemarks.length} points, current index: $currentIndex");
      print("Loaded transport mode: $_selectedTransportMode");
    }
    return currentIndex;
  }

  Future<void> _moveMapToShowRoute() async {
    if (_routePlacemarks.isEmpty) return;

    double minLat = _routePlacemarks.first.point.latitude;
    double maxLat = _routePlacemarks.first.point.latitude;
    double minLon = _routePlacemarks.first.point.longitude;
    double maxLon = _routePlacemarks.first.point.longitude;

    for (var placemark in _routePlacemarks) {
      minLat = min(minLat, placemark.point.latitude);
      maxLat = max(maxLat, placemark.point.latitude);
      minLon = min(minLon, placemark.point.longitude);
      maxLon = max(maxLon, placemark.point.longitude);
    }

    BoundingBox boundingBox = BoundingBox(
      northEast: Point(latitude: maxLat, longitude: maxLon),
      southWest: Point(latitude: minLat, longitude: minLon),
    );

    await _mapController.moveCamera(
      CameraUpdate.newGeometry(Geometry.fromBoundingBox(boundingBox)),
      animation: const MapAnimation(type: MapAnimationType.smooth, duration: 0.5),
    );
  }

  Future<void> _rebuildRouteFromCurrentIndex(int currentIndex, List<PlacemarkMapObject> placemarks) async {
    List<RequestPoint> routePoints = [];

    for (int i = currentIndex; i < placemarks.length; i++) {
      routePoints.add(RequestPoint(
        point: placemarks[i].point,
        requestPointType: i == currentIndex || i == placemarks.length - 1
            ? RequestPointType.wayPoint
            : RequestPointType.viaPoint,
      ));
    }

    try {
      if (_selectedTransportMode == 'Пешком') {
        var resultWithSession = await YandexPedestrian.requestRoutes(
          points: routePoints,
          avoidSteep: true,
          timeOptions: TimeOptions(departureTime: DateTime.now()),
        );

        PedestrianSessionResult result = await resultWithSession.$2;

        if (result.routes != null && result.routes!.isNotEmpty) {
          PedestrianRoute route = result.routes!.first;

          setState(() {
            _routePolylines.clear();
            _routePolylines.add(PolylineMapObject(
              mapId: const MapObjectId('route_polyline'),
              polyline: route.geometry,
              strokeColor: Colors.orange,
              strokeWidth: 3.0,
            ));
          });

          await _saveRouteGeometry(route.geometry);
        } else {
          print("No pedestrian routes returned from Yandex");
        }
      } else {
        var resultWithSession = await YandexDriving.requestRoutes(
          points: routePoints,
          drivingOptions: const DrivingOptions(
            initialAzimuth: 0,
            routesCount: 1,
            avoidTolls: true,
          ),
        );

        DrivingSessionResult result = await resultWithSession.$2;

        if (result.routes != null && result.routes!.isNotEmpty) {
          DrivingRoute route = result.routes!.first;

          setState(() {
            _routePolylines.clear();
            _routePolylines.add(PolylineMapObject(
              mapId: const MapObjectId('route_polyline'),
              polyline: route.geometry,
              strokeColor: Colors.blue,
              strokeWidth: 3.0,
            ));
          });

          await _saveRouteGeometry(route.geometry);
        } else {
          print("No driving routes returned from Yandex");
        }
      }
    } catch (e) {
      print("Error requesting route: $e");
    }
  }

  void _updatePassedPoints(int currentIndex) async {
    for (int i = 0; i < _routePlacemarks.length; i++) {
      _routePlacemarks[i] = _routePlacemarks[i].copyWith(
        icon: PlacemarkIcon.single(PlacemarkIconStyle(
          image: BitmapDescriptor.fromAssetImage(i <= currentIndex
              ? 'assets/images/passed_metka.png'
              : 'assets/images/green_metka.png'),
        )),
      );
    }

    // Вычисляем пройденное расстояние
    if (currentIndex > 0) {
      Point prevPoint = _routePlacemarks[currentIndex - 1].point;
      Point currentPoint = _routePlacemarks[currentIndex].point;
      double segmentDistance = calculateDistance(
        prevPoint.latitude,
        prevPoint.longitude,
        currentPoint.latitude,
        currentPoint.longitude,
      );
      _totalDistance += segmentDistance;
      await saveTotalDistance(_totalDistance);
    }
  }

  Future<void> _finishRoute() async {
    // Проверяем, авторизован ли пользователь
    User? user = FirebaseAuth.instance.currentUser;

    if (user != null) {
      // Пользователь авторизован, выполняем существующую логику
      String userId = FirebaseAuth.instance.currentUser!.uid;
      DocumentReference userRef = FirebaseFirestore.instance.collection('User').doc(userId);

      bool isNewTrip = false;

      // Проверяем, является ли это новым прохождением маршрута из Trip
      if (widget.tripId != null) {
        String combinedId = "${widget.tripId}_$userId";
        DocumentSnapshot userTripDoc = await FirebaseFirestore.instance
            .collection('UserTrips')
            .doc(combinedId)
            .get();

        if (!userTripDoc.exists) {
          isNewTrip = true;
          // Создаем запись о прохождении маршрута
          await FirebaseFirestore.instance.collection('UserTrips').doc(combinedId).set({
            'tripId': widget.tripId,
            'userId': userId,
            'completedAt': FieldValue.serverTimestamp(),
          });
        }
      }

      // Загружаем общее пройденное расстояние
      _totalDistance = await loadTotalDistance();

      await FirebaseFirestore.instance.runTransaction((transaction) async {
        DocumentSnapshot userSnapshot = await transaction.get(userRef);
        double currentKilo = userSnapshot.get('kilo') ?? 0.0;
        double newKilo = currentKilo + _totalDistance;

        Map<String, dynamic> updateData = {'kilo': newKilo};

        // Увеличиваем routes только если это новое прохождение маршрута из Trip
        if (isNewTrip) {
          int currentRoutes = userSnapshot.get('routes') ?? 0;
          updateData['routes'] = currentRoutes + 1;
        }

        transaction.update(userRef, updateData);

        // Проверяем достижение
        if (newKilo >= 10) {
          await _checkAndAddAchievement(userId, "Шаг за шагом");
        }
      });

      // Показываем сообщение о завершении маршрута
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Вы успешно завершили маршрут! Пройдено: ${_totalDistance.toStringAsFixed(2)} км')),
      );
    } else {
      // Пользователь не авторизован, показываем специальное сообщение
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Вы успешно завершили маршрут! Чтобы сохранить прогресс в статистику, необходимо Авторизоваться'),
          duration: Duration(seconds: 5),
        ),
      );
    }

    // Очищаем маршрут и сбрасываем общее расстояние (это выполняется для всех пользователей)
    clearRoute();
    setState(() {
      _totalDistance = 0.0;
    });
    await saveTotalDistance(0.0);

    if (kDebugMode) {
      print("Route cleared and distance reset");
    }
  }

  Future<void> clearRoute() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('current_route');
    await prefs.remove('current_route_index');
    setState(() {
      _routePlacemarks.clear();
      _routePolylines.clear();
      _isRouteActive = false;
      _placemarks = List.from(_originalPlacemarks);
      _totalDistance = 0.0;
      _routeAddresses.clear();
      _addressControllers.clear();
    });

    // Сбрасываем пройденное расстояние в SharedPreferences
    await saveTotalDistance(0.0);
    await _saveAddresses(); // Добавьте эту строку

    if (kDebugMode) {
      print("Route cleared and distance reset");
    }
  }

  Future<void> _checkAndAddAchievement(String userId, String achievementName) async {
    // Получаем ID достижения
    QuerySnapshot achievementQuery = await FirebaseFirestore.instance
        .collection('Achievements')
        .where('name', isEqualTo: achievementName)
        .get();

    if (achievementQuery.docs.isNotEmpty) {
      String achievementId = achievementQuery.docs.first.id;
      String combinedId = "${achievementId}_$userId";

      // Проверяем, есть ли уже такое достижение у пользователя
      DocumentSnapshot existingAchievement = await FirebaseFirestore.instance
          .collection('UserAchievements')
          .doc(combinedId)
          .get();

      if (!existingAchievement.exists) {
        // Добавляем достижение пользователю
        await FirebaseFirestore.instance.collection('UserAchievements').doc(combinedId).set({
          'achievementId': achievementId,
          'userId': userId,
          'gotAt': FieldValue.serverTimestamp(),
        });

        // Показываем сообщение о получении достижения
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Поздравляем! Вы получили достижение "$achievementName"')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Карты'),
      ),
      body: Stack(
        children: [
          YandexMap(
            onMapCreated: (controller) {
              _mapController = controller;
              _loadPlaces();
              if (widget.routePlaces != null) {
                _showRouteOnMap(widget.routePlaces!);
              }
            },
            onMapTap: (point) async {
              if (_addAddressByTap) {
                final address = await _getAddressFromPoint(point);
                setState(() {
                  _lastTapPosition = point;
                  _addAddressField();
                  final lastIndex = _addressControllers.length - 1;
                  _addressControllers[lastIndex].text = address;
                  _routeAddresses[lastIndex] = address;
                });
                _saveAddresses();
              }
            },
            mapObjects:  [
              if (!_isRouteActive) ..._placemarks,
              ..._eventPlacemarks,
              ..._routePlacemarks,
              ..._routePolylines,
            ],
          ),
          if (_isRouteMenuOpen)
            Positioned(
              left: 0,
              top: 0,
              bottom: 0,
              child: Container(
                width: 250,
                color: Colors.white,
                child: Column(
                  children: [
                    Align(
                      alignment: Alignment.topRight,
                      child: IconButton(
                        icon: const Icon(Icons.close),
                        onPressed: () => Navigator.of(context).pop(),
                      ),
                    ),
                    ElevatedButton(
                      onPressed: _addAddressField,
                      child: const Text('Добавить адрес'),
                    ),
                    Expanded(
                      child: ListView.builder(
                        itemCount: _addressControllers.length,
                        itemBuilder: (context, index) {
                          return Padding(
                            padding: const EdgeInsets.all(8.0),
                            child: Row(
                              children: [
                                Expanded(
                                  child: TextField(
                                    controller: _addressControllers[index],
                                    decoration: const InputDecoration(
                                      hintText: 'Введите адрес',
                                    ),
                                  ),
                                ),
                                IconButton(
                                  icon: const Icon(Icons.delete),
                                  onPressed: () => _removeAddressField(index),
                                ),
                              ],
                            ),
                          );
                        },
                      ),
                    ),
                    CheckboxListTile(
                      title: const Text('Возвращение на начальную точку'),
                      value: _returnToStart,
                      onChanged: _toggleReturnToStart,
                    ),
                    CheckboxListTile(
                      title: const Text('Добавление адреса нажатием на карту'),
                      value: _addAddressByTap,
                      onChanged: _toggleAddAddressByTap,
                    ),
                    DropdownButton<String>(
                      value: _selectedTransportMode,
                      items: ['Пешком', 'Автомобиль']
                          .map((String value) {
                        return DropdownMenuItem<String>(
                          value: value,
                          child: Text(value),
                        );
                      }).toList(),
                      onChanged: _setTransportMode,
                    ),
                    ElevatedButton(
                      onPressed: () {
                        _userAddresses = _addressControllers
                            .map((controller) => controller.text)
                            .where((text) => text.isNotEmpty)
                            .toList();
                        Navigator.of(context).pop();
                        _createRoute();
                      },
                      child: const Text('Составить'),
                    ),
                    ElevatedButton(
                      onPressed: () {
                        Navigator.of(context).pop();
                        _createAutomaticRoute();
                      },
                      child: const Text('Составить автоматически'),
                    ),
                    ElevatedButton(
                      onPressed: _showCategorySelection,
                      child: const Text('Выбрать теги'),
                    ),
                  ],
                ),
              ),
            ),
          Positioned(
            left: 0,
            right: 0,
            bottom: 16,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                ElevatedButton(
                  onPressed: _showRouteMenu,
                  child: const Text('Составить маршрут'),
                ),
                ElevatedButton(
                  onPressed: () {
                    _showMenu();
                  },
                  child: const Text('Меню'),
                ),
              ],
            ),
          ),
        ],
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

  void _showMenu() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (BuildContext context) {
        return StatefulBuilder(
          builder: (BuildContext context, StateSetter setModalState) {
            return SizedBox(
              height: MediaQuery.of(context).size.height * 0.5,
              child: Column(
                children: [
                  AppBar(
                    title: const Text('Меню'),
                    leading: IconButton(
                      icon: const Icon(Icons.close),
                      onPressed: () => Navigator.of(context).pop(),
                    ),
                  ),
                  Expanded(
                    child: ListView(
                      padding: const EdgeInsets.all(16),
                      children: [
                        ElevatedButton(
                          onPressed: () {
                            // Логика для кнопки "Руководство пользователя"
                            Navigator.of(context).pop();
                            _showUserGuide();
                          },
                          child: const Text('Руководство пользователя'),
                        ),
                        ElevatedButton(
                          onPressed: () {
                            // Логика для кнопки "Достижения"
                            Navigator.of(context).pop();
                            _showAchievements();
                          },
                          child: const Text('Достижения'),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  // Логика для вывода руководства пользователя
  void _showUserGuide() {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'Руководство пользователя',
                style: TextStyle(fontSize: 16),
              ),
              IconButton(
                icon: const Icon(Icons.close),
                onPressed: () => Navigator.of(context).pop(),
              ),
            ],
          ),
          content: const SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Общая информация',
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
                SizedBox(height: 8),
                Text(
                  'Данная карта отображает интересные точки в городе. '
                      'Чтобы посмотреть информацию о точке, необходимо нажать на метку, '
                      'после чего откроется окно с подробной информацией о точке.',
                ),
                SizedBox(height: 16),
                Text(
                  'Сценарий использования маршрутизации',
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
                SizedBox(height: 8),
                Text(
                  'Для составления маршрута необходимо нажать на кнопку "Составить маршрут". '
                      'После нажатия на кнопку, откроется боковое меню для составления маршрута.\n\n'
                      'Маршруты ВСЕГДА составляются от местоположения пользователя.\n\n'
                      'Маршрут можно составить вручную пользователем или автоматически от местоположения пользователя.\n\n'
                      'Для автоматического построения маршрута необходимо выбрать категорию точек из меню "Выбрать теги".\n\n'
                      'Для ручного составления маршрута необходимо либо добавить новые поля нажатием на кнопку "Добавить адрес" '
                      'и вписать в поля необходимые адреса, либо добавлять поля с уже заполнённым адресом нажатием на карту при '
                      'включённой опции "Добавление адреса нажатием на карту".',
                ),
                SizedBox(height: 16),
                Text(
                  'Обратите внимание!',
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
                SizedBox(height: 8),
                Text(
                  'При включённой опции "Добавление адреса нажатием на карту" можно добавить точки интереса в маршрут, '
                      'однако информация о точке станет недоступной при включённой опции. Чтобы снова получать информацию о точке '
                      'нажатием на неё, необходимо отключить данную опцию!',
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Понятно'),
            ),
          ],
        );
      },
    );
  }

  void _showAchievements() async {
    User? user = FirebaseAuth.instance.currentUser;

    if (user == null) {
      _showLoginAlert(context);
      return;
    }

    QuerySnapshot achievementsSnapshot =
    await FirebaseFirestore.instance.collection('Achievements').get();
    List<Achievement> achievements = achievementsSnapshot.docs
        .map((doc) => Achievement.fromDocument(doc))
        .toList();

    QuerySnapshot userAchievementsSnapshot = await FirebaseFirestore.instance
        .collection('UserAchievements')
        .where('userId', isEqualTo: user.uid)
        .get();

    Map<String, Timestamp> obtainedAchievementTimes = {};
    for (var doc in userAchievementsSnapshot.docs) {
      obtainedAchievementTimes[doc['achievementId'] as String] =
      doc['gotAt'] as Timestamp;
    }

    List<String> obtainedAchievementIds = obtainedAchievementTimes.keys.toList();
    List<Achievement> obtainedAchievements = achievements
        .where((achievement) => obtainedAchievementIds.contains(achievement.id))
        .toList();

    // Получаем общее количество пользователей
    QuerySnapshot usersSnapshot =
    await FirebaseFirestore.instance.collection('User').get();
    int totalUsers = usersSnapshot.size;

    // Получаем статистику по достижениям
    Map<String, int> achievementStats = {};
    QuerySnapshot allUserAchievementsSnapshot = await FirebaseFirestore.instance
        .collection('UserAchievements')
        .get();

    for (var doc in allUserAchievementsSnapshot.docs) {
      String achievementId = doc['achievementId'] as String;
      achievementStats[achievementId] =
          (achievementStats[achievementId] ?? 0) + 1;
    }

    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text('Мои достижения'),
              IconButton(
                icon: const Icon(Icons.close),
                onPressed: () => Navigator.of(context).pop(),
              ),
            ],
          ),
          content: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Прогресс'),
                const SizedBox(height: 8),
                Text(
                    'Получено ${obtainedAchievements.length} из ${achievements.length} достижений'),
                const SizedBox(height: 8),
                LinearProgressIndicator(
                    value: obtainedAchievements.length / achievements.length),
                const SizedBox(height: 16),
                const Text('Полученные достижения'),
                const SizedBox(height: 8),
                obtainedAchievements.isEmpty
                    ? const Text('У вас нет достижений')
                    : Column(
                    children: obtainedAchievements
                        .map((a) => _buildAchievementBlock(
                        a,
                        true,
                        obtainedAchievementTimes[a.id]!,
                        achievementStats[a.id] ?? 0,
                        totalUsers))
                        .toList()),
                const SizedBox(height: 16),
                const Text('Неполученные достижения',
                    style: TextStyle(fontWeight: FontWeight.bold)),
                const SizedBox(height: 8),
                ...achievements
                    .where((a) => !obtainedAchievements.contains(a))
                    .map((a) => _buildUnreceivedAchievementBlock(a, false)),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildAchievementBlock(Achievement achievement, bool obtained,
      Timestamp? obtainedTime, int achievementCount, int totalUsers) {
    // Форматирование даты
    String formattedDate = obtainedTime != null
        ? DateFormat('dd.MM.yyyy HH:mm').format(obtainedTime.toDate())
        : '';

    return Card(
      margin: const EdgeInsets.symmetric(vertical: 8.0),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12.0)),
      elevation: 4.0,
      child: Container(
        height: 150, // Задайте нужный размер блока
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(12.0),
          image: DecorationImage(
            image: NetworkImage(achievement.image),
            fit: BoxFit.cover,
          ),
        ),
        child: Stack(
          children: [
            // Полупрозрачный фон для текста
            Container(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(12.0),
                color: Colors.black.withOpacity(0.5),
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(achievement.conditions,
                      style: const TextStyle(
                          fontStyle: FontStyle.italic, color: Colors.white)),
                  const SizedBox(height: 8),
                  if (obtained && obtainedTime != null)
                    Text(formattedDate,
                        style: const TextStyle(color: Colors.white)),
                  const SizedBox(height: 8),
                  Text(
                      'Это достижение есть у ${(achievementCount / totalUsers * 100).toStringAsFixed(2)}% пользователей',
                      style: const TextStyle(color: Colors.white)),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildUnreceivedAchievementBlock(Achievement achievement, bool obtained) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8.0),
      child: Row(
        children: [
          Image.network(achievement.image, width: 40, height: 40),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(achievement.name,
                    style: const TextStyle(fontWeight: FontWeight.bold)),
                Text(achievement.conditions),
              ],
            ),
          ),
        ],
      ),
    );
  }

  @override
  void dispose() {
    for (var controller in _addressControllers) {
      controller.dispose();
    }
    super.dispose();
  }
}

void _showLoginAlert(BuildContext context) {
  showDialog(
    context: context,
    builder: (BuildContext context) {
      return AlertDialog(
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
                UserCredential userCredential = await FirebaseAuth.instance
                    .signInWithCredential(credential);
                var user = userCredential.user;

                if (user != null) {
                  // Check if user exists in Firestore
                  CollectionReference userRef =
                  FirebaseFirestore.instance.collection('User');
                  DocumentSnapshot snapshotUser =
                  await userRef.doc(user.uid).get();

                  // Initialize userData as an empty Map if the document doesn't exist
                  Map<String, dynamic> userData =
                      snapshotUser.data() as Map<String, dynamic>? ?? {};

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
                    CollectionReference achievementsRef =
                    FirebaseFirestore.instance.collection('Achievements');
                    QuerySnapshot achievementSnapshot = await achievementsRef
                        .where('name', isEqualTo: 'Новое начало')
                        .get();

                    if (achievementSnapshot.docs.isNotEmpty) {
                      var achievementDoc = achievementSnapshot.docs.first;
                      String achievementId = achievementDoc.id;

                      // Add the achievement to UserAchievements
                      CollectionReference userAchievementsRef =
                      FirebaseFirestore.instance
                          .collection('UserAchievements');
                      await userAchievementsRef
                          .doc('${achievementId}_${user.uid}')
                          .set({
                        'achievementId': achievementId,
                        'userId': user.uid,
                        'gotAt': FieldValue.serverTimestamp(),
                      });

                      // Show notification to the user
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                            content: Text('Ура! У вас новое достижение!')),
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
                  Image.asset('assets/icons/google.png', height: 24, width: 24),
                  const SizedBox(width: 10),
                  const Text("Войти через Google",
                      style: TextStyle(color: Colors.black)),
                ],
              ),
            ),
          ],
        ),
      );
    },
  );
}

class Achievement {
  final String id;
  final String name;
  final String conditions;
  final String image;

  Achievement(
      {required this.id,
        required this.name,
        required this.conditions,
        required this.image});

  factory Achievement.fromDocument(DocumentSnapshot doc) {
    return Achievement(
      id: doc.id,
      name: doc['name'],
      conditions: doc['conditions'],
      image: doc['image'],
    );
  }
}
