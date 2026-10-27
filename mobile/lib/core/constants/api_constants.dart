class ApiConstants {
  ApiConstants._();

  // Host IP for backend connection
  // استخدم '127.0.0.1' عند توصيل الهاتف بكابل USB مع (adb reverse tcp:3000 tcp:3000)
  // أو IP الكمبيوتر المحلي '192.168.1.198' عند الاتصال بالـ Wi-Fi (مع إيقاف VPN أو تفعيل Allow LAN)
  // Public VPS Server
  static const String cloudUrl = 'http://45.151.180.73:3000/api';

  // Local server (نفس جهاز التشغيل أو جهاز على نفس الشبكة)
  static const String serverHost = '45.151.180.73';
  static const String serverPort = '3000';
  static const String localUrl = 'http://$serverHost:$serverPort/api';

  // true = الخادم المحلي، false = خادم VPS السحابي
  static const bool useLocalServer = true;

  static String get baseUrl => useLocalServer ? localUrl : cloudUrl;

  // Endpoints
  static const String authLogin = '/auth/login';
  static const String authRegister = '/auth/register';
  static const String authMe = '/auth/me';
  static const String authRefresh = '/auth/refresh';

  static const String apps = '/apps';
  static const String adminApps = '/apps/admin/all';

  static const String productsByApp = '/products/by-app';
  static const String adminProducts = '/products/admin/all';
  static const String serviceTemplates = '/service-templates';
  static const String adminServiceTemplates = '/service-templates/admin/all';
  static const String syncProviderPrices = '/products/sync-provider-prices';

  static const String providers = '/providers';

  static const String orders = '/orders';
  static const String myOrders = '/orders/my-orders';
  static const String adminOrders = '/orders/admin/all';
  static const String adminDashboardStats = '/dashboard/admin';
  static const String adminDashboardPendingCounts =
      '/dashboard/admin/pending-counts';

  static const String walletBalance = '/wallet/balance';
  static const String walletTransactions = '/wallet/transactions';
  static const String adminAdjustBalance = '/wallet/admin/adjust-balance';

  static const String topupAccounts = '/topup/accounts';
  static const String topupRequest = '/topup/request';
  static const String topupMyRequests = '/topup/my-requests';
  static const String adminTopupAccounts = '/topup/admin/accounts';
  static const String adminTopupRequests = '/topup/admin/requests';
  static const String adminTopupLog = '/topup/admin/log';
  static const String adminIdTopup = '/topup/admin/id-topup';

  static const String codesVerify = '/codes/verify';
  static const String codesRedeem = '/codes/redeem';
  static const String adminCodes = '/codes/admin/all';
  static const String adminCodesGenerate = '/codes/admin/generate';

  static const String uploadImage = '/upload/image';

  static const String myNotifications = '/notifications/my';
  static const String adminNotifications = '/notifications/admin';

  static const String banners = '/banners';
  static const String adminBanners = '/banners/admin/all';

  // سعر صرف الدولار مقابل الليرة السورية (يُحدَّث على الخادم يومياً)
  static const String exchangeRate = '/exchange-rates/current';
  static const String adminRefreshExchangeRate = '/exchange-rates/refresh';

  // Manual Services & Supervisor Workflow Endpoints
  static const String supervisorOrders = '/orders/supervisor/my-orders';

  // Users Management Endpoints
  static const String usersList = '/users';

  // Agent (الوكيل) Endpoints
  static const String agentDashboard = '/agent/dashboard';
  static const String agentMyUsers = '/agent/my-users';
  static const String agentCreateUser = '/agent/create-user';
  static const String agentLinkUser = '/agent/link-user';
  static const String agentTransferBalance = '/agent/transfer-balance';
  static const String agentToggleUserStatus = '/agent/users';
  static const String agentTransfers = '/agent/transfers';
}
