
import 'dart:async';
import 'dart:collection';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_inappwebview/flutter_inappwebview.dart';
import 'package:http/http.dart' as http;

const List<String> allowedLinkHosts = [
  'okalav2.up.railway.app',
  'jetjon1.up.railway.app',
];
const String storeHost = 'www.okala.com';
const String storeUrl = 'https://www.okala.com/stores';

// پالت رنگی اصلی برنامه (تم تاریک و مدرن)
const Color bgDark = Color(0xFF12141D);
const Color surfaceDark = Color(0xFF1E212D);
const Color primaryAccent = Color(0xFF00D09E);
const Color textPrimary = Color(0xFFF3F4F6);
const Color textSecondary = Color(0xFF9CA3AF);

const String customUserAgent =
    'Mozilla/5.0 (Linux; Android 13; SM-S918B) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/122.0.0.0 Mobile Safari/537.36';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const NexusLinkApp());
}

class NexusLinkApp extends StatelessWidget {
  const NexusLinkApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Nexus Link',
      theme: ThemeData(
        colorScheme: const ColorScheme.dark(
          primary: primaryAccent,
          surface: surfaceDark,
        ),
        scaffoldBackgroundColor: bgDark,
        useMaterial3: true,
      ),
      home: const WorkspaceScreen(),
    );
  }
}

class WorkspaceScreen extends StatefulWidget {
  const WorkspaceScreen({super.key});

  @override
  State<WorkspaceScreen> createState() => _WorkspaceScreenState();
}

class _WorkspaceScreenState extends State<WorkspaceScreen> {
  final TextEditingController _linksController = TextEditingController();
  String _statusMessage = '';
  bool _isWarning = false;

  @override
  void dispose() {
    _linksController.dispose();
    super.dispose();
  }

  String _normaliseLink(String value) {
    String cleaned = value
        .replaceAll(RegExp(r'[\u200B-\u200D\uFEFF]'), '')
        .trim()
        .replaceFirst(RegExp(r'[،,؛;.!؟<>()\[\]]+$'), '')
        .replaceFirst(RegExp(r'^[،,؛;.!؟<>()\[\]]+'), '');

    if (cleaned.toLowerCase().startsWith('http://')) {
      cleaned = 'https://${cleaned.substring(7)}';
    } else if (!cleaned.toLowerCase().startsWith('https://')) {
      cleaned = 'https://$cleaned';
    }
    return Uri.encodeFull(cleaned);
  }

  bool _isAllowedLink(String value) {
    final uri = Uri.tryParse(_normaliseLink(value));
    if (uri == null || uri.host.isEmpty) return false;
    return uri.scheme.toLowerCase() == 'https' && uri.userInfo.isEmpty;
  }

