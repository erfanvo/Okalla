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
    if (userMap.containsKey('stateCode')) {
      userMap['stateCode'] = 1;
    }
    if (tokenMs != null && tokenMs.isNotEmpty && userMap.containsKey('token')) {
      userMap['token'] = tokenMs;
    }
  }

  /// نرمال‌سازی مقدار کوکی و localStorage مربوط به user
  String _normalizeUserValueString(String rawValue, String? tokenMs,
      {bool forceUrlEncode = true}) {
    try {
      final bool wasEncoded =
          rawValue.contains('%7B') || rawValue.contains('%22');
      final String decodedStr =
          wasEncoded ? Uri.decodeComponent(rawValue) : rawValue;
      final dynamic parsed = jsonDecode(decodedStr);
      if (parsed is Map<String, dynamic>) {
        _normalizeUserMap(parsed, tokenMs);
        final String reEncodedJson = jsonEncode(parsed);
        return (forceUrlEncode || wasEncoded)
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
                if (tokenMs != null && tokenMs.isNotEmpty) {
                  innerUser['token'] = tokenMs;
                }
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

  /// ساخت اسکریپت تزریق و محافظت از نشست (جلوگیری از حذف توکن و خروج ناگهانی)
  String _buildFastInjectionScript({
    required String targetKey,
    required List<Map<String, String>> localData,
    required String? tokenMs,
    required String? refreshToken,
    required String? userCookieValue,
  }) {
    final String safeJsonItems =
        jsonEncode(localData).replaceAll('</', r'<\/');
    final String safeTokenMs = jsonEncode(tokenMs ?? '');
    final String safeRefreshToken = jsonEncode(refreshToken ?? '');
    final String safeUserCookie = jsonEncode(userCookieValue ?? '');
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

          var origSetItem = Storage.prototype.setItem;
          var origRemoveItem = Storage.prototype.removeItem;
          var origClear = Storage.prototype.clear;

          function fixUserStatuses(str) {
            if (typeof str !== 'string' || str.indexOf('customerIsLoggedInForFirstTime') === -1) return str;
            var isUrlEncoded = str.indexOf('%7B') !== -1 || str.indexOf('%22') !== -1;
            try {
              var raw = isUrlEncoded ? decodeURIComponent(str) : str;
              raw = raw.replace(/("customerIsLoggedInForFirstTime"\s*:\s*)true/g, '$1false');
              raw = raw.replace(/(\\"customerIsLoggedInForFirstTime\\"\s*:\s*)true/g, '$1false');
              raw = raw.replace(/("state"\s*:\s*)false/g, '$1true');
              raw = raw.replace(/(\\"state\\"\s*:\s*)false/g, '$1true');
              raw = raw.replace(/("stateCode"\s*:\s*)0/g, '$11');
              raw = raw.replace(/(\\"stateCode\\"\s*:\s*)0/g, '$11');
              return isUrlEncoded ? encodeURIComponent(raw) : raw;
            } catch (_) {
              return str;
            }
          }

          // ۱. تزریق اولیه و یک‌باره برای اکانت فعلی
          var alreadyInjected = false;
          try {
            alreadyInjected = (localStorage.getItem('__nx_active_key') === targetKey);
          } catch (_) {}

          if (!alreadyInjected) {
            try {
              origClear.call(localStorage);
              origClear.call(sessionStorage);
            } catch (_) {}

            if (Array.isArray(items)) {
              for (var i = 0; i < items.length; i++) {
                var item = items[i];
                if (!item || !item.name) continue;
                var k = String(item.name);
                var v = item.value != null ? String(item.value) : '';
                if (k === 'user' || k === 'persist:root') {
                  v = fixUserStatuses(v);
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
            if (uCk !== '' && !localStorage.getItem('user')) {
              origSetItem.call(localStorage, 'user', fixUserStatuses(uCk));
            }

            origSetItem.call(localStorage, '__nx_active_key', targetKey);
            origSetItem.call(sessionStorage, targetKey, '1');

            // ثبت کوکی‌های سمت کلاینت روی دامنه www.okala.com
            if (tMs !== '') {
              document.cookie = 'tokenMS=' + tMs + '; path=/; max-age=7776000; SameSite=Lax';
              document.cookie = 'token=' + tMs + '; path=/; max-age=7776000; SameSite=Lax';
            }
            if (uCk !== '') {
              document.cookie = 'user=' + fixUserStatuses(uCk) + '; path=/; max-age=7776000; SameSite=Lax';
            }
          }

          // ۲. محافظت در برابر حذف خودکار توکن‌ها و اطلاعات کاربری توسط اسکریپت‌های سایت
          if (!window.__nxStorageProtected) {
            window.__nxStorageProtected = true;

            var savedPersistRoot = localStorage.getItem('persist:root');
            var savedUser = localStorage.getItem('user');

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
                  v = fixUserStatuses(v);
                  savedUser = v;
                } else if (k === 'persist:root') {
                  v = fixUserStatuses(v);
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
                          if ('stateCode' in parsedUserSlice.user) {
                            parsedUserSlice.user.stateCode = 1;
                          }
                          if (tMs && !parsedUserSlice.user.token) {
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

            // محافظت از حذف کوکی‌های احراز هویت در document.cookie
            try {
              var cookieDesc = Object.getOwnPropertyDescriptor(Document.prototype, 'cookie') ||
                               Object.getOwnPropertyDescriptor(HTMLDocument.prototype, 'cookie');
              if (cookieDesc && cookieDesc.set && cookieDesc.get) {
                Object.defineProperty(document, 'cookie', {
                  configurable: true,
                  get: function() {
                    return cookieDesc.get.call(this);
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
                        if (cName === 'user') {
                          str = fixUserStatuses(str);
                        }
                      }
                    }
                    return cookieDesc.set.call(this, str);
                  }
                });
              }
            } catch (_) {}

            // اصلاح پاسخ‌های API که فیلد customerIsLoggedInForFirstTime: true یا state: false برمی‌گردانند
            if (window.fetch) {
              var origFetch = window.fetch;
              window.fetch = function(input, init) {
                return origFetch.apply(this, arguments).then(function(response) {
                  try {
                    var cType = response.headers && response.headers.get ? (response.headers.get('content-type') || '') : '';
                    if (cType.indexOf('application/json') !== -1) {
                      var clone = response.clone();
                      return clone.text().then(function(txt) {
                        if (txt && txt.indexOf('customerIsLoggedInForFirstTime') !== -1) {
                          var fixedTxt = fixUserStatuses(txt);
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

            if (window.XMLHttpRequest) {
              var origOpen = XMLHttpRequest.prototype.open;
              var origSend = XMLHttpRequest.prototype.send;
              XMLHttpRequest.prototype.open = function(method, url) {
                this.__nxUrl = String(url || '');
                return origOpen.apply(this, arguments);
              };
              XMLHttpRequest.prototype.send = function() {
                this.addEventListener('readystatechange', function() {
                  if (this.readyState === 4 && (this.responseType === '' || this.responseType === 'text')) {
                    try {
                      var txt = this.responseText;
                      if (txt && txt.indexOf('customerIsLoggedInForFirstTime') !== -1) {
                        var fixedTxt = fixUserStatuses(txt);
                        Object.defineProperty(this, 'responseText', { configurable: true, get: function() { return fixedTxt; } });
                        Object.defineProperty(this, 'response', { configurable: true, get: function() { return fixedTxt; } });
                      }
                    } catch (_) {}
                  }
                });
                return origSend.apply(this, arguments);
              };
            }
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
        .replaceAll('__USER_COOKIE__', safeUserCookie);
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
      // ۱. توقف کامل صفحه قبلی قبل از تغییر کوکی‌ها (جلوگیری از تداخل نشست قبلی با نشست جدید)
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
      String? rawUserCookie;

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
          if (name == 'user') rawUserCookie = val;
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
          if (name == 'user' &&
              (rawUserCookie == null || rawUserCookie.isEmpty)) {
            rawUserCookie = val;
          }
        }
      }

      final String? normalizedUserCookie = rawUserCookie != null
          ? _normalizeUserValueString(rawUserCookie, tMs, forceUrlEncode: true)
          : null;

      // آماده‌سازی و اصلاح تمام مقادیر localStorage در سمت دارت
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
          val = _normalizeUserValueString(val, tMs, forceUrlEncode: true);
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

      if (!hasUser && normalizedUserCookie != null) {
        normalizedLocalData
            .add({'name': 'user', 'value': normalizedUserCookie});
      }
      if (!hasCityId) {
        normalizedLocalData.add({'name': 'city_id', 'value': '129'});
      }
      if (!hasCityName) {
        normalizedLocalData.add({'name': 'city_name', 'value': 'تهران'});
      }

      // ۳. ثبت دقیق کوکی‌ها مطابق ساختار استاندارد مرورگر با تاریخ انقضای معتبر
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
        cookieFutures.add(cookieManager.setCookie(
          url: storeUri,
          name: 'tokenMS',
          value: tMs,
          path: '/',
          expiresDate: futureExpiresMs,
          isHttpOnly: false,
          isSecure: false,
          sameSite: HTTPCookieSameSitePolicy.LAX,
        ));
        cookieFutures.add(cookieManager.setCookie(
          url: storeUri,
          name: 'token',
          value: tMs,
          path: '/',
          expiresDate: futureExpiresMs,
          isHttpOnly: false,
          isSecure: false,
          sameSite: HTTPCookieSameSitePolicy.LAX,
        ));
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
        final String rawDomain = c['domain']?.toString() ?? '';
        final bool isDomainCookie = rawDomain.startsWith('.');
        cookieFutures.add(cookieManager.setCookie(
          url: storeUri,
          name: cName,
          value: cVal,
          domain: isDomainCookie ? rawDomain : null,
          path: c['path']?.toString() ?? '/',
          expiresDate: futureExpiresMs,
          isHttpOnly: c['httpOnly'] == true,
          isSecure: c['secure'] == true,
          sameSite: isDomainCookie
              ? HTTPCookieSameSitePolicy.NONE
              : HTTPCookieSameSitePolicy.LAX,
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
            forMainFrameOnly: true,
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
                      forMainFrameOnly: true,
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
              onLoadStart: (controller, url) {
                if (!mounted || url == null) return;
                final String urlStr = url.toString();
                if (url.host.toLowerCase().contains('okala.com') &&
                    !urlStr.contains(bootstrapPath)) {
                  setState(() {
                    _isBootstrapping = false;
                  });
                }
              },
              onProgressChanged: (controller, progress) {
                if (!mounted || _isBootstrapping) return;
                setState(() {
                  _progress = progress / 100.0;
                });
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
