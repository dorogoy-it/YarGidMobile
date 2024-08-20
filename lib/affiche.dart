import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:html/parser.dart' as parser;
import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher.dart';
import 'map.dart';
import 'model/map_model.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:yar_gid_mobile/user_area.dart';

class AffichePage extends ConsumerStatefulWidget {
  const AffichePage({super.key});

  @override
  ConsumerState<AffichePage> createState() => AffichePageState();
}

class AffichePageState extends ConsumerState<AffichePage> {
  DateTime selectedDate = DateTime.now();
  bool showMovies = true;
  bool showEvents = false;
  int _currentIndex = 0;

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      home: Scaffold(
        appBar: AppBar(
          leading: IconButton(
            icon: const Icon(Icons.arrow_back),
            onPressed: () {
              Navigator.of(context).pop();
            },
          ),
          title: Text(showEvents ? 'Ивенты' : (showMovies ? 'Киноафиша' : 'Афиша театра')),
        ),
        body: Column(
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                ElevatedButton(
                  onPressed: () => setState(() {
                    showMovies = true;
                    showEvents = false;
                  }),
                  child: const Text('Киноафиша'),
                ),
                ElevatedButton(
                  onPressed: () => setState(() {
                    showMovies = false;
                    showEvents = false;
                  }),
                  child: const Text('Афиша театра'),
                ),
                ElevatedButton(
                  onPressed: () => setState(() {
                    showEvents = true;
                    showMovies = false;
                  }),
                  child: const Text('Ивенты'),
                ),
              ],
            ),
            if (showMovies)
              ElevatedButton(
                onPressed: () => _selectDate(context),
                child: Text('Выбрать дату: ${DateFormat('dd.MM.yyyy').format(selectedDate)}'),
              ),
            Expanded(
              child: showEvents
                  ? const EventListWidget()
                  : (showMovies
                  ? MovieListWidget(selectedDate: selectedDate)
                  : const TheaterListWidget()),
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
      ),
    );
  }

  Future<void> _selectDate(BuildContext context) async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: selectedDate,
      firstDate: DateTime.now(),
      lastDate: DateTime.now().add(const Duration(days: 30)),
    );
    if (picked != null && picked != selectedDate) {
      setState(() {
        selectedDate = picked;
      });
    }
  }
}

class EventListWidget extends StatelessWidget {
  const EventListWidget({super.key});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance.collection('Events').snapshots(),
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return Text('Ошибка: ${snapshot.error}');
        }

        if (snapshot.connectionState == ConnectionState.waiting) {
          return const CircularProgressIndicator();
        }

        return ListView(
          children: snapshot.data!.docs.map((DocumentSnapshot document) {
            Map<String, dynamic> data = document.data() as Map<String, dynamic>;
            return Card(
              child: Column(
                children: [
                  Image.network(data['image']),
                  ListTile(
                    title: Text(
                      data['name'],
                      style: const TextStyle(fontWeight: FontWeight.bold),
                    ),
                    subtitle: Text(data['desc']),
                  ),
                  ElevatedButton(
                    onPressed: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => MapPage(
                            eventPlaces: [MapModel(
                              latitude: data['latitude'] ?? 0, // Предполагается, что координаты хранятся в документе
                              longitude: data['longitude'] ?? 0,
                              address: data['address'],
                              name: data['name'],
                              subcategory: '',
                              category: '',
                            )],
                          ),
                        ),
                      );
                    },
                    child: const Text('Перейти к событию'),
                  ),
                ],
              ),
            );
          }).toList(),
        );
      },
    );
  }
}

class Movie {
  final String title;
  final String age;
  final String imageUrl;
  final String genres;
  final String? duration; // Длительность может быть null, если блок отсутствует
  final List<ShowTime> showTimes;

  Movie({
    required this.title,
    required this.age,
    required this.imageUrl,
    required this.genres,
    this.duration,
    required this.showTimes,
  });
}
class ShowTime {
  final String startAt;
  final String price;
  final String roomType;
  final Uri href;

  ShowTime({
    required this.startAt,
    required this.price,
    required this.roomType,
    required this.href,
  });
}

class TheaterShow {
  final String title;
  final String age;
  final String tag;
  final String time;
  final String roomType;
  final String dateDay;
  final String dateMonth;
  final String startAt;
  final String preview;

  TheaterShow({
    required this.title,
    required this.age,
    required this.tag,
    required this.time,
    required this.roomType,
    required this.dateDay,
    required this.dateMonth,
    required this.startAt,
    required this.preview,
  });
}

