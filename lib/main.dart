
import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;
import 'package:flutter_inappwebview/flutter_inappwebview.dart';

const Color bgDark = Color(0xFF090D16);
const Color cardDark = Color(0xFF131B2E);
const Color primaryAccent = Color(0xFF00E5FF);
const Color secondaryAccent = Color(0xFF1E88E5);
const Color textPrimary = Color(0xFFF8FAFC);
const Color textSecondary = Color(0xFF94A3B8);

const String storeHost = 'www.okala.com';
const String storeUrl = 'https://www.okala.com/stores';

const String customUserAgent =
    'Mozilla/5.0 (Linux; Android 13; SM-S918B) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/122.0.0.0 Mobile Safari/537.36';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  SystemChrome.setSystemUIOverlayStyle(
    const SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      statusBarIconBrightness: Brightness.light,
      systemNavigationBarColor: bgDark,
      systemNavigationBarIconBrightness: Brightness.light,
    ),
  );
  runApp(const NexusLinkApp());
}

class NexusLinkApp extends StatelessWidget {
  const NexusLinkApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Nexus Link',
      debugShowCheckedModeBanner: false,
      theme: ThemeData.dark().copyWith(
        scaffoldBackgroundColor: bgDark,
        primaryColor: primaryAccent,
        colorScheme: const ColorScheme.dark(
          primary: primaryAccent,
          secondary: secondaryAccent,
          surface: cardDark,
        ),
      ),
      home: const InputScreen(),
    );
  }
}

class InputScreen extends StatefulWidget {
  const InputScreen({super.key});

  @override
  State<InputScreen> createState() => _InputScreenState();
}

class _InputScreenState extends State<InputScreen> {
  final TextEditingController _linksController = TextEditingController();
  String _statusMessage = '';
  bool _isWarning = false;

  Future<void> _pasteFromClipboard() async {
    final ClipboardData? data = await Clipboard.getData(Clipboard.kTextPlain);
    if (data != null && data.text != null) {
      setState(() {
        final currentText = _linksController.text;
        _linksController.text = currentText.isEmpty
            ? data.text!
            : '$currentText\n${data.text!}';
        _statusMessage = '';
      });
    }
  }

  void _processLinks() {
    final rawText = _linksController.text.trim();
    if (rawText.isEmpty) {
      setState(() {
        _statusMessage = 'لطفاً حداقل یک پیوند معتبر وارد نمایید.';
        _isWarning = true;
      });
      return;
    }

    final RegExp urlRegex = RegExp(r'(https?://[^\s]+)');
    final Iterable<RegExpMatch> matches = urlRegex.allMatches(rawText);
    final List<String> urls = matches.map((m) => m.group(0)!).toList();

    if (urls.isEmpty) {
      setState(() {
        _statusMessage = 'هیچ پیوند معتبری (شروع با http/https) یافت نشد.';
        _isWarning = true;
      });
      return;
    }

    Navigator.of(context).pushReplacement(
      PageRouteBuilder(
        pageBuilder: (context, animation, secondaryAnimation) =>
            BrowserScreen(urls: urls),
        transitionsBuilder: (context, animation, secondaryAnimation, child) {
          return FadeTransition(opacity: animation, child: child);
        },
      ),
    );
  }

