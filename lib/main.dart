import 'package:flutter/material.dart';
import 'package:flutter_inappwebview/flutter_inappwebview.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';

const List<String> allowedLinkHosts = [
  'okalav2.up.railway.app',
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
  const NexusLinkApp({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Nexus Link',
      theme: ThemeData(
        colorScheme: const ColorScheme.dark(
          primary: primaryAccent,
          surface: surfaceDark,
          background: bgDark,
        ),
        scaffoldBackgroundColor: bgDark,
        fontFamily: 'Tahoma',
        useMaterial3: true,
      ),
      home: const WorkspaceScreen(),
    );
  }
}

class WorkspaceScreen extends StatefulWidget {
  const WorkspaceScreen({Key? key}) : super(key: key);

  @override
  _WorkspaceScreenState createState() => _WorkspaceScreenState();
}

class _WorkspaceScreenState extends State<WorkspaceScreen> {
  final TextEditingController _linksController = TextEditingController();
  String _statusMessage = '';

  @override
  void dispose() {
    _linksController.dispose();
    super.dispose();
  }

  String _normaliseLink(String value) {
    String cleaned = value
        .replaceAll(RegExp(r'[\u200B-\u200D\uFEFF]'), '')
        .trim()
        .replaceFirst(RegExp(r'[،,؛;.!؟]+$'), '');

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
    bool isAllowed = allowedLinkHosts.any((allowedHost) => host == allowedHost);
    
    return isAllowed &&
        uri.scheme.toLowerCase() == 'https' &&
        uri.userInfo.isEmpty;
  }

