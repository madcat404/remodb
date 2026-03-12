import 'package:flutter/material.dart';
import '../models/connection_info.dart';
import '../services/api_service.dart';

class NewConnectionDialog extends StatefulWidget {
  const NewConnectionDialog({super.key});

  @override
  State<NewConnectionDialog> createState() => _NewConnectionDialogState();
}

class _NewConnectionDialogState extends State<NewConnectionDialog> {
  bool _obscurePassword = true;
  bool _useSSH = false;
  bool _usePrivateKey = false;
  String? _selectedVendor;
  bool _isTesting = false; // 테스트 진행 상태
  bool _isSaving = false; // [추가됨] 저장 중 상태 관리

  final TextEditingController _hostController = TextEditingController();
  final TextEditingController _portController = TextEditingController();
  final TextEditingController _dbController = TextEditingController();
  final TextEditingController _userController = TextEditingController();
  final TextEditingController _passController = TextEditingController();

  final TextEditingController _sshHostController = TextEditingController();
  final TextEditingController _sshPortController = TextEditingController();
  final TextEditingController _sshUserController = TextEditingController();
  final TextEditingController _sshPassController = TextEditingController();

  final TextEditingController _descriptionController = TextEditingController();
  final TextEditingController _pictureUrlController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _sshPortController.text = '22';
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

  // 통신 로직(ApiService)을 호출하고 UI(Snackbar)를 그리는 함수
  Future<void> _testConnection() async {
    if (_hostController.text.isEmpty || _userController.text.isEmpty || _selectedVendor == null) {
      _showCustomSnackBar('필수 정보를 모두 입력해주세요.', isSuccess: false);
      return;
    }

    setState(() {
      _isTesting = true;
    });

    final Map<String, dynamic> requestData = {
      "host": _hostController.text,
      "port": _portController.text,
      "database": _dbController.text,
      "user": _userController.text,
      "password": _passController.text,
    };

    // [핵심] 분리해둔 ApiService를 호출하여 통신 작업을 위임합니다.
    final result = await ApiService.testDbConnection(requestData);

    setState(() {
      _isTesting = false;
    });

    // 결과에 따라 UI(스낵바) 처리
    if (result['success'] == true) {
      _showCustomSnackBar(result['message'] ?? 'Test connection succeeded', isSuccess: true);
    } else {
      _showCustomSnackBar(result['message'] ?? 'Connection failed', isSuccess: false);
    }
  }

