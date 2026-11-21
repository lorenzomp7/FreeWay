/// Stato di un luogo in un certo momento secondo i suoi orari.
enum OpeningStatus { open, closed, unknown }

class OpeningCheck {
  const OpeningCheck(this.status, {this.closesAt, this.opensAt});

  static const OpeningCheck unknown = OpeningCheck(OpeningStatus.unknown);

  final OpeningStatus status;

  /// Se è aperto: quando chiude (`null` se è sempre aperto).
  final DateTime? closesAt;

  /// Se è chiuso: quando riapre, entro una settimana (`null` se non si sa).
  final DateTime? opensAt;
}

/// Orari di apertura nel formato `opening_hours` di OpenStreetMap, come le
/// voci "Aperto · Chiude alle 19" di Google Maps.
///
/// Si capisce solo la forma più comune: `24/7`, giorni (`Mo-Fr`, `Sa,Su`)
/// seguiti da fasce orarie (`09:00-12:30,15:00-19:00`) oppure `off`, regole
/// separate da `;`. Gli orari più complessi (mesi, settimane, alba e
/// tramonto, commenti…) danno `null`: meglio non dire niente che dire una
/// cosa sbagliata. Le regole dei festivi (`PH`) e delle vacanze scolastiche
/// (`SH`) si ignorano, perché non sappiamo quando cadono.
class OpeningHours {
  OpeningHours._(this._week, {this.alwaysOpen = false});

  /// Fasce in minuti dalla mezzanotte, per giorno (0 = lunedì). La fine può
  /// superare 1440: la fascia continua dopo mezzanotte.
  final List<List<(int, int)>> _week;
  final bool alwaysOpen;

  static const List<String> _days = ['Mo', 'Tu', 'We', 'Th', 'Fr', 'Sa', 'Su'];

  static final RegExp _unsupported = RegExp(
    r'Jan|Feb|Mar|Apr|May|Jun|Jul|Aug|Sep|Oct|Nov|Dec|week|sunrise|sunset|'
    r'dawn|dusk|easter|"|\|\||\+|\[|\d{4}|unknown',
  );
  static final RegExp _rule = RegExp(
    r'^((?:Mo|Tu|We|Th|Fr|Sa|Su|PH|SH)(?:-(?:Mo|Tu|We|Th|Fr|Sa|Su))?'
    r'(?:\s*,\s*(?:Mo|Tu|We|Th|Fr|Sa|Su|PH|SH)(?:-(?:Mo|Tu|We|Th|Fr|Sa|Su))?)*)'
    r'\s*:?\s*(.*)$',
  );
  static final RegExp _span = RegExp(r'^(\d{1,2}):(\d{2})-(\d{1,2}):(\d{2})$');

  static OpeningHours? parse(String? raw) {
    final text = raw?.trim() ?? '';
    if (text.isEmpty || _unsupported.hasMatch(text)) return null;
    if (text == '24/7') return OpeningHours._(_emptyWeek(), alwaysOpen: true);

    final week = _emptyWeek();
    var anyRule = false;
    for (final part in text.split(';')) {
      final rule = part.trim();
      if (rule.isEmpty) continue;
      final match = _rule.firstMatch(rule);
      final List<int> days;
      final String times;
      if (match != null) {
        days = _parseDays(match.group(1)!);
        times = match.group(2)!.trim();
        // Solo festivi o vacanze: non sappiamo quando sono.
        if (days.isEmpty) continue;
      } else {
        days = List.generate(7, (i) => i);
        times = rule;
      }
      final spans = _parseTimes(times);
      if (spans == null) return null;
      for (final day in days) {
        week[day] = spans;
      }
      anyRule = true;
    }
    if (!anyRule) return null;
    return OpeningHours._(week);
  }

  static List<List<(int, int)>> _emptyWeek() => List.generate(7, (_) => []);

  static List<int> _parseDays(String selector) {
    final days = <int>{};
    for (final token in selector.split(',')) {
      final item = token.trim();
      if (item == 'PH' || item == 'SH') continue;
      final ends = item.split('-');
      final from = _days.indexOf(ends.first);
      final to = _days.indexOf(ends.last);
      // Anche gli intervalli che passano dalla domenica (Fr-Mo).
      for (var d = from; ; d = (d + 1) % 7) {
        days.add(d);
        if (d == to) break;
      }
    }
    return days.toList()..sort();
  }

  /// `null` se le fasce non si capiscono; lista vuota se è chiuso.
  static List<(int, int)>? _parseTimes(String times) {
    if (times == 'off' || times == 'closed') return const [];
    if (times.isEmpty) return null;
    final spans = <(int, int)>[];
    for (final token in times.split(',')) {
      final match = _span.firstMatch(token.trim());
      if (match == null) return null;
      final numbers = [for (var i = 1; i <= 4; i++) int.parse(match.group(i)!)];
      if (numbers[0] > 24 || numbers[2] > 48) return null;
      if (numbers[1] > 59 || numbers[3] > 59) return null;
      final start = numbers[0] * 60 + numbers[1];
      var end = numbers[2] * 60 + numbers[3];
      if (start >= 1440) return null;
      // 18:00-02:00: continua dopo mezzanotte.
      if (end <= start) end += 1440;
      spans.add((start, end));
    }
    return spans;
  }

