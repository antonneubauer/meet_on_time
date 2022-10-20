import 'dart:convert';
import 'Values.dart';
import 'package:http/http.dart' as http;

class WeatherData {
  late int sessionID; // for later use?
  late int timestamp;
  late double windStrength; // speed + gust / 2
  late int windDirectionDeg;
  late double rainLastHour;

  WeatherData.set(int timestamp, json) {
    this.sessionID = -1;
    this.timestamp = timestamp;
    this.windStrength = ((json['wind']['speed'] as double) + (json['wind']['gust'] as double)) / 2;
    this.windDirectionDeg = json['wind']['deg'] as int;
    if (json['rain'] != null) {
      this.rainLastHour = json['rain']['1h'] as double;
    }
    this.show();
  }

  static Future<WeatherData> weatherDataGet(double lat, double lon) async {
    int timeStamp = DateTime.now().millisecondsSinceEpoch;
    var requestURL = Uri.parse(buildWeatherRequestURI(lat, lon));

    var response = await http.get(requestURL);
    Map<String, dynamic> contents = json.decode(response.body);

    return WeatherData.set(timeStamp, contents);
  }

  static buildWeatherRequestURI(double lat, double lon) {
    // https://api.openweathermap.org/data/2.5/weather?lat={double}&lon={double}&appid={API-key}
    String baseURL = "https://api.openweathermap.org/data/2.5/weather?";
    String apiKey = Values.openWeatherApiKey;
    String requestURI = "${baseURL}lat=$lat&lon=$lon&appid=$apiKey";

    return requestURI;
  }

  show() {
    print("current Weather:");
    print("sessionID: " + this.sessionID.toString());
    print("timestamp: " + this.timestamp.toString());
    print("windStrength: " + this.windStrength.toString());
    print("windDirectionDeg: " + this.windDirectionDeg.toString());
    print("rainLastHour: " + this.rainLastHour.toString());
  }
}
