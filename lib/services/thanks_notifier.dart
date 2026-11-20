import 'package:shared_preferences/shared_preferences.dart';

/// Dice a chi segnala quando riceve nuovi "grazie", come i messaggi di
/// ringraziamento che motivano a continuare a segnalare.
///
/// Ricorda sul dispositivo quanti grazie sono già stati mostrati per
/// ciascun utente; alla prima lettura non annuncia nulla.
class ThanksNotifier {
  ThanksNotifier({Future<SharedPreferences> Function()? preferences})
    : _preferences = preferences ?? SharedPreferences.getInstance;

  final Future<SharedPreferences> Function() _preferences;

  static String _key(String userId) => 'thanks_seen_$userId';

  /// Quanti grazie nuovi ci sono rispetto all'ultima volta, e li segna
  /// come visti. Restituisce 0 se non ce ne sono o alla prima lettura.
  Future<int> newThanks(String userId, int total) async {
    try {
      final prefs = await _preferences();
      final seen = prefs.getInt(_key(userId));
      if (seen != total) await prefs.setInt(_key(userId), total);
      if (seen == null) return 0;
      return total > seen ? total - seen : 0;
    } catch (_) {
      return 0;
    }
  }
}
