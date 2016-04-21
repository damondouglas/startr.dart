import 'dart:io';

final usage = "dart test_runner.dart <test file path>";

main(List<String> args) {
  if (args.length > 0)
    watch(args[0]);
  else
    print(usage);
}

watch(String testFilePath) {
  var dir = new Directory('.');
  dir.watch(recursive: true).listen((FileSystemModifyEvent e) {
    if (!e.isDirectory && !e.path.contains("mock/")) {
      var result = Process.runSync("dart", [testFilePath]);
      print(result.stdout);
    }
  });
}
