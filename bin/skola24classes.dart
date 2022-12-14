import 'package:timezone/standalone.dart' as tz;

class Class {
  final String guid;
  final String name;

  const Class({
    required this.guid,
    required this.name,
  });

  Map<String, dynamic> toJson() => {
        "guid": guid,
        "name": name,
      };
}

class Lesson {
  final String guid;
  final tz.TZDateTime start;
  final tz.TZDateTime end;

  final String name;
  final String? location;
  final String? description;

  const Lesson({
    required this.guid,
    required this.start,
    required this.end,
    required this.name,
    this.location,
    this.description,
  });

  @override
  String toString() {
    return "'$name' at: ${start.toIso8601String()}; ${end.toIso8601String()}";
  }

  Map<String, dynamic> toJson() => {
        "guid": guid,
        "name": name,
        "start": start.millisecondsSinceEpoch,
        "end": end.millisecondsSinceEpoch,
        "location": location,
        "description": description,
      };
}

class School {
  final String guid;
  final String name;

  const School({
    required this.guid,
    required this.name,
  });

  Map<String, dynamic> toJson() => {
        "guid": guid,
        "name": name,
      };
}
