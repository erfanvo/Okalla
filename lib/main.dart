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
const String bootstrapPath = '/__nexus_init__';

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
    final bool isAllowed =
        allowedLinkHosts.any((allowedHost) => host == allowedHost);

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
  final http.Client _httpClient = http.Client();
  InAppWebViewController? _webViewController;

  int _currentIndex = 0;
  int _sessionGeneration = 0;
  bool _isLoading = true;
  bool _isBootstrapping = true;
  bool _hasError = false;
  String _loadingMessage = 'در حال آماده‌سازی...';
  double _progress = 0.0;

  String _activeInjectionScript = '';
  String _activeBootstrapHtml = '';

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

  /// اصلاح فیلدهای وضعیت کاربر برای جلوگیری از خروج خودکار در اوکالا
  void _normalizeUserMap(Map<String, dynamic> userMap, String? tokenMs) {
    userMap['customerIsLoggedInForFirstTime'] = false;
    userMap['state'] = true;
    userMap['stateCode'] = 1;
    if (tokenMs != null && tokenMs.isNotEmpty) {
      userMap['token'] = tokenMs;
    }
  }

  /// نرمال‌سازی مقدار user (برای کوکی به صورت URL-Encoded و برای localStorage به صورت JSON خام)
  String _normalizeUserValueString(String rawValue, String? tokenMs,
      {required bool urlEncodeOutput}) {
    try {
      final bool wasEncoded =
          rawValue.contains('%7B') || rawValue.contains('%22');
      final String decodedStr =
          wasEncoded ? Uri.decodeComponent(rawValue) : rawValue;
      final dynamic parsed = jsonDecode(decodedStr);
      if (parsed is Map<String, dynamic>) {
        _normalizeUserMap(parsed, tokenMs);
        final String reEncodedJson = jsonEncode(parsed);
        return urlEncodeOutput
            ? Uri.encodeComponent(reEncodedJson)
            : reEncodedJson;
      }
    } catch (_) {}
    return rawValue;
  }

  /// نرمال‌سازی ساختار persist:root برای هماهنگی کامل Redux Persist با توکن و وضعیت لاگین
  String _normalizePersistRootString(String rawValue, String? tokenMs) {
    try {
      final dynamic outer = jsonDecode(rawValue);
      if (outer is Map<String, dynamic>) {
        if (outer['user'] is String) {
          try {
            final dynamic userSlice = jsonDecode(outer['user'] as String);
            if (userSlice is Map<String, dynamic>) {
              if (userSlice['user'] is Map<String, dynamic>) {
                final Map<String, dynamic> innerUser =
                    Map<String, dynamic>.from(userSlice['user'] as Map);
                _normalizeUserMap(innerUser, tokenMs);
                userSlice['user'] = innerUser;
              }
              outer['user'] = jsonEncode(userSlice);
            }
          } catch (_) {}
        }

        if (outer['eventData'] is String) {
          try {
            final dynamic eventSlice = jsonDecode(outer['eventData'] as String);
            if (eventSlice is Map<String, dynamic>) {
              eventSlice['isLoggedIn'] = true;
              outer['eventData'] = jsonEncode(eventSlice);
            }
          } catch (_) {}
        }

        if (outer['_persist'] is String) {
          try {
            final dynamic persistSlice =
                jsonDecode(outer['_persist'] as String);
            if (persistSlice is Map<String, dynamic>) {
              persistSlice['rehydrated'] = true;
              outer['_persist'] = jsonEncode(persistSlice);
            }
          } catch (_) {}
        }

        return jsonEncode(outer);
      }
    } catch (_) {}
    return rawValue;
  }

  /// ساخت اسکریپت جامع تزریق، محافظت از کوکی/حافظه و سپر ضد ۴۰۱ (Anti-Logout Shield)
  String _buildFastInjectionScript({
    required String targetKey,
    required List<Map<String, String>> localData,
    required String? tokenMs,
    required String? refreshToken,
    required String? userCookieValue,
    required String? userPlainJson,
  }) {
    final String safeJsonItems =
        jsonEncode(localData).replaceAll('</', r'<\/');
    final String safeTokenMs = jsonEncode(tokenMs ?? '');
    final String safeRefreshToken = jsonEncode(refreshToken ?? '');
    final String safeUserCookie = jsonEncode(userCookieValue ?? '');
    final String safeUserPlainJson = jsonEncode(userPlainJson ?? '');
    final String safeTargetKey = jsonEncode(targetKey);

    const String template = r'''
      (function() {
        try {
          if (!location.hostname || location.hostname.toLowerCase().indexOf('okala.com') === -1) return;

          var targetKey = __TARGET_KEY__;
          var items = __ITEMS_JSON__;
          var tMs = __TOKEN_MS__;
          var rTk = __REFRESH_TOKEN__;
          var uCk = __USER_COOKIE__;
          var uJson = __USER_PLAIN_JSON__;

          if (!window.__nxOrigStorage) {
            window.__nxOrigStorage = {
              setItem: Storage.prototype.setItem,
              removeItem: Storage.prototype.removeItem,
              clear: Storage.prototype.clear,
              cookieDesc: Object.getOwnPropertyDescriptor(Document.prototype, 'cookie') ||
                          Object.getOwnPropertyDescriptor(HTMLDocument.prototype, 'cookie')
            };
          }

          var origSetItem = window.__nxOrigStorage.setItem;
          var origRemoveItem = window.__nxOrigStorage.removeItem;
          var origClear = window.__nxOrigStorage.clear;
          var origCookieDesc = window.__nxOrigStorage.cookieDesc;

          function setRawCookie(cookieStr) {
            try {
              if (origCookieDesc && origCookieDesc.set) {
                origCookieDesc.set.call(document, cookieStr);
              } else {
                document.cookie = cookieStr;
              }
            } catch (_) {}
          }

          function fixUserStatuses(str, wantUrlEncoded) {
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
              if (wantUrlEncoded === true) return encodeURIComponent(raw);
              if (wantUrlEncoded === false) return raw;
              return isUrlEncoded ? encodeURIComponent(raw) : raw;
            } catch (_) {
              return str;
            }
          }

          function applyAuthState(forceClear) {
            try {
              if (forceClear) {
                origClear.call(localStorage);
                origClear.call(sessionStorage);
              }

              if (Array.isArray(items)) {
                for (var i = 0; i < items.length; i++) {
                  var item = items[i];
                  if (!item || !item.name) continue;
                  var k = String(item.name);
                  var v = item.value != null ? String(item.value) : '';
                  if (k === 'user') {
                    v = fixUserStatuses(v, false);
                  } else if (k === 'persist:root') {
                    v = fixUserStatuses(v, false);
                  }
                  origSetItem.call(localStorage, k, v);
                }
              }

              if (tMs !== '') {
                origSetItem.call(localStorage, 'tokenMS', tMs);
                origSetItem.call(localStorage, 'token', tMs);
              }
              if (rTk !== '') {
                origSetItem.call(localStorage, 'refresh_token', rTk);
              }
              if (uJson !== '') {
                origSetItem.call(localStorage, 'user', fixUserStatuses(uJson, false));
              } else if (uCk !== '') {
                origSetItem.call(localStorage, 'user', fixUserStatuses(uCk, false));
              }

              origSetItem.call(localStorage, '__nx_active_key', targetKey);
              origSetItem.call(sessionStorage, targetKey, '1');

              if (tMs !== '') {
                setRawCookie('tokenMS=' + tMs + '; path=/; max-age=7776000; SameSite=Lax');
                setRawCookie('token=' + tMs + '; path=/; max-age=7776000; SameSite=Lax');
                setRawCookie('tokenMS=' + tMs + '; domain=.okala.com; path=/; max-age=7776000; Secure; SameSite=None');
                setRawCookie('token=' + tMs + '; domain=.okala.com; path=/; max-age=7776000; Secure; SameSite=None');
              }
              if (uCk !== '') {
                var cleanUCk = fixUserStatuses(uCk, true);
                setRawCookie('user=' + cleanUCk + '; path=/; max-age=7776000; SameSite=Lax');
                setRawCookie('user=' + cleanUCk + '; domain=.okala.com; path=/; max-age=7776000; Secure; SameSite=None');
              }
              if (rTk !== '') {
                setRawCookie('refresh_token=' + rTk + '; domain=.okala.com; path=/; max-age=7776000; Secure; SameSite=None');
              }
            } catch (_) {}
          }

          // ۱. تزریق اولیه یا ترمیم در صورت پاک شدن کلیدها
          var isNewAccount = false;
          try {
            isNewAccount = (localStorage.getItem('__nx_active_key') !== targetKey);
          } catch (_) {
            isNewAccount = true;
          }

          if (isNewAccount) {
            applyAuthState(true);
          } else {
            // اطمینان از برقراری کامل کوکی‌ها و کلیدها در لود صفحه اصلی
            if (!localStorage.getItem('token') || !localStorage.getItem('user') || !localStorage.getItem('persist:root')) {
              applyAuthState(false);
            } else {
              if (tMs !== '') {
                setRawCookie('tokenMS=' + tMs + '; path=/; max-age=7776000; SameSite=Lax');
                setRawCookie('token=' + tMs + '; path=/; max-age=7776000; SameSite=Lax');
              }
              if (uCk !== '') {
                setRawCookie('user=' + fixUserStatuses(uCk, true) + '; path=/; max-age=7776000; SameSite=Lax');
              }
            }
          }

          // ۲. نصب محافظ‌های زمان اجرا روی window فعلی
          if (window.__nxProtectedKey !== targetKey) {
            window.__nxProtectedKey = targetKey;

            var savedPersistRoot = localStorage.getItem('persist:root');
            var savedUserObj = null;
            try {
              savedUserObj = JSON.parse(uJson || decodeURIComponent(uCk));
            } catch (_) {}

            function buildFallbackAuthResponse(urlStr) {
              var lower = String(urlStr || '').toLowerCase();
              if (lower.indexOf('token') !== -1 || lower.indexOf('refresh') !== -1 || lower.indexOf('cerberus') !== -1) {
                return JSON.stringify({
                  access_token: tMs,
                  token: tMs,
                  tokenMS: tMs,
                  refresh_token: rTk,
                  expires_in: 36000,
                  token_type: 'Bearer',
                  success: true,
                  isSuccess: true,
                  statusCode: 200
                });
              }
              return JSON.stringify({
                data: savedUserObj || {},
                user: savedUserObj || {},
                success: true,
                isSuccess: true,
                status: true,
                statusCode: 200,
                message: 'OK'
              });
            }

            // الف) محافظت از localStorage در برابر حذف یا لاگ‌اوت شدن Redux Persist
            Storage.prototype.setItem = function(key, value) {
              var k = String(key);
              var v = String(value);

              if (this === localStorage) {
                if (k === 'token' || k === 'tokenMS') {
                  if (!v || v === 'null' || v === 'undefined' || v.length < 20) {
                    return;
                  }
                  tMs = v;
                } else if (k === 'user') {
                  if (!v || v === 'null' || v === 'undefined' || v === '{}' || v === '%7B%7D') {
                    return;
                  }
                  v = fixUserStatuses(v, false);
                } else if (k === 'persist:root') {
                  v = fixUserStatuses(v, false);
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
                          if (tMs) {
                            parsedUserSlice.user.token = tMs;
                          }
                          parsedRoot.user = JSON.stringify(parsedUserSlice);
                        }
                      }
                      if (shouldRestoreUser && savedPersistRoot) {
                        var prevRoot = JSON.parse(savedPersistRoot);
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
                      savedPersistRoot = v;
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

            // ب) محافظت از کوکی‌ها در برابر حذف توسط js-cookie / سایت
            if (origCookieDesc && origCookieDesc.set && origCookieDesc.get) {
              try {
                Object.defineProperty(document, 'cookie', {
                  configurable: true,
                  get: function() {
                    return origCookieDesc.get.call(this);
                  },
                  set: function(val) {
                    var str = String(val).trim();
                    var eqIdx = str.indexOf('=');
                    if (eqIdx !== -1) {
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
                          tMs = cVal;
                        }
                        if (cName === 'user') {
                          var suffix = semiIdx !== -1 ? rest.substring(semiIdx) : '; path=/; max-age=7776000; SameSite=Lax';
                          str = 'user=' + fixUserStatuses(cVal, true) + suffix;
                        }
                      }
                    }
                    return origCookieDesc.set.call(this, str);
                  }
                });
              } catch (_) {}
            }

            // ج) سپر ضد 401/403 و اصلاح وضعیت کاربر در fetch
            if (window.fetch && !window.__nxFetchWrapped) {
              window.__nxFetchWrapped = true;
              var origFetch = window.fetch;
              window.fetch = function(input, init) {
                var urlStr = '';
                try {
                  urlStr = (typeof input === 'string') ? input : (input && input.url ? input.url : String(input));
                } catch (_) {}

                if (tMs && urlStr.indexOf('okala.com') !== -1) {
                  try {
                    init = init ? Object.assign({}, init) : {};
                    var hdrs = new Headers(init.headers || (typeof input !== 'string' && input && input.headers ? input.headers : undefined));
                    var curAuth = hdrs.get('Authorization') || hdrs.get('authorization');
                    if (!curAuth || curAuth.indexOf('null') !== -1 || curAuth.indexOf('undefined') !== -1 || curAuth.trim() === 'Bearer') {
                      hdrs.set('Authorization', 'Bearer ' + tMs);
                    }
                    init.headers = hdrs;
                  } catch (_) {}
                }

                return origFetch.call(this, input, init).then(function(response) {
                  try {
                    var st = response.status;
                    var lowerUrl = urlStr.toLowerCase();
                    var isRefreshOrAuth = lowerUrl.indexOf('refresh') !== -1 || lowerUrl.indexOf('cerberus') !== -1 || lowerUrl.indexOf('connect/token') !== -1 || lowerUrl.indexOf('logout') !== -1;

                    if (st === 401 || st === 403 || (isRefreshOrAuth && st >= 400)) {
                      return new Response(buildFallbackAuthResponse(urlStr), {
                        status: 200,
                        statusText: 'OK',
                        headers: { 'Content-Type': 'application/json' }
                      });
                    }

                    var cType = response.headers && response.headers.get ? (response.headers.get('content-type') || '') : '';
                    if (cType.indexOf('application/json') !== -1) {
                      var clone = response.clone();
                      return clone.text().then(function(txt) {
                        if (txt && (txt.indexOf('customerIsLoggedInForFirstTime') !== -1 || txt.indexOf('"state":false') !== -1 || txt.indexOf('"state": false') !== -1)) {
                          var fixedTxt = fixUserStatuses(txt, false);
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
                });
              };
            }

            // د) سپر ضد 401/403 همگام (Synchronous Getter) در XMLHttpRequest پیش از اجرای اینترسپتور Axios
            if (window.XMLHttpRequest && !window.__nxXhrWrapped) {
              window.__nxXhrWrapped = true;
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
                self.__nxHasAuth = false;

                try {
                  if (statusProtoDesc && statusProtoDesc.get) {
                    Object.defineProperty(self, 'status', {
                      configurable: true,
                      get: function() {
                        var realStatus = statusProtoDesc.get.call(self);
                        var lowerUrl = (self.__nxUrl || '').toLowerCase();
                        var isRefreshOrAuth = lowerUrl.indexOf('refresh') !== -1 || lowerUrl.indexOf('cerberus') !== -1 || lowerUrl.indexOf('connect/token') !== -1 || lowerUrl.indexOf('logout') !== -1;
                        if (realStatus === 401 || realStatus === 403 || (isRefreshOrAuth && realStatus >= 400)) {
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
                        if (realStatus === 401 || realStatus === 403) return 'OK';
                        return statusTextProtoDesc.get.call(self);
                      }
                    });
                  }
                  if (responseTextProtoDesc && responseTextProtoDesc.get) {
                    Object.defineProperty(self, 'responseText', {
                      configurable: true,
                      get: function() {
                        var realStatus = statusProtoDesc ? statusProtoDesc.get.call(self) : 200;
                        var lowerUrl = (self.__nxUrl || '').toLowerCase();
                        var isRefreshOrAuth = lowerUrl.indexOf('refresh') !== -1 || lowerUrl.indexOf('cerberus') !== -1 || lowerUrl.indexOf('connect/token') !== -1 || lowerUrl.indexOf('logout') !== -1;
                        if (realStatus === 401 || realStatus === 403 || (isRefreshOrAuth && realStatus >= 400)) {
                          return buildFallbackAuthResponse(self.__nxUrl);
                        }
                        var rawTxt = responseTextProtoDesc.get.call(self);
                        if (typeof rawTxt === 'string' && (rawTxt.indexOf('customerIsLoggedInForFirstTime') !== -1 || rawTxt.indexOf('"state":false') !== -1 || rawTxt.indexOf('"state": false') !== -1)) {
                          return fixUserStatuses(rawTxt, false);
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
                        var lowerUrl = (self.__nxUrl || '').toLowerCase();
                        var isRefreshOrAuth = lowerUrl.indexOf('refresh') !== -1 || lowerUrl.indexOf('cerberus') !== -1 || lowerUrl.indexOf('connect/token') !== -1 || lowerUrl.indexOf('logout') !== -1;
                        if (realStatus === 401 || realStatus === 403 || (isRefreshOrAuth && realStatus >= 400)) {
                          var fallbackStr = buildFallbackAuthResponse(self.__nxUrl);
                          if (self.responseType === 'json') {
                            try { return JSON.parse(fallbackStr); } catch (_) { return fallbackStr; }
                          }
                          return fallbackStr;
                        }
                        var rawResp = responseProtoDesc.get.call(self);
                        if (typeof rawResp === 'string' && (rawResp.indexOf('customerIsLoggedInForFirstTime') !== -1 || rawResp.indexOf('"state":false') !== -1 || rawResp.indexOf('"state": false') !== -1)) {
                          return fixUserStatuses(rawResp, false);
                        }
                        return rawResp;
                      }
                    });
                  }
                } catch (_) {}

                return origOpen.apply(this, arguments);
              };

              XMLHttpRequest.prototype.setRequestHeader = function(header, value) {
                if (String(header).toLowerCase() === 'authorization') {
                  var vStr = String(value || '');
                  if (vStr.indexOf('null') !== -1 || vStr.indexOf('undefined') !== -1 || vStr.trim() === 'Bearer') {
                    if (tMs) {
                      this.__nxHasAuth = true;
                      return origSetRequestHeader.call(this, header, 'Bearer ' + tMs);
                    }
                  } else {
                    this.__nxHasAuth = true;
                  }
                }
                return origSetRequestHeader.apply(this, arguments);
              };

              XMLHttpRequest.prototype.send = function() {
                try {
                  if (!this.__nxHasAuth && tMs && this.__nxUrl && this.__nxUrl.indexOf('okala.com') !== -1) {
                    origSetRequestHeader.call(this, 'Authorization', 'Bearer ' + tMs);
                  }
                } catch (_) {}
                return origSend.apply(this, arguments);
              };
            }

            // هـ) پایش دوره‌ای برای اطمینان از پاک نشدن نشست
            if (window.__nxWatchdogTimer) {
              clearInterval(window.__nxWatchdogTimer);
            }
            window.__nxWatchdogTimer = setInterval(function() {
              try {
                if (window.__nxProtectedKey !== targetKey) return;
                if (tMs && !localStorage.getItem('token')) {
                  origSetItem.call(localStorage, 'token', tMs);
                  origSetItem.call(localStorage, 'tokenMS', tMs);
                }
                if (uJson && !localStorage.getItem('user')) {
                  origSetItem.call(localStorage, 'user', fixUserStatuses(uJson, false));
                }
                var curCookies = origCookieDesc && origCookieDesc.get ? origCookieDesc.get.call(document) : document.cookie;
                if (tMs && curCookies.indexOf('token=') === -1) {
                  setRawCookie('tokenMS=' + tMs + '; path=/; max-age=7776000; SameSite=Lax');
                  setRawCookie('token=' + tMs + '; path=/; max-age=7776000; SameSite=Lax');
                }
              } catch (_) {}
            }, 400);
          }
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
        .replaceAll('__USER_PLAIN_JSON__', safeUserPlainJson);
  }

  /// ساخت صفحه بوت‌استرپ محلی روی دامنه اوکالا برای تزریق ۱۰۰٪ تضمینی پیش از لود سایت
  String _buildBootstrapHtml(String injectionScript) {
    return '''
<!DOCTYPE html>
<html lang="fa" dir="rtl">
<head>
  <meta charset="utf-8">
  <meta name="viewport" content="width=device-width, initial-scale=1.0">
  <style>
    html, body {
      margin: 0;
      padding: 0;
      width: 100%;
      height: 100%;
      background-color: #12141D;
    }
  </style>
  <script>
    $injectionScript
    window.location.replace('https://$storeHost/');
  </script>
</head>
<body></body>
</html>
''';
  }

  Future<void> _loadAccount(int index) async {
    if (!mounted) return;
    _sessionGeneration++;
    final int currentGen = _sessionGeneration;
    final String targetKey = '__nx_acc_${index}_$currentGen';

    setState(() {
      _isLoading = true;
      _isBootstrapping = true;
      _hasError = false;
      _progress = 0.1;
      _loadingMessage = 'در حال دریافت اطلاعات حساب ${index + 1}...';
      _currentIndex = index;
    });

    try {
      // ۱. توقف کامل صفحه قبلی قبل از تغییر کوکی‌ها
      if (_webViewController != null) {
        await _webViewController!.stopLoading();
        await _webViewController!.removeAllUserScripts();
        await _webViewController!.loadUrl(
          urlRequest: URLRequest(url: WebUri('about:blank')),
        );
      }

      final CookieManager cookieManager = CookieManager.instance();

      // ۲. پاکسازی کوکی‌های قبلی و دریافت اطلاعات اکانت جدید به صورت موازی
      final results = await Future.wait([
        cookieManager.deleteAllCookies(),
        _httpClient
            .get(Uri.parse(widget.urls[index]))
            .timeout(const Duration(seconds: 15)),
      ]);

      if (!mounted || currentGen != _sessionGeneration) return;

      final http.Response response = results[1] as http.Response;
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

      final List<dynamic> cookies =
          (data['cookies'] is List) ? data['cookies'] : [];
      for (var c in cookies) {
        if (c is Map) {
          final String? name = c['name']?.toString();
          final String? val = c['value']?.toString();
          if (val == null || val.isEmpty) continue;
          if (name == 'tokenMS') tMs = val;
          if (name == 'token' && (tMs == null || tMs.isEmpty)) tMs = val;
          if (name == 'refresh_token') rTk = val;
          if (name == 'user') rawUserValue = val;
        }
      }

      for (var item in rawLocalData) {
        if (item is Map) {
          final String? name = item['name']?.toString();
          final String? val = item['value']?.toString();
          if (val == null || val.isEmpty) continue;
          if (name == 'tokenMS' && (tMs == null || tMs.isEmpty)) tMs = val;
          if (name == 'token' && (tMs == null || tMs.isEmpty)) tMs = val;
          if (name == 'refresh_token' && (rTk == null || rTk.isEmpty)) {
            rTk = val;
          }
          if (name == 'user' && (rawUserValue == null || rawUserValue.isEmpty)) {
            rawUserValue = val;
          }
        }
      }

      // کوکی user باید URL-Encoded باشد و localStorage['user'] باید JSON خام باشد
      final String? normalizedUserCookie = rawUserValue != null
          ? _normalizeUserValueString(rawUserValue, tMs, urlEncodeOutput: true)
          : null;
      final String? normalizedUserPlainJson = rawUserValue != null
          ? _normalizeUserValueString(rawUserValue, tMs, urlEncodeOutput: false)
          : null;

      final List<Map<String, String>> normalizedLocalData = [];
      bool hasCityId = false;
      bool hasCityName = false;
      bool hasUser = false;

      for (var item in rawLocalData) {
        if (item is! Map) continue;
        final String? name = item['name']?.toString();
        if (name == null || name.isEmpty) continue;
        String val = item['value']?.toString() ?? '';

        if (name == 'user') {
          val = _normalizeUserValueString(val, tMs, urlEncodeOutput: false);
          hasUser = true;
        } else if (name == 'persist:root') {
          val = _normalizePersistRootString(val, tMs);
        } else if (name == 'token' || name == 'tokenMS') {
          if (tMs != null && tMs.isNotEmpty) val = tMs;
        } else if (name == 'city_id') {
          hasCityId = true;
        } else if (name == 'city_name') {
          hasCityName = true;
        }

        normalizedLocalData.add({'name': name, 'value': val});
      }

      if (!hasUser && normalizedUserPlainJson != null) {
        normalizedLocalData
            .add({'name': 'user', 'value': normalizedUserPlainJson});
      }
      if (!hasCityId) {
        normalizedLocalData.add({'name': 'city_id', 'value': '129'});
      }
      if (!hasCityName) {
        normalizedLocalData.add({'name': 'city_name', 'value': 'تهران'});
      }

      // ۳. ثبت کوکی‌ها هم روی دامنه اصلی (.okala.com) برای زیرسرویس‌های API و هم روی www.okala.com
      final WebUri storeUri = WebUri('https://$storeHost/');
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
        }
      }

      if (normalizedUserCookie != null && normalizedUserCookie.isNotEmpty) {
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
      );
      final String bootstrapHtml = _buildBootstrapHtml(script);

      _activeInjectionScript = script;
      _activeBootstrapHtml = bootstrapHtml;

      setState(() {
        _loadingMessage = 'در حال ورود به فروشگاه...';
        _progress = 0.4;
      });

      if (_webViewController != null) {
        await _webViewController!.addUserScript(
          userScript: UserScript(
            source: script,
            injectionTime: UserScriptInjectionTime.AT_DOCUMENT_START,
            forMainFrameOnly: false,
          ),
        );
        await _webViewController!.loadData(
          data: bootstrapHtml,
          mimeType: 'text/html',
          encoding: 'utf-8',
          baseUrl: WebUri('https://$storeHost$bootstrapPath'),
          historyUrl: WebUri('https://$storeHost/'),
        );
      }
    } on TimeoutException {
      if (!mounted || currentGen != _sessionGeneration) return;
      setState(() {
        _hasError = true;
        _isLoading = false;
        _loadingMessage =
            'مهلت اتصال به سرور به پایان رسید. اینترنت خود را بررسی کنید.';
      });
    } catch (e) {
      if (!mounted || currentGen != _sessionGeneration) return;
      setState(() {
        _hasError = true;
        _isLoading = false;
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
          final WebUri? currentUrl = await _webViewController!.getUrl();
          if (currentUrl != null &&
              currentUrl.path != '/' &&
              currentUrl.path.isNotEmpty &&
              !currentUrl.path.contains(bootstrapPath)) {
            await _webViewController!.goBack();
            return;
          }
        }
        if (context.mounted) {
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
                databaseEnabled: true,
                cacheEnabled: true,
                cacheMode: CacheMode.LOAD_DEFAULT,
                clearCache: false,
                clearSessionCache: false,
                thirdPartyCookiesEnabled: true,
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
                      forMainFrameOnly: false,
                    ),
                  );
                  await controller.loadData(
                    data: _activeBootstrapHtml,
                    mimeType: 'text/html',
                    encoding: 'utf-8',
                    baseUrl: WebUri('https://$storeHost$bootstrapPath'),
                    historyUrl: WebUri('https://$storeHost/'),
                  );
                }
              },
              onLoadStart: (controller, url) async {
                if (!mounted || url == null) return;
                final String urlStr = url.toString();
                if (url.host.toLowerCase().contains('okala.com') &&
                    !urlStr.contains(bootstrapPath)) {
                  setState(() {
                    _isBootstrapping = false;
                  });
                  if (_activeInjectionScript.isNotEmpty) {
                    await controller.evaluateJavascript(
                        source: _activeInjectionScript);
                  }
                }
              },
              onProgressChanged: (controller, progress) async {
                if (!mounted || _isBootstrapping) return;
                setState(() {
                  _progress = progress / 100.0;
                });
                if (_activeInjectionScript.isNotEmpty && progress >= 20) {
                  try {
                    await controller.evaluateJavascript(
                        source: _activeInjectionScript);
                  } catch (_) {}
                }
                if (progress >= 85 && _isLoading && !_hasError) {
                  setState(() {
                    _isLoading = false;
                  });
                }
              },
              onLoadStop: (controller, url) async {
                if (!mounted || url == null) return;
                final String urlStr = url.toString();
                final String host = url.host.toLowerCase();
                if (host.contains('okala.com') &&
                    !urlStr.contains(bootstrapPath)) {
                  if (_activeInjectionScript.isNotEmpty) {
                    await controller.evaluateJavascript(
                        source: _activeInjectionScript);
                  }
                  if (mounted && (_isLoading || _isBootstrapping)) {
                    setState(() {
                      _isBootstrapping = false;
                      _isLoading = false;
                    });
                  }
                }
              },
              onReceivedError: (controller, request, error) {
                if (request.isForMainFrame == true &&
                    !_isBootstrapping &&
                    mounted) {
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
