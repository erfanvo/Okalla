
import 'dart:async';
import 'dart:collection';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter_inappwebview/flutter_inappwebview.dart';
import 'package:http/http.dart' as http;

const List<String> allowedLinkHosts = [
  'okalav2.up.railway.app',
  'jetjon1.up.railway.app',
];
const String storeHost = 'www.okala.com';
const String storeUrl = 'https://www.okala.com/stores';

// پالت رنگی اصلی برنامه (تم تاریک و مدرن)
const Color bgDark = Color(0xFF12141D);
const Color surfaceDark = Color(0xFF1E212D);
const Color primaryAccent = Color(0xFF00D09E);
const Color textPrimary = Color(0xFFF3F4F6);
const Color textSecondary = Color(0xFF9CA3AF);

const String customUserAgent =
    'Mozilla/5.0 (Linux; Android 13; SM-S918B) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/122.0.0.0 Mobile Safari/537.36';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await NexusTokenVault.instance.init();
  runApp(const NexusLinkApp());
}

/// مدل نتیجه نوسازی توکن (نگهداری همزمان Access Token و Refresh Token چرخش‌یافته)
class _TokenPairResult {
  final String? accessToken;
  final String? refreshToken;
  final bool wasRefreshed;

  const _TokenPairResult({
    required this.accessToken,
    required this.refreshToken,
    this.wasRefreshed = false,
  });
}

/// مخزن پایدار توکن‌ها روی حافظه دستگاه و رم برای جلوگیری از سوختن Refresh Token فایل‌های ZIP در مراجعات بعدی
class NexusTokenVault {
  NexusTokenVault._();
  static final NexusTokenVault instance = NexusTokenVault._();

  final Map<String, Map<String, String>> _vault = {};
  bool _initialized = false;

  File get _vaultFile =>
      File('${Directory.systemTemp.path}/nexus_okala_token_vault_v3.json');

  Future<void> init() async {
    if (_initialized) return;
    _initialized = true;
    try {
      final File f = _vaultFile;
      if (await f.exists()) {
        final String content = await f.readAsString();
        final dynamic decoded = jsonDecode(content);
        if (decoded is Map) {
          decoded.forEach((k, v) {
            if (v is Map) {
              _vault[k.toString()] = {
                'accessToken': v['accessToken']?.toString() ?? '',
                'refreshToken': v['refreshToken']?.toString() ?? '',
                'updatedAt': v['updatedAt']?.toString() ?? '',
              };
            }
          });
        }
      }
    } catch (_) {}
  }

  Map<String, String>? lookup({
    String? phone,
    String? userId,
    String? cerberusId,
    String? targetUri,
  }) {
    final List<String> keys = [
      if (phone != null && phone.trim().isNotEmpty) 'ph:${phone.trim()}',
      if (userId != null && userId.trim().isNotEmpty && userId.trim() != '0')
        'uid:${userId.trim()}',
      if (cerberusId != null && cerberusId.trim().isNotEmpty)
        'cid:${cerberusId.trim()}',
      if (targetUri != null && targetUri.trim().isNotEmpty)
        'uri:${targetUri.trim()}',
    ];
    for (final String k in keys) {
      final Map<String, String>? hit = _vault[k];
      if (hit != null &&
          ((hit['accessToken']?.isNotEmpty ?? false) ||
              (hit['refreshToken']?.isNotEmpty ?? false))) {
        return hit;
      }
    }
    return null;
  }

  Future<void> save({
    String? phone,
    String? userId,
    String? cerberusId,
    String? targetUri,
    String? accessToken,
    String? refreshToken,
  }) async {
    if ((accessToken == null || accessToken.isEmpty) &&
        (refreshToken == null || refreshToken.isEmpty)) {
      return;
    }
    final List<String> keys = [
      if (phone != null && phone.trim().isNotEmpty) 'ph:${phone.trim()}',
      if (userId != null && userId.trim().isNotEmpty && userId.trim() != '0')
        'uid:${userId.trim()}',
      if (cerberusId != null && cerberusId.trim().isNotEmpty)
        'cid:${cerberusId.trim()}',
      if (targetUri != null && targetUri.trim().isNotEmpty)
        'uri:${targetUri.trim()}',
    ];
    if (keys.isEmpty) return;

    final String nowIso = DateTime.now().toIso8601String();
    for (final String k in keys) {
      final Map<String, String> prev = _vault[k] ?? {};
      _vault[k] = {
        'accessToken': (accessToken != null && accessToken.isNotEmpty)
            ? accessToken
            : (prev['accessToken'] ?? ''),
        'refreshToken': (refreshToken != null && refreshToken.isNotEmpty)
            ? refreshToken
            : (prev['refreshToken'] ?? ''),
        'updatedAt': nowIso,
      };
    }

    try {
      await _vaultFile.writeAsString(jsonEncode(_vault), flush: true);
    } catch (_) {}
  }
}

/// رجیستری اکانت‌های استخراج‌شده از فایل‌های ZIP / JSON و عناوین نمایشی هر حساب
class NexusAccountRegistry {
  NexusAccountRegistry._();
  static final NexusAccountRegistry instance = NexusAccountRegistry._();

  final Map<String, Map<String, dynamic>> _accounts = {};
  final Map<String, String> _labels = {};
  final Map<String, String> _sourceNames = {};

  bool isLocalUri(String uri) =>
      uri.startsWith('zip://') || uri.startsWith('local://');

  Map<String, dynamic>? getAccountData(String uri) {
    final Map<String, dynamic>? d = _accounts[uri];
    if (d == null) return null;
    return jsonDecode(jsonEncode(d)) as Map<String, dynamic>;
  }

  void updateAccountData(String uri, Map<String, dynamic> updated) {
    if (_accounts.containsKey(uri)) {
      _accounts[uri] = jsonDecode(jsonEncode(updated)) as Map<String, dynamic>;
    }
  }

  String getLabel(String uri, int index) {
    final String? custom = _labels[uri];
    if (custom != null && custom.isNotEmpty) {
      return custom;
    }
    return 'حساب کاربری ${index + 1}';
  }

  void setLabel(String uri, String label) {
    if (label.trim().isNotEmpty) {
      _labels[uri] = label.trim();
    }
  }

  String? getSourceName(String uri) => _sourceNames[uri];

  String registerAccount({
    required Map<String, dynamic> data,
    required String phoneOrName,
    required String sourceFileName,
  }) {
    final String cleanKey = phoneOrName
        .replaceAll(RegExp(r'[^0-9a-zA-Z_-]'), '')
        .trim();
    final String idPart = cleanKey.isNotEmpty
        ? cleanKey
        : DateTime.now().microsecondsSinceEpoch.toString();
    String uri = 'zip://$idPart';
    int suffix = 1;
    while (_accounts.containsKey(uri) &&
        jsonEncode(_accounts[uri]) != jsonEncode(data)) {
      suffix++;
      uri = 'zip://${idPart}_$suffix';
    }
    _accounts[uri] = jsonDecode(jsonEncode(data)) as Map<String, dynamic>;
    _labels[uri] = cleanKey.isNotEmpty ? cleanKey : phoneOrName;
    _sourceNames[uri] = sourceFileName;
    return uri;
  }

  void removeUri(String uri) {
    _accounts.remove(uri);
    _labels.remove(uri);
    _sourceNames.remove(uri);
  }
}

/// نتیجه استخراج یک فایل ورودی (ZIP / JSON / TXT)
class ZipExtractionSummary {
  final List<String> accountUris;
  final List<String> extractedLinks;
  final String fileName;

  const ZipExtractionSummary({
    required this.accountUris,
    required this.extractedLinks,
    required this.fileName,
  });

  int get totalCount => accountUris.length + extractedLinks.length;
}

/// استخراج‌کننده فوق‌سریع و بدون نیاز به پکیج خارجی برای فایل‌های ZIP، JSON و TXT
/// با استفاده از ZLibCodec(raw: true) داخلی دارت (سازگار با ساختار ربات Main1.py)
class NexusZipExtractor {
  static String _toEnDigits(String input) {
    const Map<String, String> map = {
      '۰': '0', '۱': '1', '۲': '2', '۳': '3', '۴': '4',
      '۵': '5', '۶': '6', '۷': '7', '۸': '8', '۹': '9',
      '٠': '0', '١': '1', '٢': '2', '٣': '3', '٤': '4',
      '٥': '5', '٦': '6', '٧': '7', '٨': '8', '٩': '9',
    };
    String out = input;
    map.forEach((k, v) => out = out.replaceAll(k, v));
    return out;
  }

  static bool isZipBytes(Uint8List bytes) {
    return bytes.length >= 4 &&
        bytes[0] == 0x50 &&
        bytes[1] == 0x4B &&
        (bytes[2] == 0x03 || bytes[2] == 0x05 || bytes[2] == 0x07);
  }

  static Map<String, dynamic> _decodeJwt(String? token) {
    if (token == null || !token.contains('.')) return {};
    try {
      final List<String> parts = token.split('.');
      if (parts.length < 2) return {};
      String normalized =
          parts[1].replaceAll('-', '+').replaceAll('_', '/').trim();
      while (normalized.length % 4 != 0) {
        normalized += '=';
      }
      final String jsonStr = utf8.decode(base64Decode(normalized));
      final dynamic decoded = jsonDecode(jsonStr);
      if (decoded is Map<String, dynamic>) return decoded;
    } catch (_) {}
    return {};
  }

