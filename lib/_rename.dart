/// 生成无限的文件名序列（不含扩展名）
/// 规则：首字符必须为字母（a-z 或 A-Z），后续字符可为字母或数字
/// 顺序：先长度1（a-z, A-Z），然后长度2（aa, ab, ...），依此类推
Iterable<String> nameGenerator() sync* {
  const String firstChars =
      'abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ';
  const String otherChars =
      '0123456789abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ';

  // 长度 = 1
  for (int i = 0; i < firstChars.length; i++) {
    yield firstChars[i];
  }

  // 长度 >= 2
  int length = 2;
  while (true) {
    for (int i = 0; i < firstChars.length; i++) {
      final String prefix = firstChars[i];
      yield* _generateSuffixes(prefix, length - 1, otherChars);
    }
    length++;
  }
}

/// 递归生成后缀部分（depth 表示还需要添加的字符数）
Iterable<String> _generateSuffixes(
    String current, int depth, String chars) sync* {
  if (depth == 0) {
    yield current;
    return;
  }
  for (int i = 0; i < chars.length; i++) {
    yield* _generateSuffixes(current + chars[i], depth - 1, chars);
  }
}

void main() async {
  final Iterable<String> si = nameGenerator();
  int i = 0;
  final Iterator<String> it = si.iterator;
  while (i <= 10) {
    it.moveNext();
    print(it.current);

    i++;
  }
}
