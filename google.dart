import "dart:async";
import "dart:io";
import "dart:convert";

import "package:http/http.dart" as http;

var googleAPIKey = "AIzaSyBNTRakVvRuGHn6AVIhPXE_B3foJDOxmBU";

Future<Map<String, Object>> google(String query) {
  return http.get("http://ajax.googleapis.com/ajax/services/search/web?v=1.0&q=${Uri.encodeComponent(query)}").then((http.Response response) {
    return new Future.value(JSON.decoder.convert(response.body));
  });
}

Future<String> google_shorten(String longUrl) {
  var input = JSON.encode({
    "longUrl": longUrl
  });
  return http.post("https://www.googleapis.com/urlshortener/v1/url?key=${googleAPIKey}", headers: {
    "Content-Type": ContentType.JSON.toString()
  }, body: input).then((http.Response response) {
    Map<String, Object> resp = JSON.decoder.convert(response.body);
    return new Future.value(resp["id"]);
  });
}