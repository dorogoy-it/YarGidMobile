class UserModel {
  String name = '';
  String login = '';
  String id = '';
  String authToken = '';
  double kilo = 0.0;
  int reviews = 0;
  int routes = 0;
  bool showAchievements = true;
  bool showStats = true;
  bool showPersonalInfo = true;

  UserModel({
    required this.name,
    required this.login,
    required this.id,
    required this.kilo,
    required this.reviews,
    required this.routes,
    this.showAchievements = true,
    this.showStats = true,
    this.showPersonalInfo = true,
  });

  UserModel.fromJson(Map<String, dynamic>? json) {
    if (json == null) {
      // Если json null, используем значения по умолчанию
      return;
    }
    name = json['name'] ?? '';
    login = json['login'] ?? '';
    id = json['id'] ?? '';
    kilo = (json['kilo'] ?? 0.0).toDouble();
    reviews = json['reviews'] ?? 0;
    routes = json['routes'] ?? 0;
    authToken = json['authToken'] ?? '';
    showAchievements = json['showAchievements'] ?? true;
    showStats = json['showStats'] ?? true;
    showPersonalInfo = json['showPersonalInfo'] ?? true;
  }

  Map<String, dynamic> toJson() {
    final Map<String, dynamic> data = <String, dynamic>{};
    data['name'] = name;
    data['login'] = login;
    data['id'] = id;
    data['kilo'] = kilo;
    data['reviews'] = reviews;
    data['routes'] = routes;
    data['authToken'] = authToken;
    data['showAchievements'] = showAchievements;
    data['showStats'] = showStats;
    data['showPersonalInfo'] = showPersonalInfo;
    return data;
  }
}