import 'package:flutter/material.dart';
import 'package:flutter_inappwebview/flutter_inappwebview.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'dart:collection';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const HyperLinkProApp());
}

class HyperLinkProApp extends StatelessWidget {
  const HyperLinkProApp({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'HyperLink Pro',
      theme: ThemeData(
        primarySwatch: Colors.deepPurple,
        fontFamily: 'Tahoma', 
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

  void _processLinks() {
    final text = _linksController.text;
    if (text.trim().isEmpty) {
      setState(() => _statusMessage = 'لطفاً لینک‌ها را وارد کنید.');
      return;
    }

    final RegExp linkRegex = RegExp(r'(https?:\/\/[^\s]+)');
    final Iterable<Match> matches = linkRegex.allMatches(text);
    
    List<String> extractedUrls = matches.map((m) => m.group(0)!).toList();

    if (extractedUrls.isEmpty) {
      setState(() => _statusMessage = 'هیچ لینک معتبری در متن یافت نشد!');
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
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [Color(0xFF4A00E0), Color(0xFF8E2DE2)], 
          ),
        ),
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24.0),
            child: Container(
              padding: const EdgeInsets.all(32.0),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(24.0),
                boxShadow: const [BoxShadow(color: Colors.black26, blurRadius: 30, offset: Offset(0, 10))],
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Colors.deepPurple.shade50,
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(Icons.rocket_launch_rounded, color: Colors.deepPurple, size: 56),
                  ),
                  const SizedBox(height: 16),
                  const Text('HyperLink Pro', style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: Colors.black87)),
                  const Text('Workspace Management', style: TextStyle(fontSize: 14, color: Colors.grey)),
                  const SizedBox(height: 32),
                  
                  TextField(
                    controller: _linksController,
                    maxLines: 6,
                    textDirection: TextDirection.ltr,
                    decoration: InputDecoration(
                      hintText: 'میتوانید یک یا چند لینک را اینجا جایگذاری کنید...\n()',
                      filled: true,
                      fillColor: Colors.grey.shade100,
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide.none),
                      focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: const BorderSide(color: Colors.deepPurple, width: 2)),
                    ),
                  ),
                  const SizedBox(height: 24),
                  
                  SizedBox(
                    width: double.infinity,
                    height: 54,
                    child: ElevatedButton.icon(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.deepPurple,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                        elevation: 0,
                      ),
                      onPressed: _processLinks,
                      icon: const Icon(Icons.flash_on_rounded, color: Colors.white),
                      label: const Text('ورود به اکانت', style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold)),
                    ),
                  ),
                  if (_statusMessage.isNotEmpty) ...[
                    const SizedBox(height: 16),
                    Text(_statusMessage, style: const TextStyle(color: Colors.redAccent, fontWeight: FontWeight.bold), textAlign: TextAlign.center),
                  ]
                ],
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
      _loadingMessage = 'در حال دریافت اطلاعات اکانت ${index + 1}...';
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
          if (o is Map && o['origin'] != null && o['origin'].toString().contains('okala.com')) {
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
        await cookieManager.setCookie(url: WebUri("https://www.okala.com"), name: "tokenMS", value: tMs, domain: ".okala.com", path: "/", isSecure: true, sameSite: HTTPCookieSameSitePolicy.NONE);
        await cookieManager.setCookie(url: WebUri("https://www.okala.com"), name: "token", value: tMs, domain: ".okala.com", path: "/", isSecure: true, sameSite: HTTPCookieSameSitePolicy.NONE);
      }
      if (rTk != null) {
        await cookieManager.setCookie(url: WebUri("https://www.okala.com"), name: "refresh_token", value: rTk, domain: ".okala.com", path: "/", isSecure: true, sameSite: HTTPCookieSameSitePolicy.NONE);
      }

      for (var c in cookies) {
        if (c['name'] != 'tokenMS' && c['name'] != 'refresh_token' && c['name'] != 'token') {
          String rawDomain = c['domain']?.toString() ?? ".okala.com";
          String domain = rawDomain.startsWith('.') ? rawDomain : '.$rawDomain';
          await cookieManager.setCookie(url: WebUri("https://www.okala.com"), name: c['name'], value: c['value'], domain: domain, path: c['path'] ?? "/", isSecure: true, sameSite: HTTPCookieSameSitePolicy.NONE);
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
        const SnackBar(content: Text('شما در آخرین اکانت هستید!'), backgroundColor: Colors.green),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('اکانت ${_currentIndex + 1} از ${widget.urls.length}', style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.white)),
        backgroundColor: Colors.deepPurple,
        iconTheme: const IconThemeData(color: Colors.white),
        actions: [
          if (_currentIndex < widget.urls.length - 1)
            TextButton.icon(
              onPressed: _nextAccount,
              icon: const Icon(Icons.skip_next_rounded, color: Colors.white),
              label: const Text('بعدی', style: TextStyle(color: Colors.white)),
            ),
        ],
      ),
      drawer: Drawer(
        child: Column(
          children: [
            Container(
              width: double.infinity,
              padding: const EdgeInsets.only(top: 50, bottom: 20),
              color: Colors.deepPurple,
              child: Column(
                children: [
                  const Icon(Icons.list_alt_rounded, color: Colors.white, size: 48),
                  const SizedBox(height: 10),
                  Text('لیست اکانت‌ها (${widget.urls.length})', style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
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
                      backgroundColor: isActive ? Colors.deepPurple : Colors.grey.shade300,
                      child: Text('${index + 1}', style: TextStyle(color: isActive ? Colors.white : Colors.black87, fontSize: 14)),
                    ),
                    title: Text('اکانت ${index + 1}', style: TextStyle(fontWeight: isActive ? FontWeight.bold : FontWeight.normal)),
                    subtitle: Text(widget.urls[index], maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 10, color: Colors.grey)),
                    selected: isActive,
                    selectedTileColor: Colors.deepPurple.shade50,
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
              initialUrlRequest: URLRequest(url: WebUri("https://www.okala.com/")),
              initialSettings: InAppWebViewSettings(
                javaScriptEnabled: true,
                domStorageEnabled: true,
                thirdPartyCookiesEnabled: true,
                clearCache: true,
                clearSessionCache: true, // این اضافه شد تا سشن قبلی کامل پاک بشه
              ),
              onLoadStop: (controller, url) async {
                final String base64Data = base64Encode(utf8.encode(jsonEncode(_currentLocalData)));
                final String injectionJs = """
                  try {
                    // شرط اومد بیرون تا لوپ بی‌نهایت نگیره
                    if (!sessionStorage.getItem('injected_once')) {
                        
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
                        
                        // اینجا فلگ رو ست میکنیم و بعدش رفرش میشه
                        sessionStorage.setItem('injected_once', 'true');
                        window.location.replace('https://www.okala.com/');
                    }
                  } catch(e) {
                    console.error("Storage Injection Error:", e);
                  }
                """;
                await controller.evaluateJavascript(source: injectionJs);
              },
            ),

          if (_isLoading)
            Container(
              color: Colors.white,
              child: Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const CircularProgressIndicator(color: Colors.deepPurple),
                    const SizedBox(height: 16),
                    Text(_loadingMessage, style: const TextStyle(color: Colors.deepPurple, fontWeight: FontWeight.bold, fontSize: 16)),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }
}

