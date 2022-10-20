import 'dart:async';
import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'dart:math' show cos, sqrt, asin;
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:meet_on_time/MyRequest.dart';
import 'package:device_info_plus/device_info_plus.dart';
import 'dart:io';

void main() {
  runApp(MyApp());
}

class MyApp extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return MaterialApp(home: Home());
  }
}

class Home extends StatefulWidget {
  @override
  State<Home> createState() => _HomeState();
}

class _HomeState extends State<Home> {
  bool servicestatus = false;
  bool haspermission = false;
  late LocationPermission permission;
  late Position position;
  String long = "", lat = "";
  String lastTimeStamp = "";
  String lastVelocity = "";
  late StreamSubscription<Position> positionStream;
  List<Position> positions = [];
  List<int> timeStamps = [];
  List<Weather> weather = [];

  @override
  void initState() {
    checkGps();
    super.initState();
  }

  checkGps() async {
    servicestatus = await Geolocator.isLocationServiceEnabled();
    if (servicestatus) {
      permission = await Geolocator.checkPermission();

      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.denied) {
          print('Location permissions are denied');
        } else if (permission == LocationPermission.deniedForever) {
          print("'Location permissions are permanently denied");
        } else {
          haspermission = true;
        }
      } else {
        haspermission = true;
      }

      if (haspermission) {
        setState(() {
          //refresh the UI
        });
      }
    } else {
      print("GPS Service is not enabled, turn on GPS location");
    }

    setState(() {
      //refresh the UI
    });
  }

  addWayPoint() async {
    await getLocation();
    getTimeStamp();
    calcVelocity();
  }

  getLocation() async {
    print("getting location");
    position = await Geolocator.getCurrentPosition(desiredAccuracy: LocationAccuracy.high);
    print("pos: ");
    print(position.longitude); //Output: 80.24599079
    print(position.latitude); //Output: 29.6593457

    long = position.longitude.toString();
    lat = position.latitude.toString();
    positions.add(position);
    setState(() {
      //refresh UI
    });
  }

  subscribeLocation() async {
    LocationSettings locationSettings = LocationSettings(
      accuracy: LocationAccuracy.high, //accuracy of the location data
      distanceFilter: 100, //minimum distance (measured in meters) a
      //device must move horizontally before an update event is generated;
    );

    // ignore: cancel_subscriptions
    StreamSubscription<Position> positionStream =
        Geolocator.getPositionStream(locationSettings: locationSettings)
            .listen((Position position) {
      print("location changed");
      print(position.longitude); //Output: 80.24599079
      print(position.latitude); //Output: 29.6593457

      long = position.longitude.toString();
      lat = position.latitude.toString();
      positions.add(position);

      setState(() {
        //refresh UI on update
      });
    });
  }

  getTimeStamp() {
    int timeStamp = DateTime.now().millisecondsSinceEpoch;
    print(timeStamp);
    lastTimeStamp = timeStamp.toString();
    timeStamps.add(timeStamp);
  }

  calcVelocity() {
    try {
      assert(positions.length == timeStamps.length);
    } catch (e) {
      print("fehler: positions.length != timeStamps.length");
      setState(() {
        lastVelocity = "fehler";
      });
      return;
    }
    int numberOfEntries = positions.length;
    if (numberOfEntries < 2) return;
    Position p1 = positions.last;
    Position p2 = positions[numberOfEntries - 2];
    double distInKm = calculateDistance(p1.latitude, p1.longitude, p2.latitude, p2.longitude);
    double timeInHours = (timeStamps.last - timeStamps[numberOfEntries - 2]) / 3600000;
    double velocityInKmH = distInKm / timeInHours;
    print("v=$velocityInKmH");
    setState(() {
      lastVelocity = velocityInKmH.toString();
    });
  }

  getAPIKey() {
    return Values.openweatherApiKey;
  }

  buildWeatherRequestURI(double lat, double lon) {
    // https://api.openweathermap.org/data/2.5/weather?lat={double}&lon={double}&appid={API-key}
    String baseURL = "https://api.openweathermap.org/data/2.5/weather?";
    String apiKey = getAPIKey();

    String requestURI = "${baseURL}lat=$lat&lon=$lon&appid=$apiKey";

    print(requestURI);

    return requestURI;
  }

  Future<Weather> getCurrentWeather(double lat, double lon) async {
    int timeStamp = DateTime.now().millisecondsSinceEpoch;
    var requestURL = Uri.parse(buildWeatherRequestURI(lat, lon));
    var response = await http.get(requestURL);
    Map<String, dynamic> contents = json.decode(response.body);
    print(contents);
    Weather currentWeather = Weather(timeStamp, contents);
    currentWeather.show();
    return currentWeather;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
        appBar: AppBar(title: Text("Get GPS Location"), backgroundColor: Colors.redAccent),
        body: Container(
            alignment: Alignment.center,
            padding: EdgeInsets.all(50),
            child: Column(children: [
              Text(servicestatus ? "GPS is Enabled" : "GPS is disabled."),
              Text(haspermission ? "GPS is Enabled" : "GPS is disabled."),
              Text("Longitude: $long", style: TextStyle(fontSize: 20)),
              Text(
                "Latitude: $lat",
                style: TextStyle(fontSize: 20),
              ),
              Text(
                "Last Timestamp: $lastTimeStamp",
                style: TextStyle(fontSize: 20),
              ),
              Text(
                "Last Velocity: $lastVelocity km/h",
                style: TextStyle(fontSize: 20),
              ),
              ElevatedButton(
                child: Text('Measure'),
                onPressed: () {
                  setState(() {
                    print("pressed");
                    addWayPoint();
                  });
                },
              ),
              ElevatedButton(
                child: Text('getWeather'),
                onPressed: () {
                  setState(() {
                    print("gettingWeather");
                    getCurrentWeather(position.latitude, position.longitude);
                  });
                },
              ),
              ElevatedButton(
                child: Text('Login'),
                onPressed: () {
                  sendLoginRequest();
                  setState(() {});
                },
              )
            ])));
  }
}

