import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math';

import 'package:flutter_asset_collector/collector.dart';
import 'package:path/path.dart';
import 'package:yaml_edit/yaml_edit.dart';

import '_rename.dart';
import 'config.dart';
import 'logger.dart';

const String _logPrefix = 'Proguard assets records';
const String _libTag = 'asset_proguard_builder';

const List<String> dprs = <String>[
  '1.0x',
  '1.5x',
  '2.0x',
  '3.0x',
  '4.0x',
];

Logger logger = Logger()
  ..isDebug = true
  ..tag = 'AssetsProguard';

class AssetsExecutor {
  // ResourceDartBuilder(String projectRootPath, this.outputPath) {
  AssetsExecutor(this.config);

  final Config config;

  Filter? get filter => config.filter;

  bool get isWatch => config.isWatch;

  final FileWatcher _fileWatcher = FileWatcher();

  late AssetCollector _assetCollector;

  void collectAssetsAndEncrypt() {
    // logger.debug('$_logPrefix for project: $projectRootPath');
    _log('$_logPrefix for project: $projectRootPath');
    _fileWatcher
      ..stopWatch()
      ..clear();

    _log('delete work dir: ${<String>[prp, outputDirName].join(separator)}');
    // _log('delete log: ${logFile.path}');
    try {
      final Directory d =
          Directory(<String>[prp, outputDirName].join(separator));
      if (d.existsSync()) {
        d.deleteSync(recursive: true);
      }
    } catch (e) {
      _log('error: $e');
    }

    _log('config.params= \n${formatJson(config.params)}');
    if (File(config.configFilePath).existsSync()) {
      _log(
        'config file content=\n'
        '------------------------\n'
        '${File(config.configFilePath).readAsStringSync()}\n'
        '------------------------\n',
      );
    }

    try {
      _assetCollector = AssetCollector(
        module: 'proguard',
        projectRootPath: config.src,
        logFile: logFile,
        filter: config.filter,
      )..collect();
      final List<String> allAssetsList = <String>[
        ..._assetCollector.allFileListByFilter
      ];

      _log('The all resources path list is: \n${formatJson(allAssetsList)}');

      _log('start filter resources by [$outputDirName]');

      // 过滤掉已经混淆过的路径
      final List<String> allNeedProguardList = <String>[...allAssetsList]
        ..removeWhere((String test) {
          return test.contains('$outputDirName/');
        });
      _log(
        'The result of filter resources path list is: \n${formatJson(allNeedProguardList)}',
      );

      _log('[ start proguard resources');
      final Iterator<String> nameG = nameGenerator().iterator;
      // relative path -> old:new
      final Map<String, String> proguardPathMap = <String, String>{};
      for (final String path in allNeedProguardList) {
        final File fromFile = File(<String>[prp, path].join(separator));
        final int index = path.lastIndexOf('/');
        final String fileName = path.substring(max(index + 1, 0));
        final String parent = path.substring(0, max(index, 0));
        //'${outputDirName}${separator}${parent}${separator}$fileName';
        final String ext =
            fileName.contains('.') ? '.${fileName.split('.').last}' : '';
        nameG.moveNext();
        String newNamePrefix = nameG.current;
        String newFileName = <String>[newNamePrefix, ext].join('');
        //'${prp}${separator}$toDir';
        String toNewPath =
            <String>[prp, outputDirName, parent, newFileName].join(separator);

        int counter = 1;
        while (File(toNewPath).existsSync()) {
          newNamePrefix = <Object>[newNamePrefix, counter].join('_');
          newFileName = <String>[newNamePrefix, ext].join('');

          toNewPath =
              <String>[prp, outputDirName, parent, newFileName].join(separator);
          counter++;
        }

        File(toNewPath).parent.createSync(recursive: true);
        File(toNewPath).writeAsBytesSync(fromFile.readAsBytesSync());
        _log(
          'proguard: $path -> ${toNewPath.replaceFirst(prp, '')}',
          toConsole: false,
        );

        {
          String rPath = toNewPath.replaceFirst(prp, '').replaceAll(r'\', '/');
          rPath = rPath.substring(rPath.startsWith('/') ? 1 : 0);
          proguardPathMap[path] = rPath;
        }

        {
          /// 检测处理多分辨率图
          for (final String dpr in dprs) {
            final File fromFile =
                File(<String>[prp, parent, dpr, fileName].join(separator));
            if (fromFile.existsSync()) {
              final String toNewPath = <String>[
                prp,
                outputDirName,
                parent,
                dpr,
                newFileName
              ].join(separator);
              File(toNewPath).parent.createSync(recursive: true);
              File(toNewPath).writeAsBytesSync(fromFile.readAsBytesSync());
              _log(
                'proguard: ${fromFile.path.replaceFirst(prp, '')} -> ${toNewPath.replaceFirst(prp, '')}',
                toConsole: false,
              );
            }
          }
        }
      }
      _log('end proguard resources. ]');

      {
        // 处理可能的R文件
        final List<String>? inputRFiles = config.inputRFiles;
        inputRFiles?.forEach((String rPath) {
          final File rFile = File(rPath);
          if (!rFile.existsSync()) {
            return;
          }
          final String content = rFile.readAsStringSync();
          String newContent = content;
          proguardPathMap.forEach((String _old, String _new) {
            newContent = newContent.replaceAll('\'$_old\'', '\'$_new\'');
            newContent = newContent.replaceAll('"$_old"', '"$_new"');
          });
          rFile.writeAsStringSync(newContent);
        });
      }

      {
        // 存储混淆映射文件
        if (null != config.outputMapperFilePath) {
          final String mapperPath = config.outputMapperFilePath!;
          _log('save path mapper file: $mapperPath');
          final File file = File(mapperPath);
          file.parent.createSync(recursive: true);
          file.writeAsStringSync(jsonEncode(proguardPathMap));
        }
      }

      {
        // 更新pubspec.yaml
        final String? newContent = _handlePubspecYaml(proguardPathMap);
        if (null != newContent) {
          File pubFile = _pubspecYamlFile();
          if (config.dbgPubspec) {
            pubFile = File(<String>[
              prp,
              '.dart_tool',
              '.pubspec',
              'pubspec_proguard_${config.type}.yaml',
            ].join(separator));
            pubFile.parent.createSync(recursive: true);
          }
          pubFile.writeAsStringSync(newContent);
        }

        // String? newContent = _handlePubspecYamlByAssetAndFonts(diffFiles);
        // String? newContent = _handlePubspecYamlOnlyAssets(diffFiles);
        // if (null != newContent) {
        //   File('$projectRootPath${separator}pubspec.g.yaml')
        //       .writeAsString(newContent);
        // }
        _log('end modify pubspec.yaml file');
      }
    } catch (e) {
      print(e);
      if (e is StackOverflowError && e.stackTrace != null) {
        writeLog(e.stackTrace!);
      } else {
        writeLog(e);
      }
    }
    _log('$_logPrefix finish.');
    _startWatch();
  }

  String? _handlePubspecYaml(Map<String, String> proguardPathMap) {
    final List<String> beFilteredFiles = <String>[
      ..._assetCollector.allFileListBeforeFilter
    ]..retainWhere((String test) {
        return !_assetCollector.allFileListByFilter.contains(test);
      });
    _log('被过滤掉的文件: \n${formatJson(beFilteredFiles)}');
    // beFilteredFiles.forEach((action) {
    //   print('被过滤掉的: $action');
    // });

    /// asset目录一定是配置在yaml中的
    /// 所以 这里只需要将在exclude中存在的文件排除即可 剩余的是需要额外添加进去的

    final List<String> beFilteredDirs = <String>[
      ..._assetCollector.dirListBeforeFilter
    ]..retainWhere((String test) {
        return !_assetCollector.dirListByFilter.contains(test);
      });

    _log('被过滤掉的目录: \n${formatJson(beFilteredDirs)}');
    final List<String> diffFiles = <String>[...beFilteredFiles]
      ..removeWhere((String test) {
        test = test.replaceAll(r'\', '/');
        final String dir = test.substring(0, test.lastIndexOf('/'));
        // print('<> $test -> $dir');
        return beFilteredDirs.contains(dir);
      })
      ..removeWhere((String test) {
        return test.contains('$outputDirName/');
      });

    _log('被过滤掉的综合: \n${formatJson(diffFiles)}');

    final YamlEditor editor = YamlEditor(_pubspecYamlFile().readAsStringSync());
    {
      final List<String> rList = <String>[];

      // 先处理被规则排除的文件
      // 这里优化以下 如果排除的是整个目录 则这里按照目录处理

      final Pair<Map<String, Set<String>>, List<String>> diffPair =
          parseGroup(projectRootPath, diffFiles);
      final List<String> fullDirs = diffPair.second;

      // final others = {...pair.first}
      //   ..removeWhere((key, _) {
      //     return fullDirs.contains(key);
      //   });

      // 部分文件完全被目录替代场景
      rList.addAll(fullDirs);

      final Map<String, Set<String>> otherFilesMap = <String, Set<String>>{
        ...diffPair.first
      }..removeWhere((String key, _) {
          return fullDirs.contains(key);
        });
      final List<String> otherFiles =
          otherFilesMap.values.toList().expand((Set<String> e) => e).toList();
      // 其余分散的文件
      rList.addAll(otherFiles);
      // print(rList);

      // final aaa = [
      //   ...pair.first.keys,
      //   ...pair.first.values.expand((e) => e).toList()
      // ]..removeWhere((test) {
      //   return proguardPathMap.keys.contains(test);
      // });

      {
        final List<String> _diffExcludeAll = proguardPathMap.keys.toList()
          ..removeWhere((String test) {
            return <String>[
              ...diffPair.first.keys,
              ...diffPair.first.values.expand((Set<String> e) => e).toList()
            ].contains(test);
          });

        // 找出完整处理的目录
        final Pair<Map<String, Set<String>>, List<String>> pair =
            parseGroup(projectRootPath, _diffExcludeAll);
        rList.addAll(pair.second.map((String e) => '$outputDirName/$e'));

        final Map<String, Set<String>> otherFilesMap = <String, Set<String>>{
          ...pair.first
        }..removeWhere((String key, _) {
            return pair.second.contains(key);
          });
        final List<String> otherFiles =
            otherFilesMap.values.toList().expand((Set<String> e) => e).toList();

        rList.addAll(otherFiles.map((String e) {
          return proguardPathMap[e]!;
        }).toList());
      }

      {
        // 混淆的单独文件
        // rList.addAll(_diffExcludeAll.map((e) {
        //   return proguardPathMap[e]!;
        // }).toList());
      }

      // 处理定义在pubspec.yaml中的
      // final list = jsonDecode(jsonEncode(assetNode.value as YamlList)) as List;
      // print('list: ${list}');

      // print('fullDirs: ${fullDirs}');
      // // 移除被排除的目录|文件 剩余的就是被混淆的
      // final _tAll = [
      //   ...pair.first.keys,
      //   ...pair.first.values.expand((e) => e).toList()
      // ];
      // final proguard = [...list]..removeWhere((test) {
      //     return _tAll.contains(test);
      //   });
      // print('===============');
      // print(list);
      // print(_tAll);
      // print(proguard);
      // print('===============');
      // rList.addAll(proguard.map((item) {
      //   item = proguardPathMap[item] ?? item;
      //   return  item.toString().startsWith(outputDirName) ? item : '$outputDirName/$item';
      // }));

      editor.update(<Object?>['flutter', 'assets'], rList);

      return editor.toString();
    }
  }

  static File getLogFile(Config config) {
    return File('.dart_tool$separator${config.type}_assets_proguard_log.txt');
  }

  File get logFile => getLogFile(config);

  String get projectRootPath => config.src;

  String get prp => projectRootPath;

  String get outputDirName => config.output;

  final bool isWriting = false;

  /// Watch all paths
  Future<void> _startWatch() async {
    if (!isWatch) {
      return;
    }
    if (_fileWatcher.watching) {
      return;
    }
    for (final String dir in _assetCollector.dirListByFilter) {
      final StreamSubscription<FileSystemEvent>? sub = _fileWatcher.watch(
        Directory(dir),
        onData: (_) {
          config.refresh();
          collectAssetsAndEncrypt();
        },
      );
      if (sub != null) {
        sub.onDone(sub.cancel);
      }
    }
    final File pubspec = _pubspecYamlFile();
    // ignore: cancel_subscriptions
    _fileWatcher.watch(pubspec);

    final File configFile = File(config.configFilePath);
    if (configFile.existsSync()) {
      // ignore: cancel_subscriptions
      _fileWatcher.watch(configFile);
    }

    print('Watching all resources file.');
  }

  File _pubspecYamlFile() {
    return File('$projectRootPath${separator}pubspec.yaml');
  }

  /// Write logs to the file
  /// Defaults to `.dart_tools/${config.type}_assets_proguard_log.txt'`
  void writeLog(Object text, {File? file}) {
    file ??= logFile;
    if (!file.existsSync()) {
      file.createSync(recursive: true);
    }
    file
      ..writeAsStringSync(DateTime.now().toString(), mode: FileMode.append)
      ..writeAsStringSync('  : $text', mode: FileMode.append)
      ..writeAsStringSync('\n', mode: FileMode.append);
  }

  void _log(String message, {bool toConsole = true, bool toFile = true}) {
    if (toConsole) {
      // print(message);
      logger.debug(message);
    }
    if (toFile) {
      writeLog(message);
    }
  }
}
