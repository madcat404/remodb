import 'package:flutter/material.dart';
import '../models/connection_info.dart';
import '../services/api_service.dart';

class NewConnectionDialog extends StatefulWidget {
  // [핵심] 수정 모드일 때 외부(main.dart)에서 넘겨받을 데이터 선언
  final ConnectionInfo? connectionInfo;

  // [핵심] 생성자에서 connectionInfo를 선택적 매개변수로 추가
  const NewConnectionDialog({super.key, this.connectionInfo});

  @override
  State<NewConnectionDialog> createState() => _NewConnectionDialogState();
}

class _NewConnectionDialogState extends State<NewConnectionDialog> {
  // --- UI 상태 관리 변수 (스위치 상태, 로딩 여부 등) ---
  bool _obscurePassword = true; // 비밀번호 숨김/보임 상태
  bool _useSSH = false;         // SSH 터널링 사용 여부
  bool _usePrivateKey = false;  // SSH 개인키 사용 여부
  String? _selectedVendor;      // 현재 선택된 DB 엔진 이름
  bool _isTesting = false;      // 테스트 버튼 로딩 상태
  bool _isSaving = false;       // 저장 버튼 로딩 상태

  // --- 입력 필드 컨트롤러 (PHP의 $_POST['name'] 값을 가져오는 것과 유사함) ---
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

  // --- 차별화된 디자인: 벤더 선택용 아이콘 데이터 리스트 ---
  final List<Map<String, String>> _vendors = [
    {'name': 'MySQL', 'logoPath': 'assets/logo/mysql.png'},
    {'name': 'MariaDB', 'logoPath': 'assets/logo/maria.png'},
    //name': 'PostgreSQL', 'logoPa': 'assets/logo/postgres.png'},
    {'name': 'MSSQL', 'logoPath': 'assets/logo/mssql.png'},
  ];

  @override
  void initState() {
    super.initState();
    _sshPortController.text = '22'; // SSH 기본 포트 초기값 설정
  }

