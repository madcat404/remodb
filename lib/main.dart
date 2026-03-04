import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  runApp(const MyApp());
}

// 1. 데이터를 담을 모델 클래스 (필드 추가됨)
class ConnectionInfo {
  final String vendor;
  final String ip;
  final String port;
  final String dbName;
  final String user;

  // SSH 관련
  final bool useSSH;
  final String? sshHost;
  final String? sshPort; // [New] SSH 포트
  final String? sshUser;
  final bool usePrivateKey; // [New] 개인키 사용 여부
  final String? sshPass;

  // Other 관련 [New]
  final String? description;
  final String? pictureUrl;

  ConnectionInfo({
    required this.vendor,
    required this.ip,
    required this.port,
    required this.dbName,
    required this.user,
    this.useSSH = false,
    this.sshHost,
    this.sshPort,
    this.sshUser,
    this.usePrivateKey = false,
    this.sshPass,
    this.description,
    this.pictureUrl,
  });

  Map<String, dynamic> toJson() {
    return {
      'vendor': vendor,
      'ip': ip,
      'port': port,
      'dbName': dbName,
      'user': user,
      'useSSH': useSSH,
      'sshHost': sshHost,
      'sshPort': sshPort,
      'sshUser': sshUser,
      'usePrivateKey': usePrivateKey,
      'sshPass': sshPass,
      'description': description,
      'pictureUrl': pictureUrl,
    };
  }

  factory ConnectionInfo.fromJson(Map<String, dynamic> json) {
    return ConnectionInfo(
      vendor: json['vendor'],
      ip: json['ip'],
      port: json['port'],
      dbName: json['dbName'],
      user: json['user'],
      useSSH: json['useSSH'] ?? false,
      sshHost: json['sshHost'],
      sshPort: json['sshPort'],
      sshUser: json['sshUser'],
      usePrivateKey: json['usePrivateKey'] ?? false,
      sshPass: json['sshPass'],
      description: json['description'],
      pictureUrl: json['pictureUrl'],
    );
  }
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

  @override
  void initState() {
    super.initState();
    _loadConnections();
  }

  Future<void> _loadConnections() async {
    final prefs = await SharedPreferences.getInstance();
    final List<String>? jsonStringList = prefs.getStringList('connections');

    if (jsonStringList != null) {
      setState(() {
        _connections = jsonStringList
            .map((item) => ConnectionInfo.fromJson(jsonDecode(item)))
            .toList();
      });
    }
  }

  Future<void> _saveConnections() async {
    final prefs = await SharedPreferences.getInstance();
    final List<String> jsonStringList = _connections
        .map((item) => jsonEncode(item.toJson()))
        .toList();

    await prefs.setStringList('connections', jsonStringList);
  }

  void _addConnection(ConnectionInfo info) {
    setState(() {
      _connections.add(info);
    });
    _saveConnections();
  }

  void _deleteConnection(ConnectionInfo info) {
    setState(() {
      _connections.remove(info);
    });
    _saveConnections();
  }

