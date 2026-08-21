# flutter_asset_proguard

English | [中文文档](README_CHN.md)

The purpose of this library is to help flutter developers
automatically proguard assets.
To help developers release their hands from this meaningless job,
and the open source community has a lot of the same functionality.

The steps are as follows:
1. Scan the `assets` field in the project's `pubspec.yaml` to collect assets.
2. Filter the asset set using the configured `include` and `exclude` rules.
3. Obfuscate the file names of the collected assets. The obfuscated files will be saved to the configured `output` directory. Relative paths and file names of other assets remain unchanged.
4. Modify the project's `pubspec.yaml` file to prefix the original asset paths with the `output` configuration.

## Usage

### Run from source

Add `dart` to your `$PATH` environment.

```bash
git clone https://github.com/yangxiaoweihn/flutter_asset_proguard
cd flutter_asset_proguard
dart pub get
dart bin/assets_proguard_bin.dart $flutter_project
```

### Run from pub global

1. Install using [pub global][]:

```bash
dart pub global activate flutter_asset_proguard

# or

dart pub global activate -s git https://github.com/yangxiaoweihn/flutter_asset_proguard.git                 
```


### Support options

```bash
fgen -h
-w, --[no-]watch    Continue to monitor changes after execution of orders.
                    (defaults to on)

-o, --output        The save directory for proguard resources.
                    It's a relative path, the relative flutter root directory
                    (defaults to "/fap_xxx/")

-s, --src           Flutter project root path
                    (defaults to ".")

    --config_file   The config file path.
                    (defaults to "cfg_assets_proguard.yaml")
                    
  , --input_r_files The assets generator mapper files.
                    (defaults to null)
                    
  , --output_mapper_file      
                    The output assets proguard mapper file.
                    (defaults to "proguard_mapper.json")
                    
-h, --[no-]help     Help usage

-d, --[no-]debug    debug info
```

### exclude and include rules

The file is yaml format, every element is `glob` style.

The name of the excluded file is under the `exclude` node, and the type is a string array. If no rule is included, it means no file is excluded.

The `include` node is the name of the file that needs to be imported, and the type is a string array. If it does not contain any rules, all file are allowed.

In terms of priority, exclude is higher than include, in other words:

First import the file according to the include nodes, and then exclude the files.

#### Example

`pubspec.yaml`
```yaml
flutter:
  assets:
    - assets/
    - images/
```

```yaml
exclude:
  - "**/add*.png"
  - "**_**"

include:
  - "**/a*.png"
  - "**/b*"
  - "**/c*"
```

```sh
assets
├── address.png           # exclude by "**/add*.png"
├── address@at.png        # exclude by "**/add*.png"
├── bluetoothon-fjdfj.png
├── bluetoothon.png
└── camera.png
images
├── address space.png     # exclude by "**/add*.png"
├── address.png           # exclude by "**/add*.png"
├── addto.png             # exclude by "**/add*.png"
├── audio.png
├── bluetooth_link.png    # exclude by **_**
├── bluetoothoff.png
├── child.png
└── course.png
```

Result：
```yaml
flutter:
  assets:
    - assets/address.png   
    - assets/address@at.png
    - fap_xxx/assets/a.png # bluetoothon-fjdfj.png
    - fap_xxx/assets/b.png # bluetoothon.png
    - fap_xxx/assets/c.png # camera.png
    
    - images/address space.png
    - images/address.png
    - images/addto.png
    - images/bluetooth_link.png
    - fap_xxx/images/d.png # audio.png
    - fap_xxx/images/e.png # bluetoothoff.png
    - fap_xxx/images/f.png # child.png
    - fap_xxx/images/g.png # course.png
```
```sh
fap_xxx/assets
├── a.png # bluetoothon-fjdfj.png
├── b.png # bluetoothon.png
└── c.png # camera.png

fap_xxx/images
├── d.png # audio.png
├── e.png # bluetoothoff.png
├── f.png # child.png
└── g.png # course.png
```

### Other configuration options
For full configuration parameters, refer to:
```
 [_cfg_demo.yaml](_cfg_demo.yaml)
```