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
      _statusMessage = 'در حال دریافت اطلاعات...';
    });

    try {
      final response = await http.get(Uri.parse(endpointUrl));
      if (response.statusCode != 200) {
        throw Exception('خطا در ارتباط با سرور.');
      }
      
      final Map<String, dynamic> data = json.decode(response.body);

      setState(() => _statusMessage = 'در حال تنظیم کوکی‌ها و حافظه...');

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

      // تنظیم دقیق کوکی‌ها برای دامنه‌ی اکالا
      for (var c in cookies) {
        await cookieManager.setCookie(
          url: WebUri("https://www.okala.com"),
          name: c['name'],
          value: c['value'],
          domain: ".okala.com",
          path: "/",
          isSecure: true,
        );
      }

      setState(() => _statusMessage = 'آماده‌سازی مرورگر امن...');

      if (!mounted) return;
      
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
                const Text('تزریق‌گر امن اکالا', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
                const SizedBox(height: 24),
                TextField(
                  controller: _linkController,
                  decoration: InputDecoration(
                    hintText: 'لینک ربات را اینجا وارد کنید...',
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
                        ? const CircularProgressIndicator(color: Colors.white)
                        : const Text('ورود به اکانت', style: TextStyle(color: Colors.white, fontSize: 16)),
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

class SecureBrowserScreen extends StatelessWidget {
  final List<dynamic> localData;
  final List<dynamic> cookies;

  const SecureBrowserScreen({Key? key, required this.localData, required this.cookies}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    // کدگذاری امن داده‌ها برای جلوگیری از تداخل کاراکترها
    final String base64Data = base64Encode(utf8.encode(jsonEncode(localData)));

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
          console.error("Storage Error:", e);
        }
      """,
      injectionTime: UserScriptInjectionTime.AT_DOCUMENT_START,
    );

    // ساخت هدر کوکی جهت ارسال همزمان با درخواست اولیه صفحه
    final String cookieHeader = cookies.map((c) => "${c['name']}=${c['value']}").join("; ");

    return Scaffold(
      appBar: AppBar(
        title: const Text('مرورگر امن اکالا', style: TextStyle(color: Colors.white)),
        backgroundColor: Colors.indigo,
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: InAppWebView(
        initialUrlRequest: URLRequest(
          url: WebUri("https://www.okala.com/profile"),
          headers: {"Cookie": cookieHeader},
        ),
        initialUserScripts: UnmodifiableListView<UserScript>([injectionScript]),
        initialSettings: InAppWebViewSettings(
          javaScriptEnabled: true,
          domStorageEnabled: true,
          thirdPartyCookiesEnabled: true,
          mixedContentMode: MixedContentMode.MIXED_CONTENT_ALWAYS_ALLOW,
        ),
      ),
    );
  }
}

