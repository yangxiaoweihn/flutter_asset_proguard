import 'dart:async';
import 'dart:io';

import 'package:build/build.dart';
import 'package:yaml/yaml.dart';

import 'assets_executor.dart';
import 'config.dart';

Builder assetsProguardBuilder(BuilderOptions options) {
  Map<String, dynamic> p = options.config.map((k, v) {
    // print('options: $k -> $v');
    if (v is YamlMap) {
      return MapEntry(k, v.map((k, v) => MapEntry<String, dynamic>(k, v)));
    } else {
      return MapEntry(k, v);
    }
  });

  log.info('asset_proguard: config is=$p');

  return AssetsProguardBuilder(p);
}

const _m = '.dart_tool/generated/.assets_proguard_trigger_cache.dart';

class AssetsProguardBuilder implements Builder {
  /// 做了分类
  final Map<String, dynamic> params;
  late List<AssetsExecutor> builders;

  AssetsProguardBuilder(this.params) {
    builders = params.entries.map((entry) {
      final config = Config(params: entry.value, type: entry.key)..refresh();
      return AssetsExecutor(config);
    }).toList();

    if (builders.isEmpty) {
      log.info('asset_encrypt: params is empty, set a default builder.');
      builders = [
        AssetsExecutor(Config(params: {})..refresh()),
      ];
    }
  }

  static int _buildCount = 0;

  @override
  FutureOr<void> build(BuildStep buildStep) async {
    _buildCount++;
    print('🏗️  build-count: $_buildCount');

    final timestamp = DateTime.now().toIso8601String();
    final buildId = '${_buildCount}_${DateTime.now().millisecondsSinceEpoch}';

    // 生成构建信息
    final output = AssetId(buildStep.inputId.package, _m);

    await buildStep.writeAsString(output, '''
// GENERATED - Build #$_buildCount
// Build ID: $buildId
// Timestamp: $timestamp

class BuildInfo {
  static const int count = $_buildCount;
  static const String id = '$buildId';
  static const String timestamp = '$timestamp';
}
    ''');

    for (final AssetsExecutor builder in builders) {
      final File logFile = AssetsExecutor.getLogFile(builder.config);
      if (logFile.existsSync()) {
        logFile.deleteSync();
      }
    }

    for (final AssetsExecutor builder in builders) {
      builder.collectAssetsAndEncrypt();
    }
    // return Future.delayed(Duration(seconds: 10));
    return Future.value();
  }

  @override
  Map<String, List<String>> get buildExtensions => {
        'pubspec.yaml': [_m],
      };
}
