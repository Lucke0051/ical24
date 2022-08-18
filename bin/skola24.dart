import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:timezone/standalone.dart' as tz;

import 'extensions.dart';
import 'skola24classes.dart';

export 'skola24classes.dart';

bool mapEquals<T, U>(Map<T, U>? a, Map<T, U>? b) {
  if (a == null) {
    return b == null;
  }
  if (b == null || a.length != b.length) {
    return false;
  }
  if (identical(a, b)) {
    return true;
  }
  for (final T key in a.keys) {
    if (!b.containsKey(key) || b[key] != a[key]) {
      return false;
    }
  }
  return true;
}

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

Map classCache = {};
Future<List<Class>?> getClasses(String hostname, String guid, String scope) async {
  final String cacheKey = hostname + guid + scope;
  if (classCache[cacheKey] != null) {
    print("Got classes from cache");
    return classCache[cacheKey] as List<Class>;
  }

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

    classCache[cacheKey] = classes;

    return classes;
  } else {
    print("Could not get classes, status code: ${response.statusCode}");
  }
}

Map lessonCache = {};
Future<List<Lesson>?> getLessons(String hostname, String schoolGuid, String scope, String classGuid, {int extraWeeks = 0}) async {
  final String cacheKey = hostname + schoolGuid + scope + classGuid + extraWeeks.toString();
  if (lessonCache[cacheKey] != null) {
    print("Got lessons from cache");
    return lessonCache[cacheKey] as List<Lesson>;
  }

  DateTime now = DateTime.now().toUtc();
  if (extraWeeks > 0) {
    now = now.add(Duration(days: 7 * extraWeeks));
  }
  now = now.toLocal();

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
        if (split.length >= 2) {
          split.removeLast();
          location = split.join(" ");
        } else {
          location = null;
        }

        if (location == "" || location == " ") {
          location = null;
        }
      }

      final List<String> startSplit = (jsonLesson["timeStart"] as String).split(":");
      tz.TZDateTime start = tz.TZDateTime.local(
        now.year,
        1,
        1,
        int.parse(startSplit[0]),
        int.parse(startSplit[1]),
        int.parse(startSplit[2]),
      ).toUtc();
      print(start.toIso8601String());
      print(tz.TZDateTime.local(
        now.year,
        1,
        1,
        int.parse(startSplit[0]),
        int.parse(startSplit[1]),
        int.parse(startSplit[2]),
      ).toIso8601String());
      start = start.add(Duration(days: (yearStartDiff.inDays - now.weekday) + (jsonLesson["dayOfWeekNumber"] as int))).toLocal();

      final List<String> endSplit = (jsonLesson["timeEnd"] as String).split(":");
      tz.TZDateTime end = tz.TZDateTime.local(
        now.year,
        1,
        1,
        int.parse(endSplit[0]),
        int.parse(endSplit[1]),
        int.parse(endSplit[2]),
      ).toUtc();
      end = end.add(Duration(days: (yearStartDiff.inDays - now.weekday) + (jsonLesson["dayOfWeekNumber"] as int))).toLocal();

      lessons.add(
        Lesson(
          guid: start.week.toString() + (jsonLesson["guidId"] as String),
          start: start,
          end: end,
          name: jsonLesson["texts"].first as String? ?? "Unknown",
          location: location,
          description: texts.join("\n"),
        ),
      );
    }

    lessonCache[cacheKey] = lessons;

    return lessons;
  } else {
    print("Request failed, status code: ${response.statusCode}");
  }
}

Map schoolCache = {};
Future<List<School>?> getSchools(String hostname, String scope) async {
  final String cacheKey = hostname + scope;
  if (schoolCache[cacheKey] != null) {
    print("Got schools from cache");
    return schoolCache[cacheKey] as List<School>;
  }

  final http.Response response = await http.post(
    Uri(
      host: "web.skola24.se",
      pathSegments: ["api", "services", "skola24", "get", "timetable", "viewer", "units"],
      scheme: "https",
      port: 443,
    ),
    body: '{"getTimetableViewerUnitsRequest":{"hostName":"$hostname"}}',
    headers: {
      "Content-Type": "application/json",
      "Accept": "application/json",
      "X-Scope": scope,
    },
  );

  if (response.statusCode == 200) {
    final Map data = jsonDecode(response.body) as Map;
    final List units = data["data"]["getTimetableViewerUnitsResponse"]["units"] as List;

    final List<School> schools = [];
    for (final unit in units) {
      schools.add(School(guid: unit["unitGuid"] as String, name: unit["unitId"] as String));
    }

    schoolCache[cacheKey] = schools;

    return schools;
  } else {
    print("Could not get units, status code: ${response.statusCode}");
  }
}
