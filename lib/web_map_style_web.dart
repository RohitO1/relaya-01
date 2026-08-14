// ignore: avoid_web_libraries_in_flutter
import 'dart:html' as html;

void setWebMapDarkMode(bool isDark) {
  final body = html.document.body;
  if (body != null) {
    if (isDark) {
      body.classes.add('map-dark-mode');
    } else {
      body.classes.remove('map-dark-mode');
    }
  }
}
