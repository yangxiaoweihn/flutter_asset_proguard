import 'package:args/args.dart';
import 'package:flutter_asset_proguard/assets_executor.dart';
import 'package:flutter_asset_proguard/config.dart';
import 'package:flutter_asset_proguard/logger.dart';

void main(List<String> args) {
  print('assets_encrypt_bin.dart -> $args');
  final ArgParser parser = ArgParser();
  parser.addFlag(
    'watch',
    abbr: 'w',
    defaultsTo: null,
    help: 'Continue to monitor changes after execution of orders.',
  );
  final String defaultDirName = Config.defaultOutput;
  parser.addOption(
    'output',
    abbr: 'o',
    help: 'The save directory for encrypted assets. \n'
        "It's a relative path, the relative flutter root directory.\n"
        "If you don't specify it, the default path is $defaultDirName.\n",
  );
  parser.addOption(
    'src',
    abbr: 's',
    defaultsTo: '.',
    help: 'Flutter project root path',
  );

  parser.addFlag(
    'help',
    abbr: 'h',
    help: 'Help usage',
    defaultsTo: false,
    negatable: false,
  );

  parser.addFlag(
    'debug',
    abbr: 'd',
    help: 'debug info',
    defaultsTo: false,
    negatable: false,
  );

  parser.addOption(
    'config_file',
    abbr: null,
    help: 'The config file path, default is ${Config.defaultConfigFile}',
    defaultsTo: null,
  );

  parser.addFlag(
    'dbg_pubspec',
    abbr: null,
    help: '',
    defaultsTo: false,
  );

  final ArgResults results = parser.parse(args);

  Logger().isDebug = results['debug'] as bool;

  if (results.wasParsed('help')) {
    print(parser.usage);
    return;
  }

  final Map<String, Option> options = parser.options;
  final Map<String, dynamic> params = options.map((String key, Option o) {
    return MapEntry<String, dynamic>(key, results[key]);
  });

  final Config config = Config(params: params)..refresh();

  logger.debug('assets_encrypt_bin.dart -> The config is: $config');

  final AssetsExecutor builder = AssetsExecutor(config);
  builder.collectAssetsAndEncrypt();
}
