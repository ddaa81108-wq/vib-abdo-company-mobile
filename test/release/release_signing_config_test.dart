import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('release signing reads env or key.properties, never inline values', () {
    final gradle = File('android/app/build.gradle.kts').readAsStringSync();
    for (final name in [
      'ANDROID_KEY_PROPERTIES',
      'ANDROID_KEYSTORE_PATH',
      'ANDROID_KEYSTORE_PASSWORD',
      'ANDROID_KEY_ALIAS',
      'ANDROID_KEY_PASSWORD',
      'ANDROID_REQUIRE_RELEASE_SIGNING',
      'requireReleaseSigning',
    ]) {
      expect(gradle, contains(name));
    }
    expect(gradle, contains('namespace = "com.vip2100.vib"'));
    expect(gradle, isNot(contains('com.example')));
    expect(RegExp(r'storePassword\s*=\s*"').hasMatch(gradle), isFalse);
    expect(RegExp(r'keyPassword\s*=\s*"').hasMatch(gradle), isFalse);
  });

  test('signing material is git-ignored and only the example is tracked', () {
    final root = File('.gitignore').readAsLinesSync();
    expect(root, containsAll(['*.jks', '*.keystore', '*.p12', 'key.properties']));
    final android = File('android/.gitignore').readAsLinesSync();
    expect(
      android,
      containsAll(['key.properties', '**/*.jks', '**/*.keystore', '**/*.p12']),
    );
    final example = File('android/key.properties.example').readAsStringSync();
    expect(example, contains('storePassword=CHANGE_ME'));
    expect(example, contains('keyPassword=CHANGE_ME'));
  });

  test('MainActivity lives in the release package', () {
    final activity = File(
      'android/app/src/main/kotlin/com/vip2100/vib/MainActivity.kt',
    ).readAsStringSync();
    expect(activity, startsWith('package com.vip2100.vib\n'));
  });
}