  /// Una fascia che finisce a mezzanotte (o dopo) e riprende subito il
  /// giorno dopo (`00:00-24:00` tutti i giorni) chiude più avanti.
  int _closing(int day, int end) {
    var close = end;
    var current = day;
    for (var i = 0; i < 7 && close >= 1440 * (i + 1); i++) {
      current = (current + 1) % 7;
      final offset = 1440 * (i + 1);
      final next = _week[current].where((s) => s.$1 + offset <= close);
      if (next.isEmpty) break;
      final reach = next
          .map((s) => s.$2 + offset)
          .reduce((a, b) => a > b ? a : b);
      if (reach <= close) break;
      close = reach;
    }
    return close;
  }

  OpeningCheck at(DateTime time) {
    if (alwaysOpen) return const OpeningCheck(OpeningStatus.open);
    final day = time.weekday - 1;
    final minute = time.hour * 60 + time.minute;
    final midnight = DateTime(time.year, time.month, time.day);
    DateTime clock(int dayOffset, int minutes) => DateTime(
      midnight.year,
      midnight.month,
      midnight.day + dayOffset,
      0,
      minutes,
    );

    for (final (start, end) in _week[day]) {
      if (minute >= start && minute < end) {
        return OpeningCheck(
          OpeningStatus.open,
          closesAt: clock(0, _closing(day, end)),
        );
      }
    }
    // Fasce di ieri che continuano dopo mezzanotte.
    final yesterday = (day + 6) % 7;
    for (final (start, end) in _week[yesterday]) {
      if (end > 1440 && minute + 1440 >= start && minute + 1440 < end) {
        return OpeningCheck(
          OpeningStatus.open,
          closesAt: clock(-1, _closing(yesterday, end)),
        );
      }
    }

    DateTime? next;
    for (var offset = 0; offset <= 7 && next == null; offset++) {
      final spans = [..._week[(day + offset) % 7]]
        ..sort((a, b) => a.$1.compareTo(b.$1));
      for (final (start, _) in spans) {
        if (offset == 0 && start <= minute) continue;
        next = clock(offset, start);
        break;
      }
    }
    return OpeningCheck(OpeningStatus.closed, opensAt: next);
  }
}

String _hhmm(DateTime t) => '${t.hour}:${t.minute.toString().padLeft(2, '0')}';

const List<String> _weekdayNames = [
  'lunedì',
  'martedì',
  'mercoledì',
  'giovedì',
  'venerdì',
  'sabato',
  'domenica',
];

/// "alle 15:00", "domani alle 9:00" o "lunedì alle 9:00", rispetto a [from].
String formatWhen(DateTime when, DateTime from) {
  final days = DateTime(
    when.year,
    when.month,
    when.day,
  ).difference(DateTime(from.year, from.month, from.day)).inDays;
  final time = 'alle ${_hhmm(when)}';
  if (days <= 0) return time;
  if (days == 1) return 'domani $time';
  return '${_weekdayNames[when.weekday - 1]} $time';
}

/// Ora di arrivo per la scheda dei percorsi: "10:42".
String formatClock(DateTime time) => _hhmm(time);

/// Riga per la scheda del luogo: "Aperto ora · chiude alle 19:00".
String? openingNowText(OpeningHours? hours, DateTime now) {
  if (hours == null) return null;
  if (hours.alwaysOpen) return 'Aperto 24 ore su 24';
  final check = hours.at(now);
  switch (check.status) {
    case OpeningStatus.open:
      final closes = check.closesAt;
      return closes == null
          ? 'Aperto ora'
          : 'Aperto ora · chiude ${formatWhen(closes, now)}';
    case OpeningStatus.closed:
      final opens = check.opensAt;
      return opens == null
          ? 'Chiuso ora'
          : 'Chiuso ora · apre ${formatWhen(opens, now)}';
    case OpeningStatus.unknown:
      return null;
  }
}

/// Avviso sull'orario di arrivo, come "Potrebbe essere chiuso quando
/// arrivi" di Google Maps. `null` se all'arrivo è aperto e non chiude subito
/// dopo, o se gli orari non si conoscono.
String? arrivalOpeningWarning(OpeningHours? hours, DateTime arrival) {
  if (hours == null || hours.alwaysOpen) return null;
  final check = hours.at(arrival);
  switch (check.status) {
    case OpeningStatus.closed:
      final opens = check.opensAt;
      return opens == null
          ? 'Potrebbe essere chiuso quando arrivi'
          : 'Potrebbe essere chiuso quando arrivi: apre '
                '${formatWhen(opens, arrival)}';
    case OpeningStatus.open:
      final closes = check.closesAt;
      if (closes != null &&
          closes.difference(arrival) <= const Duration(minutes: 30)) {
        return 'Chiude alle ${_hhmm(closes)}, poco dopo il tuo arrivo';
      }
      return null;
    case OpeningStatus.unknown:
      return null;
  }
}
