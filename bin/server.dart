import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:ical/serializer.dart';
import 'package:shelf/shelf.dart';
import 'package:shelf/shelf_io.dart';
import 'package:shelf_router/shelf_router.dart';

import 'skola24.dart' as skola24;

// /ical/orebro.skola24.se/ZjBiZTJhODQtYWU3Mi1mYWI0LTg1NGMtYTdlMmQ5YzQzYjE1/8a22163c-8662-4535-9050-bc5e1923df48/Mzg4ZGY4YmYtYTc1ZS1mM2JkLTk4NDktMjZiYWNhNDg3NDQ5

final _router = Router()
  ..get("/", _rootHandler)
  ..get("/ical/<schoolHostname>/<schoolGuid>/<schoolScope>/<classGuid>", _getCalendarHandler)
  ..get("/schools/<schoolHostname>/<schoolScope>", _getSchoolsHandler)
  ..get("/classes/<schoolHostname>/<schoolGuid>/<schoolScope>", _getClassesHandler);

Future<Response> _rootHandler(Request req) async {
  return Response.ok(await File("/app/index.html").readAsString(), headers: {"Content-Type": "text/html"});
}

void main(List<String> args) async {
  final InternetAddress ip = InternetAddress.anyIPv4;

  final handler = const Pipeline().addMiddleware(logRequests()).addHandler(_router);

  final int port = int.parse(Platform.environment["PORT"] ?? "2005");
  final HttpServer server = await serve(handler, ip, port);
  print("Server listening on port: ${server.port}");

  Timer.periodic(const Duration(hours: 12), (_) {
    skola24.schoolCache = {};
    skola24.classCache = {};
  });
  Timer.periodic(const Duration(minutes: 30), (_) => skola24.lessonCache = {});
}

Future<Response> _getCalendarHandler(Request request) async {
  final String schoolHostname = request.params["schoolHostname"] as String;
  final String schoolGuid = request.params["schoolGuid"] as String;
  final String schoolScope = request.params["schoolScope"] as String;
  final String classGuid = request.params["classGuid"] as String;
  final int weeks = int.tryParse((request.url.queryParameters["weeks"] as String?) ?? "1") ?? 1;

  final List<skola24.Lesson> allLessons = [];

  for (var i = 0; i < weeks; i++) {
    final List<skola24.Lesson>? lessons = await skola24.getLessons(schoolHostname, schoolGuid, schoolScope, classGuid, weeks: weeks);
    if (lessons == null) return Response.internalServerError(body: "Could not get lessons");
    allLessons.addAll(lessons);
  }

  final ICalendar calendar = ICalendar(company: "skola24", product: "skola/schema", lang: "SV", refreshInterval: const Duration(hours: 4));
  for (final skola24.Lesson lesson in allLessons) {
    final IEvent event = IEvent(
      uid: lesson.guid,
      start: lesson.start,
      end: lesson.end,
      description: lesson.description,
      location: lesson.location,
      summary: lesson.name,
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

  return Response.ok(jsonEncode(schools));
}

Future<Response> _getClassesHandler(Request request) async {
  final String schoolHostname = request.params["schoolHostname"] as String;
  final String schoolGuid = request.params["schoolGuid"] as String;
  final String schoolScope = request.params["schoolScope"] as String;

  final List<skola24.Class>? classes = await skola24.getClasses(schoolHostname, schoolGuid, schoolScope);
  if (classes == null) return Response.internalServerError(body: "Could not get classes");

  return Response.ok(jsonEncode(classes));
}
