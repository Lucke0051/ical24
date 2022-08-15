import 'dart:io';

import 'package:ical/serializer.dart';
import 'package:shelf/shelf.dart';
import 'package:shelf/shelf_io.dart';
import 'package:shelf_router/shelf_router.dart';

import 'skola24.dart' as skola24;

final _router = Router()
  ..get("/", _rootHandler)
  ..get("/ical/<schoolHostname>/<schoolGuid>/<schoolScope>/<classGuid>", _getCalendarHandler);

Future<Response> _rootHandler(Request req) async {
  return Response.ok(
      "/ical/orebro.skola24.se/ZjBiZTJhODQtYWU3Mi1mYWI0LTg1NGMtYTdlMmQ5YzQzYjE1/8a22163c-8662-4535-9050-bc5e1923df48/Mzg4ZGY4YmYtYTc1ZS1mM2JkLTk4NDktMjZiYWNhNDg3NDQ5");
}

void main(List<String> args) async {
  final InternetAddress ip = InternetAddress.anyIPv4;

  final handler = const Pipeline().addMiddleware(logRequests()).addHandler(_router);

  final int port = int.parse(Platform.environment["PORT"] ?? "2005");
  final HttpServer server = await serve(handler, ip, port);
  print("Server listening on port: ${server.port}");
}

Future<Response> _getCalendarHandler(Request request) async {
  final String schoolHostname = request.params["schoolHostname"] as String;
  final String schoolGuid = request.params["schoolGuid"] as String;
  final String schoolScope = request.params["schoolScope"] as String;
  final String classGuid = request.params["classGuid"] as String;

  final List<skola24.Lesson>? lessons = await skola24.getLessons(schoolHostname, schoolGuid, schoolScope, classGuid);
  if (lessons == null) return Response.internalServerError(body: "Could not get lessons");

  final ICalendar calendar = ICalendar(company: "skola24", product: "skola/schema", lang: "SV", refreshInterval: const Duration(hours: 4));
  for (final skola24.Lesson lesson in lessons) {
    final IEvent event = IEvent(
      uid: lesson.guid,
      start: lesson.start,
      end: lesson.end,
      description: lesson.description,
      location: lesson.location,
      summary: lesson.teacher,
    );
    calendar.addElement(event);
  }

  return Response.ok(calendar.serialize(), headers: {"Content-Type": "text/calendar"});
}
