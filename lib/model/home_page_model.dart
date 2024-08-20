import 'package:flutter/material.dart';
import '../main.dart';
import 'domashniya_stranitsa_model.dart';

class HomePageModel extends HomePageWidget {
  ///  State fields for stateful widgets in this page.

  final unfocusNode = FocusNode();
  // Model for domashnaya_stranitsa component.
  late DomashnayaStranitsaModel domashnayaStranitsaModel;

  HomePageModel() {
    domashnayaStranitsaModel = DomashnayaStranitsaModel();
  }

  void initState(BuildContext context) {
    // Инициализация уже происходит в конструкторе
  }

  void dispose() {
    unfocusNode.dispose();
    domashnayaStranitsaModel.dispose();
  }
}