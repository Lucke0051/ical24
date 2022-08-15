import 'dart:convert';

import 'package:http/http.dart' as http;

import 'extensions.dart';
import 'skola24classes.dart';

export 'skola24classes.dart';

Future<String?> getRenderKey(String scope) async {
  final http.Response response = await http.post(
    Uri(
      host: "web.skola24.se",
      pathSegments: ["api", "get", "timetable", "render", "key"],
      scheme: "https",
      port: 443,
    ),
    body: "null",
    headers: {
      "Content-Type": "application/json",
      "Accept": "application/json",
      "X-Scope": scope,
    },
  );

  if (response.statusCode == 200) {
    final Map data = jsonDecode(response.body) as Map;
    return data["data"]["key"] as String;
  } else {
    print("Could not get renderKey, status code: ${response.statusCode}");
  }
}

Future<List<Class>?> getClasses(String hostname, String guid, String scope) async {
  final http.Response response = await http.post(
    Uri(
      host: "web.skola24.se",
      pathSegments: ["api", "get", "timetable", "selection"],
      scheme: "https",
      port: 443,
    ),
    body:
        '{"hostName":"$hostname","unitGuid":"$guid","filters":{"class":true,"course":false,"group":false,"period":false,"room":false,"student":false,"subject":false,"teacher":false}}',
    headers: {
      "Content-Type": "application/json",
      "Accept": "application/json",
      "X-Scope": scope,
    },
  );

  if (response.statusCode == 200) {
    final Map data = jsonDecode(response.body) as Map;
    final List jsonClasses = data["data"]["classes"] as List;

    final List<Class> classes = [];
    for (final jsonClass in jsonClasses) {
      classes.add(Class(guid: jsonClass["groupGuid"] as String, name: jsonClass["groupName"] as String));
    }
    return classes;
  } else {
    print("Could not get classes, status code: ${response.statusCode}");
  }
}

Future<List<Lesson>?> getLessons(String hostname, String schoolGuid, String scope, String classGuid) async {
  final DateTime now = DateTime.now();
  final Duration yearStartDiff = now.difference(DateTime(now.year));

  final String requestBody = jsonEncode({
    "blackAndWhite": false,
    "customerKey": "",
    "endDate": null,
    "height": 550,
    "host": hostname,
    "periodText": "",
    "privateFreeTextMode": null,
    "privateSelectionMode": false,
    "renderKey": await getRenderKey(scope),
    "scheduleDay": 0,
    "selection": classGuid,
    "selectionType": 0,
    "showHeader": false,
    "startDate": null,
    "unitGuid": schoolGuid,
    "week": now.week,
    "width": 600,
    "year": now.year,
  });

  final http.Response response = await http.post(
    Uri(
      host: "web.skola24.se",
      pathSegments: ["api", "render", "timetable"],
      scheme: "https",
      port: 443,
    ),
    headers: {
      "Content-Type": "application/json",
      "Accept": "application/json",
      "X-Scope": scope,
    },
    body: requestBody,
  );

  if (response.statusCode == 200) {
    final Map jsonResponse = jsonDecode(response.body) as Map;
    final List jsonLessons = jsonResponse["data"]["lessonInfo"] as List;

    final List<Lesson> lessons = [];
    for (final jsonLesson in jsonLessons) {
      final List texts = jsonLesson["texts"] as List;
      String? location;
      if (texts.length >= 2) {
        location = texts[2] as String;
        if (location.substring(0, 1) == "/") {
          location = location.substring(1);
        }

        final List<String> split = location.split(" ");
        if (split.length >= 3) {
          split.removeLast();
          location = split.join(" ");
        }
      }

      String? teacher;
      if (texts.length >= 2) {
        teacher = texts[1] as String;
        if (teacher.substring(0, 1) == "/") {
          teacher = teacher.substring(1);
        }
        if (teacher.isEmpty) {
          teacher = null;
        }
      }

      final List<String> startSplit = (jsonLesson["timeStart"] as String).split(":");
      DateTime start = DateTime.utc(
        now.year,
        1,
        1,
        int.parse(startSplit[0]),
        int.parse(startSplit[1]),
        int.parse(startSplit[2]),
      );
      start = start.add(Duration(days: (yearStartDiff.inDays - now.weekday) + (jsonLesson["dayOfWeekNumber"] as int)));

      final List<String> endSplit = (jsonLesson["timeEnd"] as String).split(":");
      DateTime end = DateTime.utc(
        now.year,
        1,
        1,
        int.parse(endSplit[0]),
        int.parse(endSplit[1]),
        int.parse(endSplit[2]),
      );
      end = end.add(Duration(days: (yearStartDiff.inDays - now.weekday) + (jsonLesson["dayOfWeekNumber"] as int)));

      lessons.add(
        Lesson(
          guid: jsonLesson["guidId"] as String,
          start: start,
          end: end,
          name: jsonLesson["texts"].first as String? ?? "Unknown",
          teacher: teacher,
          location: location,
          description: texts.join("\n"),
        ),
      );
    }

    return lessons;
  } else {
    print("Request failed, status code: ${response.statusCode}");
  }
}
