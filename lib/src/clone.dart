part of startr.command;

final _variableRegExp = new RegExp(r'__([a-zA-Z]+)__');

class CloneCommand extends Command {
  final name = "clone";
  final description = "Clones template into project.";

  CloneCommand() {
    addSubcommand(new PathCommand());
    addSubcommand(new GitCommand());
  }

  run() => new Future(() async {
        if (argResults.rest.isEmpty) print(usage);
      });
}

abstract class CloneSubcommand extends Command with Templatable {
  String get uri => argResults.rest.isNotEmpty
      ? AliasConfig.getUriFromAlias(argResults.rest.first)
      : null;

  Future setUp() => new Future(() {
        targetDirectory = new Directory('.');
        return cloneSourceIntoTemporaryDirectory(uri);
      });

  Future<bool> performChecks() => new Future(() async {
        var matches = await getMatchingFiles();
        if (matches.isNotEmpty) {
          print("The following files already exist.\n");
          matches.forEach((f) => print(f));
          print('');
          var deleteOk =
              await prompt.askYN("Are you sure you want to overwrite them?\n");
          return deleteOk == prompt.YES;
        } else
          return true;
      });

  Future tearDown() => new Future(() async {
        return cleanUp(temporaryDirectory);
      });

  Future processJob() => new Future(() async {
        var variablePathMap = await findTemplateVariables(temporaryDirectory);
        var replacementMap =
            await getTemplateVariableReplacements(variablePathMap.keys);
        variablePathMap =
            await renameTemplateFiles(replacementMap, variablePathMap);
        await replaceContent(replacementMap, variablePathMap);
        await deployContent();
      });

  run() async {
    if (uri == null) throw new UsageException(this.invocation, this.usage);
    try {
      await setUp();
      if (await performChecks()) await processJob();
      await tearDown();
    } catch (e) {
      await tearDown();
      throw e;
    }
  }
}

class PathCommand extends CloneSubcommand with Templatable {
  final name = "path";
  final description = "Clones template from local directory path.";

  final invocation = "startr clone path <directory>";

  Future<Directory> cloneSourceIntoTemporaryDirectory(String sourceUriPath) =>
      new Future(() async {
        var sourceDir = new Directory(sourceUriPath);
        if (!sourceDir.existsSync())
          throw new UsageException('$sourceUriPath does not exist', this.usage);
        await for (File f in list(sourceDir)) {
          var content = await f.readAsBytes();
          var relativePath = path.relative(f.path, from: sourceDir.path);
          var newPath = path.join(temporaryDirectory.path, relativePath);
          var newFile = new File(newPath);
          await newFile.create(recursive: true);
          await newFile.writeAsBytes(content);
        }
      });
}

class GitCommand extends CloneSubcommand with Templatable {
  final name = "git";
  final description = "Clones template from git repository.";

  final invocation = "startr clone git <uri>";

  Future<Directory> cloneSourceIntoTemporaryDirectory(String sourceUriPath) =>
      new Future(() async {
        var isValidGitUrl = await getIsValidGitUri(sourceUriPath);
        if (isValidGitUrl) {
          await _cloneGitIntoTemporaryDirectory(sourceUriPath);
        } else
          throw new UsageException(
              '$sourceUriPath is not a valid git url', this.usage);
      });

  Future _cloneGitIntoTemporaryDirectory(String sourceUriPath) =>
      git.runGit(['clone', sourceUriPath, temporaryDirectory.path]);

  Future<bool> getIsValidGitUri(sourceUriPath) => new Future(() async {
        try {
          var result = await git.runGit(['ls-remote', sourceUriPath]);
          return result.stdout.contains('HEAD');
        } catch (e) {
          return false;
        }
      });
}

abstract class Templatable {
  /// [targetDirectory] serves as the acting current directory to target the new template files.
  Directory targetDirectory;

  Directory _temporaryDirectory;

  /// [temporaryDirectory] serves as the target directory to clone raw template files.
  Directory get temporaryDirectory => () {
        if (_temporaryDirectory == null ||
            (_temporaryDirectory != null &&
                !_temporaryDirectory.existsSync())) {
          _temporaryDirectory =
              targetDirectory != null && targetDirectory.existsSync()
                  ? targetDirectory.createTempSync()
                  : null;
        }
        return _temporaryDirectory;
      }();

  /// Clones content from [sourceUriPath] into a temporary directory.
  Future<Directory> cloneSourceIntoTemporaryDirectory(String sourceUriPath);

  /// Find template variables in [sourceDirectory].
  ///
  /// Template variables obey the syntax __<variable name>__.  Returns a [Map] of <variable name> to a [List] of paths.
  Future<Map<String, List>> findTemplateVariables(Directory sourceDirectory) =>
      new Future(() async {
        print("Searching for __<variable>__ ...");
        var variablePathMap = {};

        var fileList = await list(sourceDirectory).toList();
        await Future.forEach(fileList, (File file) async {
          var relativePath =
              path.relative(file.path, from: sourceDirectory.path);

          var fileName = path.basenameWithoutExtension(relativePath);
          if (_variableRegExp.hasMatch(fileName)) {
            var variableMatches = _variableRegExp.allMatches(fileName);
            variableMatches.forEach((Match match) {
              var variableName = match.group(0);
              if (!variablePathMap.containsKey(variableName))
                variablePathMap[variableName] = [];

              if (!variablePathMap[variableName].contains(relativePath))
                variablePathMap[variableName].add(relativePath);
            });
          }

          try {
            var content = await file.readAsString();
            if (_variableRegExp.hasMatch(content)) {
              var variableMatches = _variableRegExp.allMatches(content);
              variableMatches.forEach((Match match) {
                var variableName = match.group(0);
                if (!variablePathMap.containsKey(variableName))
                  variablePathMap[variableName] = [];

                if (!variablePathMap[variableName].contains(relativePath))
                  variablePathMap[variableName].add(relativePath);
              });
            }
          } catch (e) {
            print("Skipping text __<variable>__ search in $relativePath.");
          }
        });

        return variablePathMap;
      });

