import 'package:flutter/material.dart';
import 'package:flutter_inappwebview/flutter_inappwebview.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';

const List<String> allowedLinkHosts = [
  'okala.baranlink.cyou',
  'okalaa.baranlink.cyou',
];
const String storeHost = 'www.okala.com';
const Color navy = Color(0xFF0B1F3A);
const Color navyLight = Color(0xFF163A63);
const Color gold = Color(0xFFC69B4A);
const Color cream = Color(0xFFF7F2E8);

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const BaranLinkApp());
}

class BaranLinkApp extends StatelessWidget {
  const BaranLinkApp({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'baran link',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(
          seedColor: navy,
          brightness: Brightness.light,
        ),
        scaffoldBackgroundColor: cream,
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
    final withoutTrailingPunctuation = value
        .trim()
        .replaceFirst(RegExp(r'[،,؛;.!؟]+$'), '');

    if (withoutTrailingPunctuation.contains('://')) {
      return withoutTrailingPunctuation;
    }

    return 'https://$withoutTrailingPunctuation';
  }

  bool _isAllowedLink(String value) {
    final uri = Uri.tryParse(_normaliseLink(value));
    return uri != null &&
        uri.scheme.toLowerCase() == 'https' &&
        allowedLinkHosts.contains(uri.host.toLowerCase()) &&
        uri.userInfo.isEmpty &&
        (uri.port == 0 || uri.port == 443);
  }

  void _processLinks() {
    final text = _linksController.text;
    if (text.trim().isEmpty) {
      setState(() => _statusMessage = 'لطفاً پیوندها را وارد کنید.');
      return;
    }

    // Accept full URLs as before, as well as either supported domain entered
    // directly (for example: Okalaa.baranlink.cyou/path). The boundary
    // prevents the bare-domain pattern from matching another hostname.
    final RegExp linkRegex = RegExp(
      r'(?:https?:\/\/[^\s]+|(?<![A-Za-z0-9.-])okalaa?\.baranlink\.cyou(?::\d+)?(?:[\/?#][^\s]*)?)',
      caseSensitive: false,
    );
    final Iterable<Match> matches = linkRegex.allMatches(text);

    final List<String> extractedUrls = matches
        .map((match) => _normaliseLink(match.group(0)!))
        .where(_isAllowedLink)
        .toList();

    if (extractedUrls.isEmpty) {
      setState(
        () => _statusMessage =
            'تنها پیوندهای دامنه ${allowedLinkHosts.join(' و ')} پذیرفته می‌شوند.',
      );
      return;
    }

    final totalLinks = matches.length;
    if (extractedUrls.length != totalLinks) {
      setState(
        () => _statusMessage =
            'برخی پیوندها خارج از دامنه مجاز هستند.',
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
      body: Stack(
        children: [
          Container(
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topRight,
                end: Alignment.bottomLeft,
                colors: [navyLight, navy],
              ),
            ),
          ),
          Positioned(
            top: -130,
            left: -90,
            child: _GlowCircle(size: 280, color: gold.withOpacity(.16)),
          ),
          Positioned(
            bottom: -180,
            right: -100,
            child: _GlowCircle(size: 340, color: Colors.white.withOpacity(.06)),
          ),
          SafeArea(
            child: Center(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(22),
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 430),
                  child: Container(
                    padding: const EdgeInsets.fromLTRB(24, 28, 24, 24),
                    decoration: BoxDecoration(
                      color: cream,
                      borderRadius: BorderRadius.circular(28),
                      border: Border.all(color: Colors.white.withOpacity(.35)),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(.28),
                          blurRadius: 34,
                          offset: const Offset(0, 18),
                        ),
                      ],
                    ),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Center(
                          child: Container(
                            width: 94,
                            height: 94,
                            padding: const EdgeInsets.all(4),
                            decoration: BoxDecoration(
                              color: navy,
                              borderRadius: BorderRadius.circular(26),
                              boxShadow: [
                                BoxShadow(
                                  color: navy.withOpacity(.24),
                                  blurRadius: 16,
                                  offset: const Offset(0, 8),
                                ),
                              ],
                            ),
                            child: ClipRRect(
                              borderRadius: BorderRadius.circular(22),
                              child: Image.asset(
                                'assets/baran_link_icon.png',
                                fit: BoxFit.cover,
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(height: 20),
                        const Text(
                          'baran link',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            color: navy,
                            fontSize: 28,
                            fontWeight: FontWeight.w800,
                            letterSpacing: .3,
                          ),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          'مدیریت پیوندهای فروشگاه',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            color: navy.withOpacity(.64),
                            fontSize: 13,
                          ),
                        ),
                        const SizedBox(height: 30),
                        const Text(
                          'پیوندها',
                          textAlign: TextAlign.right,
                          style: TextStyle(
                            color: navy,
                            fontSize: 14,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        const SizedBox(height: 9),
                        TextField(
                          controller: _linksController,
                          maxLines: 6,
                          textDirection: TextDirection.ltr,
                          textAlign: TextAlign.left,
                          style: const TextStyle(
                            color: navy,
                            fontSize: 13,
                            height: 1.5,
                          ),
                          decoration: InputDecoration(
                            hintText: 'https://${allowedLinkHosts.first}/... یا ${allowedLinkHosts.last}/...',
                            hintStyle: TextStyle(
                              color: navy.withOpacity(.38),
                              fontSize: 12,
                            ),
                            filled: true,
                            fillColor: Colors.white.withOpacity(.72),
                            contentPadding: const EdgeInsets.all(16),
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(16),
                              borderSide: BorderSide(
                                color: navy.withOpacity(.1),
                              ),
                            ),
                            enabledBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(16),
                              borderSide: BorderSide(
                                color: navy.withOpacity(.12),
                              ),
                            ),
                            focusedBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(16),
                              borderSide: const BorderSide(
                                color: gold,
                                width: 1.8,
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(height: 10),
                        Text(
                          'هر پیوند را در یک خط وارد کنید.',
                          textAlign: TextAlign.right,
                          style: TextStyle(
                            color: navy.withOpacity(.5),
                            fontSize: 11,
                          ),
                        ),
                        const SizedBox(height: 22),
                        SizedBox(
                          height: 54,
                          child: ElevatedButton.icon(
                            style: ElevatedButton.styleFrom(
                              backgroundColor: navy,
                              foregroundColor: Colors.white,
                              elevation: 0,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(16),
                              ),
                            ),
                            onPressed: _processLinks,
                            icon: const Icon(Icons.arrow_back_rounded, size: 20),
                            label: const Text(
                              'ادامه',
                              style: TextStyle(
                                fontSize: 15,
                                fontWeight: FontWeight.w700,
                                fontFamily: 'Tahoma',
                              ),
                            ),
                          ),
                        ),
                        if (_statusMessage.isNotEmpty) ...[
                          const SizedBox(height: 15),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 12,
                              vertical: 10,
                            ),
                            decoration: BoxDecoration(
                              color: const Color(0xFFFBE9E7),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Text(
                              _statusMessage,
                              textAlign: TextAlign.center,
                              style: const TextStyle(
                                color: Color(0xFFB3261E),
                                fontSize: 12,
                                height: 1.4,
                              ),
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _GlowCircle extends StatelessWidget {
  final double size;
  final Color color;

  const _GlowCircle({required this.size, required this.color});

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: color,
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
      _loadingMessage = 'در حال آماده‌سازی ${index + 1}...';
      _currentIndex = index;
    });

    try {
      final CookieManager cookieManager = CookieManager.instance();
      await cookieManager.deleteAllCookies();

      final response = await http.get(Uri.parse(widget.urls[index]));
      if (response.statusCode != 200) {
        throw Exception('ارتباط با سرور لینک ناموفق بود.');
      }

      final Map<String, dynamic> data = json.decode(response.body);

      List<dynamic> localData = [];
      if (data['origins'] != null && data['origins'] is List && (data['origins'] as List).isNotEmpty) {
        List<dynamic> originsList = data['origins'];
        dynamic matchedOrigin = originsList[0]; 
        for (var o in originsList) {
          if (o is Map &&
              o['origin'] != null &&
              o['origin'].toString().contains(storeHost)) {
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
        _loadingMessage = 'خطا در بارگذاری اکانت: $e';
      });
    }
  }

  void _nextAccount() {
    if (_currentIndex < widget.urls.length - 1) {
      _loadAccount(_currentIndex + 1);
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('آخرین مورد در حال نمایش است.'),
          backgroundColor: navy,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(
          'baran link  ·  ${_currentIndex + 1} / ${widget.urls.length}',
          style: const TextStyle(
            fontSize: 15,
            fontWeight: FontWeight.w700,
            color: Colors.white,
          ),
        ),
        backgroundColor: navy,
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.white),
        actions: [
          if (_currentIndex < widget.urls.length - 1)
            TextButton.icon(
              onPressed: _nextAccount,
              icon: const Icon(Icons.arrow_back_rounded, color: Colors.white),
              label: const Text(
                'بعدی',
                style: TextStyle(color: Colors.white, fontFamily: 'Tahoma'),
              ),
            ),
        ],
      ),
      drawer: Drawer(
        child: Column(
          children: [
            Container(
              width: double.infinity,
              padding: const EdgeInsets.only(top: 52, bottom: 24),
              color: navy,
              child: Column(
                children: [
                  Container(
                    width: 64,
                    height: 64,
                    padding: const EdgeInsets.all(3),
                    decoration: BoxDecoration(
                      color: cream,
                      borderRadius: BorderRadius.circular(18),
                    ),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(15),
                      child: Image.asset(
                        'assets/baran_link_icon.png',
                        fit: BoxFit.cover,
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    'baran link',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 19,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '${widget.urls.length} پیوند',
                    style: TextStyle(
                      color: Colors.white.withOpacity(.68),
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
            ),
            Expanded(
              child: ListView.builder(
                itemCount: widget.urls.length,
                itemBuilder: (context, index) {
                  final isActive = index == _currentIndex;
                  return ListTile(
                    leading: CircleAvatar(
                      backgroundColor: isActive ? gold : Colors.grey.shade200,
                      child: Text(
                        '${index + 1}',
                        style: TextStyle(
                          color: isActive ? navy : Colors.black54,
                          fontSize: 14,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                    title: Text(
                      'مورد ${index + 1}',
                      style: TextStyle(
                        color: navy,
                        fontWeight: isActive ? FontWeight.bold : FontWeight.normal,
                      ),
                    ),
                    subtitle: Text(widget.urls[index], maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 10, color: Colors.grey)),
                    selected: isActive,
                    selectedTileColor: const Color(0xFFE9E3D6),
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
              color: Colors.white,
              child: Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const CircularProgressIndicator(color: gold),
                    const SizedBox(height: 16),
                    Text(
                      _loadingMessage,
                      style: const TextStyle(
                        color: navy,
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
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