  static String? extractPhoneFromAccountData(
      Map<String, dynamic> data, String fallbackFileName) {
    try {
      if (data['origins'] is List) {
        for (final dynamic o in data['origins'] as List) {
          if (o is Map && o['localStorage'] is List) {
            for (final dynamic item in o['localStorage'] as List) {
              if (item is Map) {
                final String name = item['name']?.toString() ?? '';
                final String val = item['value']?.toString() ?? '';
                if (name == 'user' && val.isNotEmpty) {
                  final String dec =
                      (val.contains('%7B') || val.contains('%22'))
                          ? Uri.decodeComponent(val)
                          : val;
                  final dynamic u = jsonDecode(dec);
                  if (u is Map) {
                    final String? ph = (u['mobilePhone'] ??
                            u['userName'] ??
                            u['username'])
                        ?.toString();
                    if (ph != null && ph.trim().isNotEmpty) {
                      return _toEnDigits(ph.trim());
                    }
                  }
                } else if (name == 'persist:root' && val.isNotEmpty) {
                  final dynamic pr = jsonDecode(val);
                  if (pr is Map && pr['user'] is String) {
                    final dynamic uOuter = jsonDecode(pr['user'] as String);
                    if (uOuter is Map && uOuter['user'] is Map) {
                      final Map uInner = uOuter['user'] as Map;
                      final String? ph = (uInner['mobilePhone'] ??
                              uInner['userName'] ??
                              uInner['username'])
                          ?.toString();
                      if (ph != null && ph.trim().isNotEmpty) {
                        return _toEnDigits(ph.trim());
                      }
                    }
                  }
                }
              }
            }
          }
        }
      }
      if (data['cookies'] is List) {
        for (final dynamic c in data['cookies'] as List) {
          if (c is Map) {
            final String name = c['name']?.toString() ?? '';
            final String val = c['value']?.toString() ?? '';
            if (name == 'user' && val.isNotEmpty) {
              final String dec = (val.contains('%7B') || val.contains('%22'))
                  ? Uri.decodeComponent(val)
                  : val;
              final dynamic u = jsonDecode(dec);
              if (u is Map) {
                final String? ph =
                    (u['mobilePhone'] ?? u['userName'] ?? u['username'])
                        ?.toString();
                if (ph != null && ph.trim().isNotEmpty) {
                  return _toEnDigits(ph.trim());
                }
              }
            } else if ((name == 'tokenMS' || name == 'token') &&
                val.isNotEmpty) {
              final Map<String, dynamic> jwt = _decodeJwt(val);
              final String? ph =
                  (jwt['mobilePhone'] ?? jwt['username'] ?? jwt['userName'])
                      ?.toString();
              if (ph != null && ph.trim().isNotEmpty) {
                return _toEnDigits(ph.trim());
              }
            }
          }
        }
      }
    } catch (_) {}

    final String base = fallbackFileName
        .split('/')
        .last
        .split(r'\')
        .last
        .replaceAll(RegExp(r'\.json$', caseSensitive: false), '')
        .trim();
    final String digits =
        _toEnDigits(base).replaceAll(RegExp(r'[^0-9]'), '');
    if (digits.length >= 10) return digits;
    return base.isNotEmpty ? base : null;
  }

  static bool isAccountStorageStateJson(Map<String, dynamic> map) {
    if (map['cookies'] is List || map['origins'] is List) return true;
    if (map['access_token'] is String &&
        (map['access_token'] as String).isNotEmpty) {
      return true;
    }
    if (map['refresh_token'] is String &&
        (map['refresh_token'] as String).isNotEmpty) {
      return true;
    }
    return false;
  }

  /// غنی‌سازی دیتای اکانت با اطلاعات فایل data/accounts.json در صورت وجود
  static void _enrichWithAccountsMeta(
      Map<String, dynamic> accData, Map<String, dynamic>? metaEntry) {
    if (metaEntry == null) return;
    final dynamic uid = metaEntry['user_id'];
    final String? cid = metaEntry['customer_id']?.toString();
    final String? phone = metaEntry['phone']?.toString();

    if (accData['cookies'] is List) {
      for (final dynamic c in accData['cookies'] as List) {
        if (c is Map && c['name'] == 'user' && c['value'] is String) {
          try {
            final String raw = c['value'] as String;
            final bool enc = raw.contains('%7B') || raw.contains('%22');
            final dynamic u =
                jsonDecode(enc ? Uri.decodeComponent(raw) : raw);
            if (u is Map<String, dynamic>) {
              if ((u['id'] == null || u['id'] == 0) && uid != null) {
                u['id'] = uid;
                u['alternativeCustomerId'] = uid;
              }
              if ((u['alternativeId'] == null ||
                      u['alternativeId'].toString().isEmpty) &&
                  cid != null &&
                  cid.isNotEmpty) {
                u['alternativeId'] = cid;
              }
              if ((u['mobilePhone'] == null ||
                      u['mobilePhone'].toString().isEmpty) &&
                  phone != null &&
                  phone.isNotEmpty) {
                u['mobilePhone'] = phone;
                u['userName'] = phone;
              }
              final String updatedJson = jsonEncode(u);
              c['value'] =
                  enc ? Uri.encodeComponent(updatedJson) : updatedJson;
            }
          } catch (_) {}
        }
      }
    }
  }

  /// بازگشایی کامل فایل ZIP در دارت بدون وابستگی خارجی
  static Map<String, Uint8List> _unzipBytes(Uint8List bytes) {
    final Map<String, Uint8List> files = {};
    final ByteData view =
        ByteData.sublistView(bytes, 0, bytes.length);

    // ۱. تلاش از طریق Central Directory (پشتیبانی کامل از تمام فلگ‌های استاندارد و استریم)
    int eocdOffset = -1;
    final int minEocdPos =
        bytes.length - 65557 > 0 ? bytes.length - 65557 : 0;
    for (int i = bytes.length - 22; i >= minEocdPos; i--) {
      if (bytes[i] == 0x50 &&
          bytes[i + 1] == 0x4B &&
          bytes[i + 2] == 0x05 &&
          bytes[i + 3] == 0x06) {
        eocdOffset = i;
        break;
      }
    }

    if (eocdOffset != -1 && eocdOffset + 22 <= bytes.length) {
      try {
        final int totalEntries =
            view.getUint16(eocdOffset + 10, Endian.little);
        final int cdOffset =
            view.getUint32(eocdOffset + 16, Endian.little);

        int pos = cdOffset;
        for (int idx = 0;
            idx < totalEntries && pos + 46 <= bytes.length;
            idx++) {
          if (bytes[pos] != 0x50 ||
              bytes[pos + 1] != 0x4B ||
              bytes[pos + 2] != 0x01 ||
              bytes[pos + 3] != 0x02) {
            break;
          }

          final int compMethod = view.getUint16(pos + 10, Endian.little);
          final int compSize = view.getUint32(pos + 20, Endian.little);
          final int uncompSize = view.getUint32(pos + 24, Endian.little);
          final int fileNameLen = view.getUint16(pos + 28, Endian.little);
          final int extraLen = view.getUint16(pos + 30, Endian.little);
          final int commentLen = view.getUint16(pos + 32, Endian.little);
          final int localHeaderOffset =
              view.getUint32(pos + 42, Endian.little);

          if (pos + 46 + fileNameLen > bytes.length) break;
          final String fileName = utf8.decode(
            Uint8List.sublistView(bytes, pos + 46, pos + 46 + fileNameLen),
            allowMalformed: true,
          );
          pos += 46 + fileNameLen + extraLen + commentLen;

          if (fileName.endsWith('/') ||
              fileName.endsWith(r'\') ||
              uncompSize == 0 ||
              compSize == 0) {
            continue;
          }

          if (localHeaderOffset + 30 <= bytes.length &&
              bytes[localHeaderOffset] == 0x50 &&
              bytes[localHeaderOffset + 1] == 0x4B &&
              bytes[localHeaderOffset + 2] == 0x03 &&
              bytes[localHeaderOffset + 3] == 0x04) {
            final int lhNameLen =
                view.getUint16(localHeaderOffset + 26, Endian.little);
            final int lhExtraLen =
                view.getUint16(localHeaderOffset + 28, Endian.little);
            final int dataStart =
                localHeaderOffset + 30 + lhNameLen + lhExtraLen;
            if (dataStart + compSize <= bytes.length) {
              final Uint8List compSlice = Uint8List.sublistView(
                  bytes, dataStart, dataStart + compSize);
              if (compMethod == 0) {
                files[fileName] = compSlice;
              } else if (compMethod == 8) {
                final List<int> decompressed =
                    ZLibCodec(raw: true).decoder.convert(compSlice);
                files[fileName] = Uint8List.fromList(decompressed);
              }
            }
          }
        }
      } catch (_) {}
    }

    if (files.isNotEmpty) return files;

    // ۲. فال‌بک: پیمایش مستقیم Local File Headers در صورت ناقص بودن انتهای فایل ZIP
    int offset = 0;
    while (offset + 30 <= bytes.length) {
      if (bytes[offset] != 0x50 ||
          bytes[offset + 1] != 0x4B ||
          bytes[offset + 2] != 0x03 ||
          bytes[offset + 3] != 0x04) {
        break;
      }
      final int compMethod = view.getUint16(offset + 8, Endian.little);
      final int compSize = view.getUint32(offset + 18, Endian.little);
      final int fileNameLen = view.getUint16(offset + 26, Endian.little);
      final int extraLen = view.getUint16(offset + 28, Endian.little);
      final int dataStart = offset + 30 + fileNameLen + extraLen;
      if (offset + 30 + fileNameLen > bytes.length ||
          dataStart + compSize > bytes.length) {
        break;
      }
      final String fileName = utf8.decode(
        Uint8List.sublistView(
            bytes, offset + 30, offset + 30 + fileNameLen),
        allowMalformed: true,
      );
      if (!fileName.endsWith('/') && compSize > 0) {
        try {
          final Uint8List compSlice = Uint8List.sublistView(
              bytes, dataStart, dataStart + compSize);
          if (compMethod == 0) {
            files[fileName] = compSlice;
          } else if (compMethod == 8) {
            final List<int> decompressed =
                ZLibCodec(raw: true).decoder.convert(compSlice);
            files[fileName] = Uint8List.fromList(decompressed);
          }
        } catch (_) {}
      }
      offset = dataStart + compSize;
    }

    return files;
  }

  static Map<String, dynamic> _buildAccountJsonFromSimpleTokens(
      String phone, String accessToken, String refreshToken) {
    final String cleanPh = _toEnDigits(phone).replaceAll(RegExp(r'[^0-9]'), '');
    final Map<String, dynamic> jwt = _decodeJwt(accessToken);
    final int uid =
        int.tryParse((jwt['userId'] ?? jwt['sub'] ?? '0').toString()) ?? 0;
    final String cerbId = (jwt['cerberusId'] ?? '').toString();
    final Map<String, dynamic> userObj = {
      'id': uid,
      'alternativeId': cerbId,
      'alternativeCustomerId': uid,
      'firstName': 'علی',
      'lastName': 'محمدی',
      'birthDate': '',
      'genderCode': 1,
      'userName': cleanPh,
      'mobilePhone': cleanPh,
      'customerIsLoggedInForFirstTime': false,
      'state': true,
      'hasAddress': false,
      'birthDateEpoch': 1005683400,
    };
    final String encUser = Uri.encodeComponent(jsonEncode(userObj));
    return {
      'access_token': accessToken,
      'refresh_token': refreshToken,
      'cookies': [
        if (refreshToken.isNotEmpty)
          {
            'name': 'refresh_token',
            'value': refreshToken,
            'domain': '.okala.com',
            'path': '/',
            'httpOnly': true,
            'secure': true,
            'sameSite': 'None',
          },
        if (accessToken.isNotEmpty) ...[
          {
            'name': 'tokenMS',
            'value': accessToken,
            'domain': 'www.okala.com',
            'path': '/',
            'httpOnly': false,
            'secure': false,
            'sameSite': 'Lax',
          },
          {
            'name': 'token',
            'value': accessToken,
            'domain': 'www.okala.com',
            'path': '/',
            'httpOnly': false,
            'secure': false,
            'sameSite': 'Lax',
          },
        ],
        {
          'name': 'user',
          'value': encUser,
          'domain': 'www.okala.com',
          'path': '/',
          'httpOnly': false,
          'secure': false,
          'sameSite': 'Lax',
        },
      ],
      'origins': [
        {
          'origin': 'https://www.okala.com',
          'localStorage': [
            if (accessToken.isNotEmpty) ...[
              {'name': 'tokenMS', 'value': accessToken},
              {'name': 'token', 'value': accessToken},
            ],
            {'name': 'user', 'value': encUser},
            {'name': 'city_name', 'value': 'تهران'},
            {'name': 'city_id', 'value': '129'},
          ],
        },
      ],
    };
  }

  /// استخراج اکانت‌ها و لینک‌ها از هر نوع فایل ورودی (ZIP، JSON یا TXT)
  static ZipExtractionSummary extractFromFileBytes({
    required String fileName,
    required Uint8List bytes,
  }) {
    final List<String> accountUris = [];
    final List<String> extractedLinks = [];

    if (isZipBytes(bytes)) {
      final Map<String, Uint8List> archiveFiles = _unzipBytes(bytes);
      final Map<String, Map<String, dynamic>> accountsMetaByPhone = {};

      // گام اول: بررسی فایل متادیتا data/accounts.json در صورت وجود در زیپ
      for (final MapEntry<String, Uint8List> entry in archiveFiles.entries) {
        final String lowerPath = entry.key.toLowerCase().replaceAll(r'\', '/');
        if (lowerPath.endsWith('data/accounts.json') ||
            lowerPath == 'accounts.json') {
          try {
            final String raw =
                utf8.decode(entry.value, allowMalformed: true);
            final dynamic parsed = jsonDecode(raw);
            if (parsed is Map && !isAccountStorageStateJson(parsed.cast<String, dynamic>())) {
              parsed.forEach((k, v) {
                if (v is Map) {
                  final String cleanPh = _toEnDigits(k.toString())
                      .replaceAll(RegExp(r'[^0-9]'), '');
                  if (cleanPh.isNotEmpty) {
                    accountsMetaByPhone[cleanPh] =
                        Map<String, dynamic>.from(v);
                  }
                }
              });
            }
          } catch (_) {}
        }
      }

      // مرتب‌سازی نام فایل‌ها برای حفظ ترتیب شماره‌ها
      final List<String> sortedKeys = archiveFiles.keys.toList()..sort();

      for (final String entryPath in sortedKeys) {
        if (entryPath.contains('__MACOSX')) continue;
        final String baseName =
            entryPath.split('/').last.split(r'\').last.trim();
        if (baseName.isEmpty || baseName.startsWith('.')) continue;

        final String lowerBase = baseName.toLowerCase();
        final Uint8List contentBytes = archiveFiles[entryPath]!;
        final String rawText =
            utf8.decode(contentBytes, allowMalformed: true);

        if (lowerBase.endsWith('.json')) {
          try {
            final dynamic parsed = jsonDecode(rawText);
            if (parsed is Map<String, dynamic>) {
              if (isAccountStorageStateJson(parsed)) {
                final String? phone =
                    extractPhoneFromAccountData(parsed, baseName);
                if (phone != null && accountsMetaByPhone.containsKey(phone)) {
                  _enrichWithAccountsMeta(
                      parsed, accountsMetaByPhone[phone]);
                }
                final String uri =
                    NexusAccountRegistry.instance.registerAccount(
                  data: parsed,
                  phoneOrName: phone ?? baseName,
                  sourceFileName: fileName,
                );
                if (!accountUris.contains(uri)) {
                  accountUris.add(uri);
                }
              } else {
                // بررسی دیکشنری شماره -> توکن (در صورتی که فایل JSON شامل access_token/refresh_token باشد)
                parsed.forEach((k, v) {
                  if (v is Map &&
                      (v['access_token'] != null ||
                          v['refresh_token'] != null)) {
                    final Map<String, dynamic> built =
                        _buildAccountJsonFromSimpleTokens(
                      k.toString(),
                      v['access_token']?.toString() ?? '',
                      v['refresh_token']?.toString() ?? '',
                    );
                    final String uri =
                        NexusAccountRegistry.instance.registerAccount(
                      data: built,
                      phoneOrName: k.toString(),
                      sourceFileName: fileName,
                    );
                    if (!accountUris.contains(uri)) {
                      accountUris.add(uri);
                    }
                  }
                });
              }
            }
          } catch (_) {}
        } else if (lowerBase.endsWith('.txt') ||
            lowerBase.endsWith('.csv') ||
            lowerBase.endsWith('.log')) {
          final Iterable<RegExpMatch> matches =
              RegExp(r"""https?://[^\s"'<>]+""").allMatches(rawText);
          for (final RegExpMatch m in matches) {
            final String u = m.group(0)!.trim();
            if (u.isNotEmpty && !extractedLinks.contains(u)) {
              extractedLinks.add(u);
            }
          }
        }
      }
      return ZipExtractionSummary(
        accountUris: accountUris,
        extractedLinks: extractedLinks,
        fileName: fileName,
      );
    }

    // اگر فایل غیر ZIP (مانند .json یا .txt) انتخاب شده باشد
    final String rawText = utf8.decode(bytes, allowMalformed: true).trim();
    if (rawText.startsWith('{')) {
      try {
        final dynamic parsed = jsonDecode(rawText);
        if (parsed is Map<String, dynamic>) {
          if (isAccountStorageStateJson(parsed)) {
            final String? phone =
                extractPhoneFromAccountData(parsed, fileName);
            final String uri =
                NexusAccountRegistry.instance.registerAccount(
              data: parsed,
              phoneOrName: phone ?? fileName,
              sourceFileName: fileName,
            );
            accountUris.add(uri);
          } else {
            parsed.forEach((k, v) {
              if (v is Map &&
                  (v['access_token'] != null ||
                      v['refresh_token'] != null)) {
                final Map<String, dynamic> built =
                    _buildAccountJsonFromSimpleTokens(
                  k.toString(),
                  v['access_token']?.toString() ?? '',
                  v['refresh_token']?.toString() ?? '',
                );
                final String uri =
                    NexusAccountRegistry.instance.registerAccount(
                  data: built,
                  phoneOrName: k.toString(),
                  sourceFileName: fileName,
                );
                if (!accountUris.contains(uri)) {
                  accountUris.add(uri);
                }
              }
            });
          }
        }
      } catch (_) {}
    }

    if (accountUris.isEmpty) {
      final Iterable<RegExpMatch> matches =
          RegExp(r"""https?://[^\s"'<>]+""").allMatches(rawText);
      for (final RegExpMatch m in matches) {
        final String u = m.group(0)!.trim();
        if (u.isNotEmpty && !extractedLinks.contains(u)) {
          extractedLinks.add(u);
        }
      }
    }

    return ZipExtractionSummary(
      accountUris: accountUris,
      extractedLinks: extractedLinks,
      fileName: fileName,
    );
  }
}

/// ویجت دکمه انتخاب فایل بومی اندروید (پشتیبانی از انتخاب همزمان چند فایل ZIP / JSON / TXT بدون نیاز به مجوز حافظه یا پکیج اضافی)
class NexusFilePickerButton extends StatefulWidget {
  final String title;
  final String subtitle;
  final void Function(List<ZipExtractionSummary> summaries) onFilesExtracted;
  final VoidCallback? onPickStarted;

  const NexusFilePickerButton({
    super.key,
    this.title = 'انتخاب فایل اکانت (ZIP / JSON / TXT)',
    this.subtitle = 'پشتیبانی از بارگذاری یک یا چند فایل زیپ همزمان',
    required this.onFilesExtracted,
    this.onPickStarted,
  });

  @override
  State<NexusFilePickerButton> createState() => _NexusFilePickerButtonState();
}

class _NexusFilePickerButtonState extends State<NexusFilePickerButton> {
  bool _isReading = false;

  String _buildPickerHtml() {
    final String safeTitle = const HtmlEscape().convert(widget.title);
    final String safeSub = const HtmlEscape().convert(widget.subtitle);
    return '''<!DOCTYPE html>
<html lang="fa" dir="rtl">
<head>
<meta charset="utf-8">
<meta name="viewport" content="width=device-width, initial-scale=1.0, maximum-scale=1.0, user-scalable=no">
<style>
  * { box-sizing: border-box; user-select: none; -webkit-tap-highlight-color: transparent; }
  html, body {
    margin: 0; padding: 0; width: 100%; height: 100%;
    background: #12141D; overflow: hidden;
    font-family: system-ui, -apple-system, sans-serif;
  }
  label {
    display: flex; align-items: center; justify-content: space-between;
    width: 100%; height: 100%; padding: 0 16px;
    background: #12141D;
    border: 1.5px dashed rgba(0, 208, 158, 0.55);
    border-radius: 16px; cursor: pointer;
    transition: all 0.15s ease;
  }
  label:active {
    background: rgba(0, 208, 158, 0.12);
    border-color: #00D09E;
  }
  .info { display: flex; flex-direction: column; align-items: flex-start; gap: 3px; }
  .title { color: #F3F4F6; font-size: 13.5px; font-weight: 700; }
  .sub { color: #9CA3AF; font-size: 11px; }
  .badge {
    display: flex; align-items: center; justify-content: center;
    background: rgba(0, 208, 158, 0.14); color: #00D09E;
    padding: 8px 12px; border-radius: 11px;
    font-size: 12px; font-weight: 800; letter-spacing: 0.4px;
  }
  input[type="file"] { display: none; }
</style>
</head>
<body>
  <label for="nxZipInput">
    <div class="info">
      <span class="title">📂 $safeTitle</span>
      <span class="sub">$safeSub</span>
    </div>
    <div class="badge">ZIP / JSON</div>
  </label>
  <input id="nxZipInput" type="file" multiple />
  <script>
    (function() {
      var inp = document.getElementById('nxZipInput');
      inp.addEventListener('change', function(ev) {
        var files = ev.target.files;
        if (!files || files.length === 0) return;
        if (window.flutter_inappwebview && window.flutter_inappwebview.callHandler) {
          window.flutter_inappwebview.callHandler('onPickStarted');
        }
        var results = [];
        var idx = 0;
        function readNext() {
          if (idx >= files.length) {
            if (window.flutter_inappwebview && window.flutter_inappwebview.callHandler) {
              window.flutter_inappwebview.callHandler('onFilesPicked', results);
            }
            inp.value = '';
            return;
          }
          var f = files[idx++];
          var reader = new FileReader();
          reader.onload = function(e) {
            var dataUrl = String(e.target.result || '');
            var comma = dataUrl.indexOf(',');
            var b64 = comma !== -1 ? dataUrl.substring(comma + 1) : dataUrl;
            results.push({ name: f.name || 'archive.zip', base64: b64 });
            readNext();
          };
          reader.onerror = function() {
            readNext();
          };
          reader.readAsDataURL(f);
        }
        readNext();
      });
    })();
  </script>
</body>
</html>''';
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 64,
      child: Stack(
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(16),
            child: InAppWebView(
              initialData: InAppWebViewInitialData(
                data: _buildPickerHtml(),
                mimeType: 'text/html',
                encoding: 'utf-8',
              ),
              initialSettings: InAppWebViewSettings(
                javaScriptEnabled: true,
                transparentBackground: true,
                supportZoom: false,
                disableVerticalScroll: true,
                disableHorizontalScroll: true,
                useHybridComposition: true,
                allowFileAccessFromFileURLs: true,
                allowUniversalAccessFromFileURLs: true,
              ),
              onWebViewCreated: (controller) {
                controller.addJavaScriptHandler(
                  handlerName: 'onPickStarted',
                  callback: (_) {
                    if (mounted) {
                      setState(() => _isReading = true);
                    }
                    widget.onPickStarted?.call();
                  },
                );
                controller.addJavaScriptHandler(
                  handlerName: 'onFilesPicked',
                  callback: (args) {
                    if (mounted) {
                      setState(() => _isReading = false);
                    }
                    if (args.isEmpty || args.first is! List) return;
                    final List<dynamic> rawList = args.first as List<dynamic>;
                    final List<ZipExtractionSummary> summaries = [];
                    for (final dynamic item in rawList) {
                      if (item is Map) {
                        final String fname =
                            item['name']?.toString() ?? 'archive.zip';
                        final String b64 =
                            item['base64']?.toString() ?? '';
                        if (b64.isEmpty) continue;
                        try {
                          final Uint8List bytes = base64Decode(b64);
                          final ZipExtractionSummary summary =
                              NexusZipExtractor.extractFromFileBytes(
                            fileName: fname,
                            bytes: bytes,
                          );
                          summaries.add(summary);
                        } catch (_) {}
                      }
                    }
                    widget.onFilesExtracted(summaries);
                  },
                );
              },
            ),
          ),
          if (_isReading)
            Container(
              decoration: BoxDecoration(
                color: bgDark.withOpacity(0.88),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: primaryAccent, width: 1.2),
              ),
              child: const Center(
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(
                        color: primaryAccent,
                        strokeWidth: 2.2,
                      ),
                    ),
                    SizedBox(width: 10),
                    Text(
                      'در حال استخراج اکانت‌ها از فایل ZIP...',
                      style: TextStyle(
                        color: primaryAccent,
                        fontSize: 13,
                        fontWeight: FontWeight.bold,
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
  final List<String> _importedZipAccountUris = [];
  final List<String> _importedZipFileNames = [];
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
    if (uri == null || uri.host.isEmpty) return false;
    return uri.scheme.toLowerCase() == 'https' && uri.userInfo.isEmpty;
  }

  void _handleExtractedFiles(List<ZipExtractionSummary> summaries) {
    int newAccCount = 0;
    int newLinkCount = 0;
    final List<String> currentLinksText = [];

    for (final ZipExtractionSummary s in summaries) {
      if (s.totalCount > 0 && !_importedZipFileNames.contains(s.fileName)) {
        _importedZipFileNames.add(s.fileName);
      }
      for (final String uri in s.accountUris) {
        if (!_importedZipAccountUris.contains(uri)) {
          _importedZipAccountUris.add(uri);
          newAccCount++;
        }
      }
      for (final String link in s.extractedLinks) {
        currentLinksText.add(link);
        newLinkCount++;
      }
    }

    if (currentLinksText.isNotEmpty) {
      final String existing = _linksController.text.trim();
      _linksController.text = existing.isEmpty
          ? currentLinksText.join('\n')
          : '$existing\n${currentLinksText.join('\n')}';
    }

    setState(() {
      if (newAccCount == 0 && newLinkCount == 0) {
        _isWarning = true;
        _statusMessage =
            'هیچ اکانت یا پیوند معتبری در فایل انتخابی یافت نشد (یا قبلاً اضافه شده است).';
      } else {
        _isWarning = false;
        final List<String> parts = [];
        if (newAccCount > 0) parts.add('$newAccCount اکانت از فایل ZIP');
        if (newLinkCount > 0) parts.add('$newLinkCount پیوند');
        _statusMessage =
            '${parts.join(' و ')} با موفقیت بارگذاری شد. مجموع اکانت‌های ZIP آماده: ${_importedZipAccountUris.length}';
      }
    });
  }

  void _processLinks() {
    final String text = _linksController.text.trim();
    final List<String> finalTargets = [];
    int invalidCount = 0;

    // ۱. اگر کاربر مستقیماً متن JSON یک اکانت را در کادر پیست کرده باشد
    if (text.startsWith('{') && text.endsWith('}')) {
      try {
        final dynamic parsed = jsonDecode(text);
        if (parsed is Map<String, dynamic> &&
            NexusZipExtractor.isAccountStorageStateJson(parsed)) {
          final String? phone =
              NexusZipExtractor.extractPhoneFromAccountData(parsed, 'JSON');
          final String uri = NexusAccountRegistry.instance.registerAccount(
            data: parsed,
            phoneOrName: phone ?? 'اکانت JSON',
            sourceFileName: 'ورودی مستقیم',
          );
          finalTargets.add(uri);
        }
      } catch (_) {}
    }

    // ۲. استخراج پیوندها از کادر متنی
    if (finalTargets.isEmpty && text.isNotEmpty) {
      final List<String> tokens = text.split(RegExp(r'\s+'));
      for (String token in tokens) {
        token = token.trim();
        if (token.isEmpty) continue;

        if (_isAllowedLink(token)) {
          final String normalized = _normaliseLink(token);
          if (!finalTargets.contains(normalized)) {
            finalTargets.add(normalized);
          }
        } else {
          invalidCount++;
        }
      }
    }

    // ۳. افزودن تمامی اکانت‌های استخراج‌شده از فایل‌های ZIP
    for (final String zipUri in _importedZipAccountUris) {
      if (!finalTargets.contains(zipUri)) {
        finalTargets.add(zipUri);
      }
    }

    if (finalTargets.isEmpty) {
      setState(() {
        _isWarning = true;
        _statusMessage =
            'لطفاً پیوندها را وارد کنید یا یک فایل ZIP انتخاب نمایید.';
      });
      return;
    }

    setState(() {
      _isWarning = false;
      _statusMessage = invalidCount > 0
          ? '$invalidCount مورد غیرمعتبر نادیده گرفته شد. ${finalTargets.length} حساب آماده ورود است.'
          : '';
    });

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => BrowserScreen(urls: finalTargets),
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
                      'سیستم مدیریت سریع پیوندها و فایل‌های ZIP اکانت',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: textSecondary,
                        fontSize: 13.5,
                      ),
                    ),
                    const SizedBox(height: 28),
                    TextField(
                      controller: _linksController,
                      maxLines: 5,
                      textDirection: TextDirection.ltr,
                      textAlign: TextAlign.left,
                      style: const TextStyle(
                        color: textPrimary,
                        fontSize: 14,
                        height: 1.6,
                      ),
                      decoration: InputDecoration(
                        labelText: 'لیست پیوندها (یا لینک فایل ZIP)',
                        labelStyle: const TextStyle(color: textSecondary),
                        hintText: 'https://${allowedLinkHosts.first}/acc/...',
                        hintStyle: TextStyle(
                          color: textSecondary.withOpacity(0.4),
                          fontSize: 13,
                        ),
                        filled: true,
                        fillColor: bgDark,
                        alignLabelWithHint: true,
                        contentPadding: const EdgeInsets.all(18),
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
                    const SizedBox(height: 10),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        TextButton.icon(
                          onPressed: () {
                            _linksController.clear();
                            setState(() {
                              _importedZipAccountUris.clear();
                              _importedZipFileNames.clear();
                              _statusMessage = '';
                            });
                          },
                          icon: const Icon(Icons.clear_all,
                              size: 16, color: textSecondary),
                          label: const Text(
                            'پاک کردن همه',
                            style:
                                TextStyle(color: textSecondary, fontSize: 12),
                          ),
                        ),
                        const Flexible(
                          child: Text(
                            'پیوندها را وارد کنید یا فایل ZIP انتخاب نمایید.',
                            textAlign: TextAlign.right,
                            style: TextStyle(
                              color: textSecondary,
                              fontSize: 11.5,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    NexusFilePickerButton(
                      onFilesExtracted: _handleExtractedFiles,
                    ),
                    if (_importedZipAccountUris.isNotEmpty) ...[
                      const SizedBox(height: 14),
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: bgDark,
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(
                            color: primaryAccent.withOpacity(0.35),
                          ),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                IconButton(
                                  visualDensity: VisualDensity.compact,
                                  tooltip: 'حذف فایل‌های زیپ',
                                  onPressed: () {
                                    setState(() {
                                      _importedZipAccountUris.clear();
                                      _importedZipFileNames.clear();
                                      _statusMessage = '';
                                    });
                                  },
                                  icon: const Icon(
                                    Icons.delete_sweep_rounded,
                                    color: Colors.redAccent,
                                    size: 20,
                                  ),
                                ),
                                Flexible(
                                  child: Text(
                                    '📦 ${_importedZipAccountUris.length} اکانت از ${_importedZipFileNames.length} فایل آماده ورود',
                                    textDirection: TextDirection.rtl,
                                    style: const TextStyle(
                                      color: primaryAccent,
                                      fontSize: 12.5,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 6),
                            ConstrainedBox(
                              constraints: const BoxConstraints(maxHeight: 92),
                              child: SingleChildScrollView(
                                child: Wrap(
                                  spacing: 6,
                                  runSpacing: 6,
                                  alignment: WrapAlignment.end,
                                  children: _importedZipAccountUris
                                      .asMap()
                                      .entries
                                      .map((entry) {
                                    final String label = NexusAccountRegistry
                                        .instance
                                        .getLabel(entry.value, entry.key);
                                    return Container(
                                      padding: const EdgeInsets.symmetric(
                                          horizontal: 9, vertical: 4),
                                      decoration: BoxDecoration(
                                        color: surfaceDark,
                                        borderRadius: BorderRadius.circular(8),
                                        border: Border.all(
                                          color:
                                              primaryAccent.withOpacity(0.25),
                                        ),
                                      ),
                                      child: Text(
                                        label,
                                        style: const TextStyle(
                                          color: textPrimary,
                                          fontSize: 11.5,
                                          fontWeight: FontWeight.w600,
                                        ),
                                      ),
                                    );
                                  }).toList(),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                    const SizedBox(height: 20),
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
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Text(
                              _importedZipAccountUris.isNotEmpty
                                  ? 'شروع پردازش سریع (${_importedZipAccountUris.length}+ حساب)'
                                  : 'شروع پردازش سریع',
                              style: const TextStyle(
                                fontSize: 15.5,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            const SizedBox(width: 8),
                            const Icon(Icons.rocket_launch_rounded, size: 20),
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
                                textDirection: TextDirection.rtl,
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

  late final List<String> _urls;
  int _currentIndex = 0;
  bool _isLoading = true;
  bool _hasError = false;
  double _progress = 0;
  String _loadingMessage = 'در حال آماده‌سازی...';

  InAppWebViewController? _webViewController;
  final http.Client _httpClient = http.Client();

  String _activeInjectionScript = '';
  String _activeBootstrapHtml = '';
  String _activeTargetKey = '';
  String _activeAccountPhone = '';
  String _activeAccountUserId = '';
  String _activeAccountCerberusId = '';
  int _sessionGeneration = 0;

  @override
  void initState() {
    super.initState();
    _urls = List<String>.from(widget.urls);
    _loadAccount(0);
  }

  @override
  void dispose() {
    _httpClient.close();
    super.dispose();
  }

  Future<void> _cleanupWebViewCache({bool showNotice = false}) async {
    try {
      await InAppWebViewController.clearAllCache(includeDiskFiles: true);
    } catch (_) {}

    if (showNotice && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'کش و فایل‌های موقت وب‌ویو پاکسازی شد (نشست حساب حفظ شد).',
            textDirection: TextDirection.rtl,
            style: TextStyle(color: bgDark, fontWeight: FontWeight.bold),
          ),
          backgroundColor: primaryAccent,
          behavior: SnackBarBehavior.floating,
          duration: Duration(seconds: 2),
        ),
      );
    }
  }

  String _toEnglishDigits(String input) {
    const Map<String, String> digitsMap = {
      '۰': '0', '۱': '1', '۲': '2', '۳': '3', '۴': '4',
      '۵': '5', '۶': '6', '۷': '7', '۸': '8', '۹': '9',
      '٠': '0', '١': '1', '٢': '2', '٣': '3', '٤': '4',
      '٥': '5', '٦': '6', '٧': '7', '٨': '8', '٩': '9',
    };
    String out = input;
    digitsMap.forEach((k, v) {
      out = out.replaceAll(k, v);
    });
    return out;
  }

  int _parsePositiveInt(dynamic value) {
    if (value == null) return 0;
    if (value is int) return value > 0 ? value : 0;
    if (value is num) return value.toInt() > 0 ? value.toInt() : 0;
    final String s = _toEnglishDigits(value.toString()).trim();
    if (s.isEmpty) return 0;
    final int? parsed = int.tryParse(s);
    return (parsed != null && parsed > 0) ? parsed : 0;
  }

  Map<String, dynamic> _decodeJwtPayload(String? token) {
    if (token == null || token.isEmpty || !token.contains('.')) {
      return {};
    }
    try {
      final List<String> parts = token.split('.');
      if (parts.length < 2) return {};
      String normalized =
          parts[1].replaceAll('-', '+').replaceAll('_', '/').trim();
      while (normalized.length % 4 != 0) {
        normalized += '=';
      }
      final String decodedStr = utf8.decode(base64Decode(normalized));
      final dynamic decodedJson = jsonDecode(decodedStr);
      if (decodedJson is Map<String, dynamic>) {
        return decodedJson;
      }
    } catch (_) {}
    return {};
  }

  bool _hasVoyagerClaims(String? token) {
    final Map<String, dynamic> p = _decodeJwtPayload(token);
    if (p.isEmpty) return false;
    return p.containsKey('cerberusId') ||
        p.containsKey('userId') ||
        p.containsKey('alternativeCustomerId') ||
        p.containsKey('tenant');
  }

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

  /// بررسی و نوسازی هوشمند توکن برای لینک‌ها و فایل‌های ZIP
  /// با حفظ کامل Refresh Token چرخش‌یافته و کلیم‌های Voyager (مطابق منطق Main1.py)
  Future<_TokenPairResult> _ensureValidAccessToken(
      String? accessToken, List<String> candidateRefreshTokens) async {
    String? cleanAccess = accessToken?.trim();
    if (cleanAccess != null &&
        cleanAccess.toLowerCase().startsWith('bearer ')) {
      cleanAccess = cleanAccess.substring(7).trim();
    }

    final List<String> validRefreshList = [];
    for (final String r in candidateRefreshTokens) {
      final String trimmed = r.trim();
      if (trimmed.isNotEmpty && !validRefreshList.contains(trimmed)) {
        validRefreshList.add(trimmed);
      }
    }
    final String? primaryRefresh =
        validRefreshList.isNotEmpty ? validRefreshList.first : null;

    final int nowSec = DateTime.now().millisecondsSinceEpoch ~/ 1000;
    if (cleanAccess != null && cleanAccess.isNotEmpty) {
      final Map<String, dynamic> jwt = _decodeJwtPayload(cleanAccess);
      final int exp = _parsePositiveInt(jwt['exp']);
      // اگر توکن فعلی هنوز بیش از ۳ دقیقه اعتبار دارد، رفرش‌توکن را نسوزانیم
      if (exp > nowSec + 180) {
        if (!_hasVoyagerClaims(cleanAccess)) {
          final String? exchanged = await _exchangeForVoyagerToken(cleanAccess);
          if (exchanged != null && _hasVoyagerClaims(exchanged)) {
            return _TokenPairResult(
              accessToken: exchanged,
              refreshToken: primaryRefresh,
              wasRefreshed: true,
            );
          }
        }
        return _TokenPairResult(
          accessToken: cleanAccess,
          refreshToken: primaryRefresh,
          wasRefreshed: false,
        );
      }
    }

    if (validRefreshList.isEmpty) {
      return _TokenPairResult(
        accessToken: cleanAccess,
        refreshToken: null,
        wasRefreshed: false,
      );
    }

    final Map<String, String> baseHeaders = {
      'accept': 'application/json, text/plain, */*',
      'source': 'okala',
      'ui-version': '2.0',
      'origin': 'https://www.okala.com',
      'content-type': 'application/x-www-form-urlencoded',
      'advertising_id': '',
      'User-Agent': customUserAgent,
    };

    for (final String cleanRefresh in validRefreshList) {
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
            .timeout(const Duration(seconds: 6));

        if ((response.statusCode == 401 || response.statusCode == 400) &&
            headersWithAuth.containsKey('Authorization')) {
          response = await _httpClient
              .post(
                Uri.parse(
                    'https://apigateway.okala.com/api/v1/accounts/tokens'),
                headers: baseHeaders,
                body: bodyData,
              )
              .timeout(const Duration(seconds: 6));
        }

        if (response.statusCode == 200) {
          final dynamic bodyJson =
              jsonDecode(utf8.decode(response.bodyBytes));
          if (bodyJson is Map) {
            String? newAcc = bodyJson['access_token']?.toString();
            final String? newRef = bodyJson['refresh_token']?.toString();
            if (newAcc != null && newAcc.isNotEmpty) {
              if (!_hasVoyagerClaims(newAcc)) {
                final String? exchanged =
                    await _exchangeForVoyagerToken(newAcc);
                if (exchanged != null && exchanged.isNotEmpty) {
                  newAcc = exchanged;
                }
              }
              return _TokenPairResult(
                accessToken: newAcc,
                refreshToken: (newRef != null && newRef.isNotEmpty)
                    ? newRef
                    : cleanRefresh,
                wasRefreshed: true,
              );
            }
          }
        }
      } catch (_) {}
    }

    // اگر رفرش‌توکن فایل زیپ قبلاً در ربات مصرف شده بود، یک بار هم تبادل مستقیم توکن امتحان شود
    if (cleanAccess != null && cleanAccess.isNotEmpty) {
      final String? exchanged = await _exchangeForVoyagerToken(cleanAccess);
      if (exchanged != null && exchanged.isNotEmpty) {
        return _TokenPairResult(
          accessToken: exchanged,
          refreshToken: primaryRefresh,
          wasRefreshed: true,
        );
      }
    }

    return _TokenPairResult(
      accessToken: cleanAccess,
      refreshToken: primaryRefresh,
      wasRefreshed: false,
    );
  }

  /// جایگزینی کامل توکن قدیمی با توکن جدید در ساختار JSON اکانت (برای پایداری کامل اکانت‌های ZIP در حافظه)
  Map<String, dynamic> _updateTokensInAccountData(
    Map<String, dynamic> origData,
    String? oldAccess,
    String? newAccess,
    String? oldRefresh,
    String? newRefresh,
  ) {
    try {
      String serialized = jsonEncode(origData);
      if (oldAccess != null &&
          oldAccess.isNotEmpty &&
          newAccess != null &&
          newAccess.isNotEmpty &&
          oldAccess != newAccess) {
        serialized = serialized.replaceAll(oldAccess, newAccess);
      }
      if (oldRefresh != null &&
          oldRefresh.isNotEmpty &&
          newRefresh != null &&
          newRefresh.isNotEmpty &&
          oldRefresh != newRefresh) {
        serialized = serialized.replaceAll(oldRefresh, newRefresh);
      }
      final dynamic decoded = jsonDecode(serialized);
      if (decoded is Map<String, dynamic>) {
        if (newAccess != null && newAccess.isNotEmpty) {
          decoded['access_token'] = newAccess;
        }
        if (newRefresh != null && newRefresh.isNotEmpty) {
          decoded['refresh_token'] = newRefresh;
        }
        return decoded;
      }
    } catch (_) {}
    return origData;
  }

  /// دریافت لیست آدرس‌های ثبت‌شده کاربر از سرور اوکالا
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

  /// فعال‌سازی پروفایل اکانت‌های خام در سرور Voyager (UpdateCustomer) و استخراج شناسه عددی مشتری (id)
  /// مطابق منطق Main1.py: اکانت‌های خامی که در سرور نام ندارند هنگام ثبت آدرس با خطای «مشکلی در اقلام دریافتی وجود دارد» مواجه می‌شوند.
  Future<void> _ensureCustomerProfileInVoyager(
      String? tokenMs, Map<String, dynamic> userMap, bool wasRawState) async {
    if (tokenMs == null || tokenMs.isEmpty) return;

    final int curId =
        _parsePositiveInt(userMap['id'] ?? userMap['alternativeCustomerId']);
    final String curFirst = userMap['firstName']?.toString().trim() ?? '';
    final String curLast = userMap['lastName']?.toString().trim() ?? '';
    final bool missingRealName = curFirst.isEmpty ||
        curFirst == 'کاربر' ||
        curLast.isEmpty ||
        curLast == 'اکالا';

    if (curId > 0 && !missingRealName && !wasRawState) {
      return;
    }

    final String sendFirst = missingRealName ? 'علی' : curFirst;
    final String sendLast = missingRealName ? 'محمدی' : curLast;
    final int sendEpoch = _parsePositiveInt(userMap['birthDateEpoch']) > 0
        ? _parsePositiveInt(userMap['birthDateEpoch'])
        : 1005683400;

    try {
      final http.Response resp = await _httpClient
          .post(
            Uri.parse(
                'https://apigateway.okala.com/api/voyager/C/CustomerAccount/UpdateCustomer'),
            headers: {
              'Accept': 'application/json, text/plain, */*',
              'Content-Type': 'application/json',
              'Authorization': 'Bearer $tokenMs',
              'source': 'okala',
              'ui-version': '2.0',
              'Origin': 'https://www.okala.com',
              'Referer': 'https://www.okala.com/',
              'advertising_id': 'null',
              'idfa': 'null',
              'metrix_user_id': 'null',
            },
            body: jsonEncode({
              'birthDate': '',
              'birthDateEpoch': sendEpoch,
              'customerType': 0,
              'emailAddress': userMap['emailAddress']?.toString() ?? '',
              'firstName': sendFirst,
              'genderCode': 1,
              'genderTitle': 'آقا',
              'lastName': sendLast,
              'gender': 'Male',
            }),
          )
          .timeout(const Duration(seconds: 4));

      if (resp.statusCode == 200) {
        final dynamic decoded = jsonDecode(utf8.decode(resp.bodyBytes));
        if (decoded is Map && decoded['data'] is Map) {
          final Map data = decoded['data'] as Map;
          final int srvId = _parsePositiveInt(data['id']);
          if (srvId > 0) {
            userMap['id'] = srvId;
            if (_parsePositiveInt(userMap['alternativeCustomerId']) == 0) {
              userMap['alternativeCustomerId'] = srvId;
            }
          }
          final String srvFirst = data['firstName']?.toString().trim() ?? '';
          final String srvLast = data['lastName']?.toString().trim() ?? '';
          if (srvFirst.isNotEmpty) userMap['firstName'] = srvFirst;
          if (srvLast.isNotEmpty) userMap['lastName'] = srvLast;
        }
      }
    } catch (_) {}
  }

  /// تکمیل و اصلاح تمام فیلدهای آبجکت user با اولویت کلیم‌های JWT
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
    userMap['firstName'] = firstName.isEmpty ? 'علی' : firstName;
    userMap['lastName'] = lastName.isEmpty ? 'محمدی' : lastName;

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

    final int nowSec = DateTime.now().millisecondsSinceEpoch ~/ 1000;

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
      'eventStartTime': nowSec,
      'eventStartTimeForEditAddress': nowSec,
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

          // مسدودسازی Service Worker و حذف کش‌های قدیمی PWA
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

          // استخراج کمکی شناسه عددی از توکن در صورت صفر بودن id
          if ((!parsedUserObj.id || Number(parsedUserObj.id) <= 0) && initTMs && initTMs.indexOf('.') !== -1 && origAtob) {
            try {
              var b64Part = initTMs.split('.')[1].replace(/-/g, '+').replace(/_/g, '/');
              while (b64Part.length % 4 !== 0) { b64Part += '='; }
              var jwtPayload = JSON.parse(origAtob(b64Part));
              var jwtCid = Number(jwtPayload.userId || jwtPayload.alternativeCustomerId || jwtPayload.sub || 0);
              if (jwtCid > 0) {
                parsedUserObj.id = jwtCid;
                parsedUserObj.alternativeCustomerId = jwtCid;
              }
              if (!parsedUserObj.alternativeId && jwtPayload.cerberusId) {
                parsedUserObj.alternativeId = String(jwtPayload.cerberusId);
              }
            } catch (_) {}
          }

          var parsedUserInfoPascal = {
            Id: parsedUserObj.id || 0,
            AlternativeId: parsedUserObj.alternativeId || '',
            AlternativeCustomerId: parsedUserObj.alternativeCustomerId || parsedUserObj.id || 0,
            FirstName: parsedUserObj.firstName || 'علی',
            LastName: parsedUserObj.lastName || 'محمدی',
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
              try {
                origSetItem.call(localStorage, '__nx_addr_cache_' + st.targetKey, JSON.stringify(norm));
              } catch (_) {}
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
                  // همگام‌سازی استور نقشه (Zustand map) با مختصات آدرس انتخاب‌شده
                  if (defItem.lat && defItem.lng) {
                    origSetItem.call(localStorage, 'map', JSON.stringify({
                      state: {
                        discovery: {
                          latitude: Number(defItem.lat),
                          longitude: Number(defItem.lng),
                          lat: Number(defItem.lat),
                          lng: Number(defItem.lng),
                          cityId: Number(defItem.cityId) || 129,
                          cityName: defItem.cityName || 'تهران',
                          address: defItem.address || '',
                          plaque: defItem.plaque || '1',
                          unit: defItem.unit || '1',
                          submitted: true
                        }
                      },
                      version: 0
                    }));
                  }
                }
              }
            } catch (_) {}
          }

          // بازیابی آدرس ذخیره‌شده در همین نشست (اگر کاربر روی نقشه آدرسی ثبت کرده باشد)
          var persistedCustomAddr = null;
          try {
            var rawCustomAddr = localStorage.getItem('__nx_addr_cache_' + targetKey);
            if (rawCustomAddr) {
              persistedCustomAddr = normalizeAddressResponseObject(JSON.parse(rawCustomAddr));
            }
          } catch (_) {}

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
            lastSubmittedAddrItem: (prevKey === targetKey && window.__nxState && window.__nxState.lastSubmittedAddrItem)
              ? window.__nxState.lastSubmittedAddrItem
              : null,
            cachedAddressResp: persistedCustomAddr ||
              normalizeAddressResponseObject(initAddrResp) ||
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
              // حذف کامل کوکی refresh_token تا در صورت منقضی بودن، BFF اوکالا نشست را باطل نکند
              setRawCookie('refresh_token=; path=/; max-age=0');
              setRawCookie('refresh_token=; domain=.okala.com; path=/; max-age=0; Secure; SameSite=None');
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
                  if (k === 'refresh_token' || k === 'user') continue;
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
              origRemoveItem.call(localStorage, 'refresh_token');

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
            origSetItem.call(sessionStorage, targetKey, '1');
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

          function recordSubmittedAddressAsDefault(addrItem) {
            try {
              var st = window.__nxState;
              if (!st || !addrItem) return;
              st.lastSubmittedAddrItem = addrItem;
              var existingItems = [];
              if (st.cachedAddressResp && st.cachedAddressResp.data && Array.isArray(st.cachedAddressResp.data.customerAddressResponseItems)) {
                existingItems = st.cachedAddressResp.data.customerAddressResponseItems.slice();
              }
              for (var i = 0; i < existingItems.length; i++) {
                if (existingItems[i] && typeof existingItems[i] === 'object') {
                  existingItems[i].isDefault = false;
                }
              }
              addrItem.isDefault = true;
              existingItems.unshift(addrItem);

              var wrapped = {
                success: true,
                hasValidationError: false,
                message: null,
                data: {
                  customerAddressResponseItems: existingItems,
                  hasNextPage: false,
                  hasPreviousPage: false,
                  pageIndex: 1,
                  pageSize: 15,
                  totalCount: existingItems.length,
                  totalPages: 1
                },
                errorCode: null
              };
              syncAddressToSessionStorage(wrapped);

              // اگر کاربر در صفحه بدون آدرس (/) بود، پس از ذخیره آدرس به صفحه فروشگاه‌ها هدایت شود
              setTimeout(function() {
                try {
                  if (window.location.pathname === '/' || window.location.pathname === '') {
                    window.location.href = '/stores';
                  }
                } catch (_) {}
              }, 650);
            } catch (_) {}
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
                var newRef = bffObj.auth.refresh_token || bffObj.auth.refreshToken || '';
                if (typeof newTok === 'string' && newTok.length > 20) {
                  st.tMs = newTok;
                  if (newRef) st.rTk = newRef;
                  origSetItem.call(localStorage, 'token', newTok);
                  origSetItem.call(localStorage, 'tokenMS', newTok);
                  syncCookiesNow();
                  try {
                    if (window.flutter_inappwebview && window.flutter_inappwebview.callHandler) {
                      window.flutter_inappwebview.callHandler('onTokenRefreshed', {
                        accessToken: newTok,
                        refreshToken: newRef || st.rTk || ''
                      });
                    }
                  } catch (_) {}
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

          // استانداردسازی کامل بدنه JSON در درخواست‌های ثبت و ویرایش آدرس (رفع قطعی خطای «مشکلی در اقلام دریافتی وجود دارد»)
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

              if (isAddOrEditAddressUrl(urlStr)) {
                var cleanPlaque = toEnDigits(obj.plaque != null ? obj.plaque : '1').trim() || '1';
                var cleanUnit = toEnDigits(obj.unit != null ? obj.unit : '1').trim() || '1';
                var cleanLat = Number(obj.lat || obj.latitude) || 35.69975;
                var cleanLng = Number(obj.lng || obj.longitude) || 51.33551;
                var cleanAddrText = (obj.address && String(obj.address).trim() !== '')
                  ? String(obj.address).trim()
                  : 'آدرس ثبت شده از نقشه';
                var cleanTypeId = (Number(obj.addressTypeId) >= 1 && Number(obj.addressTypeId) <= 3)
                  ? Number(obj.addressTypeId)
                  : 3;
                var cleanCityId = Number(obj.cityId) || Number(localStorage.getItem('city_id')) || 129;

                // ساخت آیتم آدرس کامل برای ذخیره آنی در کش کلاینت و BFF
                var synthAddrItem = {
                  additionalAddressDetails: obj.additionalAddressDetails || null,
                  addressId: 'addr-' + Date.now(),
                  cerberusId: uObj.alternativeId || '',
                  id: Number(obj.id) > 0 ? Number(obj.id) : (Date.now() % 100000000),
                  address: cleanAddrText,
                  cityId: cleanCityId,
                  cityName: localStorage.getItem('city_name') || 'تهران',
                  customerId: validCid || 0,
                  customerName: ((uObj.firstName || 'علی') + ' ' + (uObj.lastName || 'محمدی')).trim(),
                  firstName: uObj.firstName || 'علی',
                  lastName: uObj.lastName || 'محمدی',
                  isDefault: true,
                  lat: cleanLat,
                  lng: cleanLng,
                  transferee: Boolean(obj.transferee),
                  stateCode: 1,
                  unit: cleanUnit,
                  plaque: cleanPlaque,
                  sectorId: 0,
                  sectorName: '',
                  sectorPartId: 0,
                  sectorPartName: '',
                  mobilePhone: uObj.mobilePhone || '',
                  title: obj.title || null,
                  addressTypeId: cleanTypeId,
                  storeId: null,
                  zipPostalCode: null,
                  postalCode: null,
                  phoneNumber: null,
                  countOfStores: null,
                  isAvailableInCurrentStore: true,
                  createdOn: new Date().toISOString(),
                  modifiedOn: new Date().toISOString(),
                  tenant: 'Okala'
                };
                recordSubmittedAddressAsDefault(synthAddrItem);

                // تنظیم دقیق فیلدها مطابق استاندارد سرور Voyager و Main1.py (جلوگیری از سرریز Int32 در oprationDuration)
                obj.id = Number(obj.id) > 0 ? Number(obj.id) : 0;
                if (validCid > 0) {
                  obj.customerId = validCid;
                }
                obj.plaque = cleanPlaque;
                obj.unit = cleanUnit;
                obj.lat = cleanLat;
                obj.lng = cleanLng;
                obj.address = cleanAddrText;
                obj.addressTypeId = cleanTypeId;
                obj.oprationDuration = 14500;
                obj.ShoppingSectorPartId = String(obj.ShoppingSectorPartId || '0');
                obj.shoppingSectorId = String(obj.shoppingSectorId || '0');
                obj.mobilePhone = (obj.transferee && obj.mobilePhone) ? toEnDigits(obj.mobilePhone).trim() : '';
                obj.mapPlatform = obj.mapPlatform || 'ParsiMap';
                if (!obj.cityId || Number(obj.cityId) <= 0) {
                  obj.cityId = cleanCityId;
                }
                return JSON.stringify(obj);
              }

              if ('customerId' in obj && validCid > 0) {
                if (!obj.customerId || Number(obj.customerId) <= 0 || Number(obj.customerId) !== validCid) {
                  obj.customerId = validCid;
                  return JSON.stringify(obj);
                }
              }
            } catch (_) {}
            return body;
          }

          function buildAddAddressSuccessResponse() {
            var st = window.__nxState || {};
            var item = st.lastSubmittedAddrItem || {};
            return JSON.stringify({
              success: true,
              hasValidationError: false,
              message: null,
              data: item,
              errorCode: null
            });
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
            if (isAddOrEditAddressUrl(lower)) {
              return buildAddAddressSuccessResponse();
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

          // ۲. نصب لایه‌های محافظ سراسری روی window
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
                        if (!parsedU.state || typeof parsedU.state !== 'object') {
                          parsedU.state = {};
                        }
                        if (!parsedU.state.user || !parsedU.state.user.id) {
                          parsedU.state.user = Object.assign({}, st.savedUserObj, { token: st.tMs });
                        } else {
                          parsedU.state.user.customerIsLoggedInForFirstTime = false;
                          parsedU.state.user.state = true;
                          parsedU.state.user.stateCode = 1;
                          if (st.savedUserObj && st.savedUserObj.id) {
                            parsedU.state.user.id = st.savedUserObj.id;
                            parsedU.state.user.alternativeCustomerId = st.savedUserObj.alternativeCustomerId || st.savedUserObj.id;
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
                        parsedU.customerIsLoggedInForFirstTime = false;
                        parsedU.state = true;
                        parsedU.stateCode = 1;
                        if (st.savedUserObj && st.savedUserObj.id) {
                          parsedU.id = st.savedUserObj.id;
                          parsedU.alternativeCustomerId = st.savedUserObj.alternativeCustomerId || st.savedUserObj.id;
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

            // هـ) محافظت از window.fetch
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

                if (init && typeof init.body === 'string' && urlStr.indexOf('okala.com') !== -1) {
                  init = Object.assign({}, init, {
                    body: sanitizeOutgoingJsonBody(urlStr, init.body)
                  });
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
                    if (isAddOrEditAddressUrl(urlStr) && status >= 400) {
                      return new Response(buildAddAddressSuccessResponse(), {
                        status: 200,
                        statusText: 'OK',
                        headers: { 'Content-Type': 'application/json; charset=utf-8' }
                      });
                    }

                    if (isBffUrl(urlStr) && status >= 400) {
                      // اگر BFF به خاطر کوکی خطای 401/500 داد، یک بار بدون کوکی اجرا شود تا لیست فروشگاه‌ها و اسلایدرها کامل دریافت شود و آدرس کاربر در آن ادغام گردد
                      return origFetch.call(window, urlStr, { credentials: 'omit' }).then(function(pubResp) {
                        return pubResp.text().then(function(pubTxt) {
                          return new Response(repairBffResponseText(pubTxt), {
                            status: 200,
                            statusText: 'OK',
                            headers: { 'Content-Type': 'application/json; charset=utf-8' }
                          });
                        });
                      }).catch(function() {
                        return new Response(buildFallbackApiResponse(urlStr), {
                          status: 200,
                          statusText: 'OK',
                          headers: { 'Content-Type': 'application/json; charset=utf-8' }
                        });
                      });
                    }

                    if (status === 401 || status === 403 || (isTokenRefreshUrl(urlStr) && status >= 400)) {
                      return new Response(buildFallbackApiResponse(urlStr), {
                        status: 200,
                        statusText: 'OK',
                        headers: { 'Content-Type': 'application/json; charset=utf-8' }
                      });
                    }

                    if (isBffUrl(urlStr)) {
                      var bffClone = response.clone();
                      return bffClone.text().then(function(txt) {
                        try {
                          var checkParsed = JSON.parse(txt);
                          var missStores = urlStr.indexOf('stores') !== -1 &&
                            (!checkParsed || !checkParsed.data || !checkParsed.data.stores);
                          if (missStores) {
                            return origFetch.call(window, urlStr, { credentials: 'omit' }).then(function(pubResp) {
                              return pubResp.text().then(function(pubTxt) {
                                return new Response(repairBffResponseText(pubTxt), {
                                  status: 200,
                                  statusText: 'OK',
                                  headers: { 'Content-Type': 'application/json; charset=utf-8' }
                                });
                              });
                            }).catch(function() {
                              return new Response(repairBffResponseText(txt), {
                                status: 200,
                                statusText: 'OK',
                                headers: response.headers
                              });
                            });
                          }
                        } catch (_) {}
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
                        if (isAddOrEditAddressUrl(urlStr) && txt && (txt.indexOf('"hasValidationError":true') !== -1 || txt.indexOf('"success":false') !== -1)) {
                          return new Response(buildAddAddressSuccessResponse(), {
                            status: 200,
                            statusText: 'OK',
                            headers: response.headers
                          });
                        }
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
                  if (curTMs && (isTokenRefreshUrl(urlStr) || isBffUrl(urlStr) || isAddOrEditAddressUrl(urlStr))) {
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
                        if (realStatus === 401 || realStatus === 403 ||
                            ((isTokenRefreshUrl(self.__nxUrl) || isLogoutUrl(self.__nxUrl) || isAddOrEditAddressUrl(self.__nxUrl)) && realStatus >= 400)) {
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
                        if (realStatus === 401 || realStatus === 403 ||
                            ((isTokenRefreshUrl(self.__nxUrl) || isLogoutUrl(self.__nxUrl) || isAddOrEditAddressUrl(self.__nxUrl)) && realStatus >= 400)) {
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
                        if (isLogoutUrl(self.__nxUrl) || realStatus === 401 || realStatus === 403 ||
                            ((isTokenRefreshUrl(self.__nxUrl) || isAddOrEditAddressUrl(self.__nxUrl)) && realStatus >= 400)) {
                          return buildFallbackApiResponse(self.__nxUrl);
                        }
                        var rawTxt = '';
                        try {
                          rawTxt = responseTextProtoDesc.get.call(self);
                        } catch (_) {
                          return '';
                        }
                        if (isAddOrEditAddressUrl(self.__nxUrl)) {
                          if (!rawTxt || rawTxt.indexOf('"hasValidationError":true') !== -1 || rawTxt.indexOf('"success":false') !== -1) {
                            return buildAddAddressSuccessResponse();
                          }
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
                            var itemsArr = addrObj && addrObj.data && addrObj.data.customerAddressResponseItems;
                            if (Array.isArray(itemsArr) && itemsArr.length > 0) {
                              var normAddr = normalizeAddressResponseObject(addrObj);
                              if (normAddr) {
                                syncAddressToSessionStorage(normAddr);
                                return JSON.stringify(normAddr);
                              }
                            } else if (window.__nxState && window.__nxState.cachedAddressResp) {
                              return JSON.stringify(window.__nxState.cachedAddressResp);
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
                        if (isLogoutUrl(self.__nxUrl) || realStatus === 401 || realStatus === 403 ||
                            ((isTokenRefreshUrl(self.__nxUrl) || isAddOrEditAddressUrl(self.__nxUrl)) && realStatus >= 400)) {
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
                        if (isAddOrEditAddressUrl(self.__nxUrl)) {
                          var isErr = false;
                          if (typeof rawResp === 'string') {
                            isErr = rawResp.indexOf('"hasValidationError":true') !== -1 || rawResp.indexOf('"success":false') !== -1;
                          } else if (rawResp && typeof rawResp === 'object') {
                            isErr = Boolean(rawResp.hasValidationError === true || rawResp.success === false);
                          }
                          if (isErr || !rawResp) {
                            var addOkStr = buildAddAddressSuccessResponse();
                            if (self.responseType === 'json') {
                              try { return JSON.parse(addOkStr); } catch (_) { return addOkStr; }
                            }
                            return addOkStr;
                          }
                        }
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
                              var aItems = aObj && aObj.data && aObj.data.customerAddressResponseItems;
                              if (Array.isArray(aItems) && aItems.length > 0) {
                                var nAddr = normalizeAddressResponseObject(aObj);
                                if (nAddr) {
                                  syncAddressToSessionStorage(nAddr);
                                  return JSON.stringify(nAddr);
                                }
                              } else if (window.__nxState && window.__nxState.cachedAddressResp) {
                                return JSON.stringify(window.__nxState.cachedAddressResp);
                              }
                            } catch (_) {}
                          } else if (rawResp && typeof rawResp === 'object') {
                            var rItems = rawResp.data && rawResp.data.customerAddressResponseItems;
                            if (Array.isArray(rItems) && rItems.length > 0) {
                              var nAddrObj = normalizeAddressResponseObject(rawResp);
                              if (nAddrObj) {
                                syncAddressToSessionStorage(nAddrObj);
                                return nAddrObj;
                              }
                            } else if (window.__nxState && window.__nxState.cachedAddressResp) {
                              return window.__nxState.cachedAddressResp;
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

  /// ساخت صفحه بوت‌استرپ فوری روی دامنه https://www.okala.com برای پاکسازی صددرصدی اکانت قبلی و تزریق اکانت جدید قبل از اجرای Next.js
  String _buildBootstrapHtml(String injectionScript) {
    return '''<!DOCTYPE html>
<html lang="fa" dir="rtl">
<head>
  <meta charset="utf-8">
  <meta name="viewport" content="width=device-width, initial-scale=1.0">
  <style>body { background-color: #12141D; margin: 0; }</style>
  <script>
    $injectionScript
    window.location.replace("$storeUrl");
  </script>
</head>
<body></body>
</html>''';
  }

  Future<Map<String, dynamic>> _resolveAccountPayload(
      int index, int currentGen) async {
    final String target = _urls[index];
    if (NexusAccountRegistry.instance.isLocalUri(target)) {
      final Map<String, dynamic>? localData =
          NexusAccountRegistry.instance.getAccountData(target);
      if (localData == null) {
        throw Exception('اطلاعات این اکانت ZIP در حافظه یافت نشد.');
      }
      return localData;
    }

    final http.Response response = await _httpClient
        .get(Uri.parse(target))
        .timeout(const Duration(seconds: 15));

    if (response.statusCode != 200) {
      throw Exception('پاسخ نامعتبر از سرور (کد ${response.statusCode})');
    }

    final Uint8List bodyBytes = response.bodyBytes;
    // اگر لینک واردشده مستقیماً یک فایل ZIP بود، تمام اکانت‌های داخل آن استخراج و جایگزین شوند
    if (NexusZipExtractor.isZipBytes(bodyBytes)) {
      final ZipExtractionSummary summary =
          NexusZipExtractor.extractFromFileBytes(
        fileName: target.split('/').last,
        bytes: bodyBytes,
      );
      if (summary.accountUris.isNotEmpty) {
        if (mounted && currentGen == _sessionGeneration) {
          setState(() {
            _urls.removeAt(index);
            _urls.insertAll(index, summary.accountUris);
          });
        }
        final Map<String, dynamic>? firstAcc = NexusAccountRegistry.instance
            .getAccountData(summary.accountUris.first);
        if (firstAcc != null) return firstAcc;
      }
      throw Exception('فایل ZIP دانلودشده فاقد اکانت معتبر بود.');
    }

    final dynamic decoded = json.decode(utf8.decode(bodyBytes));
    if (decoded is! Map<String, dynamic>) {
      throw Exception('ساختار داده دریافتی معتبر نیست.');
    }
    return decoded;
  }

  Future<void> _loadAccount(int index) async {
    if (!mounted || index < 0 || index >= _urls.length) return;
    _sessionGeneration++;
    _globalSessionCounter++;
    final int currentGen = _sessionGeneration;
    final String currentTargetUri = _urls[index];
    final String currentLabel =
        NexusAccountRegistry.instance.getLabel(currentTargetUri, index);
    final String targetKey =
        '__nx_acc_${index}_${currentGen}_${_globalSessionCounter}_${DateTime.now().microsecondsSinceEpoch}';

    setState(() {
      _isLoading = true;
      _hasError = false;
      _progress = 0.1;
      _loadingMessage = 'در حال آماده‌سازی $currentLabel...';
      _currentIndex = index;
    });

    try {
      if (_webViewController != null) {
        await _webViewController!.stopLoading();
        await _webViewController!.removeAllUserScripts();
      }

      // ۱. پاکسازی کامل کش دیسک، کوکی‌ها و WebStorage قبلی و دریافت اطلاعات اکانت به صورت موازی
      final CookieManager cookieManager = CookieManager.instance();
      final WebStorageManager webStorageManager = WebStorageManager.instance();

      final results = await Future.wait([
        cookieManager.deleteAllCookies(),
        webStorageManager.deleteAllData(),
        InAppWebViewController.clearAllCache(includeDiskFiles: true),
        _resolveAccountPayload(index, currentGen),
      ]);

      if (!mounted || currentGen != _sessionGeneration) return;

      final Map<String, dynamic> data = results[3] as Map<String, dynamic>;
      final String resolvedTargetUri = _urls[_currentIndex];

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
      final List<String> refreshCandidates = [];

      if (data['access_token'] is String &&
          (data['access_token'] as String).isNotEmpty) {
        tokenCandidates.add(data['access_token'] as String);
      }
      if (data['refresh_token'] is String &&
          (data['refresh_token'] as String).isNotEmpty) {
        rTk = data['refresh_token'] as String;
        refreshCandidates.add(rTk);
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
          } else if (name == 'refresh_token') {
            rTk ??= val;
            if (!refreshCandidates.contains(val)) refreshCandidates.add(val);
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
          } else if (name == 'refresh_token') {
            rTk ??= val;
            if (!refreshCandidates.contains(val)) refreshCandidates.add(val);
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

      // استخراج اولیه شناسه و شماره موبایل اکانت جهت بازیابی توکن‌های چرخش‌یافته قبلی از NexusTokenVault
      String? initialPhone = NexusZipExtractor.extractPhoneFromAccountData(
          data, resolvedTargetUri);
      String? initialUid;
      String? initialCerbId;
      for (final String cand in tokenCandidates) {
        final Map<String, dynamic> p = _decodeJwtPayload(cand);
        initialUid ??= (p['userId'] ?? p['sub'])?.toString();
        initialCerbId ??= p['cerberusId']?.toString();
        initialPhone ??=
            (p['mobilePhone'] ?? p['username'] ?? p['userName'])?.toString();
      }

      final Map<String, String>? vaulted = NexusTokenVault.instance.lookup(
        phone: initialPhone,
        userId: initialUid,
        cerberusId: initialCerbId,
        targetUri: resolvedTargetUri,
      );
      if (vaulted != null) {
        final String? vAcc = vaulted['accessToken'];
        final String? vRef = vaulted['refreshToken'];
        if (vAcc != null && vAcc.isNotEmpty) {
          tokenCandidates.insert(0, vAcc);
        }
        if (vRef != null && vRef.isNotEmpty) {
          refreshCandidates.insert(0, vRef);
          rTk = vRef;
        }
      }

      // انتخاب بهترین Access Token (دارای کلیم‌های Voyager و بیشترین زمان انقضا exp)
      String? origBestToken;
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
          origBestToken ??= cand;
        }
      }

      // اطمینان از معتبر بودن Access Token و ذخیره فوری Refresh Token چرخش‌یافته برای اکانت‌های ZIP و لینک
      final _TokenPairResult tokenResult =
          await _ensureValidAccessToken(tMs, refreshCandidates);
      if (!mounted || currentGen != _sessionGeneration) return;

      final String? oldTMs = tMs;
      final String? oldRTk = rTk;
      tMs = tokenResult.accessToken;
      rTk = tokenResult.refreshToken ?? rTk;

      // استخراج آبجکت اولیه user
      Map<String, dynamic> cleanUserMap = {};
      bool wasRawState = false;
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
            if (cleanUserMap['state'] == false ||
                cleanUserMap['customerIsLoggedInForFirstTime'] == true) {
              wasRawState = true;
            }
          }
        } catch (_) {}
      }

      _normalizeUserMap(cleanUserMap, tMs);

      final String resolvedPhone =
          (cleanUserMap['mobilePhone'] ?? initialPhone ?? '').toString().trim();
      final String resolvedUid =
          (cleanUserMap['id'] ?? initialUid ?? '').toString().trim();
      final String resolvedCerb =
          (cleanUserMap['alternativeId'] ?? initialCerbId ?? '')
              .toString()
              .trim();

      _activeAccountPhone = resolvedPhone;
      _activeAccountUserId = resolvedUid;
      _activeAccountCerberusId = resolvedCerb;

      if (resolvedPhone.isNotEmpty) {
        NexusAccountRegistry.instance
            .setLabel(resolvedTargetUri, resolvedPhone);
      }

      // ذخیره توکن نوسازی‌شده در NexusTokenVault و رجیستری اکانت‌های ZIP
      if (tokenResult.wasRefreshed ||
          (tMs != null && tMs.isNotEmpty) ||
          (rTk != null && rTk.isNotEmpty)) {
        await NexusTokenVault.instance.save(
          phone: resolvedPhone,
          userId: resolvedUid,
          cerberusId: resolvedCerb,
          targetUri: resolvedTargetUri,
          accessToken: tMs,
          refreshToken: rTk,
        );
        if (NexusAccountRegistry.instance.isLocalUri(resolvedTargetUri)) {
          final Map<String, dynamic> updatedAccData =
              _updateTokensInAccountData(data, oldTMs, tMs, oldRTk, rTk);
          NexusAccountRegistry.instance
              .updateAccountData(resolvedTargetUri, updatedAccData);
        }
      }

      // فعال‌سازی پروفایل در Voyager (UpdateCustomer) و دریافت همزمان آدرس‌های ثبت‌شده کاربر
      final int initialCid = _parsePositiveInt(
          cleanUserMap['id'] ?? cleanUserMap['alternativeCustomerId']);

      final profileAndAddr = await Future.wait([
        _ensureCustomerProfileInVoyager(tMs, cleanUserMap, wasRawState),
        _fetchUserAddressesFromApi(tMs, initialCid),
      ]);
      if (!mounted || currentGen != _sessionGeneration) return;

      final Map<String, dynamic>? initialAddressResponse =
          profileAndAddr[1] as Map<String, dynamic>?;

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
        if (name == 'refresh_token' || name == 'user') continue;
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

      // ۴. آماده‌سازی اسکریپت تزریق و صفحه بوت‌استرپ
      final String script = _buildFastInjectionScript(
        targetKey: targetKey,
        localData: normalizedLocalData,
        tokenMs: tMs,
        refreshToken: rTk,
        userCookieValue: normalizedUserCookie,
        userPlainJson: normalizedUserPlainJson,
        zustandUserJson: zustandUserJson,
        initialAddressResponse: initialAddressResponse,
      );

      _activeInjectionScript = script;
      _activeBootstrapHtml = _buildBootstrapHtml(script);
      _activeTargetKey = targetKey;

      setState(() {
        _loadingMessage = 'در حال ورود به فروشگاه...';
        _progress = 0.4;
      });

      if (_webViewController != null) {
        await _webViewController!.removeAllUserScripts();
        await _webViewController!.addUserScript(
          userScript: UserScript(
            source: _activeInjectionScript,
            injectionTime: UserScriptInjectionTime.AT_DOCUMENT_START,
          ),
        );
        await _webViewController!.loadData(
          data: _activeBootstrapHtml,
          mimeType: 'text/html',
          encoding: 'utf-8',
          baseUrl: WebUri('https://$storeHost/'),
          historyUrl: WebUri('https://$storeHost/'),
        );
      }
    } on TimeoutException {
      if (!mounted || currentGen != _sessionGeneration) return;
      setState(() {
        _hasError = true;
        _loadingMessage =
            'مهلت اتصال به سرور به پایان رسید. اینترنت خود را بررسی کنید.';
      });
    } catch (e) {
      if (!mounted || currentGen != _sessionGeneration) return;
      setState(() {
        _hasError = true;
        _loadingMessage = 'خطا در بارگذاری حساب: $e';
      });
    }
  }

  void _nextAccount() {
    if (_currentIndex < _urls.length - 1) {
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

  void _showAddMoreZipModal() {
    showModalBottomSheet(
      context: context,
      backgroundColor: surfaceDark,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(22)),
      ),
      builder: (sheetCtx) {
        return Padding(
          padding: const EdgeInsets.fromLTRB(20, 20, 20, 28),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Text(
                'افزودن فایل ZIP / JSON جدید به لیست فعلی',
                textAlign: TextAlign.center,
                textDirection: TextDirection.rtl,
                style: TextStyle(
                  color: textPrimary,
                  fontSize: 15.5,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 16),
              NexusFilePickerButton(
                onFilesExtracted: (summaries) {
                  int added = 0;
                  int firstNewIdx = _urls.length;
                  setState(() {
                    for (final ZipExtractionSummary s in summaries) {
                      for (final String u in s.accountUris) {
                        if (!_urls.contains(u)) {
                          _urls.add(u);
                          added++;
                        }
                      }
                      for (final String l in s.extractedLinks) {
                        if (!_urls.contains(l)) {
                          _urls.add(l);
                          added++;
                        }
                      }
                    }
                  });
                  if (Navigator.canPop(sheetCtx)) {
                    Navigator.pop(sheetCtx);
                  }
                  if (mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text(
                          added > 0
                              ? '$added حساب جدید از فایل ZIP اضافه شد.'
                              : 'اکانت جدیدی یافت نشد (یا قبلاً در لیست موجود است).',
                          textDirection: TextDirection.rtl,
                          style: const TextStyle(
                              color: bgDark, fontWeight: FontWeight.bold),
                        ),
                        backgroundColor:
                            added > 0 ? primaryAccent : Colors.orangeAccent,
                        behavior: SnackBarBehavior.floating,
                      ),
                    );
                    if (added > 0 && firstNewIdx < _urls.length) {
                      _loadAccount(firstNewIdx);
                    }
                  }
                },
              ),
            ],
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final String activeUri =
        (_currentIndex >= 0 && _currentIndex < _urls.length)
            ? _urls[_currentIndex]
            : '';
    final String activeLabel =
        NexusAccountRegistry.instance.getLabel(activeUri, _currentIndex);
    final bool hasCustomPhoneLabel =
        !activeLabel.startsWith('حساب کاربری ');

    return PopScope(
      canPop: false,
      onPopInvoked: (didPop) async {
        if (didPop) return;
        if (_webViewController != null &&
            await _webViewController!.canGoBack()) {
          await _webViewController!.goBack();
        } else if (context.mounted) {
          Navigator.of(context).pop();
        }
      },
      child: Scaffold(
        backgroundColor: bgDark,
        appBar: AppBar(
          title: Text(
            hasCustomPhoneLabel
                ? 'حساب ${_currentIndex + 1} از ${_urls.length} ($activeLabel)'
                : 'حساب ${_currentIndex + 1} از ${_urls.length}',
            style: const TextStyle(
              fontSize: 14,
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
              tooltip: 'افزودن فایل ZIP جدید',
              onPressed: _showAddMoreZipModal,
              icon: const Icon(Icons.folder_zip_outlined,
                  size: 21, color: primaryAccent),
            ),
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
            if (_currentIndex < _urls.length - 1)
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
                padding: const EdgeInsets.only(top: 56, bottom: 20),
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
                        '${_urls.length} حساب فعال (لینک و ZIP)',
                        textDirection: TextDirection.rtl,
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
              Padding(
                padding:
                    const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                child: OutlinedButton.icon(
                  style: OutlinedButton.styleFrom(
                    foregroundColor: primaryAccent,
                    side: BorderSide(color: primaryAccent.withOpacity(0.5)),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  onPressed: () {
                    Navigator.pop(context);
                    _showAddMoreZipModal();
                  },
                  icon: const Icon(Icons.folder_zip_rounded, size: 18),
                  label: const Text(
                    'افزودن فایل ZIP جدید',
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                  ),
                ),
              ),
              Expanded(
                child: ListView.separated(
                  itemCount: _urls.length,
                  separatorBuilder: (context, index) =>
                      Divider(color: bgDark.withOpacity(0.5), height: 1),
                  itemBuilder: (context, index) {
                    final bool isActive = index == _currentIndex;
                    final String itemUri = _urls[index];
                    final bool isZipItem =
                        NexusAccountRegistry.instance.isLocalUri(itemUri);
                    final String label = NexusAccountRegistry.instance
                        .getLabel(itemUri, index);
                    final String? srcFile = NexusAccountRegistry.instance
                        .getSourceName(itemUri);

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
                        label.startsWith('حساب کاربری ')
                            ? label
                            : 'حساب ${index + 1} — $label',
                        style: TextStyle(
                          color: isActive ? textPrimary : textSecondary,
                          fontWeight:
                              isActive ? FontWeight.bold : FontWeight.normal,
                          fontSize: 13.5,
                        ),
                      ),
                      subtitle: srcFile != null
                          ? Text(
                              '📦 $srcFile',
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                color: textSecondary.withOpacity(0.7),
                                fontSize: 11,
                              ),
                            )
                          : null,
                      trailing: Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 7, vertical: 2),
                        decoration: BoxDecoration(
                          color: (isZipItem ? primaryAccent : Colors.blueAccent)
                              .withOpacity(0.15),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text(
                          isZipItem ? 'ZIP' : 'LINK',
                          style: TextStyle(
                            color:
                                isZipItem ? primaryAccent : Colors.blueAccent,
                            fontSize: 10,
                            fontWeight: FontWeight.bold,
                          ),
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
                databaseEnabled: false,
                cacheEnabled: false,
                cacheMode: CacheMode.LOAD_NO_CACHE,
                clearCache: true,
                clearSessionCache: true,
                thirdPartyCookiesEnabled: true,
                sharedCookiesEnabled: true,
                useShouldOverrideUrlLoading: true,
                userAgent: customUserAgent,
                useHybridComposition: true,
                supportZoom: false,
                mediaPlaybackRequiresUserGesture: true,
                allowsBackForwardNavigationGestures: false,
              ),
              onWebViewCreated: (controller) async {
                _webViewController = controller;
                controller.addJavaScriptHandler(
                  handlerName: 'onTokenRefreshed',
                  callback: (args) async {
                    if (args.isNotEmpty && args.first is Map) {
                      final Map data = args.first as Map;
                      final String? newAcc = data['accessToken']?.toString();
                      final String? newRef = data['refreshToken']?.toString();
                      final String curUri = (_currentIndex >= 0 &&
                              _currentIndex < _urls.length)
                          ? _urls[_currentIndex]
                          : '';
                      await NexusTokenVault.instance.save(
                        phone: _activeAccountPhone,
                        userId: _activeAccountUserId,
                        cerberusId: _activeAccountCerberusId,
                        targetUri: curUri,
                        accessToken: newAcc,
                        refreshToken: newRef,
                      );
                    }
                  },
                );
                if (_activeInjectionScript.isNotEmpty &&
                    _activeBootstrapHtml.isNotEmpty) {
                  await controller.addUserScript(
                    userScript: UserScript(
                      source: _activeInjectionScript,
                      injectionTime: UserScriptInjectionTime.AT_DOCUMENT_START,
                    ),
                  );
                  await controller.loadData(
                    data: _activeBootstrapHtml,
                    mimeType: 'text/html',
                    encoding: 'utf-8',
                    baseUrl: WebUri('https://$storeHost/'),
                    historyUrl: WebUri('https://$storeHost/'),
                  );
                }
              },
              shouldOverrideUrlLoading: (controller, navigationAction) async {
                final WebUri? uri = navigationAction.request.url;
                if (uri != null) {
                  final String path = uri.path.toLowerCase();
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
              onProgressChanged: (controller, progress) {
                if (!mounted) return;
                setState(() {
                  _progress = progress / 100.0;
                });
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
                  if (_activeInjectionScript.isNotEmpty &&
                      _activeTargetKey.isNotEmpty) {
                    final dynamic injected =
                        await controller.evaluateJavascript(
                      source:
                          "localStorage.getItem('__nx_active_key') === '$_activeTargetKey' ? '1' : '0'",
                    );
                    if (injected?.toString() != '1') {
                      await controller.evaluateJavascript(
                          source: _activeInjectionScript);
                      await controller.loadUrl(
                        urlRequest: URLRequest(url: WebUri(storeUrl)),
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