  /// Prompts user with [List] of [variableNames] and aquires replacement.
  Future<Map<String, String>> getTemplateVariableReplacements(
          List variableNames) =>
      new Future(() async {
        if (variableNames.isNotEmpty) print("Replace project variable names:");

        var variableReplacements = await Future.wait(variableNames
            .map((String variableName) => prompt.ask(variableName)));

        return new Map.fromIterables(variableNames, variableReplacements);
      });

  /// Replaces content in [temporaryDirectory] provided by [variablePathMap] with substituting replacement names as governed by [replacementMap].
  Future replaceContent(Map<String, String> replacementMap,
          Map<String, List> variablePathMap) =>
      new Future(() async {
        var contentMap = {};

        var pathSet = new Set();

        variablePathMap.values
            .forEach((List pathStrList) => pathSet.addAll(pathStrList));

        await Future.forEach(pathSet, (String pathStr) async {
          var f = new File(path.join(temporaryDirectory.path, pathStr));
          var content = await f.readAsString();
          contentMap[pathStr] = content;
        });

        variablePathMap.forEach((String variableName, List pathStrList) {
          var replaceWith = replacementMap[variableName];
          pathStrList.forEach((String pathStr) => contentMap[pathStr] =
              contentMap[pathStr].replaceAll(variableName, replaceWith));
        });

        return Future.forEach(pathSet, (String pathStr) {
          var f = new File(path.join(temporaryDirectory.path, pathStr));
          var content = contentMap[pathStr];
          return f.writeAsString(content);
        });
      });

  /// Renames [variablePathMap] according to [replacementMap].
  ///
  /// Checks first whether new renamed path already exists and prompts user accordingly.
  Future<Map<String, List>> renameTemplateFiles(
          Map<String, String> replacementMap,
          Map<String, List> variablePathMap) =>
      new Future(() async {
        await Future.forEach(variablePathMap.keys, (String variableName) async {
          var pathList = variablePathMap[variableName];
          var newPathList = [];
          await Future.forEach(pathList, (String pathStr) async {
            if (pathStr.contains(variableName)) {
              var f = new File(path.join(temporaryDirectory.path, pathStr));
              if (f.existsSync()) {
                var newPathStr = pathStr.replaceAll(
                    variableName, replacementMap[variableName]);
                var fullNewPathStr =
                    path.join(temporaryDirectory.path, newPathStr);
                await f.rename(fullNewPathStr);
                newPathList.add(newPathStr);
              }
            } else {
              newPathList.add(pathStr);
            }
          });
          variablePathMap[variableName] = newPathList;
        });
        return variablePathMap;
      });

  /// Copies content from [temporaryDirectory] into [targetDirectory].
  ///
  /// Checks first for existing files and prompts user if they want to proceed if files already exist in [targetDirectory].
  Future deployContent() => new Future(() async {
        List matches = await getMatchingFiles();
        var copyFromTemporaryToTarget = () => new Future(() async {
              var temporaryFileList = await list(temporaryDirectory).toList();
              await Future.forEach(temporaryFileList, (File sourceFile) async {
                var relativePath = path.relative(sourceFile.path,
                    from: temporaryDirectory.path);
                var newPath = path.join(targetDirectory.path, relativePath);
                var targetFile = new File(newPath);
                await targetFile.create(recursive: true);
                var content = await sourceFile.readAsBytes();
                await targetFile.writeAsBytes(content);
              });
            });

        if (matches.isNotEmpty) {
          print("The following files already exist: \n");
          matches.forEach((f) => print(f));
          var deleteOk =
              await prompt.askYN("Are you sure you want to overwrite?");
          if (deleteOk == prompt.YES) await copyFromTemporaryToTarget();
        } else
          await copyFromTemporaryToTarget();
      });

  /// Checks whether [targetDirectory] and [temporaryDirectory] have matching files.
  Future<List> getMatchingFiles() => new Future(() async {
        var targetDirectoryFiles = await list(targetDirectory)
            .where((File f) {
              return !f.path.contains(path.basename(temporaryDirectory.path));
            })
            .map((File f) => path.relative(f.path, from: targetDirectory.path))
            .toSet();

        var temporaryDirectoryFiles = await list(temporaryDirectory)
            .map((File f) =>
                path.relative(f.path, from: temporaryDirectory.path))
            .toSet();

        return targetDirectoryFiles
            .intersection(temporaryDirectoryFiles)
            .toList();
      });

  /// Deletes [dir].
  Future cleanUp(Directory dir) => new Future(() async {
        print('Deleting $dir ...');
        if (dir.existsSync()) await dir.delete(recursive: true);
      });

  Stream<File> list(Directory sourceDirectory) {
    return sourceDirectory
        .list(recursive: true)
        .where((FileSystemEntity fse) => fse is File)
        .map((FileSystemEntity fse) => fse as File)
        .where((FileSystemEntity fse) => !_ignore(fse));
  }

  _ignore(File file) {
    return [
      'packages/',
      '.packages',
      '.pub/',
      'pubspec.lock',
      '.git/',
      '.gitignore'
    ]
        .map((String pattern) => new RegExp(pattern))
        .any((RegExp regex) => regex.hasMatch(file.path));
  }
}
