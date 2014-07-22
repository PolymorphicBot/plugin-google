import "google.dart";

import 'package:plugins/plugin.dart';
import 'dart:isolate';

Receiver recv;

void main(List<String> args, SendPort port) {
  print("[Google] Loading");
  recv = new Receiver(port);

  recv.listen((data) {
    if (data["event"] == "command") {
      handle_command(data);
    }
  });
}

void handle_command(data) {
  void reply(String message) {
    recv.send({
      "network": data["network"],
      "target": data["target"],
      "command": "message",
      "message": message
    });
  }

  switch (data["command"]) {
    case "google":
      var args = data["args"];
      if (args.length == 0) {
        reply("> Usage: google <query>");
      } else {
        var query = args.join(" ");
        google(query).then((resp) {
          var results = resp["responseData"]["results"];
          if (results.length == 0) {
            reply("> No Results Found!");
          } else {
            var result = results[0];
            reply("> ${result["titleNoFormatting"]} | ${result["unescapedUrl"]}");
          }
        });
      }
      break;
    case "shorten":
      var args = data["args"];
      if (args.length == 0) {
        reply("> Usage: shorten <url>");
      } else {
        var url = args.join(" ");
        google_shorten(url).then((shortened) {
          if (shortened == null) {
            reply("> Failed to Shorten URL.");
          } else {
            reply("> ${shortened}");
          }
        });
      }
      break;
  }
}