sendLoginRequest() async {
  var myRequest;
  //funktioniert
  //myRequest = new MyRequest("SELECT * FROM meet_on_time_sessions");

  //die geben alle 503
  //myRequest = new MyRequest("insert into meet_on_time_users (device_id, alias) values ('wer', 'er');");
  //myRequest = new MyRequest("insert into meet_on_time_users device_id alias values wer er");
  print(await (new MyRequest(
          "insert into meet_on_time_users (device_id, alias) values ('w23er', 'er23');")
      .getResponse()));

  //myRequest = new MyRequest("INSERT INTO `meet_on_time_data` (`ID`, `session_id`, `longitude`, `latitude`, `timestamp`) VALUES (NULL, '121233', '3321', '2334', '2342343');");
  //myRequest = new MyRequest("INSERT INTO meet_on_time_sessions (ID) VALUES (NULL);");

  //Map<String, dynamic> contents = json.decode(response);
  //print(contents);
}

class Weather {
  late int sessionID; // for later use?
  late int timestamp;
  late double windStrength; // speed + gust / 2
  late int windDirectionDeg;
  late double rainLastHour;

  Weather(int timestamp, json) {
    this.sessionID = -1;
    this.timestamp = timestamp;
    this.windStrength = ((json['wind']['speed'] as double) + (json['wind']['gust'] as double)) / 2;
    this.windDirectionDeg = json['wind']['deg'] as int;
    if (json['rain'] != null) {
      this.rainLastHour = json['rain']['1h'] as double;
    }
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

Future<String?> _getId() async {
  var deviceInfo = DeviceInfoPlugin();
  if (Platform.isIOS) {
    // import 'dart:io'
    var iosDeviceInfo = await deviceInfo.iosInfo;
    return iosDeviceInfo.identifierForVendor; // unique ID on iOS
  } else if (Platform.isAndroid) {
    var androidDeviceInfo = await deviceInfo.androidInfo;
    return androidDeviceInfo.androidId; // unique ID on Android
  } else {
    return "browser";
  }
}
//helper

double calculateDistance(lat1, lon1, lat2, lon2) {
  var p = 0.017453292519943295;
  var c = cos;
  var a =
      0.5 - c((lat2 - lat1) * p) / 2 + c(lat1 * p) * c(lat2 * p) * (1 - c((lon2 - lon1) * p)) / 2;
  return 12742 * asin(sqrt(a));
}
