import 'package:web/web.dart' as web;

void openLink(String url) {
  web.window.open(url, '_blank', 'noopener');
}