Future<List<TheaterShow>> fetchTheaterShows() async {
  final response = await http.get(Uri.parse('https://sibdrama.ru/'));
  if (response.statusCode == 200) {
    var document = parser.parse(response.body);
    List<TheaterShow> shows = [];

    var showElements = document.getElementsByClassName('bill-list__item');
    for (var element in showElements) {
      var titleElement = element.getElementsByClassName('card__title');
      if (titleElement.isEmpty) continue;
      var title = titleElement[0].text.trim();

      var ageElement = titleElement[0].getElementsByClassName('card__age');
      var age = ageElement.isNotEmpty ? ageElement[0].text.trim() : 'N/A';

      var tagElement = element.getElementsByClassName('card__type');
      var tag = tagElement.isNotEmpty ? tagElement[0].text.trim() : 'N/A';

      var timeElement = element.getElementsByClassName('card__duration');
      var time = timeElement.isNotEmpty ? timeElement[0].text.trim() : 'N/A';

      var roomTypeElement = element.getElementsByClassName('card__scene');
      var roomType = roomTypeElement.isNotEmpty ? roomTypeElement[0].text.trim() : 'N/A';

      var dateDayElement = element.getElementsByClassName('card__day');
      var dateDay = dateDayElement.isNotEmpty ? dateDayElement[0].text.trim() : 'N/A';

      var dateMonthElement = element.getElementsByClassName('card__month');
      var dateMonth = dateMonthElement.isNotEmpty ? dateMonthElement[0].text.trim() : 'N/A';

      var startAtElement = element.getElementsByClassName('card__time-week');
      var startAt = startAtElement.isNotEmpty ? startAtElement[0].text.trim() : 'N/A';

      var previewElement = element.getElementsByClassName('expanded-card__text');
      var preview = previewElement.isNotEmpty ? previewElement[0].text.trim() : 'N/A';

      shows.add(TheaterShow(
        title: title,
        age: age,
        tag: tag,
        time: time,
        roomType: roomType,
        dateDay: dateDay,
        dateMonth: dateMonth,
        startAt: startAt,
        preview: preview,
      ));
    }

    return shows;
  } else {
    throw Exception('Failed to load theater shows');
  }
}


Future<List<Movie>> fetchMovies(DateTime date) async {
  final response = await http.get(Uri.parse('https://kinomax.ru/planeta/${DateFormat('yyyy-MM-dd').format(date)}'));
  if (response.statusCode == 200) {
    var document = parser.parse(response.body);
    List<Movie> movies = [];

    var movieElements = document.getElementsByClassName('XGEM9bNiZvg0iY5iYWVg');
    for (var element in movieElements) {
      var title = element.getElementsByClassName('rvteBfr7tWSx54Af5ZnL')[0].text.trim();
      var age = element.getElementsByClassName('Dcldd9dQoVUYd2wfcjzm')[0].text.trim();
      var imageUrl = element.getElementsByTagName('img')[0].attributes['src'] ?? '';

      // Извлечение жанров и длительности
      var genreElements = element.getElementsByClassName('Ifu0_dR83AoTbvMgUlcA')[0].getElementsByTagName('div');
      var genres = genreElements[0].text.trim();
      String? duration;
      if (genreElements.length > 1) {
        duration = genreElements[1].text.trim();
      }

      List<ShowTime> showTimes = [];
      var timeTableElements = element.getElementsByClassName('a1DGomhf4lH5LTLg921s');
      for (var timeElement in timeTableElements) {
        var startAt = timeElement.getElementsByClassName('r_gzS2BkVe5yHxcYwfkK')[0].text.trim();
        var price = timeElement.getElementsByClassName('J52YROaNVTJ8YnB4LPeK')[0].text.trim();
        var roomType = timeElement.getElementsByClassName('bKz7Y2h6HySrp2rT6052')[0].text.trim();
        var href = Uri.parse('https://kinomax.ru${timeElement.attributes['href']}');

        showTimes.add(ShowTime(
          startAt: startAt,
          price: price,
          roomType: roomType,
          href: href,
        ));
      }

      movies.add(Movie(
        title: title,
        age: age,
        imageUrl: imageUrl,
        genres: genres,
        duration: duration,
        showTimes: showTimes,
      ));
    }

    return movies;
  } else {
    throw Exception('Failed to load movies');
  }
}

class MovieListWidget extends StatelessWidget {
  final DateTime selectedDate;

  const MovieListWidget({super.key, required this.selectedDate});

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<List<Movie>>(
      future: fetchMovies(selectedDate),
      builder: (context, snapshot) {
        if (snapshot.hasData) {
          return ListView.builder(
            itemCount: snapshot.data!.length,
            itemBuilder: (context, index) {
              var movie = snapshot.data![index];
              return MovieCard(movie: movie, selectedDate: selectedDate,);
            },
          );
        } else if (snapshot.hasError) {
          return Text('${snapshot.error}');
        }
        return const Center(child: CircularProgressIndicator());
      },
    );
  }
}

