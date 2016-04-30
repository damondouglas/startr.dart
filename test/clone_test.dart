import 'package:test/test.dart';
import 'package:startr/command.dart' as command;
import 'dart:async';
import 'dart:io';
import 'package:path/path.dart' as path;
import 'package:random_string/random_string.dart' as random;

final mockDir = new Directory('test/mock');

main() {
  group('StartrSubCommand', () {
    TestStartrSubCommand command;
    Directory tempDir;

    setUpAll(() async {
      if (!await mockDir.exists()) {
        await mockDir.create();
      }

      command = new TestStartrSubCommand();
      tempDir = await command.cloneSourceIntoTemporaryDirectory('');
    });

    tearDownAll(() async {
      await command.cleanUp(tempDir);
    });

    group('hasMatchingFiles when true', () {
      File f;

      setUp(() {
        f = new File(path.join(command.targetDirectory.path, 'pubspec.yaml'));
        return f.create();
      });

      tearDown(() {
        return f.delete();
      });

      test('should be true', () async {
        var matches = await command.getMatchingFiles();
        expect(matches.isNotEmpty, true);
      });
    });

    group('hasMatchingFiles when false', () {
      test('should be false', () async {
        var matches = await command.getMatchingFiles();
        expect(matches.isNotEmpty, false);
      });
    });

    group('findTemplateVariables', () {
      Map variablePathMap;

      setUp(() async {
        variablePathMap = await command.findTemplateVariables(tempDir);
      });

      test('method found variable names', () {
        expect(variablePathMap.keys.isNotEmpty, true);

        expect(variablePathMap.keys.contains('__projectName__'), true);
        expect(
            variablePathMap['__projectName__'].contains('pubspec.yaml'), true);
        expect(
            variablePathMap['__projectName__'].contains('bin/main.dart'), true);
        expect(
            variablePathMap['__projectName__']
                .contains('lib/__projectName__.dart'),
            true);
        expect(
            variablePathMap['__projectName__']
                .contains('test/__projectName___test.dart'),
            true);

        expect(variablePathMap.keys.contains('__foo__'), true);
        expect(variablePathMap['__foo__'].contains('bin/main.dart'), true);

        expect(variablePathMap.keys.contains('__author__'), true);
        expect(variablePathMap['__author__'].contains('pubspec.yaml'), true);

        expect(variablePathMap.keys.contains('__email__'), true);
        expect(variablePathMap['__email__'].contains('pubspec.yaml'), true);
      });

      group('replaceContent and renameTemplateFiles', () {
        var projectName = random.randomAlphaNumeric(10);
        var author = random.randomAlpha(10) + ' ' + random.randomAlpha(10);
        var email = random.randomAlpha(10) + "@example.com";
        var foo = random.randomString(10);
        var replacementMap = {
          '__projectName__': projectName,
          '__author__': author,
          '__email__': email,
          '__foo__': foo
        };
        setUp(() async {
          variablePathMap = await command.renameTemplateFiles(
              replacementMap, variablePathMap);
          return command.replaceContent(replacementMap, variablePathMap);
        });

        test('content is replaced', () async {
          var temporaryDir = command.temporaryDirectory;
          var pubspecFile =
              new File(path.join(temporaryDir.path, 'pubspec.yaml'));
          var pubspec = await pubspecFile.readAsString();
          expect(pubspec.contains(projectName), true);
          expect(pubspec.contains(author), true);
          expect(pubspec.contains(email), true);

          var mainFile =
              new File(path.join(temporaryDir.path, 'bin/main.dart'));
          var mainScript = await mainFile.readAsString();
          expect(mainScript.contains(foo), true);
          expect(mainScript.contains(projectName), true);

          // var projectLibFile = new File(path.join(temporaryDir.path, 'lib/$projectName.dart'));
          //
          // expect(projectLibFile.existsSync(), true);
          // var projectLibContent = await projectLibFile.readAsString();
          // expect(projectLibContent.contains(projectName), true);
        });
      });
    });
  });
}

class TestStartrSubCommand extends Object with command.Templatable {
  TestStartrSubCommand() {
    this.targetDirectory = mockDir;
  }

  Future<Directory> cloneSourceIntoTemporaryDirectory(String sourceUriPath) =>
      new Future(() async {
        var contentMap = {
          path.join(temporaryDirectory.path, 'pubspec.yaml'): pubspec,
          path.join(temporaryDirectory.path, '.gitignore'): gitignore,
          path.join(temporaryDirectory.path, 'bin/main.dart'): mainScript,
          path.join(temporaryDirectory.path, 'lib/__projectName__.dart'):
              projectlib,
          path.join(temporaryDirectory.path, 'test/__projectName___test.dart'):
              testfile
        };

        await Future.wait(contentMap.keys.map((String path) async {
          var f = new File(path);
          await f.create(recursive: true);
          return f.writeAsString(contentMap[path]);
        }));
        await Process.run('pub', ['get'],
            workingDirectory: temporaryDirectory.path);
        return temporaryDirectory;
      });
}

final projectlib = """
library __projectName__;

String foo(String bar) => bar.toUpperCase();
""";

final testfile = """
library __projectName__.test;
import 'package:test/test.dart';
import 'package:__projectName__/__projectName__.dart' as __projectName__;

main(List<String> args) {
  group('foo', (){
    test('bar', () {
      var baz = __projectName__.foo('bar');
      expect(baz, 'BAR');
    });
  });
}
""";

final pubspec = """
name: __projectName__
author: __author__ <__email__>
version: 0.0.1
description: A simple console application.
dependencies:
  args: any
""";

final gitignore = """
# Files and directories created by pub
.packages
.pub/
packages
pubspec.lock # (Remove this pattern if you wish to check in your lock file)
""";

final mainScript = """
var projectName = "__projectName__";
var FOO = "__foo__";
main(List<String> args) {
  print('Hello world!');
}
""";