  void _processLinks() {
    final text = _linksController.text;
    if (text.trim().isEmpty) {
      setState(() => _statusMessage = 'لطفاً پیوندها را وارد کنید.');
      return;
    }

    final tokens = text.split(RegExp(r'\s+'));
    final List<String> extractedUrls = [];
    int invalidCount = 0;

    for (var token in tokens) {
      token = token.trim();
      if (token.isEmpty) continue;

      final normalized = _normaliseLink(token);
      if (_isAllowedLink(token)) {
        extractedUrls.add(normalized);
      } else {
        invalidCount++;
      }
    }

    if (extractedUrls.isEmpty) {
      setState(
        () => _statusMessage =
            'تنها پیوندهای دامنه ${allowedLinkHosts.first} پذیرفته می‌شوند.',
      );
      return;
    }

    if (invalidCount > 0) {
      setState(
        () => _statusMessage =
            '$invalidCount پیوند خارج از دامنه مجاز حذف شد. ${extractedUrls.length} پیوند معتبر باقی مانده است.',
      );
      return;
    }

    setState(() => _statusMessage = '');
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
                      'سیستم مدیریت یکپارچه پیوندها',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: textSecondary,
                        fontSize: 14,
                      ),
                    ),
                    const SizedBox(height: 40),
                    
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
                    const Text(
                      'پیوندها را وارد کنید (با فاصله یا خط جدید).',
                      textAlign: TextAlign.right,
                      style: TextStyle(
                        color: textSecondary,
                        fontSize: 12,
                      ),
                    ),
                    const SizedBox(height: 32),
                    
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
                              'شروع پردازش',
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
                          color: Colors.redAccent.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: Colors.redAccent.withOpacity(0.3)),
                        ),
                        child: Row(
                          children: [
                            const Icon(Icons.error_outline, color: Colors.redAccent, size: 20),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Text(
                                _statusMessage,
                                textAlign: TextAlign.right,
                                style: const TextStyle(
                                  color: Colors.redAccent,
                                  fontSize: 13,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],

                    // 🔴 بخش کپی‌رایت و تبلیغ کانال تلگرام اضافه شد 🔴
                    const SizedBox(height: 32),
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
                    // 🔴 پایان بخش تبلیغ 🔴

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

  const BrowserScreen({Key? key, required this.urls}) : super(key: key);

  @override
  State<BrowserScreen> createState() => _BrowserScreenState();
}

class _BrowserScreenState extends State<BrowserScreen> {
  int _currentIndex = 0;
  bool _isLoading = true;
  String _loadingMessage = 'در حال آماده‌سازی...';
  
  bool _hasInjectedForCurrentAccount = false; 
  List<dynamic> _currentLocalData = [];
  String? _currentTokenMs;
  String? _currentRefreshToken;
  
  Key _webViewKey = UniqueKey(); 

  @override
  void initState() {
    super.initState();
    _loadAccount(_currentIndex);
  }

  Future<void> _loadAccount(int index) async {
    setState(() {
      _isLoading = true;
      _hasInjectedForCurrentAccount = false;
      _loadingMessage = 'پیکربندی اکانت ${index + 1}...';
      _currentIndex = index;
    });

    try {
      final CookieManager cookieManager = CookieManager.instance();
      await cookieManager.deleteAllCookies();

      final response = await http.get(Uri.parse(widget.urls[index]));
      if (response.statusCode != 200) {
        throw Exception('ارتباط با سرور ناموفق بود.');
      }

      final Map<String, dynamic> data = json.decode(response.body);

      List<dynamic> localData = [];
      if (data['origins'] != null && data['origins'] is List && (data['origins'] as List).isNotEmpty) {
        List<dynamic> originsList = data['origins'];
        dynamic matchedOrigin = originsList[0]; 
        for (var o in originsList) {
          if (o is Map && o['origin'] != null && o['origin'].toString().contains(storeHost)) {
            matchedOrigin = o;
            break;
          }
        }
        if (matchedOrigin is Map && matchedOrigin['localStorage'] != null) {
          localData = matchedOrigin['localStorage'];
        }
      }

      String? tMs;
      String? rTk;

      List<dynamic> cookies = data['cookies'] ?? [];
      for (var c in cookies) {
        if (c['name'] == 'tokenMS') tMs = c['value'];
        if (c['name'] == 'refresh_token') rTk = c['value'];
      }

      if (tMs == null || rTk == null) {
        for (var item in localData) {
          if (item['name'] == 'tokenMS' && tMs == null) tMs = item['value'];
          if (item['name'] == 'refresh_token' && rTk == null) rTk = item['value'];
        }
      }

      if (tMs != null) {
        await cookieManager.setCookie(url: WebUri("https://$storeHost"), name: "tokenMS", value: tMs, domain: ".okala.com", path: "/", isSecure: true, sameSite: HTTPCookieSameSitePolicy.NONE);
        await cookieManager.setCookie(url: WebUri("https://$storeHost"), name: "token", value: tMs, domain: ".okala.com", path: "/", isSecure: true, sameSite: HTTPCookieSameSitePolicy.NONE);
      }
      if (rTk != null) {
        await cookieManager.setCookie(url: WebUri("https://$storeHost"), name: "refresh_token", value: rTk, domain: ".okala.com", path: "/", isSecure: true, sameSite: HTTPCookieSameSitePolicy.NONE);
      }

      for (var c in cookies) {
        if (c['name'] != 'tokenMS' && c['name'] != 'refresh_token' && c['name'] != 'token') {
          String rawDomain = c['domain']?.toString() ?? ".okala.com";
          String domain = rawDomain.startsWith('.') ? rawDomain : '.$rawDomain';
          await cookieManager.setCookie(url: WebUri("https://$storeHost"), name: c['name'], value: c['value'], domain: domain, path: c['path'] ?? "/", isSecure: true, sameSite: HTTPCookieSameSitePolicy.NONE);
        }
      }

      setState(() {
        _currentLocalData = localData;
        _currentTokenMs = tMs;
        _currentRefreshToken = rTk;
        _webViewKey = UniqueKey(); 
        _isLoading = false;
      });

    } catch (e) {
      setState(() {
        _loadingMessage = 'خطا در بارگذاری: $e';
      });
    }
  }

  void _nextAccount() {
    if (_currentIndex < widget.urls.length - 1) {
      _loadAccount(_currentIndex + 1);
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('شما در آخرین اکانت هستید.', style: TextStyle(color: bgDark, fontWeight: FontWeight.bold)),
          backgroundColor: primaryAccent,
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: bgDark,
      appBar: AppBar(
        title: Text(
          'مورد ${_currentIndex + 1} از ${widget.urls.length}',
          style: const TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w700,
            color: textPrimary,
          ),
        ),
        backgroundColor: surfaceDark,
        elevation: 0,
        iconTheme: const IconThemeData(color: textPrimary),
        centerTitle: true,
        actions: [
          if (_currentIndex < widget.urls.length - 1)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8.0),
              child: TextButton(
                onPressed: _nextAccount,
                style: TextButton.styleFrom(
                  foregroundColor: primaryAccent,
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
      ),
      drawer: Drawer(
        backgroundColor: surfaceDark,
        child: Column(
          children: [
            Container(
              width: double.infinity,
              padding: const EdgeInsets.only(top: 60, bottom: 30),
              decoration: const BoxDecoration(
                color: bgDark,
                border: Border(bottom: BorderSide(color: surfaceDark, width: 2)),
              ),
              child: Column(
                children: [
                  Container(
                    width: 70,
                    height: 70,
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
                  const SizedBox(height: 16),
                  const Text(
                    'Nexus Link',
                    style: TextStyle(
                      color: textPrimary,
                      fontSize: 20,
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
                separatorBuilder: (context, index) => Divider(color: bgDark.withOpacity(0.5), height: 1),
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
          ],
        ),
      ),
      body: Stack(
        children: [
          if (!_isLoading)
            InAppWebView(
              key: _webViewKey, 
              initialUrlRequest: URLRequest(url: WebUri("https://$storeHost/")),
              initialSettings: InAppWebViewSettings(
                javaScriptEnabled: true,
                domStorageEnabled: true,
                thirdPartyCookiesEnabled: true,
                clearCache: true,
                clearSessionCache: true, 
              ),
              onLoadStop: (controller, url) async {
                if (url != null &&
                    url.host.toLowerCase().contains('okala.com') &&
                    !_hasInjectedForCurrentAccount) {
                  
                  _hasInjectedForCurrentAccount = true; 
                  
                  final String base64Data = base64Encode(utf8.encode(jsonEncode(_currentLocalData)));
                  final String injectionJs = """
                    try {
                      var decodedData = decodeURIComponent(escape(window.atob('$base64Data')));
                      var items = JSON.parse(decodedData);
                      
                      localStorage.clear();
                      sessionStorage.clear();
                      
                      items.forEach(item => {
                        var finalValue = item.value;
                        if (item.name === 'user' || item.name === 'persist:root') {
                           if (finalValue.includes('%7B')) {
                              var decodedObjStr = decodeURIComponent(finalValue);
                              if (decodedObjStr.includes('"stateCode": 0')) {
                                  decodedObjStr = decodedObjStr.replace(/"stateCode":\\s*0/g, '"stateCode": 1');
                                  decodedObjStr = decodedObjStr.replace(/"customerIsLoggedInForFirstTime":\\s*true/g, '"customerIsLoggedInForFirstTime": false');
                                  finalValue = encodeURIComponent(decodedObjStr);
                              }
                           } 
                           else if (finalValue.includes('"stateCode": 0')) {
                              finalValue = finalValue.replace(/\\\\"stateCode\\\\":\\s*0/g, '\\\\"stateCode\\\\": 1');
                              finalValue = finalValue.replace(/\\\\"customerIsLoggedInForFirstTime\\\\":\\s*true/g, '\\\\"customerIsLoggedInForFirstTime\\\\": false');
                           }
                        }
                        localStorage.setItem(item.name, finalValue);
                      });
                      
                      var tMs = '${_currentTokenMs ?? ''}';
                      var rTk = '${_currentRefreshToken ?? ''}';
                      if (tMs !== '') { localStorage.setItem('tokenMS', tMs); localStorage.setItem('token', tMs); }
                      if (rTk !== '') { localStorage.setItem('refresh_token', rTk); }
                      
                      window.location.replace('https://$storeHost/');
                    } catch(e) {
                      console.error("Storage Injection Error:", e);
                    }
                  """;
                  await controller.evaluateJavascript(source: injectionJs);
                }
              },
            ),

          if (_isLoading)
            Container(
              color: bgDark,
              child: Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const CircularProgressIndicator(
                      color: primaryAccent,
                      strokeWidth: 3,
                    ),
                    const SizedBox(height: 24),
                    Text(
                      _loadingMessage,
                      style: const TextStyle(
                        color: textSecondary,
                        fontWeight: FontWeight.w500,
                        fontSize: 15,
                      ),
                    ),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }
}