  @override
  void dispose() {
    // 메모리 누수 방지를 위해 컨트롤러들을 메모리에서 해제
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

  // 벤더(DB 종류) 선택 시 해당 DB의 표준 포트를 자동으로 입력 필드에 세팅
  void _setPortByVendor(String vendor) {
    String port = '';
    switch (vendor) {
      case 'MySQL':
      case 'MariaDB': port = '3306'; break;
    //case 'PostgreSQL': port = '5432'; break;
      case 'MSSQL': port = '1433'; break;
    }
    _portController.text = port;
  }

  // [기능] DB 연결 테스트 실행
  Future<void> _testConnection() async {
    if (_hostController.text.isEmpty || _userController.text.isEmpty || _selectedVendor == null) {
      _showCustomSnackBar('필수 정보를 모두 입력해주세요.', isSuccess: false);
      return;
    }
    setState(() => _isTesting = true); // 로딩 애니메이션 시작

    // API에 보낼 JSON 데이터 구성
    final Map<String, dynamic> requestData = {
      "host": _hostController.text,
      "port": _portController.text,
      "database": _dbController.text,
      "user": _userController.text,
      "password": _passController.text,
    };

    // ApiService를 통해 PHP 서버와 통신
    final result = await ApiService.testDbConnection(requestData);
    setState(() => _isTesting = false); // 로딩 애니메이션 종료

    _showCustomSnackBar(result['message'] ?? (result['success'] ? '성공' : '실패'), isSuccess: result['success']);
  }

  // 알림 메시지(스낵바) 출력 함수
  void _showCustomSnackBar(String message, {required bool isSuccess}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: isSuccess ? Colors.green[700] : Colors.red[700],
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    // 앱의 정체성을 나타내는 메인 컬러 설정
    const Color brandColor = Color(0xFF87588E);

    return Dialog(
      backgroundColor: Colors.grey[50],
      insetPadding: const EdgeInsets.symmetric(horizontal: 20.0, vertical: 30.0),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(24),
        child: Scaffold(
          appBar: AppBar(
            elevation: 0,
            backgroundColor: brandColor,
            title: const Text('New Connection', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
            automaticallyImplyLeading: false,
            actions: [
              IconButton(icon: const Icon(Icons.close, color: Colors.white), onPressed: () => Navigator.pop(context))
            ],
          ),
          body: SingleChildScrollView(
            padding: const EdgeInsets.all(20.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // --- 1. 가로 스크롤 형태의 DB 엔진 선택 (디자인 차별화 포인트) ---
                _buildSectionTitle('Database Vendor'),
                const SizedBox(height: 12),
                SizedBox(
                  height: 100, // 카드의 그림자가 잘리지 않도록 높이를 약간 조절
                  child: ListView.builder(
                    scrollDirection: Axis.horizontal,
                    itemCount: _vendors.length,
                    itemBuilder: (context, index) {
                      bool isSelected = _selectedVendor == _vendors[index]['name'];
                      return GestureDetector(
                        onTap: () {
                          setState(() {
                            _selectedVendor = _vendors[index]['name'];
                            _setPortByVendor(_selectedVendor!);
                          });
                        },
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 200),
                          width: 85,
                          margin: const EdgeInsets.only(right: 12, bottom: 8), // 하단 여백 추가
                          decoration: BoxDecoration(
                            color: isSelected ? brandColor : Colors.white,
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(color: isSelected ? brandColor : Colors.grey[300]!, width: 2),
                            boxShadow: isSelected ? [BoxShadow(color: brandColor.withOpacity(0.3), blurRadius: 8, offset: const Offset(0, 4))] : [],
                          ),
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              // [수정] 에러 방지 및 이미지 크기 강제 축소
                              SizedBox(
                                width: 40,
                                height: 40,
                                child: Image.asset(
                                  _vendors[index]['logoPath']!, // 기존 'icon' 대신 'logoPath' 사용
                                  fit: BoxFit.contain, // 비율을 유지하며 상자 안에 맞춤
                                  errorBuilder: (context, error, stackTrace) =>
                                  const Icon(Icons.error_outline, size: 24), // 이미지 로드 실패 시 아이콘 표시
                                ),
                              ),
                              const SizedBox(height: 8),
                              Text(_vendors[index]['name']!, style: TextStyle(color: isSelected ? Colors.white : Colors.black87, fontWeight: FontWeight.bold, fontSize: 12)),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
                ),
                const SizedBox(height: 24),

                // --- 2. 접속 파라미터 섹션 (카드 레이아웃으로 그룹화) ---
                _buildSectionCard(
                  title: 'Connection Parameters',
                  icon: Icons.settings_input_component,
                  children: [
                    _buildCustomField(controller: _hostController, label: 'Hostname / IP address *', hint: '192.168.0.1', icon: Icons.dns),
                    const SizedBox(height: 16),
                    Row(
                      children: [
                        Expanded(flex: 2, child: _buildCustomField(controller: _portController, label: 'Port *', hint: '3306', icon: Icons.tag, keyboardType: TextInputType.number)),
                        const SizedBox(width: 16),
                        Expanded(flex: 3, child: _buildCustomField(controller: _dbController, label: 'Database Name', hint: 'Default DB', icon: Icons.storage)),
                      ],
                    ),
                    const SizedBox(height: 16),
                    _buildCustomField(controller: _userController, label: 'User ID *', hint: 'admin', icon: Icons.person),
                    const SizedBox(height: 16),
                    _buildCustomField(
                      controller: _passController,
                      label: 'Password',
                      hint: '••••••••',
                      icon: Icons.lock,
                      isPassword: true,
                      obscureText: _obscurePassword,
                      onToggle: () => setState(() => _obscurePassword = !_obscurePassword),
                    ),
                  ],
                ),
                const SizedBox(height: 20),

                /*
                // --- 3. 보안 설정 섹션 (SSH 터널링) - 주석 해제하여 복구 완료 ---
                _buildSectionCard(
                  title: 'Security (SSH)',
                  icon: Icons.security,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text('Enable SSH Tunnel', style: TextStyle(fontWeight: FontWeight.w500)),
                        Switch(value: _useSSH, onChanged: (v) => setState(() => _useSSH = v), activeColor: brandColor),
                      ],
                    ),
                    if (_useSSH) ...[
                      const Divider(height: 24),
                      _buildCustomField(controller: _sshHostController, label: 'SSH Host', icon: Icons.vpn_lock),
                      const SizedBox(height: 16),
                      Row(
                        children: [
                          Expanded(child: _buildCustomField(controller: _sshPortController, label: 'SSH Port', hint: '22', icon: Icons.numbers)),
                          const SizedBox(width: 16),
                          Expanded(child: _buildCustomField(controller: _sshUserController, label: 'SSH User', icon: Icons.account_circle)),
                        ],
                      ),
                      Row(
                        children: [
                          Checkbox(value: _usePrivateKey, onChanged: (v) => setState(() => _usePrivateKey = v ?? false)),
                          const Text('Private Key Mode', style: TextStyle(fontSize: 13)),
                        ],
                      ),
                      _buildCustomField(controller: _sshPassController, label: 'SSH Password', icon: Icons.key, isPassword: true),
                    ],
                  ],
                ),
                const SizedBox(height: 20),

                // --- 4. 설명 및 이미지 정보 섹션 - 주석 해제하여 복구 완료 ---
                _buildSectionCard(
                  title: 'Metadata',
                  icon: Icons.info_outline,
                  children: [
                    _buildCustomField(controller: _descriptionController, label: 'Description', hint: 'Office Database', icon: Icons.description),
                    const SizedBox(height: 16),
                    _buildCustomField(controller: _pictureUrlController, label: 'Connection Image URL', icon: Icons.image_search),
                  ],
                ),
                const SizedBox(height: 32),
                */
              ],
            ),
          ),

          // --- 하단 고정 액션 버튼 바 (Test 및 Save) ---
          bottomNavigationBar: Container(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
            decoration: BoxDecoration(color: Colors.white, border: Border(top: BorderSide(color: Colors.grey[200]!))),
            child: Row(
              children: [
                // 테스트 버튼
                Expanded(
                  child: OutlinedButton(
                    onPressed: _isTesting ? null : _testConnection,
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      side: const BorderSide(color: brandColor),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                    child: _isTesting ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2)) : const Text('TEST', style: TextStyle(color: brandColor, fontWeight: FontWeight.bold)),
                  ),
                ),
                const SizedBox(width: 12),
                // 저장 버튼
                Expanded(
                  child: ElevatedButton(
                    onPressed: _isSaving ? null : () async {
                      if (_selectedVendor == null || _hostController.text.isEmpty) {
                        _showCustomSnackBar('Vendor와 Host는 필수입니다.', isSuccess: false);
                        return;
                      }
                      setState(() => _isSaving = true);

                      // 입력된 데이터를 모델 객체에 담음
                      final info = ConnectionInfo(
                        vendor: _selectedVendor!,
                        ip: _hostController.text,
                        port: _portController.text,
                        dbName: _dbController.text,
                        user: _userController.text,
                        dbPass: _passController.text,
                        useSSH: _useSSH,
                        sshHost: _sshHostController.text,
                        sshPort: _sshPortController.text,
                        sshUser: _sshUserController.text,
                        usePrivateKey: _usePrivateKey,
                        sshPass: _sshPassController.text,
                        description: _descriptionController.text,
                        pictureUrl: _pictureUrlController.text,
                      );

                      // API를 통해 서버(PHP)에 저장 요청
                      final result = await ApiService.saveConnectionInfo(info.toJson());
                      setState(() => _isSaving = false);

                      if (result['success']) Navigator.pop(context, info); // 성공 시 데이터와 함께 팝업 닫기
                      else _showCustomSnackBar(result['message'] ?? '저장 실패', isSuccess: false);
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: brandColor,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                    child: _isSaving ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2)) : const Text('SAVE CONNECTION', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // UI 헬퍼: 섹션 제목 스타일 정의
  Widget _buildSectionTitle(String title) {
    return Text(title, style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: Colors.blueGrey[800], letterSpacing: 0.5));
  }

  // UI 헬퍼: 섹션별 둥근 카드 위젯 생성
  Widget _buildSectionCard({required String title, required IconData icon, required List<Widget> children}) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.03), blurRadius: 10, offset: const Offset(0, 4))],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: 18, color: const Color(0xFF87588E)),
              const SizedBox(width: 8),
              Text(title, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold)),
            ],
          ),
          const SizedBox(height: 16),
          ...children,
        ],
      ),
    );
  }

  // UI 헬퍼: 커스텀 입력 필드(TextField) 스타일 정의
  Widget _buildCustomField({
    required TextEditingController controller,
    required String label,
    String? hint,
    required IconData icon,
    bool isPassword = false,
    bool? obscureText,
    VoidCallback? onToggle,
    TextInputType keyboardType = TextInputType.text,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: const TextStyle(fontSize: 12, color: Colors.grey, fontWeight: FontWeight.w600)),
        const SizedBox(height: 6),
        TextField(
          controller: controller,
          obscureText: obscureText ?? false,
          keyboardType: keyboardType,
          style: const TextStyle(fontSize: 14),
          decoration: InputDecoration(
            hintText: hint,
            hintStyle: TextStyle(color: Colors.grey[400], fontSize: 13),
            prefixIcon: Icon(icon, size: 18, color: Colors.grey[600]),
            suffixIcon: isPassword ? IconButton(icon: Icon(obscureText! ? Icons.visibility_off : Icons.visibility, size: 18), onPressed: onToggle) : null,
            filled: true,
            fillColor: Colors.grey[50],
            contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: Colors.grey[200]!)),
            focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: Color(0xFF87588E), width: 1.5)),
          ),
        ),
      ],
    );
  }
}