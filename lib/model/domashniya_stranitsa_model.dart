import 'package:flutter/material.dart';
import '../main.dart';

class DomashnayaStranitsaModel extends DomashnayaStranitsaWidget {
  ///  State fields for stateful widgets in this component.

  // State field(s) for PageView widget.
  PageController? pageViewController;

  int get pageViewCurrentIndex => pageViewController != null &&
      pageViewController!.hasClients &&
      pageViewController!.page != null
      ? pageViewController!.page!.round()
      : 0;

  void initState(BuildContext context) {}

  void dispose() {}
}