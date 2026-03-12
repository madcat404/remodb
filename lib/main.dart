import 'dart:async';
import 'package:flutter/material.dart';

import 'models/connection_info.dart';
import 'screens/new_connection_dialog.dart';
import 'screens/database_dashboard_screen.dart';
import 'services/api_service.dart';

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'RemoDB',
      theme: ThemeData(
        primaryColor: const Color(0xFF87588E),
        useMaterial3: true,
        scaffoldBackgroundColor: const Color(0xFFF5F5F5),
        colorScheme: ColorScheme.fromSeed(seedColor: const Color(0xFF87588E)),
        appBarTheme: const AppBarTheme(
          backgroundColor: Color(0xFF87588E),
          foregroundColor: Colors.white,
        ),
      ),
      home: const HomeScreen(),
    );
  }
}

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  List<ConnectionInfo> _connections = [];
  final Map<ConnectionInfo, Timer> _connectionTimers = {};

  @override
  void initState() {
    super.initState();
    _loadConnections(); // 앱 시작 시 서버에서 데이터 로드
  }

  @override
  void dispose() {
    for (var timer in _connectionTimers.values) {
      timer.cancel();
    }
    super.dispose();
  }

  // 서버(db_load.php)에서 DB 목록을 가져오는 함수
  Future<void> _loadConnections() async {
    final loadedData = await ApiService.loadConnectionsFromServer();

    if (mounted) {
      setState(() {
        _connections = loadedData;
      });
    }
  }

  // [수정 기능 추가] 연결 정보를 수정하기 위해 다이얼로그를 띄우는 함수
  Future<void> _editConnection(ConnectionInfo info) async {
    // NewConnectionDialog를 띄울 때 현재의 info를 인자로 전달합니다.
    final result = await showDialog<ConnectionInfo>(
      context: context,
      builder: (BuildContext context) {
        return NewConnectionDialog(connectionInfo: info); // 인자 전달
      },
    );

    // 수정 완료 후 반환값이 있다면(저장 성공 시) 목록을 새로고침합니다.
    if (result != null) {
      _loadConnections();
      _showCustomSnackBar('연결 정보가 수정되었습니다.', isSuccess: true);
    }
  }

  // 서버(db_delete.php)에 삭제를 요청하고 성공하면 화면에서도 지웁니다.
  void _deleteConnection(ConnectionInfo info) async {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('삭제 중입니다...'), duration: Duration(seconds: 1)),
    );

    bool isDeleted = await ApiService.deleteConnection(info);

    if (isDeleted) {
      setState(() {
        _connections.remove(info);
      });
      _connectionTimers[info]?.cancel();
      _connectionTimers.remove(info);
      _showCustomSnackBar('삭제 완료', isSuccess: true);
    } else {
      _showCustomSnackBar('서버 삭제 실패', isSuccess: false);
    }
  }

  // 공통 알림 스낵바
  void _showCustomSnackBar(String message, {required bool isSuccess}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: isSuccess ? Colors.green : Colors.red,
      ),
    );
  }

  // 연결 상태 및 타이머 관리
  void _updateConnectionStatus(ConnectionInfo info, bool isConnected) {
    setState(() {
      info.isConnected = isConnected;
    });

    _connectionTimers[info]?.cancel();

    if (isConnected) {
      _connectionTimers[info] = Timer(const Duration(minutes: 10), () {
        if (mounted) {
          setState(() {
            info.isConnected = false;
          });
          _showCustomSnackBar('${info.dbName} 연결이 자동 해제되었습니다.', isSuccess: false);
        }
      });
    }
  }

  Future<void> _connectDatabase(ConnectionInfo info) async {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('연결을 시도 중입니다...'), duration: Duration(seconds: 1)),
    );

    final Map<String, dynamic> requestData = {
      "host": info.ip,
      "port": info.port,
      "database": info.dbName,
      "user": info.user,
      "password": info.dbPass ?? "",
    };

    final result = await ApiService.testDbConnection(requestData);

    if (result['success'] == true) {
      _updateConnectionStatus(info, true);
      _showCustomSnackBar('연결되었습니다.', isSuccess: true);
    } else {
      _showCustomSnackBar('연결 실패: ${result['message']}', isSuccess: false);
    }
  }

  String _getVendorLogo(String vendor) {
    switch (vendor) {
      case 'MySQL': return 'assets/logo/mysql.png';
      case 'MariaDB': return 'assets/logo/maria.png';
      case 'PostgreSQL': return 'assets/logo/postgres.png';
      case 'MSSQL': return 'assets/logo/mssql.png';
      default: return 'assets/logo/mysql.png';
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('RemoDB'),
        leading: const Icon(Icons.menu),
      ),
      body: _connections.isEmpty
          ? Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.storage, size: 80, color: Colors.grey),
            const SizedBox(height: 20),
            const Text('등록된 연결이 없습니다.', style: TextStyle(fontSize: 18, color: Colors.grey)),
          ],
        ),
      )
          : RefreshIndicator(
        onRefresh: _loadConnections,
        child: ListView.builder(
          padding: const EdgeInsets.all(10),
          itemCount: _connections.length,
          itemBuilder: (context, index) {
            return _buildConnectionCard(_connections[index]);
          },
        ),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () async {
          final result = await showDialog<ConnectionInfo>(
            context: context,
            builder: (BuildContext context) {
              return const NewConnectionDialog();
            },
          );

          if (result != null) {
            _loadConnections(); // 새로 추가된 경우 목록 갱신
          }
        },
        backgroundColor: const Color(0xFF2980B9),
        child: const Icon(Icons.add, color: Colors.white, size: 30),
      ),
    );
  }

  Widget _buildConnectionCard(ConnectionInfo info) {
    return Card(
      color: Colors.white,
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8), side: const BorderSide(color: Colors.black12, width: 1)),
      margin: const EdgeInsets.only(bottom: 10),
      child: InkWell(
        borderRadius: BorderRadius.circular(8),
        onTap: () async {
          _updateConnectionStatus(info, true);
          await Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => DatabaseDashboardScreen(connectionInfo: info),
            ),
          );
          setState(() {});
        },
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 12.0, horizontal: 16.0),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 80, height: 80,
                child: Image.asset(
                  _getVendorLogo(info.vendor),
                  fit: BoxFit.contain,
                  errorBuilder: (context, error, stackTrace) => const Icon(Icons.storage, size: 40),
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _infoRow(Icons.dns, info.ip),
                    const SizedBox(height: 6),
                    _infoRow(Icons.storage, info.dbName),
                    const SizedBox(height: 6),
                    _infoRow(Icons.person, info.user),
                    const SizedBox(height: 8),
                    _statusRow(info.isConnected),
                  ],
                ),
              ),
              PopupMenuButton<String>(
                icon: const Icon(Icons.more_vert, color: Colors.grey),
                onSelected: (String value) {
                  switch (value) {
                    case 'connect':
                      _connectDatabase(info);
                      break;
                    case 'disconnect':
                      _updateConnectionStatus(info, false);
                      break;
                    case 'edit':
                      _editConnection(info); // 수정 함수 연결
                      break;
                    case 'delete':
                      _deleteConnection(info);
                      break;
                  }
                },
                itemBuilder: (BuildContext context) => <PopupMenuEntry<String>>[
                  if (!info.isConnected)
                    const PopupMenuItem<String>(value: 'connect', child: Text('Connect')),
                  if (info.isConnected)
                    const PopupMenuItem<String>(value: 'disconnect', child: Text('Disconnect')),
                  const PopupMenuItem<String>(value: 'edit', child: Text('Edit')),
                  const PopupMenuItem<String>(value: 'delete', child: Text('Delete')),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _infoRow(IconData icon, String text) {
    return Row(
      children: [
        Icon(icon, size: 16, color: Colors.grey[600]),
        const SizedBox(width: 8),
        Text(text, style: const TextStyle(fontSize: 14)),
      ],
    );
  }

  Widget _statusRow(bool isConnected) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: isConnected ? Colors.green[50] : Colors.red[50],
        borderRadius: BorderRadius.circular(4),
      ),
      child: Text(
        isConnected ? 'Connected' : 'Disconnected',
        style: TextStyle(fontSize: 12, color: isConnected ? Colors.green[700] : Colors.red[700]),
      ),
    );
  }
}