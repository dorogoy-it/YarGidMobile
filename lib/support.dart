import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:accordion/accordion.dart';
import 'package:accordion/controllers.dart';
import 'package:yar_gid_mobile/user_area.dart';

class SupportPage extends ConsumerStatefulWidget {
  const SupportPage({super.key});

  @override
  ConsumerState<SupportPage> createState() => _SupportPageState();
}

class _SupportPageState extends ConsumerState<SupportPage> {
  static const headerStyle = TextStyle(
      color: Color(0xffffffff), fontSize: 18, fontWeight: FontWeight.bold);
  static const contentStyle = TextStyle(
      color: Color(0xff999999), fontSize: 14, fontWeight: FontWeight.normal);

  static const question1 = "Могу ли я переписываться с другими пользователями?";
  static const question2 = "Как я могу просмотреть достижения?";
  static const question3 = "Моя электронная почта будет всегда отображаться в личном кабинете?";

  static const answer1 = "Нет. На текущий момент такого функционала не предусмотрено.";
  static const answer2 = '''В вашем личном кабинете отображаются только полученные вами достижения. Для просмотра всех достижений и информации о них используйте раздел "Достижения" в "Карты" - "Меню".''';
  static const answer3 = "Да. Почта, указанная вами при регистрации, будет отображаться в вашем личном кабинете. Однако, вы можете скрыть её от других пользователей в настройках приватности.";

  int _currentIndex = 5; // Индекс "Поддержка"

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.blueGrey[100],
      appBar: AppBar(
        title: const Text('Поддержка',
          style: TextStyle(
            color: Colors.white,
          ),),
        backgroundColor: Colors.blueGrey,
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: Accordion(
        headerBorderColor: Colors.blueGrey,
        headerBorderColorOpened: Colors.transparent,
        headerBackgroundColorOpened: Colors.green,
        contentBackgroundColor: Colors.white,
        contentBorderColor: Colors.green,
        contentBorderWidth: 3,
        contentHorizontalPadding: 20,
        scaleWhenAnimating: true,
        openAndCloseAnimation: true,
        headerPadding:
        const EdgeInsets.symmetric(vertical: 7, horizontal: 15),
        sectionOpeningHapticFeedback: SectionHapticFeedback.heavy,
        sectionClosingHapticFeedback: SectionHapticFeedback.light,
        children: [
          AccordionSection(
            isOpen: true,
            contentVerticalPadding: 20,
            leftIcon:
            const Icon(Icons.question_answer, color: Colors.white),
            header: const Text(question1, style: headerStyle),
            content: const Text(answer1, style: contentStyle),
          ),
          AccordionSection(
            isOpen: true,
            contentVerticalPadding: 20,
            leftIcon:
            const Icon(Icons.question_answer, color: Colors.white),
            header: const Text(question2, style: headerStyle),
            content: const Text(answer2, style: contentStyle),
          ),
          AccordionSection(
            isOpen: true,
            contentVerticalPadding: 20,
            leftIcon:
            const Icon(Icons.question_answer, color: Colors.white),
            header: const Text(question3, style: headerStyle),
            content: const Text(answer3, style: contentStyle),
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
}