  String _getVendorLogo(String vendor) {
    switch (vendor) {
      case 'MySQL':
        return 'assets/logo/mysql.png';
      case 'MariaDB':
        return 'assets/logo/maria.png';
      case 'PostgreSQL':
        return 'assets/logo/postgres.png';
      case 'MSSQL':
        return 'assets/logo/mssql.png';
      default:
        return 'assets/logo/mysql.png';
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
                Container(
                  width: 220,
                  height: 220,
                  decoration: const BoxDecoration(
                    color: Color(0xFF4FC3F7),
                    shape: BoxShape.circle,
                  ),
                ),
                Column(
                  children: const [
                    Icon(Icons.cloud, size: 80, color: Colors.white),
                    SizedBox(height: 5),
                    Icon(Icons.storage,
                        size: 80, color: Color(0xFF424242)),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 40),
            const Text(
              '원격 DB 관리 시스템',
              style: TextStyle(
                fontSize: 26,
                fontWeight: FontWeight.bold,
                color: Color(0xFF2C3E50),
              ),
            ),
            const SizedBox(height: 10),
            const Text(
              '데이터를 조회하려면 아래 버튼을 클릭하세요.',
              style: TextStyle(fontSize: 16, color: Colors.grey),
            ),
          ],
        ),
      )
          : ListView.builder(
        padding: const EdgeInsets.all(10),
        itemCount: _connections.length,
        itemBuilder: (context, index) {
          return _buildConnectionCard(_connections[index]);
        },
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
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(8),
        side: const BorderSide(color: Colors.black12, width: 1),
      ),
      margin: const EdgeInsets.only(bottom: 10),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 12.0, horizontal: 16.0),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 100,
              height: 100,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(8),
                color: Colors.transparent,
              ),
              child: Image.asset(
                _getVendorLogo(info.vendor),
                fit: BoxFit.contain,
                errorBuilder: (context, error, stackTrace) {
                  return const Icon(Icons.storage,
                      size: 50, color: Colors.grey);
                },
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
                ],
              ),
            ),
            PopupMenuButton<String>(
              icon: const Icon(Icons.more_vert, color: Colors.grey),
              padding: EdgeInsets.zero,
              constraints: const BoxConstraints(),
              color: Colors.white,
              elevation: 3,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
              onSelected: (String value) {
                switch (value) {
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
                const PopupMenuItem<String>(
                  value: 'edit',
                  child: Text('Edit', style: TextStyle(fontSize: 16)),
                ),
                const PopupMenuItem<String>(
                  value: 'copy',
                  child: Text('Copy', style: TextStyle(fontSize: 16)),
                ),
                const PopupMenuItem<String>(
                  value: 'delete',
                  child: Text('Delete', style: TextStyle(fontSize: 16)),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _infoRow(IconData icon, String text) {
    return Row(
      children: [
        Icon(icon, size: 18, color: Colors.grey[600]),
        const SizedBox(width: 8),
        Text(
          text,
          style: TextStyle(
            fontSize: 15,
            color: Colors.grey[700],
            fontWeight: FontWeight.w400,
          ),
        ),
      ],
    );
  }
}

class NewConnectionDialog extends StatefulWidget {
  const NewConnectionDialog({super.key});

  @override
  State<NewConnectionDialog> createState() => _NewConnectionDialogState();
}

class _NewConnectionDialogState extends State<NewConnectionDialog> {
  bool _obscurePassword = true;
  bool _useSSH = false;
  bool _usePrivateKey = false; // [New] 개인키 사용 체크박스용
  String? _selectedVendor;

  // Basic Controllers
  final TextEditingController _hostController = TextEditingController();
  final TextEditingController _portController = TextEditingController();
  final TextEditingController _dbController = TextEditingController();
  final TextEditingController _userController = TextEditingController();
  final TextEditingController _passController = TextEditingController();

  // SSH Controllers
  final TextEditingController _sshHostController = TextEditingController();
  final TextEditingController _sshPortController = TextEditingController(); // [New]
  final TextEditingController _sshUserController = TextEditingController();
  final TextEditingController _sshPassController = TextEditingController();

  // Other Controllers [New]
  final TextEditingController _descriptionController = TextEditingController();
  final TextEditingController _pictureUrlController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _sshPortController.text = '22'; // SSH 포트 기본값
  }

  @override
  void dispose() {
    _hostController.dispose();
    _portController.dispose();
    _dbController.dispose();
    _userController.dispose();
    _passController.dispose();

    _sshHostController.dispose();
    _sshPortController.dispose();
    _sshUserController.dispose();
    _sshPassController.dispose();

    _descriptionController.dispose();
    _pictureUrlController.dispose();
    super.dispose();
  }

  void _setPortByVendor(String? vendor) {
    String port = '';
    switch (vendor) {
      case 'MySQL':
      case 'MariaDB':
        port = '3306';
        break;
      case 'PostgreSQL':
        port = '5432';
        break;
      case 'MSSQL':
        port = '1433';
        break;
      default:
        port = '';
    }
    _portController.text = port;
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      insetPadding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 24.0),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Container(
        width: double.maxFinite,
        child: SingleChildScrollView(
          child: Padding(
            padding: const EdgeInsets.all(20.0),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'New Connection',
                  style: TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.bold,
                      color: Colors.black54),
                ),
                const SizedBox(height: 20),

                DropdownButtonFormField<String>(
                  decoration:
                  _inputDecoration('Select a Vendor', icon: Icons.apartment),
                  value: _selectedVendor,
                  items: ['MySQL', 'MariaDB', 'PostgreSQL', 'MSSQL']
                      .map((String value) {
                    return DropdownMenuItem<String>(
                      value: value,
                      child: Text(value),
                    );
                  }).toList(),
                  onChanged: (newValue) {
                    setState(() {
                      _selectedVendor = newValue;
                      _setPortByVendor(newValue);
                    });
                  },
                ),
                const SizedBox(height: 20),

                const Text(
                  'Parameters',
                  style:
                  TextStyle(color: Colors.blue, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 10),

                TextField(
                  controller: _hostController,
                  decoration: _inputDecoration('Hostname / IP address *',
                      icon: Icons.dns),
                ),
                const SizedBox(height: 10),

                TextField(
                  controller: _portController,
                  keyboardType: TextInputType.number,
                  decoration:
                  _inputDecoration('Port *', icon: Icons.usb).copyWith(
                    suffixIcon: const Icon(Icons.refresh, size: 20),
                  ),
                ),
                const SizedBox(height: 10),

                TextField(
                  controller: _dbController,
                  decoration: _inputDecoration('Database', icon: Icons.storage),
                ),
                const SizedBox(height: 10),
                const Text('Optional',
                    style: TextStyle(fontSize: 12, color: Colors.grey)),
                const SizedBox(height: 10),

                TextField(
                  controller: _userController,
                  decoration: _inputDecoration('User *', icon: Icons.person),
                ),
                const SizedBox(height: 10),

                TextField(
                  controller: _passController,
                  obscureText: _obscurePassword,
                  decoration:
                  _inputDecoration('Password', icon: Icons.password).copyWith(
                    suffixIcon: IconButton(
                      icon: Icon(_obscurePassword
                          ? Icons.visibility_off
                          : Icons.visibility),
                      onPressed: () {
                        setState(() {
                          _obscurePassword = !_obscurePassword;
                        });
                      },
                    ),
                  ),
                ),
                const SizedBox(height: 5),
                const Text('Leave empty to ask on connect',
                    style: TextStyle(fontSize: 12, color: Colors.grey)),

                const SizedBox(height: 25),

                // [SSH Section] - 스크린샷과 같이 토글을 헤더 옆에 배치
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text('SSH',
                        style: TextStyle(fontSize: 16, color: Colors.blue, fontWeight: FontWeight.bold)),
                    Switch(
                      value: _useSSH,
                      onChanged: (value) {
                        setState(() {
                          _useSSH = value;
                        });
                      },
                      activeColor: Colors.blue,
                    ),
                  ],
                ),

                // SSH 활성화 시 나타나는 UI (스크린샷 참조)
                if (_useSSH) ...[
                  const SizedBox(height: 10),
                  TextField(
                    controller: _sshHostController,
                    decoration: _inputDecoration('SSH Host *', icon: Icons.dns), // 스크린샷: 서버 아이콘
                  ),
                  const SizedBox(height: 10),
                  TextField(
                    controller: _sshPortController,
                    keyboardType: TextInputType.number,
                    decoration: _inputDecoration('SSH Port *', icon: Icons.usb), // 스크린샷: USB/Port 아이콘
                  ),
                  const SizedBox(height: 10),
                  TextField(
                    controller: _sshUserController,
                    decoration: _inputDecoration('SSH User *', icon: Icons.person_outline), // 스크린샷: 사람 아이콘
                  ),

                  // Use Private Key Checkbox
                  Row(
                    children: [
                      Checkbox(
                        value: _usePrivateKey,
                        onChanged: (value) {
                          setState(() {
                            _usePrivateKey = value ?? false;
                          });
                        },
                      ),
                      const Text('Use Private Key'),
                    ],
                  ),

                  TextField(
                    controller: _sshPassController,
                    obscureText: true,
                    decoration: _inputDecoration('SSH Password *', icon: Icons.password)
                        .copyWith(suffixIcon: const Icon(Icons.visibility)),
                  ),
                ],

                const SizedBox(height: 25),

                // [Other Section] - 항상 표시됨 (요청사항)
                const Text(
                  'Other',
                  style: TextStyle(fontSize: 16, color: Colors.blue, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 10),

                TextField(
                  controller: _descriptionController,
                  decoration: _inputDecoration('Description', icon: Icons.edit), // 스크린샷: 연필 아이콘
                ),
                const Padding(
                  padding: EdgeInsets.only(left: 4.0, top: 4.0),
                  child: Text('Optional', style: TextStyle(fontSize: 12, color: Colors.grey)),
                ),

                const SizedBox(height: 10),

                TextField(
                  controller: _pictureUrlController,
                  decoration: _inputDecoration('Picture URL', icon: Icons.image), // 스크린샷: 이미지 아이콘
                ),
                const Padding(
                  padding: EdgeInsets.only(left: 4.0, top: 4.0),
                  child: Text('Optional', style: TextStyle(fontSize: 12, color: Colors.grey)),
                ),


                const SizedBox(height: 30),

                Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    TextButton(
                      onPressed: () => Navigator.pop(context),
                      child: const Text('Cancel',
                          style: TextStyle(color: Colors.grey)),
                    ),
                    TextButton(
                      onPressed: () {},
                      child: const Text('Test'),
                    ),
                    const SizedBox(width: 8),
                    ElevatedButton(
                      onPressed: () {
                        if (_selectedVendor == null) return;

                        final newConnection = ConnectionInfo(
                          vendor: _selectedVendor!,
                          ip: _hostController.text.isEmpty
                              ? 'localhost'
                              : _hostController.text,
                          port: _portController.text,
                          dbName: _dbController.text,
                          user: _userController.text,
                          // SSH 정보
                          useSSH: _useSSH,
                          sshHost: _useSSH ? _sshHostController.text : null,
                          sshPort: _useSSH ? _sshPortController.text : null,
                          sshUser: _useSSH ? _sshUserController.text : null,
                          usePrivateKey: _useSSH ? _usePrivateKey : false,
                          sshPass: _useSSH ? _sshPassController.text : null,
                          // Other 정보
                          description: _descriptionController.text,
                          pictureUrl: _pictureUrlController.text,
                        );

                        Navigator.pop(context, newConnection);
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.white,
                        foregroundColor: Colors.blue,
                        elevation: 0,
                      ),
                      child: const Text('Save'),
                    ),
                  ],
                )
              ],
            ),
          ),
        ),
      ),
    );
  }

  InputDecoration _inputDecoration(String label, {IconData? icon}) {
    return InputDecoration(
      labelText: label,
      prefixIcon: icon != null ? Icon(icon, color: Colors.black54) : null,
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(4.0),
      ),
      contentPadding:
      const EdgeInsets.symmetric(vertical: 16.0, horizontal: 12.0),
      filled: true,
      fillColor: Colors.white,
    );
  }
}