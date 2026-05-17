import 'package:flutter/widgets.dart';

class MyRoute extends OverlayRoute<void> {
  MyRoute({required this.builder});
  final WidgetBuilder builder;

  @override
  Iterable<OverlayEntry> createOverlayEntries() {
    return [OverlayEntry(builder: builder)];
  }
}
