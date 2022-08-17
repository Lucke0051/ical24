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
  final DateTime start;
  final DateTime end;

  final String name;
  final String? teacher;
  final String? location;
  final String? description;

  const Lesson({
    required this.guid,
    required this.start,
    required this.end,
    required this.name,
    this.teacher,
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
        "teacher": teacher,
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
