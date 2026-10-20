import 'dart:async';
import 'dart:convert';
import 'dart:collection';
import 'package:flutter/material.dart';
import 'package:flutter_inappwebview/flutter_inappwebview.dart';
import 'package:http/http.dart' as http;

const List<String> allowedLinkHosts = [
  'okalav2.up.railway.app',
  'jetjon1.up.railway.app',
];
const String storeHost = 'www.okala.com';

// پالت رنگی (تم تاریک و مدرن)
const Color bgDark = Color(0xFF12141D);
const Color surfaceDark = Color(0xFF1E212D);
const Color primaryAccent = Color(0xFF00D09E);
const Color textPrimary = Color(0xFFF3F4F6);
const Color textSecondary = Color(0xFF9CA3AF);

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
    if (uri == null) return false;

    final host = uri.host.toLowerCase();
    final bool isAllowed = allowedLinkHosts.any((allowedHost) => host == allowedHost);

    return isAllowed &&
        uri.scheme.toLowerCase() == 'https' &&
        uri.userInfo.isEmpty;
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
        _statusMessage =
            'هیچ پیوند معتبری از دامنه ${allowedLinkHosts.join(" یا ")} یافت نشد.';
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
                                  const Icon(Icons.link_rounded, size: 40, color: primaryAccent),
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
                          icon: const Icon(Icons.clear_all, size: 16, color: textSecondary),
                          label: const Text(
                            'پاک کردن متن',
                            style: TextStyle(color: textSecondary, fontSize: 12),
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
                          color: (_isWarning ? Colors.redAccent : primaryAccent).withOpacity(0.1),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: (_isWarning ? Colors.redAccent : primaryAccent).withOpacity(0.3),
                          ),
                        ),
                        child: Row(
                          children: [
                            Icon(
                              _isWarning ? Icons.error_outline : Icons.check_circle_outline,
                              color: _isWarning ? Colors.redAccent : primaryAccent,
                              size: 20,
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Text(
                                _statusMessage,
                                textAlign: TextAlign.right,
                                style: TextStyle(
                                  color: _isWarning ? Colors.redAccent : primaryAccent,
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
  final http.Client _httpClient = http.Client();
  InAppWebViewController? _webViewController;

  int _currentIndex = 0;
  int _sessionGeneration = 0;
  bool _isLoading = true;
  bool _hasError = false;
  String _loadingMessage = 'در حال آماده‌سازی...';
  double _progress = 0.0;

  String _activeInjectionScript = '';
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

  /// پاکسازی کش دیسک و فایل‌های موقت وب‌ویو برای جلوگیری از رسیدن حجم برنامه به 100 مگابایت
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

  /// ساخت اسکریپت تزریق آنی در ابتدای لود صفحه (بدون نیاز به رفرش مجدد و دوبار لود شدن سایت)
  String _buildFastInjectionScript({
    required String targetKey,
    required List<dynamic> localData,
    required String? tokenMs,
    required String? refreshToken,
  }) {
    final String safeJsonItems = jsonEncode(localData).replaceAll('</', '<\\/');
    final String safeTokenMs = jsonEncode(tokenMs ?? '');
    final String safeRefreshToken = jsonEncode(refreshToken ?? '');

    return '''
      (function() {
        try {
          if (!location.hostname || location.hostname.toLowerCase().indexOf('okala.com') === -1) return;

          // ۱. مسدودسازی Service Worker و حذف کش‌های سنگین PWA (جلوگیری از پر شدن ۱۰۰ مگابایت حافظه)
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

          // ۲. بررسی تزریق یک‌باره برای اکانت فعلی (انجام در همان لود اول بدون رفرش مجدد)
          var targetKey = '$targetKey';
          if (sessionStorage.getItem(targetKey) === '1') return;

          localStorage.clear();
          sessionStorage.clear();
          sessionStorage.setItem(targetKey, '1');

          var items = $safeJsonItems;
          if (Array.isArray(items)) {
            for (var i = 0; i < items.length; i++) {
              var item = items[i];
              if (!item || !item.name) continue;
              var k = String(item.name);
              var finalValue = item.value != null ? String(item.value) : '';

              if (k === 'user' || k === 'persist:root') {
                if (finalValue.indexOf('%7B') !== -1) {
                  try {
                    var decodedObjStr = decodeURIComponent(finalValue);
                    if (decodedObjStr.indexOf('"stateCode": 0') !== -1 || decodedObjStr.indexOf('"stateCode":0') !== -1) {
                      decodedObjStr = decodedObjStr.replace(/"stateCode":\s*0/g, '"stateCode": 1');
                      decodedObjStr = decodedObjStr.replace(/"customerIsLoggedInForFirstTime":\s*true/g, '"customerIsLoggedInForFirstTime": false');
                      finalValue = encodeURIComponent(decodedObjStr);
                    }
                  } catch (_) {}
                } else if (finalValue.indexOf('"stateCode": 0') !== -1 || finalValue.indexOf('"stateCode":0') !== -1) {
                  finalValue = finalValue.replace(/\\"stateCode\\":\s*0/g, '\\"stateCode\\": 1');
                  finalValue = finalValue.replace(/"stateCode":\s*0/g, '"stateCode": 1');
                  finalValue = finalValue.replace(/\\"customerIsLoggedInForFirstTime\\":\s*true/g, '\\"customerIsLoggedInForFirstTime\\": false');
                  finalValue = finalValue.replace(/"customerIsLoggedInForFirstTime":\s*true/g, '"customerIsLoggedInForFirstTime": false');
                }
              }
              localStorage.setItem(k, finalValue);
            }
          }

          var tMs = $safeTokenMs;
          var rTk = $safeRefreshToken;
          if (tMs !== '') {
            localStorage.setItem('tokenMS', tMs);
            localStorage.setItem('token', tMs);
          }
          if (rTk !== '') {
            localStorage.setItem('refresh_token', rTk);
          }
        } catch (e) {
          console.error('Fast Injection Error:', e);
        }
      })();
    ''';
  }

  Future<void> _loadAccount(int index) async {
    if (!mounted) return;
    _sessionGeneration++;
    final int currentGen = _sessionGeneration;
    final String targetKey = '__nx_acc_${index}_$currentGen';

    setState(() {
      _isLoading = true;
      _hasError = false;
      _progress = 0.1;
      _loadingMessage = 'در حال دریافت اطلاعات حساب ${index + 1}...';
      _currentIndex = index;
    });

    try {
      // ۱. پاکسازی کش دیسک و کوکی‌های قبلی به صورت موازی
      final CookieManager cookieManager = CookieManager.instance();
      await Future.wait([
        cookieManager.deleteAllCookies(),
        InAppWebViewController.clearAllCache(includeDiskFiles: true),
      ]);

      // ۲. دریافت اطلاعات اکانت با محدودیت زمانی ۱۵ ثانیه (جلوگیری از هنگ کردن برنامه)
      final response = await _httpClient
          .get(Uri.parse(widget.urls[index]))
          .timeout(const Duration(seconds: 15));

      if (!mounted || currentGen != _sessionGeneration) return;

      if (response.statusCode != 200) {
        throw Exception('پاسخ نامعتبر از سرور (کد ${response.statusCode})');
      }

      final dynamic decoded = json.decode(utf8.decode(response.bodyBytes));
      if (decoded is! Map<String, dynamic>) {
        throw Exception('ساختار داده دریافتی معتبر نیست.');
      }
      final Map<String, dynamic> data = decoded;

      List<dynamic> localData = [];
      if (data['origins'] is List && (data['origins'] as List).isNotEmpty) {
        final List<dynamic> originsList = data['origins'];
        dynamic matchedOrigin = originsList.first;
        for (var o in originsList) {
          if (o is Map && o['origin'] != null && o['origin'].toString().contains(storeHost)) {
            matchedOrigin = o;
            break;
          }
        }
        if (matchedOrigin is Map && matchedOrigin['localStorage'] is List) {
          localData = matchedOrigin['localStorage'];
        }
      }

      String? tMs;
      String? rTk;

      final List<dynamic> cookies = (data['cookies'] is List) ? data['cookies'] : [];
      for (var c in cookies) {
        if (c is Map) {
          final String? name = c['name']?.toString();
          final String? val = c['value']?.toString();
          if (name == 'tokenMS' && val != null) tMs = val;
          if (name == 'refresh_token' && val != null) rTk = val;
        }
      }

      if (tMs == null || rTk == null) {
        for (var item in localData) {
          if (item is Map) {
            final String? name = item['name']?.toString();
            final String? val = item['value']?.toString();
            if (name == 'tokenMS' && tMs == null && val != null) tMs = val;
            if (name == 'refresh_token' && rTk == null && val != null) rTk = val;
          }
        }
      }

      // ۳. ثبت موازی تمام کوکی‌ها با Future.wait (افزایش چشمگیر سرعت آماده‌سازی)
      final WebUri storeUri = WebUri('https://$storeHost');
      final List<Future<void>> cookieFutures = [];

      if (tMs != null && tMs.isNotEmpty) {
        cookieFutures.add(cookieManager.setCookie(
          url: storeUri,
          name: 'tokenMS',
          value: tMs,
          domain: '.okala.com',
          path: '/',
          isSecure: true,
          sameSite: HTTPCookieSameSitePolicy.NONE,
        ));
        cookieFutures.add(cookieManager.setCookie(
          url: storeUri,
          name: 'token',
          value: tMs,
          domain: '.okala.com',
          path: '/',
          isSecure: true,
          sameSite: HTTPCookieSameSitePolicy.NONE,
        ));
      }
      if (rTk != null && rTk.isNotEmpty) {
        cookieFutures.add(cookieManager.setCookie(
          url: storeUri,
          name: 'refresh_token',
          value: rTk,
          domain: '.okala.com',
          path: '/',
          isSecure: true,
          sameSite: HTTPCookieSameSitePolicy.NONE,
        ));
      }

      for (var c in cookies) {
        if (c is! Map) continue;
        final String? cName = c['name']?.toString();
        final String? cVal = c['value']?.toString();
        if (cName == null || cName.isEmpty || cVal == null) continue;
        if (cName != 'tokenMS' && cName != 'refresh_token' && cName != 'token') {
          final String rawDomain = c['domain']?.toString() ?? '.okala.com';
          final String domain = rawDomain.startsWith('.') ? rawDomain : '.$rawDomain';
          cookieFutures.add(cookieManager.setCookie(
            url: storeUri,
            name: cName,
            value: cVal,
            domain: domain,
            path: c['path']?.toString() ?? '/',
            isSecure: true,
            sameSite: HTTPCookieSameSitePolicy.NONE,
          ));
        }
      }

      await Future.wait(cookieFutures);
      if (!mounted || currentGen != _sessionGeneration) return;

      // ۴. آماده‌سازی اسکریپت تزریق در لحظه شروع لود سند (AT_DOCUMENT_START)
      final String script = _buildFastInjectionScript(
        targetKey: targetKey,
        localData: localData,
        tokenMs: tMs,
        refreshToken: rTk,
      );

      _activeInjectionScript = script;
      _activeTargetKey = targetKey;

      setState(() {
        _loadingMessage = 'در حال ورود به فروشگاه...';
        _progress = 0.4;
      });

      if (_webViewController != null) {
        await _webViewController!.removeAllUserScripts();
        await _webViewController!.addUserScript(
          userScript: UserScript(
            source: script,
            injectionTime: UserScriptInjectionTime.AT_DOCUMENT_START,
          ),
        );
        // اگر از قبل روی دامنه اوکالا هستیم، بلافاصله حافظه را آپدیت کن تا نیاز به رفرش نباشد
        await _webViewController!.evaluateJavascript(source: script);
        await _webViewController!.loadUrl(
          urlRequest: URLRequest(url: WebUri('https://$storeHost/')),
        );
      }
    } on TimeoutException {
      if (!mounted) return;
      setState(() {
        _hasError = true;
        _loadingMessage = 'مهلت اتصال به سرور به پایان رسید. اینترنت خود را بررسی کنید.';
      });
    } catch (e) {
      if (!mounted) return;
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
        if (_webViewController != null && await _webViewController!.canGoBack()) {
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
              icon: const Icon(Icons.cleaning_services_rounded, size: 20, color: textSecondary),
            ),
            IconButton(
              tooltip: 'بارگذاری مجدد این حساب',
              onPressed: () => _loadAccount(_currentIndex),
              icon: const Icon(Icons.refresh_rounded, size: 22, color: textSecondary),
            ),
            if (_currentIndex > 0)
              IconButton(
                tooltip: 'حساب قبلی',
                onPressed: _prevAccount,
                icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 18, color: primaryAccent),
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
                      Text('بعدی', style: TextStyle(fontWeight: FontWeight.bold)),
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
                  border: Border(bottom: BorderSide(color: surfaceDark, width: 2)),
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
                              const Icon(Icons.link, color: primaryAccent, size: 30),
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
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
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
                      contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 4),
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
                          fontWeight: isActive ? FontWeight.bold : FontWeight.normal,
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
                leading: const Icon(Icons.exit_to_app_rounded, color: Colors.redAccent),
                title: const Text(
                  'بازگشت به صفحه اصلی',
                  style: TextStyle(color: Colors.redAccent, fontSize: 14, fontWeight: FontWeight.bold),
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
            // نگه داشتن یک نمونه ثابت از InAppWebView برای جلوگیری از کرش و نشت رم
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
                useHybridComposition: true,
                supportZoom: false,
                mediaPlaybackRequiresUserGesture: true,
                allowsBackForwardNavigationGestures: false,
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
                    urlRequest: URLRequest(url: WebUri('https://$storeHost/')),
                  );
                }
              },
              onProgressChanged: (controller, progress) {
                if (!mounted) return;
                setState(() {
                  _progress = progress / 100.0;
                });
                // به محض اینکه ۸۰ درصد صفحه رندر شد، لایه لودینگ را بردار تا کاربر معطل نشود
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
                  // بررسی پشتیبان: اگر در برخی گوشی‌های قدیمی AT_DOCUMENT_START اجرا نشده بود، اینجا تزریق کن
                  if (_activeInjectionScript.isNotEmpty && _activeTargetKey.isNotEmpty) {
                    final dynamic injected = await controller.evaluateJavascript(
                      source: "sessionStorage.getItem('$_activeTargetKey')",
                    );
                    if (injected?.toString() != '1') {
                      await controller.evaluateJavascript(source: _activeInjectionScript);
                      await controller.loadUrl(
                        urlRequest: URLRequest(url: WebUri('https://$storeHost/')),
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