  @override
  void dispose() {
    _linksController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: RadialGradient(
            center: Alignment.topRight,
            radius: 1.5,
            colors: [Color(0xFF162238), bgDark],
          ),
        ),
        child: SafeArea(
          child: Center(
            child: SingleChildScrollView(
              padding:
                  const EdgeInsets.symmetric(horizontal: 24.0, vertical: 16.0),
              child: Container(
                constraints: const BoxConstraints(maxWidth: 480),
                padding: const EdgeInsets.all(28.0),
                decoration: BoxDecoration(
                  color: cardDark.withOpacity(0.85),
                  borderRadius: BorderRadius.circular(28),
                  border: Border.all(
                      color: Colors.white.withOpacity(0.08), width: 1.5),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.5),
                      blurRadius: 30,
                      offset: const Offset(0, 15),
                    ),
                    BoxShadow(
                      color: primaryAccent.withOpacity(0.05),
                      blurRadius: 40,
                      spreadRadius: 2,
                    ),
                  ],
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: primaryAccent.withOpacity(0.1),
                            shape: BoxShape.circle,
                            border: Border.all(
                                color: primaryAccent.withOpacity(0.3)),
                          ),
                          child: const Icon(
                            Icons.hub_rounded,
                            color: primaryAccent,
                            size: 32,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    const Text(
                      'نکسوس لینک',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 26,
                        fontWeight: FontWeight.w900,
                        color: textPrimary,
                        letterSpacing: 0.5,
                      ),
                    ),
                    const SizedBox(height: 6),
                    const Text(
                      'مدیریت هوشمند و فوق‌سریع نشست‌های کاربری',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 13,
                        color: textSecondary,
                      ),
                    ),
                    const SizedBox(height: 28),
                    Directionality(
                      textDirection: TextDirection.rtl,
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text(
                            'لیست پیوندها:',
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.bold,
                              color: textPrimary,
                            ),
                          ),
                          TextButton.icon(
                            onPressed: _pasteFromClipboard,
                            icon: const Icon(Icons.content_paste_rounded,
                                size: 16, color: primaryAccent),
                            label: const Text(
                              'چسباندن از حافظه',
                              style: TextStyle(
                                  color: primaryAccent, fontSize: 12),
                            ),
                            style: TextButton.styleFrom(
                              backgroundColor: primaryAccent.withOpacity(0.1),
                              shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12)),
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 12, vertical: 6),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 10),
                    TextField(
                      controller: _linksController,
                      maxLines: 6,
                      textDirection: TextDirection.ltr,
                      style: const TextStyle(
                        color: textPrimary,
                        fontSize: 13,
                        fontFamily: 'monospace',
                      ),
                      decoration: InputDecoration(
                        hintText:
                            'https://example.com/acc/1\nhttps://example.com/acc/2',
                        hintStyle: TextStyle(
                            color: textSecondary.withOpacity(0.4)),
                        filled: true,
                        fillColor: bgDark.withOpacity(0.6),
                        contentPadding: const EdgeInsets.all(16),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(16),
                          borderSide: BorderSide.none,
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(16),
                          borderSide: BorderSide(
                              color: Colors.white.withOpacity(0.05)),
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
  bool _isPreparingAccount = true;
  bool _hasError = false;
  String _loadingMessage = 'در حال آماده‌سازی...';
  double _progress = 0.0;

  String _activeInjectionScript = '';

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

  /// ارتقای توکن معمولی به توکن کامل Voyager از طریق customer_token_exchange_grant_type (مطابق ماژول 18726 اوکالا)
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

  /// تلاش برای رفرش مستقیم توکن از سرور اوکالا (مطابق منطق ربات Main1.py)
  /// اگر رفرش‌توکن منقضی شده باشد (کد 400/401)، آن را حذف می‌کند تا کوکی منقضی به BFF اوکالا ارسال نشود.
  Future<Map<String, String?>> _tryRenewTokenIfPossible(
      String? accessToken, String? refreshToken) async {
    String? cleanAccess = accessToken?.trim();
    if (cleanAccess != null &&
        cleanAccess.toLowerCase().startsWith('bearer ')) {
      cleanAccess = cleanAccess.substring(7).trim();
    }

    if (refreshToken == null || refreshToken.trim().isEmpty) {
      if (cleanAccess != null &&
          cleanAccess.isNotEmpty &&
          !_hasVoyagerClaims(cleanAccess)) {
        final String? exchanged = await _exchangeForVoyagerToken(cleanAccess);
        if (exchanged != null) cleanAccess = exchanged;
      }
      return {
        'access_token': cleanAccess,
        'refresh_token': null,
        'refresh_valid': 'false',
      };
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

      // مطابق Main1.py: اگر به خاطر هدر Authorization خطای 401 داد، یک بار بدون هدر تست شود
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
          final String? newRef = bodyJson['refresh_token']?.toString();
          if (newAcc != null && newAcc.isNotEmpty) {
            if (!_hasVoyagerClaims(newAcc)) {
              final String? exchanged = await _exchangeForVoyagerToken(newAcc);
              if (exchanged != null && _hasVoyagerClaims(exchanged)) {
                newAcc = exchanged;
              } else if (cleanAccess != null &&
                  _hasVoyagerClaims(cleanAccess)) {
                final Map<String, dynamic> oldJwt =
                    _decodeJwtPayload(cleanAccess);
                final int oldExp = _parsePositiveInt(oldJwt['exp']);
                final int nowSec =
                    DateTime.now().millisecondsSinceEpoch ~/ 1000;
                if (oldExp > nowSec + 120) {
                  newAcc = cleanAccess;
                }
              }
            }
            return {
              'access_token': newAcc,
              'refresh_token':
                  (newRef != null && newRef.isNotEmpty) ? newRef : cleanRefresh,
              'refresh_valid': 'true',
            };
          }
        }
      }

      // اگر رفرش‌توکن منقضی یا نامعتبر است، ولی توکن فعلی نیاز به ارتقای Voyager دارد
      if (cleanAccess != null &&
          cleanAccess.isNotEmpty &&
          !_hasVoyagerClaims(cleanAccess)) {
        final String? exchanged = await _exchangeForVoyagerToken(cleanAccess);
        if (exchanged != null) cleanAccess = exchanged;
      }

      return {
        'access_token': cleanAccess,
        'refresh_token': null,
        'refresh_valid': 'false',
      };
    } catch (_) {
      return {
        'access_token': cleanAccess,
        'refresh_token': null,
        'refresh_valid': 'false',
      };
    }
  }

  /// دریافت لیست واقعی آدرس‌های کاربر از سرور اوکالا برای جلوگیری از ریدایرکت به صفحه بدون آدرس و تکمیل شناسه مشتری
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

  /// تکمیل و اصلاح تمام فیلدهای آبجکت user با اولویت کلیم‌های JWT (جلوگیری از باگ id=0 و عدم تطابق customerId)
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

    // ۱. استخراج شناسه عددی مشتری (id) با اولویت توکن JWT (چون در لینک‌های ربات گاهی id=0 است)
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

    // ۲. استخراج شناسه альтернаتیو عددی مشتری (alternativeCustomerId)
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

    // ۳. استخراج شناسه UUID (alternativeId / cerberusId) با اولویت JWT
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

    // ۴. استخراج شماره موبایل با اولویت JWT
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

    // ۵. نام و نام خانوادگی
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
    userMap['firstName'] = firstName.isEmpty ? 'کاربر' : firstName;
    userMap['lastName'] = lastName.isEmpty ? 'اکالا' : lastName;

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
      'eventStartTime': 0,
      'eventStartTimeForEditAddress': 0,
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

          var parsedUserInfoPascal = {
            Id: parsedUserObj.id || 0,
            AlternativeId: parsedUserObj.alternativeId || '',
            AlternativeCustomerId: parsedUserObj.alternativeCustomerId || parsedUserObj.id || 0,
            FirstName: parsedUserObj.firstName || 'کاربر',
            LastName: parsedUserObj.lastName || 'اکالا',
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
                }
              }
            } catch (_) {}
          }

          // ذخیره وضعیت اکانت فعال در سطح window
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
            cachedAddressResp: normalizeAddressResponseObject(initAddrResp) ||
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
              if (st.rTk) {
                setRawCookie('refresh_token=' + st.rTk + '; domain=.okala.com; path=/; max-age=7776000; Secure; SameSite=None');
              } else {
                setRawCookie('refresh_token=; path=/; max-age=0');
                setRawCookie('refresh_token=; domain=.okala.com; path=/; max-age=0; Secure; SameSite=None');
              }
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
                  if (k === 'refresh_token' && !st.rTk) continue;
                  if (k === 'user') continue; // کلید user در localStorage با ساختار استاندارد Zustand ذخیره می‌شود
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
              if (st.rTk !== '') {
                origSetItem.call(localStorage, 'refresh_token', st.rTk);
              } else {
                origRemoveItem.call(localStorage, 'refresh_token');
              }
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
              var modified = false;

              if ('customerId' in obj && validCid > 0) {
                if (!obj.customerId || Number(obj.customerId) <= 0 || Number(obj.customerId) !== validCid) {
                  obj.customerId = validCid;
                  modified = true;
                }
              }

              if (isAddOrEditAddressUrl(urlStr)) {
                if (validCid > 0) {
                  obj.customerId = validCid;
                }
                if (obj.plaque != null) {
                  obj.plaque = toEnDigits(obj.plaque).trim() || '1';
                } else {
                  obj.plaque = '1';
                }
                if (obj.unit != null) {
                  obj.unit = toEnDigits(obj.unit).trim() || '1';
                } else {
                  obj.unit = '1';
                }
                if (obj.mobilePhone != null) {
                  obj.mobilePhone = toEnDigits(obj.mobilePhone).trim();
                } else {
                  obj.mobilePhone = '';
                }
                if (obj.postalCode != null) {
                  obj.postalCode = toEnDigits(obj.postalCode).trim();
                }
                if (obj.ShoppingSectorPartId == null || obj.ShoppingSectorPartId === '') {
                  obj.ShoppingSectorPartId = '0';
                }
                if (obj.shoppingSectorId == null || obj.shoppingSectorId === '') {
                  obj.shoppingSectorId = '0';
                }
                if (!obj.addressTypeId || Number(obj.addressTypeId) <= 0) {
                  obj.addressTypeId = 3;
                }
                if (!obj.oprationDuration || Number(obj.oprationDuration) <= 0) {
                  obj.oprationDuration = 12500;
                }
                if (!obj.address || String(obj.address).trim() === '') {
                  obj.address = 'آدرس منتخب روی نقشه';
                }
                if (!obj.mapPlatform) {
                  obj.mapPlatform = 'ParsiMap';
                }
                modified = true;
              }

              return modified ? JSON.stringify(obj) : body;
            } catch (_) {
              return body;
            }
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

          // ۲. نصب لایه‌های محافظ سراسری روی window (همیشه متصل به window.__nxState)
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
                        // ساختار استاندارد Zustand (ماژول 37645)
                        if (!parsedU.state || typeof parsedU.state !== 'object') {
                          parsedU.state = {};
                        }
                        if (!parsedU.state.user || !parsedU.state.user.id) {
                          parsedU.state.user = Object.assign({}, st.savedUserObj, { token: st.tMs });
                        } else {
                          parsedU.state.user.customerIsLoggedInForFirstTime = false;
                          parsedU.state.user.state = true;
                          parsedU.state.user.stateCode = 1;
                          if (st.savedUserObj && st.savedUserObj.id && (!parsedU.state.user.id || Number(parsedU.state.user.id) <= 0)) {
                            parsedU.state.user.id = st.savedUserObj.id;
                          }
                          if (st.savedUserObj && st.savedUserObj.alternativeCustomerId && (!parsedU.state.user.alternativeCustomerId || Number(parsedU.state.user.alternativeCustomerId) <= 0)) {
                            parsedU.state.user.alternativeCustomerId = st.savedUserObj.alternativeCustomerId;
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
                        // اگر آبجکت تخت بود، به فرمت استاندارد Zustand تبدیل شود
                        parsedU.customerIsLoggedInForFirstTime = false;
                        parsedU.state = true;
                        parsedU.stateCode = 1;
                        if (st.savedUserObj && st.savedUserObj.id && (!parsedU.id || Number(parsedU.id) <= 0)) {
                          parsedU.id = st.savedUserObj.id;
                        }
                        if (st.savedUserObj && st.savedUserObj.alternativeCustomerId && (!parsedU.alternativeCustomerId || Number(parsedU.alternativeCustomerId) <= 0)) {
                          parsedU.alternativeCustomerId = st.savedUserObj.alternativeCustomerId;
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

            // هـ) محافظت از window.fetch (بدون تزریق هدر Authorization روی /api/bff/ تا CORS Preflight خطا ندهد)
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

                if (isBffUrl(urlStr)) {
                  syncCookiesNow();
                }

                return origFetch.call(this, input, init).then(function(response) {
                  try {
                    if (urlStr.indexOf('okala.com') !== -1) {
                      syncCookiesNow();
                    }

                    var status = response.status;
                    if (status === 401 || status === 403 || ((isTokenRefreshUrl(urlStr) || isBffUrl(urlStr)) && status >= 400)) {
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
                  if (curTMs && (isTokenRefreshUrl(urlStr) || isBffUrl(urlStr))) {
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
                        if (realStatus === 401 || realStatus === 403 || ((isTokenRefreshUrl(self.__nxUrl) || isLogoutUrl(self.__nxUrl)) && realStatus >= 400)) {
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
                        if (realStatus === 401 || realStatus === 403 || ((isTokenRefreshUrl(self.__nxUrl) || isLogoutUrl(self.__nxUrl)) && realStatus >= 400)) {
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
                        if (isLogoutUrl(self.__nxUrl) || realStatus === 401 || realStatus === 403 || (isTokenRefreshUrl(self.__nxUrl) && realStatus >= 400)) {
                          return buildFallbackApiResponse(self.__nxUrl);
                        }
                        var rawTxt = '';
                        try {
                          rawTxt = responseTextProtoDesc.get.call(self);
                        } catch (_) {
                          return '';
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
                            var normAddr = normalizeAddressResponseObject(addrObj);
                            if (normAddr) {
                              syncAddressToSessionStorage(normAddr);
                              return JSON.stringify(normAddr);
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
                        if (isLogoutUrl(self.__nxUrl) || realStatus === 401 || realStatus === 403 || (isTokenRefreshUrl(self.__nxUrl) && realStatus >= 400)) {
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
                              var nAddr = normalizeAddressResponseObject(aObj);
                              if (nAddr) {
                                syncAddressToSessionStorage(nAddr);
                                return JSON.stringify(nAddr);
                              }
                            } catch (_) {}
                          } else if (rawResp && typeof rawResp === 'object') {
                            var nAddrObj = normalizeAddressResponseObject(rawResp);
                            if (nAddrObj) {
                              syncAddressToSessionStorage(nAddrObj);
                              return nAddrObj;
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

  Future<void> _loadAccount(int index) async {
    if (!mounted) return;
    _sessionGeneration++;
    _globalSessionCounter++;
    final int currentGen = _sessionGeneration;
    final String targetKey =
        '__nx_acc_${index}_${currentGen}_${_globalSessionCounter}_${DateTime.now().microsecondsSinceEpoch}';

    setState(() {
      _isLoading = true;
      _isPreparingAccount = true;
      _hasError = false;
      _progress = 0.1;
      _loadingMessage = 'در حال دریافت اطلاعات حساب ${index + 1}...';
      _currentIndex = index;
    });

    try {
      // ۱. توقف کامل صفحه قبلی و پاکسازی Storage در سطح جاوااسکریپت و بومی قبل از تغییر اکانت
      if (_webViewController != null) {
        await _webViewController!.stopLoading();
        await _webViewController!.removeAllUserScripts();
        try {
          await _webViewController!.evaluateJavascript(source: '''
            try {
              if (window.__nxWatchdogTimer) clearInterval(window.__nxWatchdogTimer);
              window.__nxState = null;
              if (window.__nxOrigApi && window.__nxOrigApi.clear) {
                window.__nxOrigApi.clear.call(localStorage);
                window.__nxOrigApi.clear.call(sessionStorage);
              } else {
                localStorage.clear();
                sessionStorage.clear();
              }
            } catch (_) {}
          ''');
        } catch (_) {}
        await _webViewController!.loadUrl(
          urlRequest: URLRequest(url: WebUri('about:blank')),
        );
      }

      final CookieManager cookieManager = CookieManager.instance();
      final WebStorageManager webStorageManager = WebStorageManager.instance();

      // ۲. پاکسازی کامل کوکی‌ها و WebStorage قبلی و دریافت اطلاعات اکانت جدید به صورت موازی
      final results = await Future.wait([
        cookieManager.deleteAllCookies(),
        webStorageManager.deleteAllData(),
        _httpClient
            .get(Uri.parse(widget.urls[index]))
            .timeout(const Duration(seconds: 15)),
      ]);

      if (!mounted || currentGen != _sessionGeneration) return;

      final http.Response response = results[2] as http.Response;
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

      // بررسی رفرش‌توکن و ارتقای احتمالی به توکن کامل Voyager
      final renewed = await _tryRenewTokenIfPossible(tMs, rTk);
      if (!mounted || currentGen != _sessionGeneration) return;
      if (renewed['access_token'] != null &&
          renewed['access_token']!.isNotEmpty) {
        tMs = renewed['access_token'];
      }
      if (renewed['refresh_valid'] == 'true' &&
          renewed['refresh_token'] != null &&
          renewed['refresh_token']!.isNotEmpty) {
        rTk = renewed['refresh_token'];
      } else {
        rTk = null;
      }

      // استخراج آبجکت اولیه user و شناسه عددی مشتری برای دریافت آدرس‌های واقعی اکانت
      Map<String, dynamic> cleanUserMap = {};
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
          }
        } catch (_) {}
      }

      _normalizeUserMap(cleanUserMap, tMs);
      final int initialCid = _parsePositiveInt(
          cleanUserMap['id'] ?? cleanUserMap['alternativeCustomerId']);

      // دریافت لیست آدرس‌های ثبت‌شده کاربر از سرور اوکالا
      final Map<String, dynamic>? initialAddressResponse =
          await _fetchUserAddressesFromApi(tMs, initialCid);
      if (!mounted || currentGen != _sessionGeneration) return;

      // تکمیل مجدد آبجکت user با استفاده از اطلاعات دقیق آدرس (در صورت وجود)
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
        if (name == 'refresh_token' && (rTk == null || rTk.isEmpty)) continue;
        if (name == 'user') continue; // جداگانه با ساختار Zustand تزریق می‌شود
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

      // ۳. ثبت کوکی‌ها روی دامنه www.okala.com، .okala.com و apigateway.okala.com
      final WebUri storeUri = WebUri('https://$storeHost/');
      final WebUri apiGatewayUri = WebUri('https://apigateway.okala.com/');
      final int futureExpiresMs =
          DateTime.now().add(const Duration(days: 90)).millisecondsSinceEpoch;
      final List<Future<void>> cookieFutures = [];

      if (rTk != null && rTk.isNotEmpty) {
        cookieFutures.add(cookieManager.setCookie(
          url: storeUri,
          name: 'refresh_token',
          value: rTk,
          domain: '.okala.com',
          path: '/',
          expiresDate: futureExpiresMs,
          isHttpOnly: true,
          isSecure: true,
          sameSite: HTTPCookieSameSitePolicy.NONE,
        ));
        cookieFutures.add(cookieManager.setCookie(
          url: apiGatewayUri,
          name: 'refresh_token',
          value: rTk,
          domain: '.okala.com',
          path: '/',
          expiresDate: futureExpiresMs,
          isHttpOnly: true,
          isSecure: true,
          sameSite: HTTPCookieSameSitePolicy.NONE,
        ));
      }

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

      // ۴. آماده‌سازی اسکریپت تزریق در DOCUMENT_START
      _activeInjectionScript = _buildFastInjectionScript(
        targetKey: targetKey,
        localData: normalizedLocalData,
        tokenMs: tMs,
        refreshToken: rTk,
        userCookieValue: normalizedUserCookie,
        userPlainJson: normalizedUserPlainJson,
        zustandUserJson: zustandUserJson,
        initialAddressResponse: initialAddressResponse,
      );

      if (_webViewController != null) {
        await _webViewController!.addUserScript(
          userScript: UserScript(
            source: _activeInjectionScript,
            injectionTime: UserScriptInjectionTime.AT_DOCUMENT_START,
          ),
        );

        if (!mounted || currentGen != _sessionGeneration) return;
        setState(() {
          _isPreparingAccount = false;
          _loadingMessage = 'در حال بارگذاری فروشگاه...';
          _progress = 0.4;
        });

        await _webViewController!.loadUrl(
          urlRequest: URLRequest(url: WebUri(storeUrl)),
        );
      } else {
        setState(() {
          _isPreparingAccount = false;
          _loadingMessage = 'در حال راه‌اندازی مرورگر...';
          _progress = 0.4;
        });
      }
    } catch (e) {
      if (!mounted || currentGen != _sessionGeneration) return;
      setState(() {
        _hasError = true;
        _isLoading = false;
        _isPreparingAccount = false;
        _loadingMessage = 'خطا در بارگذاری حساب:\n${e.toString()}';
      });
    }
  }

  void _goBackToInput() {
    Navigator.of(context).pushReplacement(
      PageRouteBuilder(
        pageBuilder: (context, animation, secondaryAnimation) =>
            const InputScreen(),
        transitionsBuilder: (context, animation, secondaryAnimation, child) {
          return FadeTransition(opacity: animation, child: child);
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (bool didPop, dynamic result) async {
        if (didPop) return;
        if (_webViewController != null &&
            await _webViewController!.canGoBack()) {
          await _webViewController!.goBack();
        } else {
          _goBackToInput();
        }
      },
      child: Scaffold(
        backgroundColor: bgDark,
        appBar: AppBar(
          backgroundColor: cardDark,
          elevation: 2,
          leading: Builder(
            builder: (context) => IconButton(
              icon: const Icon(Icons.menu_rounded, color: primaryAccent),
              tooltip: 'فهرست حساب‌ها',
              onPressed: () => Scaffold.of(context).openDrawer(),
            ),
          ),
          title: Text(
            'حساب ${_currentIndex + 1} از ${widget.urls.length}',
            style: const TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: textPrimary,
            ),
          ),
          centerTitle: true,
          actions: [
            IconButton(
              icon: const Icon(Icons.cleaning_services_rounded,
                  color: textSecondary, size: 20),
              tooltip: 'پاکسازی کش مرورگر',
              onPressed: () => _cleanupWebViewCache(showNotice: true),
            ),
            IconButton(
              icon: const Icon(Icons.refresh_rounded, color: textPrimary),
              tooltip: 'بارگذاری مجدد این حساب',
              onPressed: () => _loadAccount(_currentIndex),
            ),
          ],
          bottom: PreferredSize(
            preferredSize: const Size.fromHeight(3.0),
            child: _isLoading
                ? LinearProgressIndicator(
                    value: _progress > 0 ? _progress : null,
                    backgroundColor: Colors.transparent,
                    valueColor:
                        const AlwaysStoppedAnimation<Color>(primaryAccent),
                    minHeight: 3.0,
                  )
                : const SizedBox(height: 3.0),
          ),
        ),
        drawer: _buildAccountDrawer(),
        body: Stack(
          children: [
            InAppWebView(
              initialSettings: InAppWebViewSettings(
                javaScriptEnabled: true,
                domStorageEnabled: true,
                databaseEnabled: true,
                useShouldOverrideUrlLoading: true,
                userAgent: customUserAgent,
                thirdPartyCookiesEnabled: true,
                sharedCookiesEnabled: true,
                cacheEnabled: true,
                clearCache: false,
                mediaPlaybackRequiresUserGesture: false,
                allowsInlineMediaPlayback: true,
                mixedContentMode: MixedContentMode.MIXED_CONTENT_ALWAYS_ALLOW,
                supportZoom: false,
              ),
              onWebViewCreated: (controller) async {
                _webViewController = controller;
                if (_activeInjectionScript.isNotEmpty) {
                  await controller.addUserScript(
                    userScript: UserScript(
                      source: _activeInjectionScript,
                      injectionTime: UserScriptInjectionTime.AT_DOCUMENT_START,
                    ),
                  );
                  await controller.loadUrl(
                    urlRequest: URLRequest(url: WebUri(storeUrl)),
                  );
                }
              },
              shouldOverrideUrlLoading: (controller, navigationAction) async {
                final WebUri? uri = navigationAction.request.url;
                if (uri != null) {
                  final String path = uri.path.toLowerCase();
                  // جلوگیری از هدایت به صفحه خروج (/logout) یا لاگین (/auth)
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
              onLoadStart: (controller, url) async {
                if (_isPreparingAccount) return;
                if (_activeInjectionScript.isNotEmpty &&
                    url != null &&
                    url.toString().contains('okala.com')) {
                  try {
                    await controller.evaluateJavascript(
                        source: _activeInjectionScript);
                  } catch (_) {}
                }
                if (mounted) {
                  setState(() {
                    _isLoading = true;
                    _loadingMessage = 'در حال بارگذاری فروشگاه...';
                  });
                }
              },
              onProgressChanged: (controller, progress) {
                if (_isPreparingAccount) return;
                if (mounted) {
                  setState(() {
                    _progress = progress / 100.0;
                    if (progress >= 85 && _isLoading) {
                      _isLoading = false;
                    }
                  });
                }
              },
              onLoadStop: (controller, url) async {
                if (_isPreparingAccount) return;
                if (_activeInjectionScript.isNotEmpty &&
                    url != null &&
                    url.toString().contains('okala.com')) {
                  try {
                    await controller.evaluateJavascript(
                        source: _activeInjectionScript);
                  } catch (_) {}
                }
                if (mounted) {
                  setState(() {
                    _isLoading = false;
                    _progress = 1.0;
                  });
                }
              },
              onReceivedError: (controller, request, error) {
                if (request.isForMainFrame == true && !_isPreparingAccount) {
                  if (mounted) {
                    setState(() {
                      _isLoading = false;
                    });
                  }
                }
              },
            ),
            if (_isPreparingAccount || _hasError)
              Container(
                color: bgDark.withOpacity(0.92),
                child: Center(
                  child: Container(
                    margin: const EdgeInsets.symmetric(horizontal: 32),
                    padding: const EdgeInsets.all(24),
                    decoration: BoxDecoration(
                      color: cardDark,
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(
                        color: _hasError
                            ? Colors.redAccent.withOpacity(0.4)
                            : primaryAccent.withOpacity(0.25),
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.5),
                          blurRadius: 20,
                        ),
                      ],
                    ),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        if (_hasError)
                          const Icon(Icons.error_outline_rounded,
                              color: Colors.redAccent, size: 48)
                        else
                          const SizedBox(
                            width: 42,
                            height: 42,
                            child: CircularProgressIndicator(
                              strokeWidth: 3.5,
                              valueColor:
                                  AlwaysStoppedAnimation<Color>(primaryAccent),
                            ),
                          ),
                        const SizedBox(height: 18),
                        Text(
                          _loadingMessage,
                          textAlign: TextAlign.center,
                          textDirection: TextDirection.rtl,
                          style: const TextStyle(
                            color: textPrimary,
                            fontSize: 14,
                            height: 1.5,
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
              ),
          ],
        ),
        bottomNavigationBar:
            widget.urls.length > 1 ? _buildBottomBar() : null,
      ),
    );
  }

  Widget _buildBottomBar() {
    final bool hasPrev = _currentIndex > 0;
    final bool hasNext = _currentIndex < widget.urls.length - 1;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      decoration: BoxDecoration(
        color: cardDark,
        border: Border(
          top: BorderSide(color: Colors.white.withOpacity(0.08)),
        ),
      ),
      child: SafeArea(
        top: false,
        child: Directionality(
          textDirection: TextDirection.rtl,
          child: Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed:
                      hasPrev ? () => _loadAccount(_currentIndex - 1) : null,
                  icon: const Icon(Icons.arrow_back_ios_rounded, size: 16),
                  label: const Text('حساب قبلی'),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: textPrimary,
                    side: BorderSide(
                      color: hasPrev
                          ? primaryAccent.withOpacity(0.4)
                          : Colors.white12,
                    ),
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: ElevatedButton.icon(
                  onPressed:
                      hasNext ? () => _loadAccount(_currentIndex + 1) : null,
                  icon: const Icon(Icons.arrow_forward_ios_rounded, size: 16),
                  label: const Text(
                    'حساب بعدی',
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: primaryAccent,
                    foregroundColor: bgDark,
                    disabledBackgroundColor: Colors.white10,
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildAccountDrawer() {
    return Drawer(
      backgroundColor: cardDark,
      child: SafeArea(
        child: Directionality(
          textDirection: TextDirection.rtl,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: bgDark.withOpacity(0.6),
                  border: Border(
                    bottom: BorderSide(color: Colors.white.withOpacity(0.08)),
                  ),
                ),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: primaryAccent.withOpacity(0.15),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(Icons.manage_accounts_rounded,
                          color: primaryAccent, size: 24),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'فهرست حساب‌ها',
                            style: TextStyle(
                              color: textPrimary,
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            'مجموع: ${widget.urls.length} پیوند',
                            style: const TextStyle(
                              color: textSecondary,
                              fontSize: 12,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              Expanded(
                child: ListView.separated(
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  itemCount: widget.urls.length,
                  separatorBuilder: (_, __) => Divider(
                    color: Colors.white.withOpacity(0.05),
                    height: 1,
                  ),
                  itemBuilder: (context, idx) {
                    final bool isSelected = idx == _currentIndex;
                    return ListTile(
                      selected: isSelected,
                      selectedTileColor: primaryAccent.withOpacity(0.12),
                      leading: CircleAvatar(
                        radius: 16,
                        backgroundColor:
                            isSelected ? primaryAccent : Colors.white10,
                        foregroundColor: isSelected ? bgDark : textSecondary,
                        child: Text(
                          '${idx + 1}',
                          style: const TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                      title: Text(
                        'حساب شماره ${idx + 1}',
                        style: TextStyle(
                          color: isSelected ? primaryAccent : textPrimary,
                          fontWeight:
                              isSelected ? FontWeight.bold : FontWeight.normal,
                          fontSize: 14,
                        ),
                      ),
                      subtitle: Text(
                        widget.urls[idx],
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        textDirection: TextDirection.ltr,
                        style: const TextStyle(
                          color: textSecondary,
                          fontSize: 11,
                        ),
                      ),
                      trailing: isSelected
                          ? const Icon(Icons.check_circle_rounded,
                              color: primaryAccent, size: 20)
                          : null,
                      onTap: () {
                        Navigator.of(context).pop();
                        if (idx != _currentIndex) {
                          _loadAccount(idx);
                        }
                      },
                    );
                  },
                ),
              ),
              Padding(
                padding: const EdgeInsets.all(16.0),
                child: OutlinedButton.icon(
                  onPressed: _goBackToInput,
                  icon: const Icon(Icons.edit_note_rounded,
                      color: Colors.redAccent),
                  label: const Text(
                    'بازگشت به صفحه ورود پیوندها',
                    style: TextStyle(
                      color: Colors.redAccent,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  style: OutlinedButton.styleFrom(
                    side: BorderSide(color: Colors.redAccent.withOpacity(0.4)),
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
