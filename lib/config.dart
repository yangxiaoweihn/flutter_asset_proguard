import 'dart:io';

import 'package:flutter_asset_collector/filter.dart';
import 'package:path/path.dart';
import 'package:yaml/yaml.dart';

/// config_file= priority low
class Config {
  Config({
    this.type = 'default',
    required this.params,
  });

  // factory Config.fromArgResults(ArgResults results) {
  //   final Config config = Config(params: {});
  //   config.refresh();
  //   return config;
  // }

  static const String defaultOutput = 'fap_xxx';
  static const String defaultConfigFile = 'cfg_assets_proguard.yaml';
  static const String defaultOutputMapperFile = 'proguard_mapper.json';

  final String type;
  final Map<String, dynamic> params;
  late String src;
  late String output;

  late String? outputMapperFilePath;

  late bool isWatch;
  late YamlMap? configFileOptions;
  late String configFilePath;
  List<String>? inputRFiles;

  late bool dbgPubspec;

  Filter? filter;

  void refresh() {
    String src = params['src'] as String? ?? '.';

    src = absolute(src);
    src = normalize(src);

    final String? cfgFile = params['config_file'];
    configFilePath =
        join(src, (cfgFile?.isEmpty ?? true) ? defaultConfigFile : cfgFile!);
    final File configFile = File(configFilePath);

    String? outputDirName;
    String? outputMapperFile;
    List<String>? inputRFiles;
    bool? watch;
    bool? dbgPubspec;

    YamlMap? yamlMap;
    if (configFile.existsSync()) {
      final String configFileText = configFile.readAsStringSync();
      filter = Filter(configFileText);
      yamlMap = loadYaml(configFileText) as YamlMap?;

      if (yamlMap != null) {
        outputDirName ??= yamlMap['output'] as String?;
        watch = yamlMap['watch'] as bool? ?? false;

        outputMapperFile = yamlMap['output_mapper_file'] as String?;
        inputRFiles = (yamlMap['input_r_files'] as YamlList?)?.cast();

        dbgPubspec = yamlMap['dbg_pubspec'] as bool?;
      }
    }

    outputDirName = params['output'] as String? ?? outputDirName;
    watch = params['watch'] as bool? ?? watch;
    outputMapperFile =
        params['output_mapper_file'] as String? ?? outputMapperFile;

    inputRFiles = (params['input_r_files'] as YamlList?)?.cast() ?? inputRFiles;

    dbgPubspec = params['dbg_pubspec'] as bool? ?? dbgPubspec;

    final YamlList? include = params['include'] as YamlList?;
    final YamlList? exclude = params['exclude'] as YamlList?;
    if (null != include || null != exclude) {
      filter = Filter.create();
      filter!.replace(include: include, exclude: exclude);
    }

    this.src = src;
    output = outputDirName ?? defaultOutput;
    isWatch = watch ?? true;
    configFileOptions = yamlMap;
    outputMapperFilePath =
        join(src, outputMapperFile ?? defaultOutputMapperFile);

    this.dbgPubspec = dbgPubspec ?? false;

    if (null != inputRFiles) {
      this.inputRFiles = inputRFiles.map((String f) {
        return join(src, f);
      }).toList();
    }
  }

  @override
  String toString() {
    return 'Config{'
        'src: $src, output: $output, isWatch: $isWatch , config_file: $configFilePath , '
        'outputMapperFilePath: $outputMapperFilePath , inputRFiles: $inputRFiles , dbg_pubspec=$dbgPubspec'
        '}';
  }
}
