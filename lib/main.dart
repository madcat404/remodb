import 'dart:convert';
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
        primaryColor: const Color(0xFF34495E),
        useMaterial3: true,
        scaffoldBackgroundColor: const Color(0xFFF5F5F5),
        colorScheme: ColorScheme.fromSeed(seedColor: const Color(0xFF34495E)),
        appBarTheme: const AppBarTheme(
          backgroundColor: Color(0xFF34495E),
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

  // [핵심 수정됨] 로컬 저장소가 아닌 서버(db_load.php)에서 DB 목록을 가져옵니다.
  Future<void> _loadConnections() async {
    final loadedData = await ApiService.loadConnectionsFromServer();

    if (mounted) {
      setState(() {
        _connections = loadedData;
      });
    }
  }

  // 화면에 카드를 추가하는 함수 (서버 저장은 다이얼로그에서 이미 처리됨)
  void _addConnection(ConnectionInfo info) {
    setState(() {
      _connections.add(info);
    });
  }

  // [핵심 수정됨] 서버(db_delete.php)에 삭제를 요청하고 성공하면 화면에서도 지웁니다.
  void _deleteConnection(ConnectionInfo info) async {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('삭제 중입니다...'), duration: Duration(seconds: 1)),
    );

    bool isDeleted = await ApiService.deleteConnection(info);

    if (isDeleted) {
      setState(() {
        _connections.remove(info);
      });
      // 혹시 돌고 있던 10분 타이머가 있다면 취소
      _connectionTimers[info]?.cancel();
      _connectionTimers.remove(info);

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('삭제 완료'), backgroundColor: Colors.green),
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('서버 삭제 실패'), backgroundColor: Colors.red),
      );
    }
  }

  // 연결 상태를 변경하고, 10분 타이머를 관리하는 통합 함수
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
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('${info.dbName} 데이터베이스 연결이 자동 해제되었습니다.'),
              backgroundColor: Colors.orange,
            ),
          );
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
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('연결되었습니다.'), backgroundColor: Colors.green),
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('연결 실패: ${result['message']}'), backgroundColor: Colors.red),
      );
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
            Stack(
              alignment: Alignment.center,
              children: [
                Container(width: 220, height: 220, decoration: const BoxDecoration(color: Color(0xFF4FC3F7), shape: BoxShape.circle)),
                Column(
                  children: const [
                    Icon(Icons.cloud, size: 80, color: Colors.white),
                    SizedBox(height: 5),
                    Icon(Icons.storage, size: 80, color: Color(0xFF424242)),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 40),
            const Text('원격 DB 관리 시스템', style: TextStyle(fontSize: 26, fontWeight: FontWeight.bold, color: Color(0xFF2C3E50))),
            const SizedBox(height: 10),
            const Text('데이터를 조회하려면 아래 버튼을 클릭하세요.', style: TextStyle(fontSize: 16, color: Colors.grey)),
          ],
        ),
      )
          : RefreshIndicator( // [추가됨] 화면을 아래로 당기면 서버에서 다시 로드하는 기능
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
            _addConnection(result);
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

          if (info.isConnected) {
            _updateConnectionStatus(info, true);
          }
        },
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 12.0, horizontal: 16.0),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 100, height: 100,
                decoration: BoxDecoration(borderRadius: BorderRadius.circular(8), color: Colors.transparent),
                child: Image.asset(
                  _getVendorLogo(info.vendor),
                  fit: BoxFit.contain,
                  errorBuilder: (context, error, stackTrace) => const Icon(Icons.storage, size: 50, color: Colors.grey),
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
                padding: EdgeInsets.zero,
                color: Colors.white,
                elevation: 3,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                onSelected: (String value) {
                  switch (value) {
                    case 'connect':
                      _connectDatabase(info);
                      break;
                    case 'disconnect':
                      _updateConnectionStatus(info, false);
                      break;
                    case 'edit':
                      break;
                    case 'copy':
                      break;
                    case 'delete':
                      _deleteConnection(info);
                      break;
                  }
                },
                itemBuilder: (BuildContext context) => <PopupMenuEntry<String>>[
                  if (!info.isConnected)
                    const PopupMenuItem<String>(value: 'connect', child: Text('Connect', style: TextStyle(fontSize: 16))),
                  if (info.isConnected)
                    const PopupMenuItem<String>(value: 'disconnect', child: Text('Disconnect', style: TextStyle(fontSize: 16))),

                  const PopupMenuItem<String>(value: 'edit', child: Text('Edit', style: TextStyle(fontSize: 16))),
                  const PopupMenuItem<String>(value: 'copy', child: Text('Copy', style: TextStyle(fontSize: 16))),
                  const PopupMenuItem<String>(value: 'delete', child: Text('Delete', style: TextStyle(fontSize: 16))),
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
        Icon(icon, size: 18, color: Colors.grey[600]),
        const SizedBox(width: 8),
        Text(text, style: TextStyle(fontSize: 15, color: Colors.grey[700], fontWeight: FontWeight.w400)),
      ],
    );
  }

  Widget _statusRow(bool isConnected) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
      decoration: BoxDecoration(
        color: isConnected ? Colors.green[50] : Colors.red[50],
        border: Border.all(color: Colors.black12),
        borderRadius: BorderRadius.circular(4),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            isConnected ? Icons.link : Icons.link_off,
            size: 16,
            color: isConnected ? Colors.green[700] : Colors.redAccent,
          ),
          const SizedBox(width: 6),
          Text(
            isConnected ? 'Connected' : 'Disconnected',
            style: TextStyle(
              fontSize: 13,
              color: isConnected ? Colors.green[700] : Colors.redAccent,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}