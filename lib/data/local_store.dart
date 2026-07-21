import 'dart:convert';

import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:hive_flutter/hive_flutter.dart';

/// 로컬 저장소 초기화 및 Hive 박스 접근 지점.
///
/// 기획서의 "전면 로컬 저장 / 백엔드 서버 없음" 원칙에 따라 모든 학습
/// 데이터는 기기 내부에만 저장된다. 모델은 build_runner 의존을 피하기 위해
/// TypeAdapter 대신 `Map` 직렬화 형태로 박스에 보관한다.
///
/// 모든 박스는 AES로 암호화되며, 32바이트 키는 iOS Keychain / Android
/// Keystore(flutter_secure_storage)에 보관해 앱 샌드박스 밖으로 나가지
/// 않는다. iOS Data Protection(NSFileProtectionComplete)이 파일 자체를
/// 한 번 더 감싸므로, 기기 잠금 상태에서는 디스크의 학습 데이터가 평문으로
/// 남지 않는다.
class LocalStore {
  LocalStore._();

  static const String lecturesBox = 'lectures';
  static const String unitsBox = 'units';
  static const String reviewsBox = 'reviews';
  static const String timetableBox = 'timetable';
  static const String settingsBox = 'settings'; // 데모 오프셋 등 앱 설정

  static const String _keyName = 'hive_encryption_key';
  static const _secure = FlutterSecureStorage();

  static bool _initialized = false;

  /// 앱 시작 시 한 번 호출. Hive를 초기화하고 암호화된 박스를 연다.
  static Future<void> init() async {
    if (_initialized) return;
    await Hive.initFlutter();
    // 웹은 Keychain/Keystore가 없고 IndexedDB가 오리진 단위로 격리되므로
    // flutter_secure_storage 기반 암호화를 쓰지 않는다(웹 부팅 시 예외 방지).
    final cipher = kIsWeb ? null : HiveAesCipher(await _encryptionKey());
    await Future.wait([
      Hive.openBox<Map>(lecturesBox, encryptionCipher: cipher),
      Hive.openBox<Map>(unitsBox, encryptionCipher: cipher),
      Hive.openBox<Map>(reviewsBox, encryptionCipher: cipher),
      Hive.openBox<Map>(timetableBox, encryptionCipher: cipher),
      Hive.openBox(settingsBox, encryptionCipher: cipher),
    ]);
    _initialized = true;
  }

  /// AES 키를 보안 저장소에서 읽어오고, 없으면 새로 생성해 저장한다.
  /// ponytail: 키 유실 시(예: 앱 재설치) 기존 암호문은 복호화 불가 —
  /// 로컬 전용/데모 앱이라 허용. 클라우드 백업/복구가 필요해지면 키 에스크로 추가.
  static Future<List<int>> _encryptionKey() async {
    final existing = await _secure.read(key: _keyName);
    if (existing != null) return base64Url.decode(existing);
    final key = Hive.generateSecureKey();
    await _secure.write(key: _keyName, value: base64Url.encode(key));
    return key;
  }

  static Box<Map> box(String name) => Hive.box<Map>(name);

  /// 앱 설정 박스(데모 오프셋 등). 값 타입이 자유로워 제네릭 없이 연다.
  /// 데이터 초기화([clearAll])의 대상이 아니다 — 데모 설정은 유지된다.
  static Box settings() => Hive.box(settingsBox);

  /// 모든 학습 데이터를 비운다(초기화). 파일 삭제는 별도로 처리한다.
  static Future<void> clearAll() async {
    await Future.wait([
      box(lecturesBox).clear(),
      box(unitsBox).clear(),
      box(reviewsBox).clear(),
      box(timetableBox).clear(),
    ]);
  }
}
