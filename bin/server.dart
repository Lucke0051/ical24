import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:ical/serializer.dart';
import 'package:shelf/shelf.dart';
import 'package:shelf/shelf_io.dart';
import 'package:shelf_router/shelf_router.dart';
import 'package:timezone/data/latest.dart' as tzmain;
import 'package:timezone/standalone.dart' as tz;

import 'skola24.dart' as skola24;

final _router = Router()
  ..get("/", _rootHandler)
  ..get("/ical/<schoolHostname>/<schoolGuid>/<schoolScope>/<classGuid>", _getCalendarHandler)
  ..get("/lessons/<schoolHostname>/<schoolGuid>/<schoolScope>/<classGuid>", _getLessonsHandler)
  ..get("/schools/<schoolHostname>/<schoolScope>", _getSchoolsHandler)
  ..get("/classes/<schoolHostname>/<schoolGuid>/<schoolScope>", _getClassesHandler)
  ..get("/favicon.png", _iconHandler);

Future<Response> _rootHandler(Request req) async {
  return Response.ok(await File("/app/index.html").readAsString(), headers: {"Content-Type": "text/html"});
}

Future<Response> _iconHandler(Request req) async {
  return Response.ok(await File("/app/ical24.png").readAsBytes(), headers: {"Content-Type": "image/png"});
}

void main(List<String> args) async {
  tzmain.initializeTimeZones();

  final tz.Location stockholm = tz.getLocation("Europe/Stockholm");
  tz.setLocalLocation(stockholm);

  final InternetAddress ip = InternetAddress.anyIPv4;

  final FutureOr<Response> Function(Request) handler = const Pipeline().addMiddleware(logRequests()).addHandler(_router);

  final HttpServer server = await serve(handler, ip, 2005);
  print("Server listening on port: ${server.port}");

  Timer.periodic(const Duration(hours: 12), (_) {
    skola24.schoolCache = {};
    skola24.classCache = {};
    print("Cleared schools and classes cache");
  });
  Timer.periodic(const Duration(minutes: 30), (_) {
    skola24.lessonCache = {};
    print("Cleared lessons cache");
  });
}

Future<Response> _getCalendarHandler(Request request) async {
  final String schoolHostname = request.params["schoolHostname"] as String;
  final String schoolGuid = request.params["schoolGuid"] as String;
  final String schoolScope = request.params["schoolScope"] as String;
  final String classGuid = request.params["classGuid"] as String;
  final int weeks = (int.tryParse(request.url.queryParameters["weeks"] ?? "1") ?? 1).clamp(1, 10);

  final List<skola24.Lesson> allLessons = [];

  for (var i = 0; i < weeks; i++) {
    final List<skola24.Lesson>? lessons = await skola24.getLessons(schoolHostname, schoolGuid, schoolScope, classGuid, extraWeeks: i);
    if (lessons == null) return Response.internalServerError(body: "Could not get lessons");
    allLessons.addAll(lessons);
  }

  final ICalendar calendar = ICalendar(company: "skola24", product: "skola/schema", lang: "SV", refreshInterval: const Duration(hours: 4));
  for (final skola24.Lesson lesson in allLessons) {
    final IEvent event = IEvent(
      uid: lesson.guid,
      start: lesson.start.toUtc(),
      end: lesson.end.toUtc(),
      description: lesson.description,
      location: lesson.location,
      summary: lesson.name,
      transparency: ITimeTransparency.TRANSPARENT,
    );
    calendar.addElement(event);
  }

  return Response.ok(
    calendar.serialize(),
    headers: {
      "Content-Type": "text/calendar",
      "Cache-Control": "max-age=3600, public, no-transform",
    },
  );
}

Future<Response> _getSchoolsHandler(Request request) async {
  final String schoolHostname = request.params["schoolHostname"] as String;
  final String schoolScope = request.params["schoolScope"] as String;

  final List<skola24.School>? schools = await skola24.getSchools(schoolHostname, schoolScope);
  if (schools == null) return Response.internalServerError(body: "Could not get schools");

  return Response.ok(jsonEncode(schools), headers: {"Content-Type": "application/json"});
}

Future<Response> _getClassesHandler(Request request) async {
  final String schoolHostname = request.params["schoolHostname"] as String;
  final String schoolGuid = request.params["schoolGuid"] as String;
  final String schoolScope = request.params["schoolScope"] as String;

  final List<skola24.Class>? classes = await skola24.getClasses(schoolHostname, schoolGuid, schoolScope);
  if (classes == null) return Response.internalServerError(body: "Could not get classes");

  return Response.ok(jsonEncode(classes), headers: {"Content-Type": "application/json"});
}

Future<Response> _getLessonsHandler(Request request) async {
  final String schoolHostname = request.params["schoolHostname"] as String;
  final String schoolGuid = request.params["schoolGuid"] as String;
  final String schoolScope = request.params["schoolScope"] as String;
  final String classGuid = request.params["classGuid"] as String;
  final int weeks = (int.tryParse(request.url.queryParameters["weeks"] ?? "1") ?? 1).clamp(1, 10);
  final int selectionType = int.tryParse(request.url.queryParameters["selectionType"] ?? "0") ?? 0;

  final String? ignoreNamesString = request.url.queryParameters["ignoreNames"];
  final List<String>? ignoreNames = ignoreNamesString?.split(";");

  final List<skola24.Lesson> allLessons = [];

  for (var i = 0; i < weeks; i++) {
    final List<skola24.Lesson>? lessons = await skola24.getLessons(
      schoolHostname,
      schoolGuid,
      schoolScope,
      classGuid,
      extraWeeks: i,
      selectionType: selectionType,
      ignoreNames: ignoreNames,
    );

    if (lessons == null) return Response.internalServerError(body: "Could not get lessons");
    allLessons.addAll(lessons);
  }

  return Response.ok(jsonEncode(allLessons), headers: {"Content-Type": "application/json"});
}
