import 'package:flutter/foundation.dart' show kIsWeb;

import 'web_env.dart';

/// 시험 운영 기간에만 켜요: 기록을 올릴 때 기기 종류도 같이 올려 관리자 '사용자 관리'에 보여요.
/// 정식 출시 때 false로 바꾸고, 개인정보처리방침(web/privacy.html) '기기 종류' 줄도 지워요.
/// (서버 규칙은 device가 없어도 받아 주므로 그대로 둬도 돼요)
const collectDeviceKind = true;

/// 기기 종류 (서버 members 문서의 `device`)
enum DeviceKind {
  android('android', '안드로이드'),
  iphone('iphone', '아이폰'),
  web('web', '웹');

  const DeviceKind(this.code, this.label);

  final String code;
  final String label;

  /// 이 기기: 안드로이드 앱, 아이폰·아이패드 웹앱, 그 밖의 웹
  static DeviceKind get current => !kIsWeb
      ? android
      : isAppleDevice
      ? iphone
      : web;

  /// 모르는 값·없는 값은 null (예전 앱이 올린 문서)
  static DeviceKind? fromCode(Object? code) {
    for (final k in values) {
      if (k.code == code) return k;
    }
    return null;
  }
}
