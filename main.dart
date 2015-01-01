import "google.dart";

import "package:polymorphic_bot/api.dart";

import 'package:http/http.dart' as http;
import 'package:irc/client.dart' show Color;
import 'dart:convert';

BotConnector bot;

void main(args, Plugin plugin) {
  bot = plugin.getBot();
  
  plugin.addRemoteMethod("shorten", (request) {
    googleShorten(request.data['url']).then((short) {
      request.reply({ "shortened": short });
    });
  });
  
  bot.command("google", (event) {
    var args = event.args;
    if (args.length == 0) {
      event.reply("> Usage: google <query>");
    } else {
      var query = args.join(" ");
      google(query).then((resp) {
        var results = resp["responseData"]["results"];
        if (results.length == 0) {
          event.reply("> No Results Found!");
        } else {
          var result = results[0];
          event.reply("> ${result["titleNoFormatting"]} | ${result["unescapedUrl"]}");
        }
      });
    }
  });
  
  bot.command("shorten", (event) {
    var args = event.args;
    if (args.length == 0) {
      event.reply("> Usage: shorten <url>");
    } else {
      var url = args.join(" ");
      googleShorten(url).then((shortened) {
        if (shortened == null) {
          event.reply("> Failed to Shorten URL.");
        } else {
          event.reply("> ${shortened}");
        }
      });
    }
  });
  
  bot.onMessage((event) {
    handleYouTube(event);
  });
}

var LINK_REGEX = new RegExp(r'\(?\b((http|https)://|www[.])[-A-Za-z0-9+&@#/%?=~_()|!:,.;]*[-A-Za-z0-9+&@#/%=~_()|]');
var YT_INFO_LINK = 'https://www.googleapis.com/youtube/v3/videos?part=snippet,statistics,contentDetails&key=${googleAPIKey}&id=';
var YT_LINK_ID = new RegExp(r'^.*(youtu.be/|v/|embed/|watch\?|youtube.com/user/[^#]*#([^/]*?/)*)\??v?=?([^#\&\?]*).*');
var DURATION_PARSER = new RegExp(r'^([0-9]+(?:[,\.][0-9]+)?H)?([0-9]+(?:[,\.][0-9]+)?M)?([0-9]+(?:[,\.][0-9]+)?S)?$');

void handleYouTube(MessageEvent event) {
  if (LINK_REGEX.hasMatch(event.message)) {
    LINK_REGEX.allMatches(event.message).forEach((match) {
      var url = match.group(0);
      if (url.contains("youtube") || url.contains("youtu.be")) {
        outputYouTubeInfo(event, url);
      }
    });
  }
}

void outputYouTubeInfo(MessageEvent event, String url) {
  var id = extractYouTubeID(url);
  
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

void printYouTubeInfo(MessageEvent event, info) {
  void reply(String message) {
    bot.message(event.network, event.target, message);
  }
  
  var snippet = info["snippet"];
  var timeInput = info['contentDetails']['duration'].substring(2);
  var match = DURATION_PARSER.firstMatch(timeInput);
  var hours = match.group(1) != null ? int.parse(match.group(1).replaceAll('H', '')) : 0;
  var minutes = match.group(2) != null ? int.parse(match.group(2).replaceAll('M', '')) : 0;
  var seconds = match.group(3) != null ? int.parse(match.group(3).replaceAll('S', '')) : 0;
  var duration = new Duration(hours: hours, minutes: minutes, seconds: seconds).toString();
  duration = duration.substring(0, duration.length - 7);
  
  reply("${fancyPrefix("YouTube")} ${snippet['title']} | ${snippet['channelTitle']} (${Color.GREEN}${info['statistics']['likeCount']}${Color.RESET}:${Color.RED}${info['statistics']['dislikeCount']}${Color.RESET}) (${duration})");
}

String fancyPrefix(String name) {
  return "[${Color.BLUE}${name}${Color.RESET}]";
}

String extractYouTubeID(String url) {
  var first = YT_LINK_ID.firstMatch(url);

  if (first == null) {
    return null;
  }
  return first.group(3);
}

