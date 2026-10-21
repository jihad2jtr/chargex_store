class ApiConstants {
  ApiConstants._();

  // Host IP for backend connection
  // استخدم '127.0.0.1' عند توصيل الهاتف بكابل USB مع (adb reverse tcp:3000 tcp:3000)
  // أو IP الكمبيوتر المحلي '192.168.1.198' عند الاتصال بالـ Wi-Fi (مع إيقاف VPN أو تفعيل Allow LAN)
  // Public Cloud Server (Netlify)
  static const String cloudUrl = 'https://cozy-pixie-ab6ee6.netlify.app/api';

  // Local fallback
  static const String serverHost = '192.168.1.198';
  static const String serverPort = '3000';

  // Use cloud URL by default
  static String get baseUrl => cloudUrl;

  // Endpoints
  static const String authLogin = '/auth/login';
  static const String authRegister = '/auth/register';
  static const String authMe = '/auth/me';
  static const String authRefresh = '/auth/refresh';

  static const String apps = '/apps';
  static const String adminApps = '/apps/admin/all';

  static const String productsByApp = '/products/by-app';
  static const String adminProducts = '/products/admin/all';
  static const String syncProviderPrices = '/products/sync-provider-prices';

  static const String providers = '/providers';

  static const String orders = '/orders';
  static const String myOrders = '/orders/my-orders';
  static const String adminOrders = '/orders/admin/all';

  static const String walletBalance = '/wallet/balance';
  static const String walletTransactions = '/wallet/transactions';
  static const String adminAdjustBalance = '/wallet/admin/adjust-balance';

  static const String topupAccounts = '/topup/accounts';
  static const String topupRequest = '/topup/request';
  static const String topupMyRequests = '/topup/my-requests';
  static const String adminTopupAccounts = '/topup/admin/accounts';
  static const String adminTopupRequests = '/topup/admin/requests';

  static const String codesVerify = '/codes/verify';
  static const String codesRedeem = '/codes/redeem';
  static const String adminCodes = '/codes/admin/all';
  static const String adminCodesGenerate = '/codes/admin/generate';

  static const String uploadImage = '/upload/image';

  static const String myNotifications = '/notifications/my';
  static const String adminNotifications = '/notifications/admin';

  static const String banners = '/banners';
  static const String adminBanners = '/banners/admin/all';

  // Manual Services & Supervisor Workflow Endpoints
  static const String supervisorOrders = '/orders/supervisor/my-orders';
  static const String supervisorsList = '/users/supervisors';
  static const String createSupervisor = '/users/create-supervisor';

  // Agent (الوكيل) Endpoints
  static const String agentDashboard = '/agent/dashboard';
  static const String agentMyUsers = '/agent/my-users';
  static const String agentCreateUser = '/agent/create-user';
  static const String agentLinkUser = '/agent/link-user';
  static const String agentTransferBalance = '/agent/transfer-balance';
  static const String agentToggleUserStatus = '/agent/users';
  static const String agentTransfers = '/agent/transfers';
}
