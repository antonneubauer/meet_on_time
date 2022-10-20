import 'dart:async';
import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'dart:math' show cos, sqrt, asin;
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:meet_on_time/MyRequest.dart';
import 'package:meet_on_time/WeatherData.dart';
import 'package:device_info_plus/device_info_plus.dart';
import 'dart:io';
import 'Values.dart';

const UPLOAD_INTERVAL = Duration(seconds: 15);

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

  var timer;

  late StreamSubscription<Position> positionStream;
  List<Position> positions = [];
  int positionsLength = 0;
  List<int> timeStamps = [];
  List<WeatherData> weather = [];

  bool loggedIn = false;
  late var deviceID;
  bool isRecording = false;
//in database
  int sessionID = -1;
  late int userID;
  String long = "", lat = "";
  String lastTimeStamp = "";
  String lastVelocity = "";

  @override
  void initState() {
    checkGps();
    setDeviceID();
    super.initState();
  }

  @override
  void dispose() {
    timer?.cancel();
    super.dispose();
  }

  setDeviceID() async{
    deviceID = await _getDeviceId();
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

    long = position.longitude.toString();
    lat = position.latitude.toString();
    print("pos: ($long, $lat)");
    positions.add(position);
    positionsLength = positions.length;
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
      lastVelocity = velocityInKmH.toStringAsFixed(3);
    });
  }

  Future<WeatherData> getCurrentWeather(double lat, double lon) async {
    WeatherData currentWeather = await WeatherData.weatherDataGet(lat, lon);
    weather.add(currentWeather);
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
              Text(servicestatus ? "servicestatus GPS is Enabled" : "servicestatus GPS is disabled."),
              Text(haspermission ? "haspermission GPS is Enabled" : "haspermission GPS is disabled."),
              Text("Pos: ($lat, $long)"),
              Text("Last Timestamp: $lastTimeStamp"),
              Text("Last Velocity: $lastVelocity km/h"),
              Text("Waypoint count: $positionsLength"),
              Text(sessionID == -1?"":"sessionID: $sessionID"),
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
                child: Text('Login with new Session'),
                onPressed: () {
                  getNewSessionID();
                  setState(() {});
                },
              ),
              ElevatedButton(
                child: Text('upload waypoint'),
                onPressed: () {
                  uploadLastWaypoint();
                  setState(() {});
                },
              ),
              ElevatedButton(
                child: Text(isRecording ? 'finish recording' : 'start recording'),
                onPressed: () {
                  if (isRecording) {
                    stopRecording();
                  } else {
                    startRecording();
                  }
                  setState(() {
                    isRecording = !isRecording;
                  });
                },
                style: ElevatedButton.styleFrom(
                    backgroundColor: isRecording?Colors.redAccent:Colors.lightGreen
                )
              )
            ])));
  }

  startRecording() async {
    print("start recording");
    await getNewSessionID();
    await measureAndUpload();
    timer = Timer.periodic(UPLOAD_INTERVAL, (Timer t) => measureAndUpload());
  }
  stopRecording() async{
    print("stop recording");
    timer?.cancel();
  }
  measureAndUpload() async{
    print("automatic measureAndUpload");
    await loginIfNotLoggedIn();
    await addWayPoint();
    await uploadLastWaypoint();
    setState(() {});
  }

  loginIfNotLoggedIn() async {
    if (!loggedIn) {
      print("logging in");
      await sendLoginRequest();
    }
  }

  uploadLastWaypoint() async {
    await loginIfNotLoggedIn();
    if (long == "") {
      await addWayPoint();
    }
    var uploadSQL =
        "insert into meet_on_time_data (session_id, longitude, latitude, timestamp) values ('$sessionID', '$long', '$lat', '$lastTimeStamp')";
    await sqlNoResult(uploadSQL);
  }

  sendLoginRequest() async{
    var existingUserSQL = "select count(id) from meet_on_time_users where device_id='$deviceID'";
    String userCount = await sqlResult(existingUserSQL, "count(id)", 0);
    if(userCount == "0"){
      print("creating new user");
      var createUser =
          "insert into meet_on_time_users (device_id) values ('$deviceID')"; //TODO: also add alias
      await sqlNoResult(createUser);
    }
    var getUserIdSQL = "select id from meet_on_time_users where device_id='$deviceID'";
    userID = int.parse(await sqlResult(getUserIdSQL, "id", 0));
    print("userID=$userID");

    loggedIn = true;
  }
  getNewSessionID() async{
    await loginIfNotLoggedIn();

    print("init session");
    var initSessionSQL = "insert into meet_on_time_sessions (user_id) values ('$userID')";
    await sqlNoResult(initSessionSQL);

    //get newest sessionID
    var getSessionIdSQL = "select max(id) from meet_on_time_sessions where user_id='$userID'";
    sessionID = int.parse(await sqlResult(getSessionIdSQL, "max(id)", 0));
    print("sessionID=$sessionID");
  }
}

Future<String?> _getDeviceId() async {
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

Future<String> sqlResult(String sql, String key, int row) async {
  var resp = await new MyRequest(sql).getResponse();
  print(resp);
  var respJSON = json.decode(resp);
  return (respJSON[row][key]);
}

sqlNoResult(String sql) async {
  await new MyRequest(sql).getResponse();
}

double calculateDistance(lat1, lon1, lat2, lon2) {
  var p = 0.017453292519943295;
  var c = cos;
  var a =
      0.5 - c((lat2 - lat1) * p) / 2 + c(lat1 * p) * c(lat2 * p) * (1 - c((lon2 - lon1) * p)) / 2;
  return 12742 * asin(sqrt(a));
}