  // 스낵바 위젯 로직
  void _showCustomSnackBar(String message, {required bool isSuccess}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              isSuccess ? Icons.cloud_done_outlined : Icons.error_outline,
              color: isSuccess ? Colors.blue[200] : Colors.red[300],
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                message,
                style: const TextStyle(color: Colors.white, fontSize: 16),
              ),
            ),
          ],
        ),
        backgroundColor: const Color(0xFF424242),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(30)),
        margin: const EdgeInsets.only(bottom: 20, left: 20, right: 20),
        duration: const Duration(seconds: 3),
      ),
    );
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
                  decoration: _inputDecoration('Select a Vendor', icon: Icons.apartment),
                  value: _selectedVendor,
                  items: ['MySQL', 'MariaDB', 'PostgreSQL', 'MSSQL'].map((String value) {
                    return DropdownMenuItem<String>(value: value, child: Text(value));
                  }).toList(),
                  onChanged: (newValue) {
                    setState(() {
                      _selectedVendor = newValue;
                      _setPortByVendor(newValue);
                    });
                  },
                ),
                const SizedBox(height: 20),

                const Text('Parameters', style: TextStyle(color: Colors.blue, fontWeight: FontWeight.bold)),
                const SizedBox(height: 10),

                TextField(controller: _hostController, decoration: _inputDecoration('Hostname / IP address *', icon: Icons.dns)),
                const SizedBox(height: 10),

                TextField(
                  controller: _portController,
                  keyboardType: TextInputType.number,
                  decoration: _inputDecoration('Port *', icon: Icons.usb).copyWith(suffixIcon: const Icon(Icons.refresh, size: 20)),
                ),
                const SizedBox(height: 10),

                TextField(controller: _dbController, decoration: _inputDecoration('Database', icon: Icons.storage)),
                const SizedBox(height: 10),
                const Text('Optional', style: TextStyle(fontSize: 12, color: Colors.grey)),
                const SizedBox(height: 10),

                TextField(controller: _userController, decoration: _inputDecoration('User *', icon: Icons.person)),
                const SizedBox(height: 10),

                TextField(
                  controller: _passController,
                  obscureText: _obscurePassword,
                  decoration: _inputDecoration('Password', icon: Icons.password).copyWith(
                    suffixIcon: IconButton(
                      icon: Icon(_obscurePassword ? Icons.visibility_off : Icons.visibility),
                      onPressed: () {
                        setState(() { _obscurePassword = !_obscurePassword; });
                      },
                    ),
                  ),
                ),
                const SizedBox(height: 5),
                const Text('Leave empty to ask on connect', style: TextStyle(fontSize: 12, color: Colors.grey)),
                const SizedBox(height: 25),

                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text('SSH', style: TextStyle(fontSize: 16, color: Colors.blue, fontWeight: FontWeight.bold)),
                    Switch(value: _useSSH, onChanged: (value) { setState(() { _useSSH = value; }); }, activeColor: Colors.blue),
                  ],
                ),

                if (_useSSH) ...[
                  const SizedBox(height: 10),
                  TextField(controller: _sshHostController, decoration: _inputDecoration('SSH Host *', icon: Icons.dns)),
                  const SizedBox(height: 10),
                  TextField(controller: _sshPortController, keyboardType: TextInputType.number, decoration: _inputDecoration('SSH Port *', icon: Icons.usb)),
                  const SizedBox(height: 10),
                  TextField(controller: _sshUserController, decoration: _inputDecoration('SSH User *', icon: Icons.person_outline)),
                  Row(
                    children: [
                      Checkbox(value: _usePrivateKey, onChanged: (value) { setState(() { _usePrivateKey = value ?? false; }); }),
                      const Text('Use Private Key'),
                    ],
                  ),
                  TextField(
                    controller: _sshPassController,
                    obscureText: true,
                    decoration: _inputDecoration('SSH Password *', icon: Icons.password).copyWith(suffixIcon: const Icon(Icons.visibility)),
                  ),
                ],

                const SizedBox(height: 25),
                const Text('Other', style: TextStyle(fontSize: 16, color: Colors.blue, fontWeight: FontWeight.bold)),
                const SizedBox(height: 10),

                TextField(controller: _descriptionController, decoration: _inputDecoration('Description', icon: Icons.edit)),
                const Padding(padding: EdgeInsets.only(left: 4.0, top: 4.0), child: Text('Optional', style: TextStyle(fontSize: 12, color: Colors.grey))),
                const SizedBox(height: 10),

                TextField(controller: _pictureUrlController, decoration: _inputDecoration('Picture URL', icon: Icons.image)),
                const Padding(padding: EdgeInsets.only(left: 4.0, top: 4.0), child: Text('Optional', style: TextStyle(fontSize: 12, color: Colors.grey))),
                const SizedBox(height: 30),

                Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel', style: TextStyle(color: Colors.grey))),
                    TextButton(
                      onPressed: _isTesting ? null : _testConnection,
                      child: _isTesting
                          ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2))
                          : const Text('Test'),
                    ),
                    const SizedBox(width: 8),
                    ElevatedButton(
                      onPressed: _isSaving ? null : () async { // [수정됨] 비동기 처리
                        if (_selectedVendor == null || _hostController.text.isEmpty) {
                          _showCustomSnackBar('필수 정보(Vendor, Host)를 입력해주세요.', isSuccess: false);
                          return;
                        }

                        setState(() { _isSaving = true; });

                        // 저장할 모델 객체 생성
                        final newConnection = ConnectionInfo(
                          vendor: _selectedVendor!,
                          ip: _hostController.text.isEmpty ? 'localhost' : _hostController.text,
                          port: _portController.text,
                          dbName: _dbController.text,
                          user: _userController.text,
                          dbPass: _passController.text, // [추가됨] DB에 보낼 비밀번호
                          useSSH: _useSSH,
                          sshHost: _useSSH ? _sshHostController.text : null,
                          sshPort: _useSSH ? _sshPortController.text : null,
                          sshUser: _useSSH ? _sshUserController.text : null,
                          usePrivateKey: _useSSH ? _usePrivateKey : false,
                          sshPass: _useSSH ? _sshPassController.text : null,
                          description: _descriptionController.text,
                          pictureUrl: _pictureUrlController.text,
                        );

                        // 서버에 저장 API 호출
                        final result = await ApiService.saveConnectionInfo(newConnection.toJson());

                        setState(() { _isSaving = false; });

                        if (result['success'] == true) {
                          // DB 저장 성공 시에만 팝업을 닫고 메인 화면에 객체 전달
                          Navigator.pop(context, newConnection);
                        } else {
                          // 실패 시 스낵바로 에러 메시지 출력
                          _showCustomSnackBar(result['message'] ?? '저장 실패', isSuccess: false);
                        }
                      },
                      style: ElevatedButton.styleFrom(backgroundColor: Colors.white, foregroundColor: Colors.blue, elevation: 0),
                      child: _isSaving
                          ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2))
                          : const Text('Save'),
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
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(4.0)),
      contentPadding: const EdgeInsets.symmetric(vertical: 16.0, horizontal: 12.0),
      filled: true,
      fillColor: Colors.white,
    );
  }
}