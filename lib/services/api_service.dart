import 'dart:convert';
import 'package:http/http.dart' as http;
import '../models/connection_info.dart';

class ApiService {
  // 서버 API 주소 정의
  static const String baseUrl = 'https://fms.iwin.kr/remoteDB';
  static const String testUrl = "$baseUrl/connect_test.php";
  static const String saveUrl = "$baseUrl/connect_info.php";
  static const String infoUrl = "$baseUrl/database_info.php";
  static const String loadUrl = "$baseUrl/db_load.php";
  static const String deleteUrl = "$baseUrl/db_delete.php";
  static const String queryUrl = "$baseUrl/db_query.php";

  // 1. DB 연결을 테스트하는 함수
  static Future<Map<String, dynamic>> testDbConnection(Map<String, dynamic> requestData) async {
    try {
      final response = await http.post(
        Uri.parse(testUrl),
        headers: {"Content-Type": "application/json"},
        body: json.encode(requestData),
      );

      if (response.statusCode == 200) {
        return json.decode(utf8.decode(response.bodyBytes));
      } else {
        return {'success': false, 'message': '서버 응답 오류: ${response.statusCode}'};
      }
    } catch (e) {
      return {'success': false, 'message': '통신 에러가 발생했습니다.'};
    }
  }

  // 2. DB에 연결 정보를 저장하는 함수
  static Future<Map<String, dynamic>> saveConnectionInfo(Map<String, dynamic> connectionData) async {
    try {
      final response = await http.post(
        Uri.parse(saveUrl),
        headers: {"Content-Type": "application/json"},
        body: json.encode(connectionData),
      );

      if (response.statusCode == 200) {
        return json.decode(utf8.decode(response.bodyBytes));
      } else {
        return {'success': false, 'message': '서버 응답 오류: ${response.statusCode}'};
      }
    } catch (e) {
      return {'success': false, 'message': '저장 중 네트워크 에러가 발생했습니다.'};
    }
  }

  // 3. DB 구조 정보(테이블 개수, 목록 등)를 가져오는 함수
  static Future<Map<String, dynamic>> fetchDatabaseInfo(ConnectionInfo info, String targetDbName) async {
    try {
      final Map<String, dynamic> requestData = {
        "host": info.ip,
        "port": info.port,
        "database": targetDbName,
        "user": info.user,
        "password": info.dbPass ?? "",
      };

      final response = await http.post(
        Uri.parse(infoUrl),
        headers: {"Content-Type": "application/json"},
        body: json.encode(requestData),
      );

      if (response.statusCode == 200) {
        return json.decode(utf8.decode(response.bodyBytes));
      } else {
        return {'success': false, 'message': '서버 오류: ${response.statusCode}'};
      }
    } catch (e) {
      return {'success': false, 'message': '네트워크 오류가 발생했습니다.'};
    }
  }

  // 4. 서버에서 저장된 전체 DB 목록을 불러오는 함수
  static Future<List<ConnectionInfo>> loadConnectionsFromServer() async {
    try {
      final response = await http.get(Uri.parse(loadUrl));
      if (response.statusCode == 200) {
        final result = json.decode(utf8.decode(response.bodyBytes));
        if (result['success'] == true && result['data'] != null) {
          List<dynamic> dataList = result['data'];
          return dataList.map((item) => ConnectionInfo.fromJson(item)).toList();
        }
      }
    } catch (e) {
      print("불러오기 에러: $e");
    }
    return [];
  }

  // 5. 서버에서 특정 DB 연결 정보를 삭제하는 함수
  static Future<bool> deleteConnection(ConnectionInfo info) async {
    try {
      final requestData = {
        "ip": info.ip,
        "dbName": info.dbName,
      };
      final response = await http.post(
        Uri.parse(deleteUrl),
        headers: {"Content-Type": "application/json"},
        body: json.encode(requestData),
      );
      if (response.statusCode == 200) {
        final result = json.decode(utf8.decode(response.bodyBytes));
        return result['success'] == true;
      }
    } catch (e) {
      print("삭제 에러: $e");
    }
    return false;
  }

  // 6. SQL 쿼리 실행 함수
  static Future<Map<String, dynamic>> executeQuery(ConnectionInfo info, String targetDb, String query) async {
    try {
      final response = await http.post(
        Uri.parse(queryUrl),
        headers: {"Content-Type": "application/json"},
        body: json.encode({
          "host": info.ip,
          "port": info.port,
          "database": targetDb,
          "user": info.user,
          "password": info.dbPass,
          "query": query
        }),
      );
      return json.decode(utf8.decode(response.bodyBytes));
    } catch (e) {
      return {"success": false, "message": "통신 에러"};
    }
  }

  // 7. 쿼리 이력 저장 요청 (history_save.php)
  static Future<Map<String, dynamic>> saveQueryHistory(ConnectionInfo info, String dbName, String query) async {
    try {
      final response = await http.post(
        Uri.parse('$baseUrl/history_save.php'),
        headers: {"Content-Type": "application/json"}, // 헤더 추가
        body: jsonEncode({
          "host": info.ip,
          "port": info.port,
          "user": info.user,
          "password": info.dbPass,
          "database": dbName,
          "query_text": query,
        }),
      );
      return jsonDecode(utf8.decode(response.bodyBytes)); // 한글 디코딩 추가
    } catch (e) {
      return {'success': false, 'message': e.toString()};
    }
  }

  // 8. 쿼리 이력 불러오기 요청 (history_load.php)
  static Future<Map<String, dynamic>> fetchQueryHistory(ConnectionInfo info, String dbName) async {
    try {
      final response = await http.post(
        Uri.parse('$baseUrl/history_load.php'),
        headers: {"Content-Type": "application/json"}, // 헤더 추가
        body: jsonEncode({
          "host": info.ip,
          "port": info.port,
          "user": info.user,
          "password": info.dbPass,
          "database": dbName,
        }),
      );
      return jsonDecode(utf8.decode(response.bodyBytes)); // 한글 디코딩 추가
    } catch (e) {
      return {'success': false, 'message': e.toString()};
    }
  }
}