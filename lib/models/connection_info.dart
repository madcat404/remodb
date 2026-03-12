class ConnectionInfo {
  final String vendor;
  final String ip;
  final String port;
  final String dbName;
  final String user;
  final String? dbPass;

  // SSH 관련
  final bool useSSH;
  final String? sshHost;
  final String? sshPort;
  final String? sshUser;
  final bool usePrivateKey;
  final String? sshPass;

  // Other 관련
  final String? description;
  final String? pictureUrl;

  // [추가됨] 현재 연결 상태를 관리하는 변수 (앱을 껐다 켜면 초기화되도록 저장(JSON)에서 제외)
  bool isConnected;

  ConnectionInfo({
    required this.vendor,
    required this.ip,
    required this.port,
    required this.dbName,
    required this.user,
    this.dbPass,
    this.useSSH = false,
    this.sshHost,
    this.sshPort,
    this.sshUser,
    this.usePrivateKey = false,
    this.sshPass,
    this.description,
    this.pictureUrl,
    this.isConnected = false, // 기본값은 '연결 안 됨(Disconnected)'
  });

  Map<String, dynamic> toJson() {
    return {
      'vendor': vendor,
      'ip': ip,
      'port': port,
      'dbName': dbName,
      'user': user,
      'dbPass': dbPass,
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
      dbPass: json['dbPass'],
      useSSH: json['useSSH'] ?? false,
      sshHost: json['sshHost'],
      sshPort: json['sshPort'],
      sshUser: json['sshUser'],
      usePrivateKey: json['usePrivateKey'] ?? false,
      sshPass: json['sshPass'],
      description: json['description'],
      pictureUrl: json['pictureUrl'],
      isConnected: false, // 데이터를 불러올 때는 항상 Disconnected 상태로 시작
    );
  }
}