import 'dart:convert';

import 'package:file_picker/file_picker.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// 파일 저장·고르기 (폰의 파일 선택 창). 테스트에서 바꿔 끼울 수 있게 따로 둬요.
class BackupFiles {
  const BackupFiles();

  /// 저장 위치를 골라 저장. 저장했으면 true, 취소하면 false.
  Future<bool> save(String fileName, String text) async {
    final uri = await FilePicker.saveFile(
      fileName: fileName,
      bytes: utf8.encode(text),
      mimeType: 'application/json',
      dialogTitle: '기록 저장하기',
    );
    return uri != null;
  }

  /// 파일을 골라 글자로 읽기. 취소하면 null.
  /// 확장자 거르기는 기기마다 .json을 못 알아보는 경우가 있어 쓰지 않아요(내용으로 확인).
  Future<String?> pick() async {
    final file = await FilePicker.pickFile(dialogTitle: '불러올 기록 파일 고르기');
    return file?.xFile.readAsString();
  }
}

final backupFilesProvider = Provider<BackupFiles>((ref) => const BackupFiles());
