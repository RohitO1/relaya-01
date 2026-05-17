import 'package:http/http.dart' as http;
import 'package:flutter/foundation.dart';

void main() async {
  final res = await http.get(Uri.parse("https://text.pollinations.ai/hello%20how%20are%20you"));
  
  debugPrint("Status Code: ${res.statusCode}");
  debugPrint("Body: ${res.body}");
}
