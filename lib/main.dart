import 'package:flutter/material.dart';
import 'package:flutter_inappwebview/flutter_inappwebview.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'dart:collection';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const MaterialApp(
    debugShowCheckedModeBanner: false,
    home: HyperLinkScreen(),
  ));
}

class HyperLinkScreen extends StatefulWidget {
  const HyperLinkScreen({Key? key}) : super(key: key);

  @override
  _HyperLinkScreenState createState() => _HyperLinkScreenState();
}

class _HyperLinkScreenState extends State<HyperLinkScreen> {
  final TextEditingController _linkController = TextEditingController();
  bool _isProcessing = false;
  String _statusMessage = '';

  Future<void> _initializeConnection() async {
    final String endpointUrl = _linkController.text.trim();
    
    if (endpointUrl.isEmpty) {
      setState(() => _statusMessage = 'لطفاً لینک را وارد کنید.');
      return;
    }

    setState(() {
      _isProcessing = true;
      _statusMessage = 'در حال دریافت اطلاعات از سرور...';
    });

    try {
      final response = await http.get(Uri.parse(endpointUrl));
      if (response.statusCode != 200) {
        throw Exception('لینک نامعتبر است یا منقضی شده.');
      }
      
      final Map<String, dynamic> data = json.decode(response.body);

      setState(() => _statusMessage = 'در حال بازیابی نشست‌های امن...');

      final CookieManager cookieManager = CookieManager.instance();
      await cookieManager.deleteAllCookies();

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

      List<dynamic> cookies = data['cookies'] ?? [];
      
      if (cookies.isEmpty && localData.isNotEmpty) {
        String? extractedTokenMs;
        for (var item in localData) {
          if (item['name'] == 'tokenMS') {
            extractedTokenMs = item['value'];
            break;
          }
        }
        
        if (extractedTokenMs != null) {
          await cookieManager.setCookie(
            url: WebUri("https://www.okala.com"),
            name: "tokenMS",
            value: extractedTokenMs,
            domain: ".okala.com",
            path: "/",
            isSecure: true,
            sameSite: HTTPCookieSameSitePolicy.NONE,
          );
          
          await cookieManager.setCookie(
            url: WebUri("https://www.okala.com"),
            name: "token",
            value: extractedTokenMs,
            domain: ".okala.com",
            path: "/",
            isSecure: true,
            sameSite: HTTPCookieSameSitePolicy.NONE,
          );
        }
      } else {
        for (var c in cookies) {
          String rawDomain = c['domain']?.toString() ?? ".okala.com";
          String domain = rawDomain.startsWith('.') ? rawDomain : '.$rawDomain';

          await cookieManager.setCookie(
            url: WebUri("https://www.okala.com"),
            name: c['name'],
            value: c['value'],
            domain: domain,
            path: c['path'] ?? "/",
            isSecure: true,
            sameSite: HTTPCookieSameSitePolicy.NONE,
          );
        }
      }

      setState(() => _statusMessage = 'ورود به مرورگر...');

      if (!mounted) return;
      
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => SecureBrowserScreen(localData: localData),
        ),
      ).then((_) {
        setState(() {
          _isProcessing = false;
          _statusMessage = '';
          _linkController.clear();
        });
      });

    } catch (e) {
      setState(() {
        _statusMessage = 'خطا: ${e.toString()}';
        _isProcessing = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF4F6F8),
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24.0),
          child: Container(
            padding: const EdgeInsets.all(32.0),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16.0),
              boxShadow: const [BoxShadow(color: Colors.black12, blurRadius: 20, offset: Offset(0, 8))],
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.security_rounded, color: Colors.indigo, size: 48),
                const SizedBox(height: 16),
                const Text('HyperLink Workspace', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
                const SizedBox(height: 24),
                TextField(
                  controller: _linkController,
                  decoration: InputDecoration(
                    hintText: 'Enter Endpoint URL...',
                    filled: true,
                    fillColor: Colors.grey.shade50,
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                  ),
                ),
                const SizedBox(height: 20),
                SizedBox(
                  width: double.infinity,
                  height: 48,
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(backgroundColor: Colors.indigo, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10))),
                    onPressed: _isProcessing ? null : _initializeConnection,
                    child: _isProcessing
                        ? const SizedBox(width: 24, height: 24, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                        : const Text('Initialize Connection', style: TextStyle(color: Colors.white, fontSize: 16)),
                  ),
                ),
                if (_statusMessage.isNotEmpty) ...[
                  const SizedBox(height: 16),
                  Text(_statusMessage, style: TextStyle(color: _statusMessage.contains('خطا') ? Colors.red : Colors.green, fontWeight: FontWeight.w500), textAlign: TextAlign.center),
                ]
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class SecureBrowserScreen extends StatefulWidget {
  final List<dynamic> localData;

  const SecureBrowserScreen({Key? key, required this.localData}) : super(key: key);

  @override
  State<SecureBrowserScreen> createState() => _SecureBrowserScreenState();
}