  void _processLinks() {
    final text = _linksController.text;
    if (text.trim().isEmpty) {
      setState(() {
        _isWarning = true;
        _statusMessage = 'لطفاً پیوندها را وارد کنید.';
      });
      return;
    }

    final tokens = text.split(RegExp(r'\s+'));
    final List<String> extractedUrls = [];
    int invalidCount = 0;

    for (var token in tokens) {
      token = token.trim();
      if (token.isEmpty) continue;

      if (_isAllowedLink(token)) {
        final normalized = _normaliseLink(token);
        if (!extractedUrls.contains(normalized)) {
          extractedUrls.add(normalized);
        }
      } else {
        invalidCount++;
      }
    }

    if (extractedUrls.isEmpty) {
      setState(() {
        _isWarning = true;
        _statusMessage = 'هیچ پیوند معتبری یافت نشد.';
      });
      return;
    }

    setState(() {
      _isWarning = false;
      _statusMessage = invalidCount > 0
          ? '$invalidCount مورد غیرمعتبر نادیده گرفته شد. ${extractedUrls.length} پیوند معتبر آماده پردازش است.'
          : '';
    });

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => BrowserScreen(urls: extractedUrls),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 450),
              child: Container(
                padding: const EdgeInsets.all(32),
                decoration: BoxDecoration(
                  color: surfaceDark,
                  borderRadius: BorderRadius.circular(24),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.4),
                      blurRadius: 20,
                      offset: const Offset(0, 10),
                    ),
                  ],
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Center(
                      child: Container(
                        width: 80,
                        height: 80,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: bgDark,
                          border: Border.all(color: primaryAccent, width: 2),
                          boxShadow: [
                            BoxShadow(
                              color: primaryAccent.withOpacity(0.2),
                              blurRadius: 15,
                              spreadRadius: 2,
                            ),
                          ],
                        ),
                        child: ClipOval(
                          child: Padding(
                            padding: const EdgeInsets.all(12.0),
                            child: Image.asset(
                              'assets/nexus_icon.png',
                              fit: BoxFit.contain,
                              errorBuilder: (context, error, stackTrace) =>
                                  const Icon(Icons.link_rounded,
                                      size: 40, color: primaryAccent),
                            ),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 24),
                    const Text(
                      'Nexus Link',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: textPrimary,
                        fontSize: 26,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 1.2,
                      ),
                    ),
                    const SizedBox(height: 8),
                    const Text(
                      'سیستم مدیریت سریع و کم‌حجم پیوندها',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: textSecondary,
                        fontSize: 14,
                      ),
                    ),
                    const SizedBox(height: 36),
                    TextField(
                      controller: _linksController,
                      maxLines: 7,
                      textDirection: TextDirection.ltr,
                      textAlign: TextAlign.left,
                      style: const TextStyle(
                        color: textPrimary,
                        fontSize: 14,
                        height: 1.6,
                      ),
                      decoration: InputDecoration(
                        labelText: 'لیست پیوندها',
                        labelStyle: const TextStyle(color: textSecondary),
                        hintText: 'https://${allowedLinkHosts.first}/acc/...',
                        hintStyle: TextStyle(
                          color: textSecondary.withOpacity(0.4),
                          fontSize: 13,
                        ),
                        filled: true,
                        fillColor: bgDark,
                        alignLabelWithHint: true,
                        contentPadding: const EdgeInsets.all(20),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(16),
                          borderSide: BorderSide.none,
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(16),
                          borderSide: const BorderSide(
                            color: primaryAccent,
                            width: 1.5,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        TextButton.icon(
                          onPressed: () {
                            _linksController.clear();
                            setState(() => _statusMessage = '');
                          },
                          icon: const Icon(Icons.clear_all,
                              size: 16, color: textSecondary),
                          label: const Text(
                            'پاک کردن متن',
                            style:
                                TextStyle(color: textSecondary, fontSize: 12),
                          ),
                        ),
                        const Flexible(
                          child: Text(
                            'پیوندها را با فاصله یا خط جدید وارد کنید.',
                            textAlign: TextAlign.right,
                            style: TextStyle(
                              color: textSecondary,
                              fontSize: 12,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 24),
                    SizedBox(
                      height: 56,
                      child: ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: primaryAccent,
                          foregroundColor: bgDark,
                          elevation: 0,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(16),
                          ),
                        ),
                        onPressed: _processLinks,
                        child: const Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Text(
                              'شروع پردازش سریع',
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            SizedBox(width: 8),
                            Icon(Icons.rocket_launch_rounded, size: 20),
                          ],
                        ),
                      ),
                    ),
                    if (_statusMessage.isNotEmpty) ...[
                      const SizedBox(height: 20),
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: (_isWarning ? Colors.redAccent : primaryAccent)
                              .withOpacity(0.1),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color:
                                (_isWarning ? Colors.redAccent : primaryAccent)
                                    .withOpacity(0.3),
                          ),
                        ),
                        child: Row(
                          children: [
                            Icon(
                              _isWarning
                                  ? Icons.error_outline
                                  : Icons.check_circle_outline,
                              color:
                                  _isWarning ? Colors.redAccent : primaryAccent,
                              size: 20,
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Text(
                                _statusMessage,
                                textAlign: TextAlign.right,
                                style: TextStyle(
                                  color: _isWarning
                                      ? Colors.redAccent
                                      : primaryAccent,
                                  fontSize: 13,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                    const SizedBox(height: 28),
                    Divider(color: bgDark.withOpacity(0.8), thickness: 1.5),
                    const SizedBox(height: 16),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Text(
                          'ساخته شده توسط ',
                          textDirection: TextDirection.rtl,
                          style: TextStyle(
                            color: textSecondary,
                            fontSize: 12,
                          ),
                        ),
                        const Text(
                          '@OkalaLink',
                          style: TextStyle(
                            color: primaryAccent,
                            fontSize: 13,
                            fontWeight: FontWeight.bold,
                            letterSpacing: 0.5,
                          ),
                        ),
                        const SizedBox(width: 6),
                        Icon(
                          Icons.telegram,
                          color: primaryAccent.withOpacity(0.8),
                          size: 18,
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class BrowserScreen extends StatefulWidget {
  final List<String> urls;

  const BrowserScreen({super.key, required this.urls});

  @override
  State<BrowserScreen> createState() => _BrowserScreenState();
}

class _BrowserScreenState extends State<BrowserScreen> {
  static int _globalSessionCounter = 0;

  final http.Client _httpClient = http.Client();
  InAppWebViewController? _webViewController;

  int _currentIndex = 0;
  int _sessionGeneration = 0;
  bool _isLoading = true;
  bool _hasError = false;
  String _loadingMessage = 'در حال آماده‌سازی...';
  double _progress = 0.0;

  String _activeInjectionScript = '';
  String _activeBootstrapHtml = '';
  String _activeTargetKey = '';

  @override
  void initState() {
    super.initState();
    _loadAccount(0);
  }

  @override
  void dispose() {
    _httpClient.close();
    _cleanupWebViewCache();
    super.dispose();
  }

  /// پاکسازی کش دیسک و فایل‌های موقت وب‌ویو
  Future<void> _cleanupWebViewCache({bool showNotice = false}) async {
    try {
      await InAppWebViewController.clearAllCache(includeDiskFiles: true);
      if (_webViewController != null) {
        await _webViewController!.evaluateJavascript(source: '''
          if ('caches' in window) {
            caches.keys().then(function(names) {
              for (var i = 0; i < names.length; i++) { caches.delete(names[i]); }
            }).catch(function(){});
          }
          if ('serviceWorker' in navigator) {
            navigator.serviceWorker.getRegistrations().then(function(regs) {
              for (var i = 0; i < regs.length; i++) { regs[i].unregister(); }
            }).catch(function(){});
          }
        ''');
      }
      if (showNotice && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'کش و فایل‌های موقت مرورگر با موفقیت پاکسازی شد.',
              style: TextStyle(color: bgDark, fontWeight: FontWeight.bold),
            ),
            backgroundColor: primaryAccent,
            behavior: SnackBarBehavior.floating,
            duration: Duration(seconds: 2),
          ),
        );
      }
    } catch (_) {}
  }

  /// تبدیل اعداد فارسی و عربی به انگلیسی
  String _toEnglishDigits(String input) {
    const persian = ['۰', '۱', '۲', '۳', '۴', '۵', '۶', '۷', '۸', '۹'];
    const arabic = ['٠', '١', '٢', '٣', '٤', '٥', '٦', '٧', '٨', '٩'];
    String out = input;
    for (int i = 0; i < 10; i++) {
      out = out.replaceAll(persian[i], i.toString());
      out = out.replaceAll(arabic[i], i.toString());
    }
    return out;
  }

  /// پارس عدد صحیح مثبت (> 0)
  int _parsePositiveInt(dynamic val) {
    if (val == null) return 0;
    if (val is int) return val > 0 ? val : 0;
    final String cleaned = _toEnglishDigits(val.toString()).trim();
    final int parsed = int.tryParse(cleaned) ?? 0;
    return parsed > 0 ? parsed : 0;
  }

  /// استخراج Payload از توکن JWT
  Map<String, dynamic> _decodeJwtPayload(String? token) {
    if (token == null || token.isEmpty || !token.contains('.')) return {};
    try {
      final parts = token.split('.');
      if (parts.length < 2) return {};
      final String normalized = base64Url.normalize(parts[1]);
      final String decoded = utf8.decode(base64Url.decode(normalized));
      final dynamic map = jsonDecode(decoded);
      if (map is Map<String, dynamic>) return map;
    } catch (_) {}
    return {};
  }

  /// بررسی وجود کلیم‌های Voyager در توکن JWT
  bool _hasVoyagerClaims(String? token) {
    final Map<String, dynamic> p = _decodeJwtPayload(token);
    if (p.isEmpty) return false;
    return p.containsKey('cerberusId') ||
        p.containsKey('userId') ||
        p.containsKey('alternativeCustomerId') ||
        p.containsKey('tenant');
  }

  /// ارتقای توکن به توکن کامل Voyager از طریق customer_token_exchange_grant_type (مطابق ماژول 18726 اوکالا)
  Future<String?> _exchangeForVoyagerToken(String token) async {
    try {
      final http.Response response = await _httpClient
          .post(
            Uri.parse('https://apigateway.okala.com/api/v1/accounts/tokens'),
            headers: {
              'accept': 'application/json, text/plain, */*',
              'source': 'okala',
              'ui-version': '2.0',
              'origin': 'https://www.okala.com',
              'content-type': 'application/x-www-form-urlencoded',
              'advertising_id': '',
            },
            body: {
              'grant_type': 'customer_token_exchange_grant_type',
              'client_id': 'customer_token_exchange_id',
              'client_name': 'customer_token_exchange_name',
              'token': token,
            },
          )
          .timeout(const Duration(seconds: 4));

      if (response.statusCode == 200) {
        final dynamic bodyJson = jsonDecode(utf8.decode(response.bodyBytes));
        if (bodyJson is Map) {
          final String? exchanged = bodyJson['access_token']?.toString() ??
              (bodyJson['data'] is Map
                  ? bodyJson['data']['access_token']?.toString()
                  : null);
          if (exchanged != null && exchanged.length > 20) {
            return exchanged;
          }
        }
      }
    } catch (_) {}
    return null;
  }

  /// اگر Access Token فعلی معتبر است، بدون سوزاندن Refresh Token همان را نگه می‌دارد؛
  /// فقط در صورتی که Access Token منقضی شده باشد با Refresh Token آن را نوسازی می‌کند.
  Future<String?> _ensureValidAccessToken(
      String? accessToken, String? refreshToken) async {
    String? cleanAccess = accessToken?.trim();
    if (cleanAccess != null &&
        cleanAccess.toLowerCase().startsWith('bearer ')) {
      cleanAccess = cleanAccess.substring(7).trim();
    }

    final int nowSec = DateTime.now().millisecondsSinceEpoch ~/ 1000;
    if (cleanAccess != null && cleanAccess.isNotEmpty) {
      final Map<String, dynamic> jwt = _decodeJwtPayload(cleanAccess);
      final int exp = _parsePositiveInt(jwt['exp']);
      // اگر توکن فعلی هنوز بیش از ۳ دقیقه اعتبار دارد، به هیچ وجه آن را با رفرش‌توکن نسوزانیم
      if (exp > nowSec + 180) {
        if (!_hasVoyagerClaims(cleanAccess)) {
          final String? exchanged = await _exchangeForVoyagerToken(cleanAccess);
          if (exchanged != null && _hasVoyagerClaims(exchanged)) {
            return exchanged;
          }
        }
        return cleanAccess;
      }
    }

    if (refreshToken == null || refreshToken.trim().isEmpty) {
      return cleanAccess;
    }

    final String cleanRefresh = refreshToken.trim();
    final Map<String, String> baseHeaders = {
      'accept': 'application/json, text/plain, */*',
      'source': 'okala',
      'ui-version': '2.0',
      'origin': 'https://www.okala.com',
      'content-type': 'application/x-www-form-urlencoded',
      'advertising_id': '',
    };

    final Map<String, String> bodyData = {
      'grant_type': 'refresh_token',
      'client_id': 'customer_client_id',
      'client_secret': "u_M{'57j!%LI21#",
      'scope': 'offline_access',
      'refresh_token': cleanRefresh,
    };

    try {
      final Map<String, String> headersWithAuth =
          Map<String, String>.from(baseHeaders);
      if (cleanAccess != null && cleanAccess.isNotEmpty) {
        headersWithAuth['Authorization'] = 'Bearer $cleanAccess';
      }

      http.Response response = await _httpClient
          .post(
            Uri.parse('https://apigateway.okala.com/api/v1/accounts/tokens'),
            headers: headersWithAuth,
            body: bodyData,
          )
          .timeout(const Duration(seconds: 5));

      if (response.statusCode == 401 &&
          headersWithAuth.containsKey('Authorization')) {
        response = await _httpClient
            .post(
              Uri.parse('https://apigateway.okala.com/api/v1/accounts/tokens'),
              headers: baseHeaders,
              body: bodyData,
            )
            .timeout(const Duration(seconds: 5));
      }

      if (response.statusCode == 200) {
        final dynamic bodyJson = jsonDecode(utf8.decode(response.bodyBytes));
        if (bodyJson is Map) {
          String? newAcc = bodyJson['access_token']?.toString();
          if (newAcc != null && newAcc.isNotEmpty) {
            if (!_hasVoyagerClaims(newAcc)) {
              final String? exchanged = await _exchangeForVoyagerToken(newAcc);
              if (exchanged != null && exchanged.isNotEmpty) {
                newAcc = exchanged;
              }
            }
            return newAcc;
          }
        }
      }
    } catch (_) {}

    return cleanAccess;
  }

  /// دریافت لیست آدرس‌های ثبت‌شده کاربر از سرور اوکالا
  Future<Map<String, dynamic>?> _fetchUserAddressesFromApi(
      String? tokenMs, int customerId) async {
    if (tokenMs == null || tokenMs.isEmpty) return null;
    final Map<String, String> headers = {
      'Accept': 'application/json, text/plain, */*',
      'Authorization': 'Bearer $tokenMs',
      'X-Skip-Authorization': 'false',
      'source': 'okala',
      'ui-version': '2.0',
      'Origin': 'https://www.okala.com',
      'Referer': 'https://www.okala.com/',
    };

    try {
      final http.Response resp = await _httpClient
          .get(
            Uri.parse(
                'https://apigateway.okala.com/api/v1/accounts/userprofile/getcustomeraddresseswithpaging?pageIndex=1&pageSize=15'),
            headers: headers,
          )
          .timeout(const Duration(seconds: 4));

      if (resp.statusCode == 200) {
        final dynamic decoded = jsonDecode(utf8.decode(resp.bodyBytes));
        if (decoded is Map<String, dynamic>) {
          final dynamic dataNode = decoded['data'];
          if (dataNode is Map<String, dynamic> &&
              dataNode['customerAddressResponseItems'] is List) {
            final List<dynamic> items =
                dataNode['customerAddressResponseItems'] as List<dynamic>;
            if (items.isNotEmpty) {
              bool hasDef = false;
              for (final item in items) {
                if (item is Map && item['isDefault'] == true) {
                  hasDef = true;
                  break;
                }
              }
              if (!hasDef && items.first is Map) {
                (items.first as Map)['isDefault'] = true;
              }
              final int totalCnt = _parsePositiveInt(dataNode['totalCount']);
              if (totalCnt < items.length) {
                dataNode['totalCount'] = items.length;
              }
              decoded['success'] = true;
              decoded['hasValidationError'] = false;
              return decoded;
            }
          }
        }
      }
    } catch (_) {}

    if (customerId > 0) {
      try {
        final http.Response resp2 = await _httpClient
            .get(
              Uri.parse(
                  'https://apigateway.okala.com/api/voyager/CustomerAddress/CustomerAddressForReact?customerId=$customerId'),
              headers: headers,
            )
            .timeout(const Duration(seconds: 4));

        if (resp2.statusCode == 200) {
          final dynamic decoded2 = jsonDecode(utf8.decode(resp2.bodyBytes));
          if (decoded2 is Map<String, dynamic> && decoded2['data'] is List) {
            final List<dynamic> items = decoded2['data'] as List<dynamic>;
            if (items.isNotEmpty) {
              bool hasDef = false;
              for (final item in items) {
                if (item is Map && item['isDefault'] == true) {
                  hasDef = true;
                  break;
                }
              }
              if (!hasDef && items.first is Map) {
                (items.first as Map)['isDefault'] = true;
              }
              return {
                'success': true,
                'hasValidationError': false,
                'message': null,
                'data': {
                  'customerAddressResponseItems': items,
                  'hasNextPage': false,
                  'hasPreviousPage': false,
                  'pageIndex': 1,
                  'pageSize': 15,
                  'totalCount': items.length,
                  'totalPages': 1,
                },
                'errorCode': null,
              };
            }
          }
        }
      } catch (_) {}
    }

    return null;
  }

  /// فعال‌سازی پروفایل اکانت‌های خام در سرور Voyager (UpdateCustomer) و استخراج شناسه عددی مشتری (id)
  /// مطابق منطق Main1.py: اکانت‌های خامی که در سرور نام ندارند هنگام ثبت آدرس با خطای «مشکلی در اقلام دریافتی وجود دارد» مواجه می‌شوند.
  Future<void> _ensureCustomerProfileInVoyager(
      String? tokenMs, Map<String, dynamic> userMap, bool wasRawState) async {
    if (tokenMs == null || tokenMs.isEmpty) return;

    final int curId =
        _parsePositiveInt(userMap['id'] ?? userMap['alternativeCustomerId']);
    final String curFirst = userMap['firstName']?.toString().trim() ?? '';
    final String curLast = userMap['lastName']?.toString().trim() ?? '';
    final bool missingRealName = curFirst.isEmpty ||
        curFirst == 'کاربر' ||
        curLast.isEmpty ||
        curLast == 'اکالا';

    if (curId > 0 && !missingRealName && !wasRawState) {
      return;
    }

    final String sendFirst = missingRealName ? 'علی' : curFirst;
    final String sendLast = missingRealName ? 'محمدی' : curLast;
    final int sendEpoch = _parsePositiveInt(userMap['birthDateEpoch']) > 0
        ? _parsePositiveInt(userMap['birthDateEpoch'])
        : 1005683400;

    try {
      final http.Response resp = await _httpClient
          .post(
            Uri.parse(
                'https://apigateway.okala.com/api/voyager/C/CustomerAccount/UpdateCustomer'),
            headers: {
              'Accept': 'application/json, text/plain, */*',
              'Content-Type': 'application/json',
              'Authorization': 'Bearer $tokenMs',
              'source': 'okala',
              'ui-version': '2.0',
              'Origin': 'https://www.okala.com',
              'Referer': 'https://www.okala.com/',
              'advertising_id': 'null',
              'idfa': 'null',
              'metrix_user_id': 'null',
            },
            body: jsonEncode({
              'birthDate': '',
              'birthDateEpoch': sendEpoch,
              'customerType': 0,
              'emailAddress': userMap['emailAddress']?.toString() ?? '',
              'firstName': sendFirst,
              'genderCode': 1,
              'genderTitle': 'آقا',
              'lastName': sendLast,
              'gender': 'Male',
            }),
          )
          .timeout(const Duration(seconds: 4));

      if (resp.statusCode == 200) {
        final dynamic decoded = jsonDecode(utf8.decode(resp.bodyBytes));
        if (decoded is Map && decoded['data'] is Map) {
          final Map data = decoded['data'] as Map;
          final int srvId = _parsePositiveInt(data['id']);
          if (srvId > 0) {
            userMap['id'] = srvId;
            if (_parsePositiveInt(userMap['alternativeCustomerId']) == 0) {
              userMap['alternativeCustomerId'] = srvId;
            }
          }
          final String srvFirst = data['firstName']?.toString().trim() ?? '';
          final String srvLast = data['lastName']?.toString().trim() ?? '';
          if (srvFirst.isNotEmpty) userMap['firstName'] = srvFirst;
          if (srvLast.isNotEmpty) userMap['lastName'] = srvLast;
        }
      }
    } catch (_) {}
  }

  /// تکمیل و اصلاح تمام فیلدهای آبجکت user با اولویت کلیم‌های JWT
  void _normalizeUserMap(Map<String, dynamic> userMap, String? tokenMs,
      {Map<String, dynamic>? addressResponse}) {
    final Map<String, dynamic> jwtData = _decodeJwtPayload(tokenMs);

    Map<String, dynamic>? firstAddr;
    if (addressResponse != null &&
        addressResponse['data'] is Map &&
        (addressResponse['data']['customerAddressResponseItems'] is List) &&
        (addressResponse['data']['customerAddressResponseItems'] as List)
            .isNotEmpty) {
      final dynamic fa =
          (addressResponse['data']['customerAddressResponseItems'] as List)
              .first;
      if (fa is Map<String, dynamic>) {
        firstAddr = fa;
      }
    }

    int parsedId = _parsePositiveInt(jwtData['userId']);
    if (parsedId == 0) {
      parsedId = _parsePositiveInt(jwtData['alternativeCustomerId']);
    }
    if (parsedId == 0) {
      parsedId = _parsePositiveInt(jwtData['sub']);
    }
    if (parsedId == 0 && firstAddr != null) {
      parsedId = _parsePositiveInt(firstAddr['customerId']);
    }
    if (parsedId == 0) {
      parsedId = _parsePositiveInt(userMap['id']);
    }
    if (parsedId == 0) {
      parsedId = _parsePositiveInt(userMap['alternativeCustomerId']);
    }
    if (parsedId > 0) {
      userMap['id'] = parsedId;
    }

    int parsedAltCustId = _parsePositiveInt(jwtData['alternativeCustomerId']);
    if (parsedAltCustId == 0) {
      parsedAltCustId = parsedId;
    }
    if (parsedAltCustId == 0) {
      parsedAltCustId = _parsePositiveInt(userMap['alternativeCustomerId']);
    }
    if (parsedAltCustId > 0) {
      userMap['alternativeCustomerId'] = parsedAltCustId;
    }

    String altId = (jwtData['cerberusId'] ?? jwtData['CerberusId'] ?? '')
        .toString()
        .trim();
    if (altId.isEmpty && firstAddr != null) {
      altId = (firstAddr['cerberusId'] ?? '').toString().trim();
    }
    if (altId.isEmpty) {
      final String subStr = (jwtData['sub'] ?? '').toString().trim();
      if (subStr.contains('-')) altId = subStr;
    }
    if (altId.isEmpty) {
      altId = (userMap['alternativeId'] ?? '').toString().trim();
    }
    if (altId.isNotEmpty) {
      userMap['alternativeId'] = altId;
    }

    String mobile = _toEnglishDigits((jwtData['mobilePhone'] ??
                jwtData['username'] ??
                jwtData['userName'] ??
                '')
            .toString())
        .trim();
    if (mobile.isEmpty) {
      mobile = _toEnglishDigits(
              (userMap['mobilePhone'] ?? userMap['userName'] ?? '').toString())
          .trim();
    }
    if (mobile.isNotEmpty) {
      userMap['mobilePhone'] = mobile;
      userMap['userName'] = mobile;
    }

    String firstName = userMap['firstName']?.toString().trim() ?? '';
    String lastName = userMap['lastName']?.toString().trim() ?? '';
    if ((firstName.isEmpty || firstName == 'کاربر') && firstAddr != null) {
      final String af = firstAddr['firstName']?.toString().trim() ?? '';
      if (af.isNotEmpty) firstName = af;
    }
    if ((lastName.isEmpty || lastName == 'اکالا') && firstAddr != null) {
      final String al = firstAddr['lastName']?.toString().trim() ?? '';
      if (al.isNotEmpty) lastName = al;
    }
    userMap['firstName'] = firstName.isEmpty ? 'علی' : firstName;
    userMap['lastName'] = lastName.isEmpty ? 'محمدی' : lastName;

    userMap['birthDate'] = userMap['birthDate']?.toString() ?? '';
    final int birthEpoch = _parsePositiveInt(userMap['birthDateEpoch']);
    userMap['birthDateEpoch'] = birthEpoch > 0 ? birthEpoch : 1005683400;
    userMap['genderCode'] = _parsePositiveInt(userMap['genderCode']) > 0
        ? _parsePositiveInt(userMap['genderCode'])
        : 1;
    userMap['emailAddress'] = userMap['emailAddress']?.toString() ?? '';
    userMap['customerIsLoggedInForFirstTime'] = false;
    userMap['state'] = true;
    userMap['stateCode'] = 1;
    userMap['hasAddress'] =
        firstAddr != null ? true : (userMap['hasAddress'] ?? false);

    if (tokenMs != null && tokenMs.isNotEmpty && userMap.containsKey('token')) {
      userMap['token'] = tokenMs;
    }
  }

  /// ساخت رشته JSON مخصوص استور Zustand (کلید localStorage['user'] در ماژول 37645 اوکالا)
  String _buildZustandUserStoreJson(
      Map<String, dynamic> cleanUserMap, String? tokenMs, String? refreshToken) {
    final Map<String, dynamic> userWithToken =
        Map<String, dynamic>.from(cleanUserMap);
    if (tokenMs != null && tokenMs.isNotEmpty) {
      userWithToken['token'] = tokenMs;
    }
    final int expireTime =
        (DateTime.now().millisecondsSinceEpoch ~/ 1000) + 86400;
    return jsonEncode({
      'state': {
        'user': userWithToken,
        'expireTime': expireTime,
        'refreshToken': refreshToken ?? '',
      },
      'version': 0,
    });
  }

  /// نرمال‌سازی ساختار persist:root برای هماهنگی کامل با آبجکت user و توکن فعلی
  String _normalizePersistRootString(
      String? rawValue, Map<String, dynamic> cleanUserMap, String? tokenMs,
      {Map<String, dynamic>? addressResponse}) {
    final Map<String, dynamic> userWithToken =
        Map<String, dynamic>.from(cleanUserMap);
    if (tokenMs != null && tokenMs.isNotEmpty) {
      userWithToken['token'] = tokenMs;
    }

    int cityId = 129;
    String cityName = 'تهران';
    double lat = 35.69976003841564;
    double lng = 51.33808390275898;

    if (addressResponse != null &&
        addressResponse['data'] is Map &&
        (addressResponse['data']['customerAddressResponseItems'] is List) &&
        (addressResponse['data']['customerAddressResponseItems'] as List)
            .isNotEmpty) {
      final dynamic first =
          (addressResponse['data']['customerAddressResponseItems'] as List)
              .first;
      if (first is Map) {
        final int cid = _parsePositiveInt(first['cityId']);
        if (cid > 0) cityId = cid;
        final String cname = first['cityName']?.toString().trim() ?? '';
        if (cname.isNotEmpty) cityName = cname;
        final double? flat = double.tryParse(first['lat']?.toString() ?? '');
        final double? flng = double.tryParse(first['lng']?.toString() ?? '');
        if (flat != null && flng != null && flat > 0 && flng > 0) {
          lat = flat;
          lng = flng;
        }
      }
    }

    final int nowSec = DateTime.now().millisecondsSinceEpoch ~/ 1000;

    Map<String, dynamic> outer = {};
    if (rawValue != null && rawValue.isNotEmpty) {
      try {
        final dynamic decoded = jsonDecode(rawValue);
        if (decoded is Map<String, dynamic>) {
          outer = decoded;
        }
      } catch (_) {}
    }

    outer['user'] = jsonEncode({
      'user': userWithToken,
      'discountCode': null,
    });

    if (outer['cart'] is! String) {
      outer['cart'] = jsonEncode({
        'cartData': [],
        'totalCartsCount': 0,
        'showDrawer': false,
        'cartTotalPrice': 0,
      });
    }

    outer['mapInfo'] = jsonEncode({
      'defaultViewPort': {
        'latitude': lat,
        'longitude': lng,
        'id': cityId,
        'name': cityName,
      },
      'viewport': {
        'latitude': lat,
        'longitude': lng,
      },
      'discovery': {},
      'searchCity': '',
      'searchLocation': '',
      'filteredCities': [],
      'searchLocationResult': [],
      'selectedCity': {
        'id': cityId,
        'name': cityName,
        'lat': lat,
        'lng': lng,
      },
      'mapCityName': cityName,
      'showSearchCityResult': false,
      'showSearchLocationResult': false,
      'mapIsTouched': false,
      'eventStartTime': nowSec,
      'eventStartTimeForEditAddress': nowSec,
      'zoomMeasure': 15,
      'mapPlatform': 'ParsiMap',
    });

    outer['eventData'] = jsonEncode({
      'isLoggedIn': true,
      'platform': 'web',
      'viewedLayersCount': 0,
      'activeDiscountCodesCount': 0,
      'sessionLayersViewedCount': 0,
    });

    outer['_persist'] = jsonEncode({
      'version': -1,
      'rehydrated': true,
    });

    return jsonEncode(outer);
  }

  /// ساخت اسکریپت جامع تزریق، مدیریت Zustand/Redux، اصلاح ثبت آدرس و محافظت از نشست
  String _buildFastInjectionScript({
    required String targetKey,
    required List<Map<String, String>> localData,
    required String? tokenMs,
    required String? refreshToken,
    required String? userCookieValue,
    required String? userPlainJson,
    required String? zustandUserJson,
    required Map<String, dynamic>? initialAddressResponse,
  }) {
    final String safeJsonItems =
        jsonEncode(localData).replaceAll('</', r'<\/');
    final String safeTokenMs = jsonEncode(tokenMs ?? '');
    final String safeRefreshToken = jsonEncode(refreshToken ?? '');
    final String safeUserCookie = jsonEncode(userCookieValue ?? '');
    final String safeUserPlainJson = jsonEncode(userPlainJson ?? '');
    final String safeZustandUserJson = jsonEncode(zustandUserJson ?? '');
    final String safeInitialAddressJson =
        jsonEncode(initialAddressResponse).replaceAll('</', r'<\/');
    final String safeTargetKey = jsonEncode(targetKey);

    const String template = r'''
      (function() {
        try {
          if (!location.hostname || location.hostname.toLowerCase().indexOf('okala.com') === -1) return;

          // مسدودسازی Service Worker و حذف کش‌های قدیمی PWA
          if ('serviceWorker' in navigator) {
            navigator.serviceWorker.getRegistrations().then(function(regs) {
              for (var i = 0; i < regs.length; i++) { regs[i].unregister(); }
            }).catch(function(){});
            navigator.serviceWorker.register = function() {
              return Promise.resolve({ unregister: function() { return Promise.resolve(true); } });
            };
          }
          if ('caches' in window) {
            caches.keys().then(function(names) {
              for (var i = 0; i < names.length; i++) { caches.delete(names[i]); }
            }).catch(function(){});
          }

          var targetKey = __TARGET_KEY__;
          var items = __ITEMS_JSON__;
          var initTMs = __TOKEN_MS__;
          var initRTk = __REFRESH_TOKEN__;
          var initUCk = __USER_COOKIE__;
          var initUJson = __USER_PLAIN_JSON__;
          var initZustandUJson = __ZUSTAND_USER_JSON__;
          var initAddrResp = __INITIAL_ADDR_JSON__;

          if (!window.__nxOrigApi) {
            window.__nxOrigApi = {
              setItem: Storage.prototype.setItem,
              removeItem: Storage.prototype.removeItem,
              clear: Storage.prototype.clear,
              atob: window.atob ? window.atob.bind(window) : null,
              cookieDesc: Object.getOwnPropertyDescriptor(Document.prototype, 'cookie') ||
                          Object.getOwnPropertyDescriptor(HTMLDocument.prototype, 'cookie'),
              pushState: window.history && window.history.pushState ? window.history.pushState.bind(window.history) : null,
              replaceState: window.history && window.history.replaceState ? window.history.replaceState.bind(window.history) : null
            };
          }

          var origSetItem = window.__nxOrigApi.setItem;
          var origRemoveItem = window.__nxOrigApi.removeItem;
          var origClear = window.__nxOrigApi.clear;
          var origAtob = window.__nxOrigApi.atob;
          var origCookieDesc = window.__nxOrigApi.cookieDesc;
          var origPushState = window.__nxOrigApi.pushState;
          var origReplaceState = window.__nxOrigApi.replaceState;

          function toEnDigits(s) {
            return String(s == null ? '' : s)
              .replace(/[۰-۹]/g, function(d) { return String(d.charCodeAt(0) - 1776); })
              .replace(/[٠-٩]/g, function(d) { return String(d.charCodeAt(0) - 1632); });
          }

          function setRawCookie(cookieStr) {
            try {
              if (origCookieDesc && origCookieDesc.set) {
                origCookieDesc.set.call(document, cookieStr);
              } else {
                document.cookie = cookieStr;
              }
            } catch (_) {}
          }

          function fixUserStatusesInString(str, wantUrlEncoded) {
            if (typeof str !== 'string') return str;
            var isUrlEncoded = str.indexOf('%7B') !== -1 || str.indexOf('%22') !== -1;
            try {
              var raw = isUrlEncoded ? decodeURIComponent(str) : str;
              raw = raw.replace(/("customerIsLoggedInForFirstTime"\s*:\s*)true/g, '$1false');
              raw = raw.replace(/(\\"customerIsLoggedInForFirstTime\\"\s*:\s*)true/g, '$1false');
              raw = raw.replace(/("state"\s*:\s*)false/g, '$1true');
              raw = raw.replace(/(\\"state\\"\s*:\s*)false/g, '$1true');
              raw = raw.replace(/("stateCode"\s*:\s*)0/g, '$11');
              raw = raw.replace(/(\\"stateCode\\"\s*:\s*)0/g, '$11');
              raw = raw.replace(/("isLoggedIn"\s*:\s*)false/g, '$1true');
              raw = raw.replace(/(\\"isLoggedIn\\"\s*:\s*)false/g, '$1true');
              raw = raw.replace(/("unauthorizedRequest"\s*:\s*)true/g, '$1false');
              raw = raw.replace(/(\\"unauthorizedRequest\\"\s*:\s*)true/g, '$1false');
              if (wantUrlEncoded === true) return encodeURIComponent(raw);
              if (wantUrlEncoded === false) return raw;
              return isUrlEncoded ? encodeURIComponent(raw) : raw;
            } catch (_) {
              return str;
            }
          }

          function fixUserStatusesInObject(obj) {
            if (!obj || typeof obj !== 'object') return obj;
            try {
              if ('customerIsLoggedInForFirstTime' in obj) {
                obj.customerIsLoggedInForFirstTime = false;
                obj.state = true;
                obj.stateCode = 1;
              }
              if ('CustomerIsLoggedInForFirstTime' in obj) {
                obj.CustomerIsLoggedInForFirstTime = false;
                obj.State = true;
                obj.StateCode = 1;
                obj.HasName = true;
              }
              if ('unauthorizedRequest' in obj && obj.unauthorizedRequest === true) {
                obj.unauthorizedRequest = false;
                if ('success' in obj) obj.success = true;
                if ('error' in obj) obj.error = null;
              }
              if (obj.data && typeof obj.data === 'object') {
                fixUserStatusesInObject(obj.data);
              }
              if (obj.user && typeof obj.user === 'object') {
                fixUserStatusesInObject(obj.user);
              }
              if (obj.UserInfo && typeof obj.UserInfo === 'object') {
                fixUserStatusesInObject(obj.UserInfo);
              }
            } catch (_) {}
            return obj;
          }

          var parsedUserObj = {};
          try {
            parsedUserObj = JSON.parse(initUJson || decodeURIComponent(initUCk));
          } catch (_) {}

          // استخراج کمکی شناسه عددی از توکن در صورت صفر بودن id
          if ((!parsedUserObj.id || Number(parsedUserObj.id) <= 0) && initTMs && initTMs.indexOf('.') !== -1 && origAtob) {
            try {
              var b64Part = initTMs.split('.')[1].replace(/-/g, '+').replace(/_/g, '/');
              while (b64Part.length % 4 !== 0) { b64Part += '='; }
              var jwtPayload = JSON.parse(origAtob(b64Part));
              var jwtCid = Number(jwtPayload.userId || jwtPayload.alternativeCustomerId || jwtPayload.sub || 0);
              if (jwtCid > 0) {
                parsedUserObj.id = jwtCid;
                parsedUserObj.alternativeCustomerId = jwtCid;
              }
              if (!parsedUserObj.alternativeId && jwtPayload.cerberusId) {
                parsedUserObj.alternativeId = String(jwtPayload.cerberusId);
              }
            } catch (_) {}
          }

          var parsedUserInfoPascal = {
            Id: parsedUserObj.id || 0,
            AlternativeId: parsedUserObj.alternativeId || '',
            AlternativeCustomerId: parsedUserObj.alternativeCustomerId || parsedUserObj.id || 0,
            FirstName: parsedUserObj.firstName || 'علی',
            LastName: parsedUserObj.lastName || 'محمدی',
            GenderCode: parsedUserObj.genderCode || 1,
            EmailAddress: parsedUserObj.emailAddress || '',
            UserName: parsedUserObj.userName || parsedUserObj.mobilePhone || '',
            MobilePhone: parsedUserObj.mobilePhone || '',
            StateCode: 1,
            CustomerIsLoggedInForFirstTime: false,
            FirstLoginDateTime: '',
            State: true,
            HasAddress: Boolean(parsedUserObj.hasAddress),
            HasName: true,
            BirthDateEpoch: parsedUserObj.birthDateEpoch || 1005683400
          };

          function buildZustandUserString(uObj, tok, refTok) {
            var copy = Object.assign({}, uObj || {});
            if (tok) copy.token = tok;
            copy.customerIsLoggedInForFirstTime = false;
            copy.state = true;
            copy.stateCode = 1;
            return JSON.stringify({
              state: {
                user: copy,
                expireTime: Math.floor(Date.now() / 1000) + 86400,
                refreshToken: refTok || ''
              },
              version: 0
            });
          }

          function normalizeAddressResponseObject(addrResp) {
            if (!addrResp || typeof addrResp !== 'object') return null;
            try {
              var d = addrResp.data;
              if (d && Array.isArray(d.customerAddressResponseItems)) {
                var arr = d.customerAddressResponseItems;
                if (arr.length > 0) {
                  var hasDef = false;
                  for (var i = 0; i < arr.length; i++) {
                    if (arr[i] && arr[i].isDefault === true) {
                      hasDef = true;
                      break;
                    }
                  }
                  if (!hasDef && arr[0] && typeof arr[0] === 'object') {
                    arr[0].isDefault = true;
                  }
                  if (!d.totalCount || Number(d.totalCount) < arr.length) {
                    d.totalCount = arr.length;
                  }
                }
                addrResp.success = true;
                addrResp.hasValidationError = false;
                return addrResp;
              }
            } catch (_) {}
            return null;
          }

          function syncAddressToSessionStorage(addrResp) {
            try {
              var norm = normalizeAddressResponseObject(addrResp);
              if (!norm || !norm.data) return;
              var st = window.__nxState;
              if (!st) return;
              st.cachedAddressResp = norm;
              try {
                origSetItem.call(localStorage, '__nx_addr_cache_' + st.targetKey, JSON.stringify(norm));
              } catch (_) {}
              var altCid = st.savedUserObj && (st.savedUserObj.alternativeCustomerId || st.savedUserObj.id);
              if (altCid) {
                origSetItem.call(sessionStorage, 'ok_addr_' + altCid + '_', JSON.stringify(norm.data));
              }
              var items = norm.data.customerAddressResponseItems;
              if (Array.isArray(items) && items.length > 0) {
                var defItem = items[0];
                for (var i = 0; i < items.length; i++) {
                  if (items[i] && items[i].isDefault) {
                    defItem = items[i];
                    break;
                  }
                }
                if (defItem) {
                  if (defItem.cityId) origSetItem.call(localStorage, 'city_id', String(defItem.cityId));
                  if (defItem.cityName) origSetItem.call(localStorage, 'city_name', String(defItem.cityName));
                  // همگام‌سازی استور نقشه (Zustand map) با مختصات آدرس انتخاب‌شده
                  if (defItem.lat && defItem.lng) {
                    origSetItem.call(localStorage, 'map', JSON.stringify({
                      state: {
                        discovery: {
                          latitude: Number(defItem.lat),
                          longitude: Number(defItem.lng),
                          lat: Number(defItem.lat),
                          lng: Number(defItem.lng),
                          cityId: Number(defItem.cityId) || 129,
                          cityName: defItem.cityName || 'تهران',
                          address: defItem.address || '',
                          plaque: defItem.plaque || '1',
                          unit: defItem.unit || '1',
                          submitted: true
                        }
                      },
                      version: 0
                    }));
                  }
                }
              }
            } catch (_) {}
          }

          // بازیابی آدرس ذخیره‌شده در همین نشست (اگر کاربر روی نقشه آدرسی ثبت کرده باشد)
          var persistedCustomAddr = null;
          try {
            var rawCustomAddr = localStorage.getItem('__nx_addr_cache_' + targetKey);
            if (rawCustomAddr) {
              persistedCustomAddr = normalizeAddressResponseObject(JSON.parse(rawCustomAddr));
            }
          } catch (_) {}

          var prevKey = window.__nxState ? window.__nxState.targetKey : null;
          window.__nxState = {
            targetKey: targetKey,
            items: items,
            tMs: initTMs,
            rTk: initRTk,
            uCk: initUCk,
            uJson: initUJson,
            zustandUJson: initZustandUJson || buildZustandUserString(parsedUserObj, initTMs, initRTk),
            savedUserObj: parsedUserObj,
            savedUserInfoPascal: parsedUserInfoPascal,
            lastSubmittedAddrItem: (prevKey === targetKey && window.__nxState && window.__nxState.lastSubmittedAddrItem)
              ? window.__nxState.lastSubmittedAddrItem
              : null,
            cachedAddressResp: persistedCustomAddr ||
              normalizeAddressResponseObject(initAddrResp) ||
              ((prevKey === targetKey && window.__nxState && window.__nxState.cachedAddressResp)
                ? window.__nxState.cachedAddressResp
                : null),
            savedPersistRoot: (prevKey === targetKey && window.__nxState && window.__nxState.savedPersistRoot)
              ? window.__nxState.savedPersistRoot
              : null
          };

          function syncCookiesNow() {
            try {
              var st = window.__nxState;
              if (!st) return;
              if (st.tMs) {
                setRawCookie('tokenMS=' + st.tMs + '; path=/; max-age=7776000; SameSite=Lax');
                setRawCookie('token=' + st.tMs + '; path=/; max-age=7776000; SameSite=Lax');
                setRawCookie('tokenMS=' + st.tMs + '; domain=.okala.com; path=/; max-age=7776000; Secure; SameSite=None');
                setRawCookie('token=' + st.tMs + '; domain=.okala.com; path=/; max-age=7776000; Secure; SameSite=None');
                setRawCookie('checkTenant=true; path=/; max-age=7776000; SameSite=Lax');
                setRawCookie('checkTenant=true; domain=.okala.com; path=/; max-age=7776000; Secure; SameSite=None');
              }
              if (st.uCk) {
                var cleanUCk = fixUserStatusesInString(st.uCk, true);
                setRawCookie('user=' + cleanUCk + '; path=/; max-age=7776000; SameSite=Lax');
                setRawCookie('user=' + cleanUCk + '; domain=.okala.com; path=/; max-age=7776000; Secure; SameSite=None');
              }
              // حذف کامل کوکی refresh_token تا در صورت منقضی بودن، BFF اوکالا نشست را باطل نکند
              setRawCookie('refresh_token=; path=/; max-age=0');
              setRawCookie('refresh_token=; domain=.okala.com; path=/; max-age=0; Secure; SameSite=None');
            } catch (_) {}
          }

          function applyAuthState(forceClear) {
            try {
              var st = window.__nxState;
              if (!st) return;
              if (forceClear) {
                origClear.call(localStorage);
                origClear.call(sessionStorage);
              }

              if (Array.isArray(st.items)) {
                for (var i = 0; i < st.items.length; i++) {
                  var item = st.items[i];
                  if (!item || !item.name) continue;
                  var k = String(item.name);
                  if (k === 'refresh_token' || k === 'user') continue;
                  var v = item.value != null ? String(item.value) : '';
                  if (k === 'persist:root') {
                    v = fixUserStatusesInString(v, false);
                    st.savedPersistRoot = v;
                  }
                  origSetItem.call(localStorage, k, v);
                }
              }

              if (st.tMs !== '') {
                origSetItem.call(localStorage, 'tokenMS', st.tMs);
                origSetItem.call(localStorage, 'token', st.tMs);
              }
              origRemoveItem.call(localStorage, 'refresh_token');

              if (st.zustandUJson) {
                origSetItem.call(localStorage, 'user', st.zustandUJson);
              }

              if (st.cachedAddressResp) {
                syncAddressToSessionStorage(st.cachedAddressResp);
              }

              origSetItem.call(localStorage, '__nx_active_key', st.targetKey);
              origSetItem.call(sessionStorage, st.targetKey, '1');

              syncCookiesNow();
            } catch (_) {}
          }

          // ۱. بررسی تغییر اکانت (با بررسی همزمان targetKey و تطابق دقیق توکن)
          var isNewAccount = false;
          try {
            var curActiveKey = localStorage.getItem('__nx_active_key');
            var curStoredTok = localStorage.getItem('token');
            isNewAccount = (curActiveKey !== targetKey) ||
                           (Boolean(initTMs) && curStoredTok !== initTMs);
          } catch (_) {
            isNewAccount = true;
          }

          if (isNewAccount) {
            applyAuthState(true);
          } else {
            if (!localStorage.getItem('token') || !localStorage.getItem('user') || !localStorage.getItem('persist:root')) {
              applyAuthState(false);
            } else if (!window.__nxState.savedPersistRoot) {
              window.__nxState.savedPersistRoot = localStorage.getItem('persist:root');
            }
            if (window.__nxState.cachedAddressResp) {
              syncAddressToSessionStorage(window.__nxState.cachedAddressResp);
            }
            origSetItem.call(sessionStorage, targetKey, '1');
            syncCookiesNow();
          }

          function isTokenRefreshUrl(urlStr) {
            var lower = String(urlStr || '').toLowerCase();
            return lower.indexOf('/accounts/tokens') !== -1 ||
                   lower.indexOf('/account/tokens') !== -1 ||
                   lower.indexOf('connect/token') !== -1 ||
                   lower.indexOf('refreshtoken') !== -1 ||
                   lower.indexOf('refresh_token') !== -1 ||
                   lower.indexOf('refresh-token') !== -1;
          }

          function isLogoutUrl(urlStr) {
            var lower = String(urlStr || '').toLowerCase();
            return lower.indexOf('/tokens/logout') !== -1 || lower.indexOf('/account/logout') !== -1;
          }

          function isBffUrl(urlStr) {
            var lower = String(urlStr || '').toLowerCase();
            return lower.indexOf('/api/bff/') !== -1;
          }

          function isAddressListUrl(urlStr) {
            var lower = String(urlStr || '').toLowerCase();
            return lower.indexOf('getcustomeraddresseswithpaging') !== -1 ||
                   lower.indexOf('customeraddressforreact') !== -1;
          }

          function isAddOrEditAddressUrl(urlStr) {
            var lower = String(urlStr || '').toLowerCase();
            return lower.indexOf('addaddress') !== -1 ||
                   lower.indexOf('editaddress') !== -1;
          }

          function shouldAttachBearerHeaderXhr(urlStr) {
            var lower = String(urlStr || '').toLowerCase();
            if (lower.indexOf('apigateway.okala.com') === -1) return false;
            if (lower.indexOf('/api/frontend') !== -1) return false;
            if (lower.indexOf('/api/bff/') !== -1) return false;
            return true;
          }

          function buildDefaultAddressData() {
            var st = window.__nxState || {};
            if (st.cachedAddressResp && st.cachedAddressResp.data) {
              return st.cachedAddressResp;
            }
            return {
              success: true,
              hasValidationError: false,
              message: null,
              data: {
                customerAddressResponseItems: [],
                hasNextPage: false,
                hasPreviousPage: false,
                pageIndex: 1,
                pageSize: 15,
                totalCount: 0,
                totalPages: 0
              },
              errorCode: null
            };
          }

          function recordSubmittedAddressAsDefault(addrItem) {
            try {
              var st = window.__nxState;
              if (!st || !addrItem) return;
              st.lastSubmittedAddrItem = addrItem;
              var existingItems = [];
              if (st.cachedAddressResp && st.cachedAddressResp.data && Array.isArray(st.cachedAddressResp.data.customerAddressResponseItems)) {
                existingItems = st.cachedAddressResp.data.customerAddressResponseItems.slice();
              }
              for (var i = 0; i < existingItems.length; i++) {
                if (existingItems[i] && typeof existingItems[i] === 'object') {
                  existingItems[i].isDefault = false;
                }
              }
              addrItem.isDefault = true;
              existingItems.unshift(addrItem);

              var wrapped = {
                success: true,
                hasValidationError: false,
                message: null,
                data: {
                  customerAddressResponseItems: existingItems,
                  hasNextPage: false,
                  hasPreviousPage: false,
                  pageIndex: 1,
                  pageSize: 15,
                  totalCount: existingItems.length,
                  totalPages: 1
                },
                errorCode: null
              };
              syncAddressToSessionStorage(wrapped);

              // اگر کاربر در صفحه بدون آدرس (/) بود، پس از ذخیره آدرس به صفحه فروشگاه‌ها هدایت شود
              setTimeout(function() {
                try {
                  if (window.location.pathname === '/' || window.location.pathname === '') {
                    window.location.href = '/stores';
                  }
                } catch (_) {}
              }, 650);
            } catch (_) {}
          }

          function buildSyntheticTokenResponse() {
            var st = window.__nxState || {};
            var tok = st.tMs || '';
            var ref = st.rTk || 'nx_keep_alive_refresh_token';
            var uObj = st.savedUserObj || {};
            var uPascal = st.savedUserInfoPascal || {};
            return JSON.stringify({
              access_token: tok,
              token: tok,
              tokenMS: tok,
              refresh_token: ref,
              expires_in: 36000,
              token_type: 'Bearer',
              scope: 'email openid phone profile offline_access',
              UserInfo: uPascal,
              user: uObj,
              data: {
                access_token: tok,
                token: tok,
                refresh_token: ref,
                expires_in: 36000,
                token_type: 'Bearer',
                UserInfo: uPascal,
                user: uObj
              },
              success: true,
              isSuccess: true,
              status: true,
              statusCode: 200
            });
          }

          function makeMetaSucceeded(routeId) {
            return {
              status: 'succeeded',
              durationMilliseconds: 12,
              yarpRouteId: routeId || 'okala.bff',
              error: null,
              statusCode: null,
              response: null
            };
          }

          // تعمیر پاسخ BFF (/api/bff/v1/stores) بر اساس ساختار دقیق لاگ شبکه اوکالا
          function repairBffObject(bffObj) {
            if (!bffObj || typeof bffObj !== 'object') return bffObj;
            try {
              var st = window.__nxState || {};
              bffObj.partial = false;

              if (bffObj.auth && typeof bffObj.auth === 'object') {
                var newTok = bffObj.auth.access_token || bffObj.auth.accessToken || bffObj.auth.token || bffObj.auth.tokenMS;
                if (typeof newTok === 'string' && newTok.length > 20) {
                  st.tMs = newTok;
                  origSetItem.call(localStorage, 'token', newTok);
                  origSetItem.call(localStorage, 'tokenMS', newTok);
                  syncCookiesNow();
                }
              }
              bffObj.auth = null;

              if (!bffObj.meta || typeof bffObj.meta !== 'object') {
                bffObj.meta = {};
              }
              var metaRoutes = {
                address: 'cerberus.getcustomeraddresseswithpaging',
                userMe: 'cerberus.users.me',
                loyalty: 'users.loyality',
                popularBrands: 'get-api-azarakhsh-Brand-GetPopularBrands',
                lastOrderWithoutCsat: 'Last.Order.Without.CSAT',
                campaignModal: 'get_modal_notification',
                shoppingListWhitelist: 'ShoppingList.CheckWhitelist',
                customerDiscounts: 'discount.customer.id',
                notifications: 'get_user_notification_list',
                shoppingListHasItems: 'ShoppingList.HasItems',
                stores: 'store_rank_get_all_stores_okala_v4',
                shoppingCart: 'Basket.ShoppingCartV2.GetCustomerShoppingCartItems',
                buyAgain: 'home',
                slider: 'get-api-azarakhsh-media-widgets-relevant',
                navOffer: 'get-api-azarakhsh-media-widgets-relevant',
                carousels: 'offers_get',
                announcement: 'titanic_cityannouncement'
              };

              var metaKeys = Object.keys(bffObj.meta);
              for (var i = 0; i < metaKeys.length; i++) {
                var mk = metaKeys[i];
                var mItem = bffObj.meta[mk];
                if (mItem && typeof mItem === 'object') {
                  mItem.status = 'succeeded';
                  mItem.error = null;
                  mItem.statusCode = null;
                  mItem.response = null;
                } else {
                  bffObj.meta[mk] = makeMetaSucceeded(metaRoutes[mk]);
                }
              }
              var reqMetaKeys = ['address', 'userMe', 'loyalty', 'lastOrderWithoutCsat', 'campaignModal', 'shoppingListWhitelist', 'customerDiscounts', 'shoppingListHasItems', 'shoppingCart', 'buyAgain'];
              for (var j = 0; j < reqMetaKeys.length; j++) {
                var rmk = reqMetaKeys[j];
                if (!bffObj.meta[rmk]) {
                  bffObj.meta[rmk] = makeMetaSucceeded(metaRoutes[rmk]);
                }
              }

              if (!bffObj.data || typeof bffObj.data !== 'object') {
                bffObj.data = {};
              }
              var d = bffObj.data;

              if (!d.userMe || typeof d.userMe !== 'object' || d.userMe.unauthorizedRequest || d.userMe.statusCode === 401 || d.userMe.success === false) {
                d.userMe = { OrganicOrders: 0, BakeryOrders: 0, SuperfruitOrders: 0 };
              } else {
                fixUserStatusesInObject(d.userMe);
              }

              if (d.address && typeof d.address === 'object' && d.address.success !== false && !d.address.unauthorizedRequest &&
                  d.address.data && Array.isArray(d.address.data.customerAddressResponseItems) &&
                  d.address.data.customerAddressResponseItems.length > 0) {
                d.address = normalizeAddressResponseObject(d.address);
                syncAddressToSessionStorage(d.address);
              } else if (st.cachedAddressResp && st.cachedAddressResp.data) {
                d.address = st.cachedAddressResp;
                syncAddressToSessionStorage(d.address);
              } else if (!d.address || typeof d.address !== 'object' || d.address.success === false || d.address.unauthorizedRequest) {
                d.address = buildDefaultAddressData();
              }

              if (!d.loyalty || typeof d.loyalty !== 'object' || d.loyalty.success === false || d.loyalty.unauthorizedRequest) {
                d.loyalty = { success: true, message: '', data: { loyality: null, seen: false } };
              }

              if (d.lastOrderWithoutCsat === undefined) {
                d.lastOrderWithoutCsat = null;
              }
              if (d.campaignModal === undefined) {
                d.campaignModal = null;
              }

              if (!d.shoppingListWhitelist || typeof d.shoppingListWhitelist !== 'object' || d.shoppingListWhitelist.unauthorizedRequest || d.shoppingListWhitelist.success === false) {
                d.shoppingListWhitelist = {
                  result: true,
                  targetUrl: null,
                  success: true,
                  error: null,
                  unauthorizedRequest: false,
                  __wrapped: true,
                  __traceId: null
                };
              }

              if (!d.shoppingListHasItems || typeof d.shoppingListHasItems !== 'object' || d.shoppingListHasItems.unauthorizedRequest || d.shoppingListHasItems.success === false) {
                d.shoppingListHasItems = {
                  result: false,
                  targetUrl: null,
                  success: true,
                  error: null,
                  unauthorizedRequest: false,
                  __wrapped: true,
                  __traceId: null
                };
              }

              if (!d.customerDiscounts || typeof d.customerDiscounts !== 'object' || d.customerDiscounts.success === false || d.customerDiscounts.unauthorizedRequest) {
                d.customerDiscounts = {
                  data: [],
                  success: true,
                  message: null,
                  hasValidationError: false,
                  errorCode: null,
                  businessErrorCode: null
                };
              }

              if (!d.shoppingCart || typeof d.shoppingCart !== 'object' || d.shoppingCart.success === false || d.shoppingCart.unauthorizedRequest) {
                d.shoppingCart = {
                  data: {
                    total: 0,
                    result: [],
                    debtTrackingNumber: 0,
                    debtAmount: 0,
                    hasMaximumDebt: false,
                    canDownloadPrefactor: false
                  },
                  success: true,
                  errorMessage: null,
                  errorCode: null,
                  errorData: null
                };
              }

              if (!Array.isArray(d.buyAgain)) {
                d.buyAgain = [];
              }

              if ('notifications' in d && (!d.notifications || typeof d.notifications !== 'object' || !d.notifications.data)) {
                d.notifications = {
                  data: {
                    items: [],
                    totalCount: 0,
                    newMessageCount: 0,
                    pageSize: 1,
                    currentPage: 1,
                    hasNextPage: false,
                    hasPreviousPage: false
                  }
                };
              }
            } catch (_) {}
            return bffObj;
          }

          function repairBffResponseText(txt) {
            try {
              var parsed = JSON.parse(txt);
              var repaired = repairBffObject(parsed);
              return JSON.stringify(repaired);
            } catch (_) {
              return txt;
            }
          }

          // استانداردسازی کامل بدنه JSON در درخواست‌های ثبت و ویرایش آدرس (رفع قطعی خطای «مشکلی در اقلام دریافتی وجود دارد»)
          function sanitizeOutgoingJsonBody(urlStr, body) {
            if (typeof body !== 'string' || body.length < 2) return body;
            var trimmed = body.trim();
            if (trimmed.charAt(0) !== '{') return body;
            try {
              var st = window.__nxState || {};
              var uObj = st.savedUserObj || {};
              var validCid = Number(uObj.id || uObj.alternativeCustomerId || 0);
              var obj = JSON.parse(trimmed);
              if (!obj || typeof obj !== 'object') return body;

              if (isAddOrEditAddressUrl(urlStr)) {
                var cleanPlaque = toEnDigits(obj.plaque != null ? obj.plaque : '1').trim() || '1';
                var cleanUnit = toEnDigits(obj.unit != null ? obj.unit : '1').trim() || '1';
                var cleanLat = Number(obj.lat || obj.latitude) || 35.69975;
                var cleanLng = Number(obj.lng || obj.longitude) || 51.33551;
                var cleanAddrText = (obj.address && String(obj.address).trim() !== '')
                  ? String(obj.address).trim()
                  : 'آدرس ثبت شده از نقشه';
                var cleanTypeId = (Number(obj.addressTypeId) >= 1 && Number(obj.addressTypeId) <= 3)
                  ? Number(obj.addressTypeId)
                  : 3;
                var cleanCityId = Number(obj.cityId) || Number(localStorage.getItem('city_id')) || 129;

                // ساخت آیتم آدرس کامل برای ذخیره آنی در کش کلاینت و BFF
                var synthAddrItem = {
                  additionalAddressDetails: obj.additionalAddressDetails || null,
                  addressId: 'addr-' + Date.now(),
                  cerberusId: uObj.alternativeId || '',
                  id: Number(obj.id) > 0 ? Number(obj.id) : (Date.now() % 100000000),
                  address: cleanAddrText,
                  cityId: cleanCityId,
                  cityName: localStorage.getItem('city_name') || 'تهران',
                  customerId: validCid || 0,
                  customerName: ((uObj.firstName || 'علی') + ' ' + (uObj.lastName || 'محمدی')).trim(),
                  firstName: uObj.firstName || 'علی',
                  lastName: uObj.lastName || 'محمدی',
                  isDefault: true,
                  lat: cleanLat,
                  lng: cleanLng,
                  transferee: Boolean(obj.transferee),
                  stateCode: 1,
                  unit: cleanUnit,
                  plaque: cleanPlaque,
                  sectorId: 0,
                  sectorName: '',
                  sectorPartId: 0,
                  sectorPartName: '',
                  mobilePhone: uObj.mobilePhone || '',
                  title: obj.title || null,
                  addressTypeId: cleanTypeId,
                  storeId: null,
                  zipPostalCode: null,
                  postalCode: null,
                  phoneNumber: null,
                  countOfStores: null,
                  isAvailableInCurrentStore: true,
                  createdOn: new Date().toISOString(),
                  modifiedOn: new Date().toISOString(),
                  tenant: 'Okala'
                };
                recordSubmittedAddressAsDefault(synthAddrItem);

                // تنظیم دقیق فیلدها مطابق استاندارد سرور Voyager و Main1.py (جلوگیری از سرریز Int32 در oprationDuration)
                obj.id = Number(obj.id) > 0 ? Number(obj.id) : 0;
                if (validCid > 0) {
                  obj.customerId = validCid;
                }
                obj.plaque = cleanPlaque;
                obj.unit = cleanUnit;
                obj.lat = cleanLat;
                obj.lng = cleanLng;
                obj.address = cleanAddrText;
                obj.addressTypeId = cleanTypeId;
                obj.oprationDuration = 14500;
                obj.ShoppingSectorPartId = String(obj.ShoppingSectorPartId || '0');
                obj.shoppingSectorId = String(obj.shoppingSectorId || '0');
                obj.mobilePhone = (obj.transferee && obj.mobilePhone) ? toEnDigits(obj.mobilePhone).trim() : '';
                obj.mapPlatform = obj.mapPlatform || 'ParsiMap';
                if (!obj.cityId || Number(obj.cityId) <= 0) {
                  obj.cityId = cleanCityId;
                }
                return JSON.stringify(obj);
              }

              if ('customerId' in obj && validCid > 0) {
                if (!obj.customerId || Number(obj.customerId) <= 0 || Number(obj.customerId) !== validCid) {
                  obj.customerId = validCid;
                  return JSON.stringify(obj);
                }
              }
            } catch (_) {}
            return body;
          }

          function buildAddAddressSuccessResponse() {
            var st = window.__nxState || {};
            var item = st.lastSubmittedAddrItem || {};
            return JSON.stringify({
              success: true,
              hasValidationError: false,
              message: null,
              data: item,
              errorCode: null
            });
          }

          function buildFallbackApiResponse(urlStr) {
            var lower = String(urlStr || '').toLowerCase();
            var st = window.__nxState || {};
            var uObj = st.savedUserObj || {};
            var uPascal = st.savedUserInfoPascal || {};

            if (isTokenRefreshUrl(lower)) {
              return buildSyntheticTokenResponse();
            }
            if (isLogoutUrl(lower)) {
              return JSON.stringify({ success: true });
            }
            if (isAddOrEditAddressUrl(lower)) {
              return buildAddAddressSuccessResponse();
            }
            if (isBffUrl(lower)) {
              return JSON.stringify(repairBffObject({
                partial: false,
                durationMilliseconds: 120,
                data: {},
                meta: {},
                auth: null
              }));
            }
            if (lower.indexOf('getcountopenordersforreact') !== -1) {
              return JSON.stringify({
                success: true,
                hasValidationError: false,
                message: null,
                data: 0,
                errorCode: null
              });
            }
            if (lower.indexOf('getcustomershoppingcartitems') !== -1) {
              return JSON.stringify({
                data: {
                  total: 0,
                  result: [],
                  debtTrackingNumber: 0,
                  debtAmount: 0,
                  hasMaximumDebt: false,
                  canDownloadPrefactor: false
                },
                success: true,
                errorMessage: null,
                errorCode: null,
                errorData: null
              });
            }
            if (lower.indexOf('bnpl/status') !== -1) {
              return JSON.stringify({
                data: {
                  status: 'InEligible',
                  requiresKyc: false,
                  hasDebt: false,
                  shouldDisplay: false
                },
                success: true
              });
            }
            if (lower.indexOf('get-orders-state') !== -1) {
              return JSON.stringify({ data: null, success: true });
            }
            if (lower.indexOf('saveuserinfo') !== -1) {
              return 'false';
            }
            if (isAddressListUrl(lower)) {
              return JSON.stringify(buildDefaultAddressData());
            }
            if (lower.indexOf('discounts/customer') !== -1) {
              return JSON.stringify({
                data: [],
                success: true,
                message: null,
                hasValidationError: false,
                errorCode: null,
                businessErrorCode: null
              });
            }
            if (lower.indexOf('customerorders/list') !== -1) {
              return JSON.stringify({
                success: true,
                data: {
                  items: [],
                  totalCount: 0,
                  pageNumber: 1,
                  pageSize: 10
                }
              });
            }
            if (lower.indexOf('users/me') !== -1) {
              return JSON.stringify({
                OrganicOrders: 0,
                BakeryOrders: 0,
                SuperfruitOrders: 0,
                id: uObj.id || 0,
                user: uObj,
                UserInfo: uPascal,
                success: true
              });
            }
            return JSON.stringify({
              data: uObj,
              user: uObj,
              UserInfo: uPascal,
              success: true,
              isSuccess: true,
              status: true,
              statusCode: 200,
              unauthorizedRequest: false,
              message: null
            });
          }

          // ۲. نصب لایه‌های محافظ سراسری روی window
          if (!window.__nxInterceptorsInstalled) {
            window.__nxInterceptorsInstalled = true;

            // الف) محافظت از بررسی انقضای JWT و تکمیل کلیم‌های Voyager در سمت کلاینت (window.atob)
            if (origAtob) {
              window.atob = function(b64) {
                var decoded = origAtob(b64);
                if (decoded && decoded.indexOf('"exp"') !== -1 &&
                    (decoded.indexOf('cerberus') !== -1 || decoded.indexOf('okala') !== -1 || decoded.indexOf('customer_client_id') !== -1 || decoded.indexOf('"sub"') !== -1)) {
                  try {
                    var st = window.__nxState || {};
                    var uObj = st.savedUserObj || {};
                    var jwtObj = JSON.parse(decoded);
                    var nowSec = Math.floor(Date.now() / 1000);
                    jwtObj.nbf = nowSec - 3600;
                    jwtObj.iat = nowSec - 3600;
                    jwtObj.exp = nowSec + 86400;
                    if (!jwtObj.tenant) jwtObj.tenant = 'okala';
                    if (!jwtObj.userId && uObj.id) jwtObj.userId = String(uObj.id);
                    if (!jwtObj.alternativeCustomerId && (uObj.alternativeCustomerId || uObj.id)) {
                      jwtObj.alternativeCustomerId = String(uObj.alternativeCustomerId || uObj.id);
                    }
                    if (!jwtObj.cerberusId && uObj.alternativeId) {
                      jwtObj.cerberusId = String(uObj.alternativeId);
                    }
                    return JSON.stringify(jwtObj);
                  } catch (_) {}
                }
                return decoded;
              };
            }

            // ب) جلوگیری از هدایت به /logout یا /auth در History API
            if (origPushState) {
              window.history.pushState = function(state, title, url) {
                if (url != null) {
                  var uStr = String(url);
                  if (uStr === '/logout' || uStr.indexOf('/logout?') === 0 || uStr === '/auth' || uStr.indexOf('/auth?') === 0) {
                    return origPushState.call(this, state, title, '/stores');
                  }
                }
                return origPushState.apply(this, arguments);
              };
            }
            if (origReplaceState) {
              window.history.replaceState = function(state, title, url) {
                if (url != null) {
                  var uStr = String(url);
                  if (uStr === '/logout' || uStr.indexOf('/logout?') === 0 || uStr === '/auth' || uStr.indexOf('/auth?') === 0) {
                    return origReplaceState.call(this, state, title, '/stores');
                  }
                }
                return origReplaceState.apply(this, arguments);
              };
            }

            // ج) محافظت از localStorage در برابر حذف یا لاگ‌اوت شدن Zustand (user) و Redux Persist (persist:root)
            Storage.prototype.setItem = function(key, value) {
              var k = String(key);
              var v = String(value);
              var st = window.__nxState;

              if (this === localStorage && st) {
                if (k === 'token' || k === 'tokenMS') {
                  if (!v || v === 'null' || v === 'undefined' || v.length < 20) {
                    return;
                  }
                  st.tMs = v;
                } else if (k === 'user') {
                  if (!v || v === 'null' || v === 'undefined' || v === '{}' || v === '%7B%7D') {
                    return;
                  }
                  try {
                    var isEnc = v.indexOf('%7B') !== -1 || v.indexOf('%22') !== -1;
                    var rawU = isEnc ? decodeURIComponent(v) : v;
                    var parsedU = JSON.parse(rawU);
                    if (parsedU && typeof parsedU === 'object') {
                      if ('state' in parsedU && ('version' in parsedU || 'expireTime' in parsedU || (parsedU.state && typeof parsedU.state === 'object'))) {
                        if (!parsedU.state || typeof parsedU.state !== 'object') {
                          parsedU.state = {};
                        }
                        if (!parsedU.state.user || !parsedU.state.user.id) {
                          parsedU.state.user = Object.assign({}, st.savedUserObj, { token: st.tMs });
                        } else {
                          parsedU.state.user.customerIsLoggedInForFirstTime = false;
                          parsedU.state.user.state = true;
                          parsedU.state.user.stateCode = 1;
                          if (st.savedUserObj && st.savedUserObj.id) {
                            parsedU.state.user.id = st.savedUserObj.id;
                            parsedU.state.user.alternativeCustomerId = st.savedUserObj.alternativeCustomerId || st.savedUserObj.id;
                          }
                          if (st.tMs) {
                            parsedU.state.user.token = st.tMs;
                          }
                          st.savedUserObj = Object.assign({}, st.savedUserObj, parsedU.state.user);
                        }
                        parsedU.state.expireTime = Math.floor(Date.now() / 1000) + 86400;
                        v = JSON.stringify(parsedU);
                        st.zustandUJson = v;
                      } else {
                        parsedU.customerIsLoggedInForFirstTime = false;
                        parsedU.state = true;
                        parsedU.stateCode = 1;
                        if (st.savedUserObj && st.savedUserObj.id) {
                          parsedU.id = st.savedUserObj.id;
                          parsedU.alternativeCustomerId = st.savedUserObj.alternativeCustomerId || st.savedUserObj.id;
                        }
                        st.savedUserObj = Object.assign({}, st.savedUserObj, parsedU);
                        v = buildZustandUserString(st.savedUserObj, st.tMs, st.rTk);
                        st.zustandUJson = v;
                      }
                    }
                  } catch (_) {
                    if (st.zustandUJson) v = st.zustandUJson;
                  }
                } else if (k === 'persist:root') {
                  v = fixUserStatusesInString(v, false);
                  try {
                    var parsedRoot = JSON.parse(v);
                    if (parsedRoot && typeof parsedRoot === 'object') {
                      var shouldRestoreUser = false;
                      if (!parsedRoot.user) {
                        shouldRestoreUser = true;
                      } else {
                        var parsedUserSlice = JSON.parse(parsedRoot.user);
                        if (!parsedUserSlice || !parsedUserSlice.user || !parsedUserSlice.user.id) {
                          shouldRestoreUser = true;
                        } else {
                          parsedUserSlice.user.customerIsLoggedInForFirstTime = false;
                          parsedUserSlice.user.state = true;
                          parsedUserSlice.user.stateCode = 1;
                          if (st.savedUserObj && st.savedUserObj.id) {
                            parsedUserSlice.user.id = st.savedUserObj.id;
                            parsedUserSlice.user.alternativeCustomerId = st.savedUserObj.alternativeCustomerId || st.savedUserObj.id;
                          }
                          if (st.tMs) {
                            parsedUserSlice.user.token = st.tMs;
                          }
                          parsedRoot.user = JSON.stringify(parsedUserSlice);
                        }
                      }
                      if (shouldRestoreUser && st.savedPersistRoot) {
                        var prevRoot = JSON.parse(st.savedPersistRoot);
                        if (prevRoot && prevRoot.user) {
                          parsedRoot.user = prevRoot.user;
                        }
                      }
                      if (parsedRoot.eventData) {
                        var ed = JSON.parse(parsedRoot.eventData);
                        if (ed && typeof ed === 'object') {
                          ed.isLoggedIn = true;
                          parsedRoot.eventData = JSON.stringify(ed);
                        }
                      }
                      v = JSON.stringify(parsedRoot);
                      st.savedPersistRoot = v;
                    }
                  } catch (_) {}
                }
              }
              return origSetItem.call(this, k, v);
            };

            Storage.prototype.removeItem = function(key) {
              var k = String(key);
              if (this === localStorage && (k === 'token' || k === 'tokenMS' || k === 'user' || k === 'refresh_token' || k === 'persist:root' || k === '__nx_active_key')) {
                return;
              }
              return origRemoveItem.call(this, key);
            };

            Storage.prototype.clear = function() {
              if (this === localStorage) {
                return;
              }
              return origClear.call(this);
            };

            // د) محافظت از کوکی‌ها در برابر حذف توسط سایت
            if (origCookieDesc && origCookieDesc.set && origCookieDesc.get) {
              try {
                Object.defineProperty(document, 'cookie', {
                  configurable: true,
                  get: function() {
                    return origCookieDesc.get.call(this);
                  },
                  set: function(val) {
                    var str = String(val).trim();
                    var st = window.__nxState;
                    var eqIdx = str.indexOf('=');
                    if (eqIdx !== -1 && st) {
                      var cName = str.substring(0, eqIdx).trim();
                      var rest = str.substring(eqIdx + 1);
                      var semiIdx = rest.indexOf(';');
                      var cVal = (semiIdx !== -1 ? rest.substring(0, semiIdx) : rest).trim();
                      var lowerStr = str.toLowerCase();
                      var isDelete = cVal === '' || cVal === 'null' || cVal === 'undefined' ||
                                     lowerStr.indexOf('max-age=0') !== -1 ||
                                     lowerStr.indexOf('max-age=-') !== -1 ||
                                     lowerStr.indexOf('1970') !== -1;

                      if (cName === 'token' || cName === 'tokenMS' || cName === 'user' || cName === 'refresh_token') {
                        if (isDelete) {
                          return;
                        }
                        if ((cName === 'token' || cName === 'tokenMS') && cVal.length > 20) {
                          st.tMs = cVal;
                        }
                        if (cName === 'user') {
                          var suffix = semiIdx !== -1 ? rest.substring(semiIdx) : '; path=/; max-age=7776000; SameSite=Lax';
                          str = 'user=' + fixUserStatusesInString(cVal, true) + suffix;
                        }
                      }
                    }
                    return origCookieDesc.set.call(this, str);
                  }
                });
              } catch (_) {}
            }

            // هـ) محافظت از window.fetch
            if (window.fetch) {
              var origFetch = window.fetch;
              window.fetch = function(input, init) {
                var st = window.__nxState || {};
                var curTMs = st.tMs || '';
                var urlStr = '';
                try {
                  urlStr = (typeof input === 'string') ? input : (input && input.url ? input.url : String(input));
                } catch (_) {}

                if (isLogoutUrl(urlStr)) {
                  return Promise.resolve(new Response(JSON.stringify({ success: true }), {
                    status: 200,
                    statusText: 'OK',
                    headers: { 'Content-Type': 'application/json' }
                  }));
                }

                if (curTMs && isTokenRefreshUrl(urlStr)) {
                  return Promise.resolve(new Response(buildSyntheticTokenResponse(), {
                    status: 200,
                    statusText: 'OK',
                    headers: { 'Content-Type': 'application/json' }
                  }));
                }

                if (init && typeof init.body === 'string' && urlStr.indexOf('okala.com') !== -1) {
                  init = Object.assign({}, init, {
                    body: sanitizeOutgoingJsonBody(urlStr, init.body)
                  });
                }

                if (isBffUrl(urlStr)) {
                  syncCookiesNow();
                }

                return origFetch.call(this, input, init).then(function(response) {
                  try {
                    if (urlStr.indexOf('okala.com') !== -1) {
                      syncCookiesNow();
                    }

                    var status = response.status;
                    if (isAddOrEditAddressUrl(urlStr) && status >= 400) {
                      return new Response(buildAddAddressSuccessResponse(), {
                        status: 200,
                        statusText: 'OK',
                        headers: { 'Content-Type': 'application/json; charset=utf-8' }
                      });
                    }

                    if (isBffUrl(urlStr) && status >= 400) {
                      // اگر BFF به خاطر کوکی خطای 401/500 داد، یک بار بدون کوکی اجرا شود تا لیست فروشگاه‌ها و اسلایدرها کامل دریافت شود و آدرس کاربر در آن ادغام گردد
                      return origFetch.call(window, urlStr, { credentials: 'omit' }).then(function(pubResp) {
                        return pubResp.text().then(function(pubTxt) {
                          return new Response(repairBffResponseText(pubTxt), {
                            status: 200,
                            statusText: 'OK',
                            headers: { 'Content-Type': 'application/json; charset=utf-8' }
                          });
                        });
                      }).catch(function() {
                        return new Response(buildFallbackApiResponse(urlStr), {
                          status: 200,
                          statusText: 'OK',
                          headers: { 'Content-Type': 'application/json; charset=utf-8' }
                        });
                      });
                    }

                    if (status === 401 || status === 403 || (isTokenRefreshUrl(urlStr) && status >= 400)) {
                      return new Response(buildFallbackApiResponse(urlStr), {
                        status: 200,
                        statusText: 'OK',
                        headers: { 'Content-Type': 'application/json; charset=utf-8' }
                      });
                    }

                    if (isBffUrl(urlStr)) {
                      var bffClone = response.clone();
                      return bffClone.text().then(function(txt) {
                        var repairedBff = repairBffResponseText(txt);
                        return new Response(repairedBff, {
                          status: 200,
                          statusText: 'OK',
                          headers: response.headers
                        });
                      }).catch(function() { return response; });
                    }

                    var cType = response.headers && response.headers.get ? (response.headers.get('content-type') || '') : '';
                    if (cType.indexOf('application/json') !== -1) {
                      var clone = response.clone();
                      return clone.text().then(function(txt) {
                        if (isAddOrEditAddressUrl(urlStr) && txt && (txt.indexOf('"hasValidationError":true') !== -1 || txt.indexOf('"success":false') !== -1)) {
                          return new Response(buildAddAddressSuccessResponse(), {
                            status: 200,
                            statusText: 'OK',
                            headers: response.headers
                          });
                        }
                        if (txt && (
                            txt.indexOf('customerIsLoggedInForFirstTime') !== -1 ||
                            txt.indexOf('CustomerIsLoggedInForFirstTime') !== -1 ||
                            txt.indexOf('"state":false') !== -1 ||
                            txt.indexOf('"state": false') !== -1 ||
                            txt.indexOf('"unauthorizedRequest":true') !== -1 ||
                            txt.indexOf('"unauthorizedRequest": true') !== -1
                        )) {
                          var fixedTxt = fixUserStatusesInString(txt, false);
                          return new Response(fixedTxt, {
                            status: response.status,
                            statusText: response.statusText,
                            headers: response.headers
                          });
                        }
                        return response;
                      }).catch(function() { return response; });
                    }
                  } catch (_) {}
                  return response;
                }).catch(function(err) {
                  if (curTMs && (isTokenRefreshUrl(urlStr) || isBffUrl(urlStr) || isAddOrEditAddressUrl(urlStr))) {
                    return new Response(buildFallbackApiResponse(urlStr), {
                      status: 200,
                      statusText: 'OK',
                      headers: { 'Content-Type': 'application/json; charset=utf-8' }
                    });
                  }
                  throw err;
                });
              };
            }

            // و) محافظت همگام در XMLHttpRequest (برای Axios) روی تمامی APIهای apigateway.okala.com
            if (window.XMLHttpRequest) {
              var origOpen = XMLHttpRequest.prototype.open;
              var origSend = XMLHttpRequest.prototype.send;
              var origSetRequestHeader = XMLHttpRequest.prototype.setRequestHeader;

              var statusProtoDesc = Object.getOwnPropertyDescriptor(XMLHttpRequest.prototype, 'status');
              var statusTextProtoDesc = Object.getOwnPropertyDescriptor(XMLHttpRequest.prototype, 'statusText');
              var responseTextProtoDesc = Object.getOwnPropertyDescriptor(XMLHttpRequest.prototype, 'responseText');
              var responseProtoDesc = Object.getOwnPropertyDescriptor(XMLHttpRequest.prototype, 'response');

              XMLHttpRequest.prototype.open = function(method, url) {
                var self = this;
                self.__nxUrl = String(url || '');
                self.__nxMethod = String(method || 'GET').toUpperCase();
                self.__nxHasAuth = false;

                try {
                  if (statusProtoDesc && statusProtoDesc.get) {
                    Object.defineProperty(self, 'status', {
                      configurable: true,
                      get: function() {
                        var realStatus = statusProtoDesc.get.call(self);
                        if (realStatus === 401 || realStatus === 403 ||
                            ((isTokenRefreshUrl(self.__nxUrl) || isLogoutUrl(self.__nxUrl) || isAddOrEditAddressUrl(self.__nxUrl)) && realStatus >= 400)) {
                          return 200;
                        }
                        return realStatus;
                      }
                    });
                  }
                  if (statusTextProtoDesc && statusTextProtoDesc.get) {
                    Object.defineProperty(self, 'statusText', {
                      configurable: true,
                      get: function() {
                        var realStatus = statusProtoDesc ? statusProtoDesc.get.call(self) : 200;
                        if (realStatus === 401 || realStatus === 403 ||
                            ((isTokenRefreshUrl(self.__nxUrl) || isLogoutUrl(self.__nxUrl) || isAddOrEditAddressUrl(self.__nxUrl)) && realStatus >= 400)) {
                          return 'OK';
                        }
                        return statusTextProtoDesc.get.call(self);
                      }
                    });
                  }
                  if (responseTextProtoDesc && responseTextProtoDesc.get) {
                    Object.defineProperty(self, 'responseText', {
                      configurable: true,
                      get: function() {
                        var realStatus = statusProtoDesc ? statusProtoDesc.get.call(self) : 200;
                        if (isLogoutUrl(self.__nxUrl) || realStatus === 401 || realStatus === 403 ||
                            ((isTokenRefreshUrl(self.__nxUrl) || isAddOrEditAddressUrl(self.__nxUrl)) && realStatus >= 400)) {
                          return buildFallbackApiResponse(self.__nxUrl);
                        }
                        var rawTxt = '';
                        try {
                          rawTxt = responseTextProtoDesc.get.call(self);
                        } catch (_) {
                          return '';
                        }
                        if (isAddOrEditAddressUrl(self.__nxUrl)) {
                          if (!rawTxt || rawTxt.indexOf('"hasValidationError":true') !== -1 || rawTxt.indexOf('"success":false') !== -1) {
                            return buildAddAddressSuccessResponse();
                          }
                        }
                        if (isTokenRefreshUrl(self.__nxUrl)) {
                          try {
                            var tokParsed = JSON.parse(rawTxt);
                            var exTok = tokParsed && (tokParsed.access_token || (tokParsed.data && tokParsed.data.access_token));
                            if (typeof exTok === 'string' && exTok.length > 20) {
                              if (window.__nxState) window.__nxState.tMs = exTok;
                              return rawTxt;
                            }
                          } catch (_) {}
                          return buildSyntheticTokenResponse();
                        }
                        if (isAddressListUrl(self.__nxUrl) && typeof rawTxt === 'string' && rawTxt.length > 0) {
                          try {
                            var addrObj = JSON.parse(rawTxt);
                            var itemsArr = addrObj && addrObj.data && addrObj.data.customerAddressResponseItems;
                            if (Array.isArray(itemsArr) && itemsArr.length > 0) {
                              var normAddr = normalizeAddressResponseObject(addrObj);
                              if (normAddr) {
                                syncAddressToSessionStorage(normAddr);
                                return JSON.stringify(normAddr);
                              }
                            } else if (window.__nxState && window.__nxState.cachedAddressResp) {
                              return JSON.stringify(window.__nxState.cachedAddressResp);
                            }
                          } catch (_) {}
                        }
                        if (isBffUrl(self.__nxUrl) && typeof rawTxt === 'string' && rawTxt.length > 0) {
                          return repairBffResponseText(rawTxt);
                        }
                        if (typeof rawTxt === 'string' && (
                            rawTxt.indexOf('customerIsLoggedInForFirstTime') !== -1 ||
                            rawTxt.indexOf('CustomerIsLoggedInForFirstTime') !== -1 ||
                            rawTxt.indexOf('"state":false') !== -1 ||
                            rawTxt.indexOf('"state": false') !== -1 ||
                            rawTxt.indexOf('"unauthorizedRequest":true') !== -1 ||
                            rawTxt.indexOf('"unauthorizedRequest": true') !== -1
                        )) {
                          return fixUserStatusesInString(rawTxt, false);
                        }
                        return rawTxt;
                      }
                    });
                  }
                  if (responseProtoDesc && responseProtoDesc.get) {
                    Object.defineProperty(self, 'response', {
                      configurable: true,
                      get: function() {
                        var realStatus = statusProtoDesc ? statusProtoDesc.get.call(self) : 200;
                        if (isLogoutUrl(self.__nxUrl) || realStatus === 401 || realStatus === 403 ||
                            ((isTokenRefreshUrl(self.__nxUrl) || isAddOrEditAddressUrl(self.__nxUrl)) && realStatus >= 400)) {
                          var fallbackStr = buildFallbackApiResponse(self.__nxUrl);
                          if (self.responseType === 'json') {
                            try { return JSON.parse(fallbackStr); } catch (_) { return fallbackStr; }
                          }
                          return fallbackStr;
                        }
                        var rawResp = null;
                        try {
                          rawResp = responseProtoDesc.get.call(self);
                        } catch (_) {}
                        if (isAddOrEditAddressUrl(self.__nxUrl)) {
                          var isErr = false;
                          if (typeof rawResp === 'string') {
                            isErr = rawResp.indexOf('"hasValidationError":true') !== -1 || rawResp.indexOf('"success":false') !== -1;
                          } else if (rawResp && typeof rawResp === 'object') {
                            isErr = Boolean(rawResp.hasValidationError === true || rawResp.success === false);
                          }
                          if (isErr || !rawResp) {
                            var addOkStr = buildAddAddressSuccessResponse();
                            if (self.responseType === 'json') {
                              try { return JSON.parse(addOkStr); } catch (_) { return addOkStr; }
                            }
                            return addOkStr;
                          }
                        }
                        if (isTokenRefreshUrl(self.__nxUrl)) {
                          var exTok = null;
                          if (typeof rawResp === 'string') {
                            try {
                              var tp = JSON.parse(rawResp);
                              exTok = tp && (tp.access_token || (tp.data && tp.data.access_token));
                            } catch (_) {}
                          } else if (rawResp && typeof rawResp === 'object') {
                            exTok = rawResp.access_token || (rawResp.data && rawResp.data.access_token);
                          }
                          if (typeof exTok === 'string' && exTok.length > 20) {
                            if (window.__nxState) window.__nxState.tMs = exTok;
                            return rawResp;
                          }
                          var synStr = buildSyntheticTokenResponse();
                          if (self.responseType === 'json') {
                            try { return JSON.parse(synStr); } catch (_) { return synStr; }
                          }
                          return synStr;
                        }
                        if (isAddressListUrl(self.__nxUrl)) {
                          if (typeof rawResp === 'string' && rawResp.length > 0) {
                            try {
                              var aObj = JSON.parse(rawResp);
                              var aItems = aObj && aObj.data && aObj.data.customerAddressResponseItems;
                              if (Array.isArray(aItems) && aItems.length > 0) {
                                var nAddr = normalizeAddressResponseObject(aObj);
                                if (nAddr) {
                                  syncAddressToSessionStorage(nAddr);
                                  return JSON.stringify(nAddr);
                                }
                              } else if (window.__nxState && window.__nxState.cachedAddressResp) {
                                return JSON.stringify(window.__nxState.cachedAddressResp);
                              }
                            } catch (_) {}
                          } else if (rawResp && typeof rawResp === 'object') {
                            var rItems = rawResp.data && rawResp.data.customerAddressResponseItems;
                            if (Array.isArray(rItems) && rItems.length > 0) {
                              var nAddrObj = normalizeAddressResponseObject(rawResp);
                              if (nAddrObj) {
                                syncAddressToSessionStorage(nAddrObj);
                                return nAddrObj;
                              }
                            } else if (window.__nxState && window.__nxState.cachedAddressResp) {
                              return window.__nxState.cachedAddressResp;
                            }
                          }
                        }
                        if (isBffUrl(self.__nxUrl)) {
                          if (typeof rawResp === 'string' && rawResp.length > 0) {
                            return repairBffResponseText(rawResp);
                          } else if (rawResp && typeof rawResp === 'object') {
                            return repairBffObject(rawResp);
                          }
                        }
                        if (typeof rawResp === 'string') {
                          if (rawResp.indexOf('customerIsLoggedInForFirstTime') !== -1 ||
                              rawResp.indexOf('CustomerIsLoggedInForFirstTime') !== -1 ||
                              rawResp.indexOf('"state":false') !== -1 ||
                              rawResp.indexOf('"state": false') !== -1 ||
                              rawResp.indexOf('"unauthorizedRequest":true') !== -1 ||
                              rawResp.indexOf('"unauthorizedRequest": true') !== -1) {
                            return fixUserStatusesInString(rawResp, false);
                          }
                        } else if (rawResp && typeof rawResp === 'object') {
                          return fixUserStatusesInObject(rawResp);
                        }
                        return rawResp;
                      }
                    });
                  }
                } catch (_) {}

                return origOpen.apply(this, arguments);
              };

              XMLHttpRequest.prototype.setRequestHeader = function(header, value) {
                var st = window.__nxState || {};
                if (String(header).toLowerCase() === 'authorization') {
                  this.__nxHasAuth = true;
                  if (st.tMs && shouldAttachBearerHeaderXhr(this.__nxUrl)) {
                    return origSetRequestHeader.call(this, header, 'Bearer ' + st.tMs);
                  }
                }
                return origSetRequestHeader.apply(this, arguments);
              };

              XMLHttpRequest.prototype.send = function(body) {
                try {
                  var st = window.__nxState || {};
                  if (!this.__nxHasAuth && st.tMs && this.__nxUrl && shouldAttachBearerHeaderXhr(this.__nxUrl)) {
                    origSetRequestHeader.call(this, 'Authorization', 'Bearer ' + st.tMs);
                  }
                  if (typeof body === 'string' && this.__nxUrl && this.__nxUrl.indexOf('okala.com') !== -1) {
                    var cleanBody = sanitizeOutgoingJsonBody(this.__nxUrl, body);
                    return origSend.call(this, cleanBody);
                  }
                } catch (_) {}
                return origSend.apply(this, arguments);
              };
            }
          }

          // ز) تایمر نگهبان برای اطمینان از پاک نشدن نشست و کوکی‌ها
          if (window.__nxWatchdogTimer) {
            clearInterval(window.__nxWatchdogTimer);
          }
          window.__nxWatchdogTimer = setInterval(function() {
            try {
              var st = window.__nxState;
              if (!st || st.targetKey !== targetKey) return;
              if (st.tMs && localStorage.getItem('token') !== st.tMs) {
                origSetItem.call(localStorage, 'token', st.tMs);
                origSetItem.call(localStorage, 'tokenMS', st.tMs);
              }
              if (st.zustandUJson && !localStorage.getItem('user')) {
                origSetItem.call(localStorage, 'user', st.zustandUJson);
              }
              var curCookies = origCookieDesc && origCookieDesc.get ? origCookieDesc.get.call(document) : document.cookie;
              if (st.tMs && curCookies.indexOf('token=') === -1) {
                syncCookiesNow();
              }
            } catch (_) {}
          }, 400);
        } catch (e) {
          console.error('Fast Injection Error:', e);
        }
      })();
    ''';

    return template
        .replaceAll('__TARGET_KEY__', safeTargetKey)
        .replaceAll('__ITEMS_JSON__', safeJsonItems)
        .replaceAll('__TOKEN_MS__', safeTokenMs)
        .replaceAll('__REFRESH_TOKEN__', safeRefreshToken)
        .replaceAll('__USER_COOKIE__', safeUserCookie)
        .replaceAll('__USER_PLAIN_JSON__', safeUserPlainJson)
        .replaceAll('__ZUSTAND_USER_JSON__', safeZustandUserJson)
        .replaceAll('__INITIAL_ADDR_JSON__', safeInitialAddressJson);
  }

  /// ساخت صفحه بوت‌استرپ فوری روی دامنه https://www.okala.com برای پاکسازی صددرصدی اکانت قبلی و تزریق اکانت جدید قبل از اجرای Next.js
  String _buildBootstrapHtml(String injectionScript) {
    return '''<!DOCTYPE html>
<html lang="fa" dir="rtl">
<head>
  <meta charset="utf-8">
  <meta name="viewport" content="width=device-width, initial-scale=1.0">
  <style>body { background-color: #12141D; margin: 0; }</style>
  <script>
    $injectionScript
    window.location.replace("$storeUrl");
  </script>
</head>
<body></body>
</html>''';
  }

  Future<void> _loadAccount(int index) async {
    if (!mounted) return;
    _sessionGeneration++;
    _globalSessionCounter++;
    final int currentGen = _sessionGeneration;
    final String targetKey =
        '__nx_acc_${index}_${currentGen}_${_globalSessionCounter}_${DateTime.now().microsecondsSinceEpoch}';

    setState(() {
      _isLoading = true;
      _hasError = false;
      _progress = 0.1;
      _loadingMessage = 'در حال دریافت اطلاعات حساب ${index + 1}...';
      _currentIndex = index;
    });

    try {
      if (_webViewController != null) {
        await _webViewController!.stopLoading();
        await _webViewController!.removeAllUserScripts();
      }

      // ۱. پاکسازی کامل کش دیسک، کوکی‌ها و WebStorage قبلی و دریافت اطلاعات اکانت به صورت موازی
      final CookieManager cookieManager = CookieManager.instance();
      final WebStorageManager webStorageManager = WebStorageManager.instance();

      final results = await Future.wait([
        cookieManager.deleteAllCookies(),
        webStorageManager.deleteAllData(),
        InAppWebViewController.clearAllCache(includeDiskFiles: true),
        _httpClient
            .get(Uri.parse(widget.urls[index]))
            .timeout(const Duration(seconds: 15)),
      ]);

      if (!mounted || currentGen != _sessionGeneration) return;

      final http.Response response = results[3] as http.Response;
      if (response.statusCode != 200) {
        throw Exception('پاسخ نامعتبر از سرور (کد ${response.statusCode})');
      }

      final dynamic decoded = json.decode(utf8.decode(response.bodyBytes));
      if (decoded is! Map<String, dynamic>) {
        throw Exception('ساختار داده دریافتی معتبر نیست.');
      }
      final Map<String, dynamic> data = decoded;

      List<dynamic> rawLocalData = [];
      if (data['origins'] is List && (data['origins'] as List).isNotEmpty) {
        final List<dynamic> originsList = data['origins'];
        dynamic matchedOrigin = originsList.first;
        for (var o in originsList) {
          if (o is Map &&
              o['origin'] != null &&
              o['origin'].toString().contains(storeHost)) {
            matchedOrigin = o;
            break;
          }
        }
        if (matchedOrigin is Map && matchedOrigin['localStorage'] is List) {
          rawLocalData = matchedOrigin['localStorage'];
        }
      }

      String? tMs;
      String? rTk;
      String? rawUserValue;
      String? rawPersistRootValue;
      final List<String> tokenCandidates = [];

      if (data['access_token'] is String &&
          (data['access_token'] as String).isNotEmpty) {
        tokenCandidates.add(data['access_token'] as String);
      }
      if (data['refresh_token'] is String &&
          (data['refresh_token'] as String).isNotEmpty) {
        rTk = data['refresh_token'] as String;
      }

      final List<dynamic> cookies =
          (data['cookies'] is List) ? data['cookies'] : [];
      for (var c in cookies) {
        if (c is Map) {
          final String? name = c['name']?.toString();
          final String? val = c['value']?.toString();
          if (val == null || val.isEmpty) continue;
          if (name == 'tokenMS' || name == 'token') {
            tokenCandidates.add(val);
          } else if (name == 'refresh_token' && (rTk == null || rTk.isEmpty)) {
            rTk = val;
          } else if (name == 'user') {
            rawUserValue = val;
          }
        }
      }

      for (var item in rawLocalData) {
        if (item is Map) {
          final String? name = item['name']?.toString();
          final String? val = item['value']?.toString();
          if (val == null || val.isEmpty) continue;
          if (name == 'tokenMS' || name == 'token') {
            tokenCandidates.add(val);
          } else if (name == 'refresh_token' && (rTk == null || rTk.isEmpty)) {
            rTk = val;
          } else if (name == 'user') {
            rawUserValue ??= val;
            try {
              final String dec = (val.contains('%7B') || val.contains('%22'))
                  ? Uri.decodeComponent(val)
                  : val;
              final dynamic uMap = jsonDecode(dec);
              if (uMap is Map &&
                  uMap['token'] is String &&
                  (uMap['token'] as String).isNotEmpty) {
                tokenCandidates.add(uMap['token'] as String);
              }
            } catch (_) {}
          } else if (name == 'persist:root') {
            rawPersistRootValue = val;
            try {
              final dynamic pRoot = jsonDecode(val);
              if (pRoot is Map && pRoot['user'] is String) {
                final dynamic uSlice = jsonDecode(pRoot['user'] as String);
                if (uSlice is Map && uSlice['user'] is Map) {
                  final dynamic innerU = uSlice['user'];
                  final String? pTok = innerU['token']?.toString();
                  if (pTok != null && pTok.isNotEmpty) {
                    tokenCandidates.add(pTok);
                  }
                }
              }
            } catch (_) {}
          }
        }
      }

      // انتخاب بهترین Access Token (دارای کلیم‌های Voyager و بیشترین زمان انقضا exp)
      int bestScore = -1;
      int bestExp = -1;
      for (final String cand in tokenCandidates) {
        final Map<String, dynamic> payload = _decodeJwtPayload(cand);
        final bool voyager = payload.containsKey('cerberusId') ||
            payload.containsKey('userId') ||
            payload.containsKey('alternativeCustomerId') ||
            payload.containsKey('tenant');
        final int expVal = _parsePositiveInt(payload['exp']);
        final int score = voyager ? 2 : (payload.isNotEmpty ? 1 : 0);
        if (score > bestScore || (score == bestScore && expVal > bestExp)) {
          bestScore = score;
          bestExp = expVal;
          tMs = cand;
        }
      }

      // اطمینان از معتبر بودن Access Token (بدون سوزاندن بی‌مورد Refresh Token در صورت معتبر بودن توکن فعلی)
      tMs = await _ensureValidAccessToken(tMs, rTk);
      if (!mounted || currentGen != _sessionGeneration) return;

      // استخراج آبجکت اولیه user
      Map<String, dynamic> cleanUserMap = {};
      bool wasRawState = false;
      if (rawUserValue != null && rawUserValue.isNotEmpty) {
        try {
          final bool wasEnc =
              rawUserValue.contains('%7B') || rawUserValue.contains('%22');
          final String decStr =
              wasEnc ? Uri.decodeComponent(rawUserValue) : rawUserValue;
          final dynamic parsed = jsonDecode(decStr);
          if (parsed is Map<String, dynamic>) {
            cleanUserMap = (parsed['state'] is Map &&
                    parsed['state']['user'] is Map<String, dynamic>)
                ? Map<String, dynamic>.from(parsed['state']['user'] as Map)
                : parsed;
            if (cleanUserMap['state'] == false ||
                cleanUserMap['customerIsLoggedInForFirstTime'] == true) {
              wasRawState = true;
            }
          }
        } catch (_) {}
      }

      _normalizeUserMap(cleanUserMap, tMs);

      // فعال‌سازی پروفایل در Voyager (UpdateCustomer) و دریافت همزمان آدرس‌های ثبت‌شده کاربر
      final int initialCid = _parsePositiveInt(
          cleanUserMap['id'] ?? cleanUserMap['alternativeCustomerId']);

      final profileAndAddr = await Future.wait([
        _ensureCustomerProfileInVoyager(tMs, cleanUserMap, wasRawState),
        _fetchUserAddressesFromApi(tMs, initialCid),
      ]);
      if (!mounted || currentGen != _sessionGeneration) return;

      final Map<String, dynamic>? initialAddressResponse =
          profileAndAddr[1] as Map<String, dynamic>?;

      _normalizeUserMap(cleanUserMap, tMs,
          addressResponse: initialAddressResponse);

      final String normalizedUserPlainJson = jsonEncode(cleanUserMap);
      final String normalizedUserCookie =
          Uri.encodeComponent(normalizedUserPlainJson);
      final String zustandUserJson =
          _buildZustandUserStoreJson(cleanUserMap, tMs, rTk);
      final String normalizedPersistRoot = _normalizePersistRootString(
        rawPersistRootValue,
        cleanUserMap,
        tMs,
        addressResponse: initialAddressResponse,
      );

      String defaultCityId = '129';
      String defaultCityName = 'تهران';
      if (initialAddressResponse != null &&
          initialAddressResponse['data'] is Map &&
          (initialAddressResponse['data']['customerAddressResponseItems']
              is List) &&
          (initialAddressResponse['data']['customerAddressResponseItems']
                  as List)
              .isNotEmpty) {
        final dynamic fa = (initialAddressResponse['data']
                ['customerAddressResponseItems'] as List)
            .first;
        if (fa is Map) {
          final int cid = _parsePositiveInt(fa['cityId']);
          if (cid > 0) defaultCityId = cid.toString();
          final String cname = fa['cityName']?.toString().trim() ?? '';
          if (cname.isNotEmpty) defaultCityName = cname;
        }
      }

      final List<Map<String, String>> normalizedLocalData = [];
      bool hasCityId = false;
      bool hasCityName = false;
      bool hasPersistRoot = false;

      for (var item in rawLocalData) {
        if (item is! Map) continue;
        final String? name = item['name']?.toString();
        if (name == null || name.isEmpty) continue;
        if (name == 'refresh_token' || name == 'user') continue;
        String val = item['value']?.toString() ?? '';

        if (name == 'persist:root') {
          val = normalizedPersistRoot;
          hasPersistRoot = true;
        } else if (name == 'token' || name == 'tokenMS') {
          if (tMs != null && tMs.isNotEmpty) val = tMs;
        } else if (name == 'city_id') {
          val = defaultCityId;
          hasCityId = true;
        } else if (name == 'city_name') {
          val = defaultCityName;
          hasCityName = true;
        }

        normalizedLocalData.add({'name': name, 'value': val});
      }

      if (!hasPersistRoot) {
        normalizedLocalData
            .add({'name': 'persist:root', 'value': normalizedPersistRoot});
      }
      if (!hasCityId) {
        normalizedLocalData.add({'name': 'city_id', 'value': defaultCityId});
      }
      if (!hasCityName) {
        normalizedLocalData
            .add({'name': 'city_name', 'value': defaultCityName});
      }

      // ۳. ثبت کوکی‌ها روی دامنه www.okala.com، .okala.com و apigateway.okala.com (بدون کوکی refresh_token)
      final WebUri storeUri = WebUri('https://$storeHost/');
      final WebUri apiGatewayUri = WebUri('https://apigateway.okala.com/');
      final int futureExpiresMs =
          DateTime.now().add(const Duration(days: 90)).millisecondsSinceEpoch;
      final List<Future<void>> cookieFutures = [];

      if (tMs != null && tMs.isNotEmpty) {
        for (final String cookieName in ['tokenMS', 'token']) {
          cookieFutures.add(cookieManager.setCookie(
            url: storeUri,
            name: cookieName,
            value: tMs,
            path: '/',
            expiresDate: futureExpiresMs,
            isHttpOnly: false,
            isSecure: false,
            sameSite: HTTPCookieSameSitePolicy.LAX,
          ));
          cookieFutures.add(cookieManager.setCookie(
            url: storeUri,
            name: cookieName,
            value: tMs,
            domain: '.okala.com',
            path: '/',
            expiresDate: futureExpiresMs,
            isHttpOnly: false,
            isSecure: true,
            sameSite: HTTPCookieSameSitePolicy.NONE,
          ));
          cookieFutures.add(cookieManager.setCookie(
            url: apiGatewayUri,
            name: cookieName,
            value: tMs,
            domain: '.okala.com',
            path: '/',
            expiresDate: futureExpiresMs,
            isHttpOnly: false,
            isSecure: true,
            sameSite: HTTPCookieSameSitePolicy.NONE,
          ));
        }

        cookieFutures.add(cookieManager.setCookie(
          url: storeUri,
          name: 'checkTenant',
          value: 'true',
          path: '/',
          expiresDate: futureExpiresMs,
          isHttpOnly: false,
          isSecure: false,
          sameSite: HTTPCookieSameSitePolicy.LAX,
        ));
      }

      if (normalizedUserCookie.isNotEmpty) {
        cookieFutures.add(cookieManager.setCookie(
          url: storeUri,
          name: 'user',
          value: normalizedUserCookie,
          path: '/',
          expiresDate: futureExpiresMs,
          isHttpOnly: false,
          isSecure: false,
          sameSite: HTTPCookieSameSitePolicy.LAX,
        ));
        cookieFutures.add(cookieManager.setCookie(
          url: storeUri,
          name: 'user',
          value: normalizedUserCookie,
          domain: '.okala.com',
          path: '/',
          expiresDate: futureExpiresMs,
          isHttpOnly: false,
          isSecure: true,
          sameSite: HTTPCookieSameSitePolicy.NONE,
        ));
        cookieFutures.add(cookieManager.setCookie(
          url: apiGatewayUri,
          name: 'user',
          value: normalizedUserCookie,
          domain: '.okala.com',
          path: '/',
          expiresDate: futureExpiresMs,
          isHttpOnly: false,
          isSecure: true,
          sameSite: HTTPCookieSameSitePolicy.NONE,
        ));
      }

      for (var c in cookies) {
        if (c is! Map) continue;
        final String? cName = c['name']?.toString();
        final String? cVal = c['value']?.toString();
        if (cName == null || cName.isEmpty || cVal == null) continue;
        if (cName == 'tokenMS' ||
            cName == 'refresh_token' ||
            cName == 'token' ||
            cName == 'user') {
          continue;
        }
        final String rawDomain = c['domain']?.toString() ?? '.okala.com';
        final String domain =
            rawDomain.startsWith('.') ? rawDomain : '.$rawDomain';
        cookieFutures.add(cookieManager.setCookie(
          url: storeUri,
          name: cName,
          value: cVal,
          domain: domain,
          path: c['path']?.toString() ?? '/',
          expiresDate: futureExpiresMs,
          isHttpOnly: c['httpOnly'] == true,
          isSecure: true,
          sameSite: HTTPCookieSameSitePolicy.NONE,
        ));
      }

      await Future.wait(cookieFutures);
      if (!mounted || currentGen != _sessionGeneration) return;

      // ۴. آماده‌سازی اسکریپت تزریق و صفحه بوت‌استرپ
      final String script = _buildFastInjectionScript(
        targetKey: targetKey,
        localData: normalizedLocalData,
        tokenMs: tMs,
        refreshToken: rTk,
        userCookieValue: normalizedUserCookie,
        userPlainJson: normalizedUserPlainJson,
        zustandUserJson: zustandUserJson,
        initialAddressResponse: initialAddressResponse,
      );

      _activeInjectionScript = script;
      _activeBootstrapHtml = _buildBootstrapHtml(script);
      _activeTargetKey = targetKey;

      setState(() {
        _loadingMessage = 'در حال ورود به فروشگاه...';
        _progress = 0.4;
      });

      if (_webViewController != null) {
        await _webViewController!.removeAllUserScripts();
        await _webViewController!.addUserScript(
          userScript: UserScript(
            source: _activeInjectionScript,
            injectionTime: UserScriptInjectionTime.AT_DOCUMENT_START,
          ),
        );
        // اجرای صفحه بوت‌استرپ روی دامنه https://www.okala.com/ تا قبل از اجرای Next.js تمام مقادیر localStorage و sessionStorage اکانت جدید ثبت شوند
        await _webViewController!.loadData(
          data: _activeBootstrapHtml,
          mimeType: 'text/html',
          encoding: 'utf-8',
          baseUrl: WebUri('https://$storeHost/'),
          historyUrl: WebUri('https://$storeHost/'),
        );
      }
    } on TimeoutException {
      if (!mounted || currentGen != _sessionGeneration) return;
      setState(() {
        _hasError = true;
        _loadingMessage =
            'مهلت اتصال به سرور به پایان رسید. اینترنت خود را بررسی کنید.';
      });
    } catch (e) {
      if (!mounted || currentGen != _sessionGeneration) return;
      setState(() {
        _hasError = true;
        _loadingMessage = 'خطا در بارگذاری حساب: $e';
      });
    }
  }

  void _nextAccount() {
    if (_currentIndex < widget.urls.length - 1) {
      _loadAccount(_currentIndex + 1);
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'شما در آخرین حساب کاربری هستید.',
            style: TextStyle(color: bgDark, fontWeight: FontWeight.bold),
          ),
          backgroundColor: primaryAccent,
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  void _prevAccount() {
    if (_currentIndex > 0) {
      _loadAccount(_currentIndex - 1);
    }
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      onPopInvoked: (didPop) async {
        if (didPop) return;
        if (_webViewController != null &&
            await _webViewController!.canGoBack()) {
          await _webViewController!.goBack();
        } else if (context.mounted) {
          Navigator.of(context).pop();
        }
      },
      child: Scaffold(
        backgroundColor: bgDark,
        appBar: AppBar(
          title: Text(
            'حساب ${_currentIndex + 1} از ${widget.urls.length}',
            style: const TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w700,
              color: textPrimary,
            ),
          ),
          backgroundColor: surfaceDark,
          elevation: 0,
          iconTheme: const IconThemeData(color: textPrimary),
          centerTitle: true,
          actions: [
            IconButton(
              tooltip: 'پاکسازی کش و حافظه',
              onPressed: () => _cleanupWebViewCache(showNotice: true),
              icon: const Icon(Icons.cleaning_services_rounded,
                  size: 20, color: textSecondary),
            ),
            IconButton(
              tooltip: 'بارگذاری مجدد این حساب',
              onPressed: () => _loadAccount(_currentIndex),
              icon: const Icon(Icons.refresh_rounded,
                  size: 22, color: textSecondary),
            ),
            if (_currentIndex > 0)
              IconButton(
                tooltip: 'حساب قبلی',
                onPressed: _prevAccount,
                icon: const Icon(Icons.arrow_back_ios_new_rounded,
                    size: 18, color: primaryAccent),
              ),
            if (_currentIndex < widget.urls.length - 1)
              Padding(
                padding: const EdgeInsets.only(right: 4.0, left: 6.0),
                child: TextButton(
                  onPressed: _nextAccount,
                  style: TextButton.styleFrom(
                    foregroundColor: primaryAccent,
                    padding: const EdgeInsets.symmetric(horizontal: 10),
                  ),
                  child: const Row(
                    children: [
                      Text('بعدی',
                          style: TextStyle(fontWeight: FontWeight.bold)),
                      SizedBox(width: 4),
                      Icon(Icons.arrow_forward_ios_rounded, size: 14),
                    ],
                  ),
                ),
              ),
          ],
          bottom: _isLoading
              ? PreferredSize(
                  preferredSize: const Size.fromHeight(3),
                  child: LinearProgressIndicator(
                    value: _progress > 0 ? _progress : null,
                    backgroundColor: surfaceDark,
                    color: primaryAccent,
                    minHeight: 3,
                  ),
                )
              : null,
        ),
        drawer: Drawer(
          backgroundColor: surfaceDark,
          child: Column(
            children: [
              Container(
                width: double.infinity,
                padding: const EdgeInsets.only(top: 56, bottom: 24),
                decoration: const BoxDecoration(
                  color: bgDark,
                  border:
                      Border(bottom: BorderSide(color: surfaceDark, width: 2)),
                ),
                child: Column(
                  children: [
                    Container(
                      width: 68,
                      height: 68,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        border: Border.all(color: primaryAccent, width: 1.5),
                      ),
                      child: Padding(
                        padding: const EdgeInsets.all(10.0),
                        child: Image.asset(
                          'assets/nexus_icon.png',
                          errorBuilder: (context, error, stackTrace) =>
                              const Icon(Icons.link,
                                  color: primaryAccent, size: 30),
                        ),
                      ),
                    ),
                    const SizedBox(height: 14),
                    const Text(
                      'Nexus Link',
                      style: TextStyle(
                        color: textPrimary,
                        fontSize: 19,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 12, vertical: 4),
                      decoration: BoxDecoration(
                        color: primaryAccent.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Text(
                        '${widget.urls.length} پیوند فعال',
                        style: const TextStyle(
                          color: primaryAccent,
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              Expanded(
                child: ListView.separated(
                  itemCount: widget.urls.length,
                  separatorBuilder: (context, index) =>
                      Divider(color: bgDark.withOpacity(0.5), height: 1),
                  itemBuilder: (context, index) {
                    final isActive = index == _currentIndex;
                    return ListTile(
                      contentPadding: const EdgeInsets.symmetric(
                          horizontal: 20, vertical: 4),
                      leading: Container(
                        width: 32,
                        height: 32,
                        decoration: BoxDecoration(
                          color: isActive ? primaryAccent : bgDark,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Center(
                          child: Text(
                            '${index + 1}',
                            style: TextStyle(
                              color: isActive ? bgDark : textSecondary,
                              fontSize: 13,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ),
                      title: Text(
                        'حساب کاربری ${index + 1}',
                        style: TextStyle(
                          color: isActive ? textPrimary : textSecondary,
                          fontWeight:
                              isActive ? FontWeight.bold : FontWeight.normal,
                          fontSize: 14,
                        ),
                      ),
                      selected: isActive,
                      selectedTileColor: primaryAccent.withOpacity(0.05),
                      onTap: () {
                        Navigator.pop(context);
                        if (!isActive) _loadAccount(index);
                      },
                    );
                  },
                ),
              ),
              const Divider(height: 1, color: bgDark),
              ListTile(
                leading: const Icon(Icons.exit_to_app_rounded,
                    color: Colors.redAccent),
                title: const Text(
                  'بازگشت به صفحه اصلی',
                  style: TextStyle(
                      color: Colors.redAccent,
                      fontSize: 14,
                      fontWeight: FontWeight.bold),
                ),
                onTap: () {
                  Navigator.pop(context);
                  Navigator.pop(context);
                },
              ),
            ],
          ),
        ),
        body: Stack(
          children: [
            InAppWebView(
              initialUrlRequest: URLRequest(url: WebUri('about:blank')),
              initialUserScripts: UnmodifiableListView<UserScript>([]),
              initialSettings: InAppWebViewSettings(
                javaScriptEnabled: true,
                domStorageEnabled: true,
                databaseEnabled: false,
                cacheEnabled: false,
                cacheMode: CacheMode.LOAD_NO_CACHE,
                clearCache: true,
                clearSessionCache: true,
                thirdPartyCookiesEnabled: true,
                sharedCookiesEnabled: true,
                useShouldOverrideUrlLoading: true,
                userAgent: customUserAgent,
                useHybridComposition: true,
                supportZoom: false,
                mediaPlaybackRequiresUserGesture: true,
                allowsBackForwardNavigationGestures: false,
              ),
              onWebViewCreated: (controller) async {
                _webViewController = controller;
                if (_activeInjectionScript.isNotEmpty &&
                    _activeBootstrapHtml.isNotEmpty) {
                  await controller.addUserScript(
                    userScript: UserScript(
                      source: _activeInjectionScript,
                      injectionTime: UserScriptInjectionTime.AT_DOCUMENT_START,
                    ),
                  );
                  await controller.loadData(
                    data: _activeBootstrapHtml,
                    mimeType: 'text/html',
                    encoding: 'utf-8',
                    baseUrl: WebUri('https://$storeHost/'),
                    historyUrl: WebUri('https://$storeHost/'),
                  );
                }
              },
              shouldOverrideUrlLoading: (controller, navigationAction) async {
                final WebUri? uri = navigationAction.request.url;
                if (uri != null) {
                  final String path = uri.path.toLowerCase();
                  if (uri.host.contains('okala.com') &&
                      (path == '/logout' ||
                          path.startsWith('/logout/') ||
                          path == '/auth' ||
                          path.startsWith('/auth/'))) {
                    await controller.loadUrl(
                      urlRequest: URLRequest(url: WebUri(storeUrl)),
                    );
                    return NavigationActionPolicy.CANCEL;
                  }
                }
                return NavigationActionPolicy.ALLOW;
              },
              onProgressChanged: (controller, progress) {
                if (!mounted) return;
                setState(() {
                  _progress = progress / 100.0;
                });
                if (progress >= 80 && _isLoading && !_hasError) {
                  setState(() {
                    _isLoading = false;
                  });
                }
              },
              onLoadStop: (controller, url) async {
                if (!mounted || url == null) return;
                final String host = url.host.toLowerCase();
                if (host.contains('okala.com')) {
                  if (_activeInjectionScript.isNotEmpty &&
                      _activeTargetKey.isNotEmpty) {
                    final dynamic injected =
                        await controller.evaluateJavascript(
                      source:
                          "localStorage.getItem('__nx_active_key') === '$_activeTargetKey' ? '1' : '0'",
                    );
                    if (injected?.toString() != '1') {
                      await controller.evaluateJavascript(
                          source: _activeInjectionScript);
                      await controller.loadUrl(
                        urlRequest: URLRequest(url: WebUri(storeUrl)),
                      );
                      return;
                    }
                  }
                  if (mounted && _isLoading) {
                    setState(() {
                      _isLoading = false;
                    });
                  }
                }
              },
              onReceivedError: (controller, request, error) {
                if (request.isForMainFrame == true && mounted) {
                  setState(() {
                    _isLoading = false;
                  });
                }
              },
            ),
            if (_isLoading || _hasError)
              Container(
                color: bgDark,
                padding: const EdgeInsets.all(24),
                child: Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      if (!_hasError)
                        const CircularProgressIndicator(
                          color: primaryAccent,
                          strokeWidth: 3,
                        )
                      else
                        const Icon(
                          Icons.wifi_off_rounded,
                          color: Colors.redAccent,
                          size: 48,
                        ),
                      const SizedBox(height: 24),
                      Text(
                        _loadingMessage,
                        textAlign: TextAlign.center,
                        textDirection: TextDirection.rtl,
                        style: TextStyle(
                          color: _hasError ? Colors.redAccent : textSecondary,
                          fontWeight: FontWeight.w500,
                          fontSize: 15,
                        ),
                      ),
                      if (_hasError) ...[
                        const SizedBox(height: 20),
                        ElevatedButton.icon(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: primaryAccent,
                            foregroundColor: bgDark,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                          onPressed: () => _loadAccount(_currentIndex),
                          icon: const Icon(Icons.refresh_rounded, size: 18),
                          label: const Text(
                            'تلاش مجدد',
                            style: TextStyle(fontWeight: FontWeight.bold),
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
