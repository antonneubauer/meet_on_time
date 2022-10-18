import 'Values.dart';
import 'package:http/http.dart' as http;
import 'dart:convert' show jsonDecode, utf8;

class MyRequest {
  String pwd = Values.pwd;
  String url = Values.url;
  late String sql;
  late Uri uri;
  var queryParameters;

  MyRequest(String sql) {
    this.sql = sql;
    queryParameters = {
      'pwd': pwd,
      'sql': sql,
      'json': 'true',
    };
  }

  Future<String> httpPost() async {
    //funktioniert nicht. gibt XMLHttpRequest error. Hat wohl was mit CORS zu tun
    var myHeaders = {
      'Content-Type': 'text/plain',
      "Access-Control-Allow-Origin": "*",
      "Access-Control-Allow-Methods": "GET,PUT,PATCH,POST,DELETE",
      "Access-Control-Allow-Headers": "Origin, X-Requested-With, Content-Type, Accept"
    };
    final response = await http.get(
        Uri.parse(Values.url +
            "?pwd=" +
            pwd +
            "&sql=" +
            sql.replaceAll(" ", "+").replaceAll(",", "%2C") +
            "&json=true"),
        headers: myHeaders);
    //final response = await http.post(Values.uri, body: queryParameters);
    print("response-len: " + response.body.length.toString());
    return response.body;
  }

  Future<String> getResponse() async {
    final response = await http.get(uri);
    if (response.statusCode == 200) {
      print("got response");
      return response.body;
    }
    return "failed";
  }
}
