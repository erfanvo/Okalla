import 'package:flutter/material.dart';
import 'package:flutter_inappwebview/flutter_inappwebview.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'dart:collection';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(MaterialApp(
    debugShowCheckedModeBanner: false,
    title: 'HyperLink',
    theme: ThemeData(
      primarySwatch: Colors.indigo,
      scaffoldBackgroundColor: const Color(0xFFF4F6F8),
      fontFamily: 'Roboto',
    ),
    home: const HyperLinkScreen(),
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
      setState(() => _statusMessage = 'Error: Please provide a valid endpoint URL.');
      return;
    }

    setState(() {
      _isProcessing = true;
      _statusMessage = 'Establishing secure connection...';
    });

    try {
      final response = await http.get(Uri.parse(endpointUrl));
      if (response.statusCode != 200) {
        throw Exception('Failed to communicate with the server.');
      }
      
      final Map<String, dynamic> data = json.decode(response.body);

      setState(() => _statusMessage = 'Configuring local session environment...');

      final CookieManager cookieManager = CookieManager.instance();
      await cookieManager.deleteAllCookies();

      List<dynamic> localData = [];
      if (data['origins'] != null && data['origins'].isNotEmpty) {
        localData = data['origins'][0]['localStorage'] ?? [];
      }

      List<dynamic> cookies = data['cookies'] ?? [];
      if (cookies.isEmpty) {
        final tokenMsObj = localData.firstWhere((e) => e['name'] == 'tokenMS', orElse: () => null);
        final refreshObj = localData.firstWhere((e) => e['name'] == 'refresh_token', orElse: () => null);
        
        if (tokenMsObj != null) cookies.add({'name': 'tokenMS', 'value': tokenMsObj['value']});
        if (refreshObj != null) cookies.add({'name': 'refresh_token', 'value': refreshObj['value']});
      }

      for (var c in cookies) {
        await cookieManager.setCookie(
          url: WebUri("https://www.okala.com"),
          name: c['name'],
          value: c['value'],
          domain: c['domain'] ?? ".okala.com",
          path: c['path'] ?? "/",
          isSecure: true,
        );
      }

      setState(() => _statusMessage = 'Connection established successfully.');

      if (!mounted) return;
      
      // در اینجا علاوه بر استوریج، کوکی‌ها را هم به صفحه بعد می‌فرستیم
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => SecureBrowserScreen(localData: localData, cookies: cookies),
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
        _statusMessage = 'Error: ${e.toString()}';
        _isProcessing = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24.0),
          child: Container(
            padding: const EdgeInsets.all(32.0),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16.0),
              boxShadow: const [
                BoxShadow(color: Colors.black12, blurRadius: 20, offset: Offset(0, 8)),
              ],
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  padding: const EdgeInsets.all(16.0),
                  decoration: BoxDecoration(
                    color: Colors.indigo.shade50,
                    shape: BoxShape.circle,
                  ),
                  child: Icon(Icons.security_rounded, color: Colors.indigo.shade700, size: 40),
                ),
                const SizedBox(height: 20),
                Text(
                  'HyperLink Workspace',
                  style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: Colors.indigo.shade900),
                ),
                const SizedBox(height: 8),
                Text(
                  'Secure Session Initialization',
                  style: TextStyle(fontSize: 14, color: Colors.grey.shade600),
                ),
                const SizedBox(height: 36),
                TextField(
                  controller: _linkController,
                  decoration: InputDecoration(
                    hintText: 'Enter Endpoint URL...',
                    filled: true,
                    fillColor: Colors.grey.shade50,
                    prefixIcon: Icon(Icons.link, color: Colors.grey.shade400),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide(color: Colors.grey.shade300)),
                    enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide(color: Colors.grey.shade300)),
                    focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide(color: Colors.indigo.shade400, width: 2)),
                    contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
                  ),
                ),
                const SizedBox(height: 24),
                SizedBox(
                  width: double.infinity,
                  height: 52,
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.indigo.shade600,
                      elevation: 0,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                    ),
                    onPressed: _isProcessing ? null : _initializeConnection,
                    child: _isProcessing
                        ? const SizedBox(width: 24, height: 24, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2.5))
                        : const Text('Initialize Connection', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: Colors.white)),
                  ),
                ),
                if (_statusMessage.isNotEmpty) ...[
                  const SizedBox(height: 20),
                  Text(
                    _statusMessage,
                    style: TextStyle(
                      color: _statusMessage.contains('Error') ? Colors.red.shade700 : Colors.teal.shade700,
                      fontWeight: FontWeight.w500,
                      fontSize: 13,
                    ),
                    textAlign: TextAlign.center,
                  ),
                ]
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class SecureBrowserScreen extends StatelessWidget {
  final List<dynamic> localData;
  final List<dynamic> cookies;

  const SecureBrowserScreen({Key? key, required this.localData, required this.cookies}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    // ۱. رمزنگاری کامل داده‌ها به Base64 برای جلوگیری از خطای نگارشی در جاوااسکریپت (حفظ نام‌های فارسی و JSON)
    final String base64Data = base64Encode(utf8.encode(jsonEncode(localData)));

    // ۲. تزریق امن داده‌ها قبل از تولد صفحه
    final injectionScript = UserScript(
      source: """
        try {
          var decodedData = decodeURIComponent(escape(window.atob('$base64Data')));
          var items = JSON.parse(decodedData);
          window.localStorage.clear();
          window.sessionStorage.clear();
          for (var i = 0; i < items.length; i++) {
            window.localStorage.setItem(items[i].name, items[i].value);
          }
        } catch(e) {
          console.error("Storage Injection Error:", e);
        }
      """,
      injectionTime: UserScriptInjectionTime.AT_DOCUMENT_START,
    );

    // ۳. کلید طلایی: ساخت هدر کوکی برای ارسال در درخواست اول (رفع مشکل نیامدن نام کاربری و فریز شدن سایت)
    final String cookieHeader = cookies.map((c) => "\${c['name']}=\${c['value']}").join("; ");

    return Scaffold(
      appBar: AppBar(
        title: const Text('HyperLink Secure Browser', style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w600)),
        backgroundColor: Colors.indigo.shade900,
        iconTheme: const IconThemeData(color: Colors.white),
        centerTitle: true,
        elevation: 0,
      ),
      body: InAppWebView(
        initialUrlRequest: URLRequest(
          url: WebUri("https://www.okala.com/profile"),
          headers: {
            "Cookie": cookieHeader // این خط سرور اکالا را مجبور می‌کند شما را لاگین شده ببیند
          }
        ),
        initialUserScripts: UnmodifiableListView<UserScript>([injectionScript]),
        initialSettings: InAppWebViewSettings(
          javaScriptEnabled: true,
          domStorageEnabled: true,
          clearCache: false,
          thirdPartyCookiesEnabled: true,
          mixedContentMode: MixedContentMode.MIXED_CONTENT_ALWAYS_ALLOW,
        ),
      ),
    );
  }
}

