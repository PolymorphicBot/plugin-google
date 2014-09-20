import "google.dart";

import 'package:plugins/plugin.dart';
import 'dart:isolate';
import 'package:http/http.dart' as http;
import 'package:irc/irc.dart';
import 'dart:convert';

Receiver recv;

void main(List<String> args, SendPort port) {
  print("[Google] Loading");
  recv = new Receiver(port);

  recv.listen((data) {
    if (data["event"] == "command") {
      handleCommand(data);
    } else if (data['event'] == "message") {
      handleYouTube(data);
    }
  });
  
  recv.listenRequest((request) {
    if (request.command == "shorten") {
      google_shorten(request.data['url']).then((short) {
        request.reply({ "shortened": short });
      });
    }
  });
}

var link_regex = new RegExp(r'\(?\b((http|https)://|www[.])[-A-Za-z0-9+&@#/%?=~_()|!:,.;]*[-A-Za-z0-9+&@#/%=~_()|]');
var YT_INFO_LINK = 'https://www.googleapis.com/youtube/v3/videos?part=snippet,statistics&key=${googleAPIKey}&id=';
var _yt_link_id = new RegExp(r'^.*(youtu.be/|v/|embed/|watch\?|youtube.com/user/[^#]*#([^/]*?/)*)\??v?=?([^#\&\?]*).*');

void handleYouTube(event) {
  if (link_regex.hasMatch(event["message"])) {
    link_regex.allMatches(event['message']).forEach((match) {
      var url = match.group(0);
      if (url.contains("youtube") || url.contains("youtu.be")) {
        outputYouTubeInfo(event, url);
      }
    });
  }
}

void outputYouTubeInfo(event, String url) {
  var id = extract_yt_id(url);
  
  if (id == null) {
    return;
  }
  
  var request_url = "${YT_INFO_LINK}${id}";
  
  http.get(request_url).then((http.Response response) {
    var data = JSON.decode(response.body);
    var items = data['items'];
    var video = items[0];
    printYouTubeInfo(event, video);
  });
}

void printYouTubeInfo(data, info) {
  void reply(String message) {
    recv.send({
      "network": data["network"],
      "target": data["target"],
      "command": "message",
      "message": message
    });
  }
  
  var snippet = info["snippet"];
  
  reply("${fancyPrefix("YouTube")} ${snippet['title']} | ${snippet['channelTitle']} (${Color.GREEN}${info['statistics']['likeCount']}${Color.RESET}:${Color.RED}${info['statistics']['dislikeCount']}${Color.RESET})");
}

String fancyPrefix(String name) {
  return "[${Color.BLUE}${name}${Color.RESET}]";
}

String extract_yt_id(url) {
  var first = _yt_link_id.firstMatch(url);

  if (first == null) {
    return null;
  }
  return first.group(3);
}

void handleCommand(data) {
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