class _SecureBrowserScreenState extends State<SecureBrowserScreen> {
  bool _isInjecting = true;
  bool _hasInjectedData = false;

  @override
  Widget build(BuildContext context) {
    final String base64Data = base64Encode(utf8.encode(jsonEncode(widget.localData)));
    final String uniqueSessionId = DateTime.now().millisecondsSinceEpoch.toString();

    // اسکریپت نجات: بررسی مقادیر خامِ کاربر و نرمالایز کردن آن‌ها قبل از تزریق
    final injectionScript = UserScript(
      source: """
        try {
          if (sessionStorage.getItem('hyperlink_inj_id') !== '$uniqueSessionId') {
            var decodedData = decodeURIComponent(escape(window.atob('$base64Data')));
            var items = JSON.parse(decodedData);
            
            localStorage.clear();
            
            items.forEach(item => {
              var finalValue = item.value;
              
              // بررسی و فریب دادن اکالا برای اکانت‌های خام
              if (item.name === 'user' || item.name === 'persist:root') {
                 // اگر رشته به صورت URL Encoded بود (مثل user)
                 if (finalValue.includes('%7B')) {
                    var decodedObjStr = decodeURIComponent(finalValue);
                    if (decodedObjStr.includes('"stateCode": 0')) {
                        decodedObjStr = decodedObjStr.replace(/"stateCode":\\s*0/g, '"stateCode": 1');
                        decodedObjStr = decodedObjStr.replace(/"customerIsLoggedInForFirstTime":\\s*true/g, '"customerIsLoggedInForFirstTime": false');
                        finalValue = encodeURIComponent(decodedObjStr);
                    }
                 } 
                 // اگر رشته جیسونِ خالص بود (مثل persist:root)
                 else if (finalValue.includes('"stateCode": 0')) {
                    finalValue = finalValue.replace(/\\\\"stateCode\\\\":\\s*0/g, '\\\\"stateCode\\\\": 1');
                    finalValue = finalValue.replace(/\\\\"customerIsLoggedInForFirstTime\\\\":\\s*true/g, '\\\\"customerIsLoggedInForFirstTime\\\\": false');
                 }
              }
              
              localStorage.setItem(item.name, finalValue);
            });
            
            sessionStorage.setItem('hyperlink_inj_id', '$uniqueSessionId');
            window.location.replace('https://www.okala.com/');
          }
        } catch(e) {
          console.error("Storage Injection Error:", e);
        }
      """,
      injectionTime: UserScriptInjectionTime.AT_DOCUMENT_START,
    );

    return Scaffold(
      appBar: AppBar(
        title: const Text('HyperLink Secure Browser', style: TextStyle(color: Colors.white, fontSize: 16)),
        backgroundColor: Colors.indigo,
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: Stack(
        children: [
          InAppWebView(
            initialUrlRequest: URLRequest(url: WebUri("https://www.okala.com/")),
            initialUserScripts: UnmodifiableListView<UserScript>([injectionScript]),
            initialSettings: InAppWebViewSettings(
              javaScriptEnabled: true,
              domStorageEnabled: true,
              thirdPartyCookiesEnabled: true,
              clearCache: true, 
            ),
            onLoadStop: (controller, url) async {
              if (!_hasInjectedData) {
                _hasInjectedData = true; 
                await controller.evaluateJavascript(source: injectionScript.source);
              } else {
                setState(() {
                  _isInjecting = false;
                });
              }
            },
          ),
          
          if (_isInjecting)
            Container(
              color: Colors.white,
              child: Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: const [
                    CircularProgressIndicator(color: Colors.indigo),
                    SizedBox(height: 16),
                    Text('در حال انتقال امن و دائمی...', style: TextStyle(color: Colors.indigo, fontWeight: FontWeight.bold)),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }
}