class MovieCard extends StatelessWidget {
  final Movie movie;
  final DateTime selectedDate;

  const MovieCard({super.key, required this.movie, required this.selectedDate});

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.all(8.0),
      child: Padding(
        padding: const EdgeInsets.all(8.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Stack(
                  children: [
                    Image.network(
                      movie.imageUrl,
                      width: 120,
                      height: 180,
                      fit: BoxFit.cover,
                    ),
                    Positioned(
                      top: 0,
                      right: 0,
                      child: Container(
                        padding: const EdgeInsets.all(4),
                        color: Colors.black,
                        child: Text(
                          movie.age,
                          style: const TextStyle(color: Colors.white),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        movie.title,
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        movie.genres,  // Выводим жанры
                        style: const TextStyle(color: Colors.grey),
                      ),
                      if (movie.duration != null) ...[
                        const SizedBox(height: 4),
                        Text(
                          movie.duration!,  // Выводим длительность, если она есть
                          style: const TextStyle(color: Colors.grey),
                        ),
                      ],
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Wrap(
              spacing: 8.0,
              runSpacing: 8.0,
              children: movie.showTimes.map((showTime) => ShowTimeButton(showTime: showTime, selectedDate: selectedDate,)).toList(),
            ),
          ],
        ),
      ),
    );
  }
}


class ShowTimeButton extends StatelessWidget {
  final DateTime selectedDate;
  final ShowTime showTime;

  const ShowTimeButton({super.key, required this.showTime, required this.selectedDate});

  @override
  Widget build(BuildContext context) {
    // Получаем текущую дату и время
    DateTime now = DateTime.now();

    // Парсим время начала сеанса с учетом даты сеанса
    DateTime showTimeDateTime = _parseShowTime(showTime.startAt, selectedDate);

    // Определяем, прошел ли сеанс
    bool isPast = now.isAfter(showTimeDateTime.add(const Duration(minutes: 1)));

    final isComfort = showTime.roomType.toLowerCase().contains('комфорт');
    final buttonColor = isPast ? Colors.grey : (isComfort ? Colors.orange : Colors.grey[800]);

    return Column(
      children: [
        ElevatedButton(
          style: ElevatedButton.styleFrom(
            backgroundColor: buttonColor,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          ),
          onPressed: isPast ? null : () => _launchURL(showTime.href),
          child: Column(
            children: [
              Text(showTime.startAt, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
              Text(showTime.price, style: const TextStyle(color: Colors.white, fontSize: 12)),
            ],
          ),
        ),
        Text(
          showTime.roomType,
          style: TextStyle(fontSize: 10, color: buttonColor),
        ),
      ],
    );
  }

  DateTime _parseShowTime(String startAt, DateTime selectedDate) {
    // Предполагаем, что startAt содержит время в формате "HH:mm"
    final timeParts = startAt.split(':');
    return DateTime(
        selectedDate.year,
        selectedDate.month,
        selectedDate.day,
        int.parse(timeParts[0]),
        int.parse(timeParts[1])
    );
  }

  void _launchURL(Uri url) async {
    if (await canLaunchUrl(url)) {
      await launchUrl(url);
    } else {
      throw 'Could not launch $url';
    }
  }
}


class TheaterListWidget extends StatelessWidget {
  const TheaterListWidget({super.key});

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<List<TheaterShow>>(
      future: fetchTheaterShows(),
      builder: (context, snapshot) {
        if (snapshot.hasData) {
          return ListView.builder(
            itemCount: snapshot.data!.length,
            itemBuilder: (context, index) {
              var show = snapshot.data![index];
              return TheaterShowCard(show: show);
            },
          );
        } else if (snapshot.hasError) {
          return Text('${snapshot.error}');
        }
        return const Center(child: CircularProgressIndicator());
      },
    );
  }
}

class TheaterShowCard extends StatelessWidget {
  final TheaterShow show;

  const TheaterShowCard({super.key, required this.show});

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.all(8.0),
      child: Padding(
        padding: const EdgeInsets.all(8.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              show.title,
              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            Text('Возраст: ${show.age}'),
            Text('Жанр: ${show.tag}'),
            Text('Длительность: ${show.time}'),
            Text('Сцена: ${show.roomType}'),
            Text('Дата: ${show.dateDay} ${show.dateMonth}'),
            Text('Начало: ${show.startAt}'),
            const SizedBox(height: 8),
            Text(
              show.preview,
              style: const TextStyle(fontSize: 12),
              maxLines: 3,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ),
      ),
    );
  }
}
