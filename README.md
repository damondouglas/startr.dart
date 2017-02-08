# startr

# About

Clones template snippets into project.  Insert __<variable>__ anywhere into your template and `startr` will find and prompt you for replacements.  It warns you if there are any existing files that match the current directory path.

![startr](https://cloud.githubusercontent.com/assets/762456/14730897/e4db6220-07ff-11e6-8ab1-33812db58315.gif)

# Install
Install [dartlang](https://www.dartlang.org), then:

`$ pub global activate startr`

# Example

See [console-simple.dart](https://github.com/damondouglas/console-simple.dart) for an example template repository (Copied courtesy of: https://github.com/google/stagehand)

`$ startr clone git git@github.com:damondouglas/console-simple.dart.git`

see list of community startrs here:  https://github.com/damondouglas/startr.dart/wiki

# Usage

```
Clones template snippets into project.

Usage: startr <command> [arguments]

Global options:
-h, --help    Print this usage information.

Available commands:
  clone   Clones template into project.
  help    Display help information for startr.

Run "startr help <command>" for more information about a command.
```

# Commands

## clone

```
Usage: startr clone <subcommand> [arguments]
-h, --help    Print this usage information.

Available subcommands:
  git    Clones template from git repository.
  path   Clones template from local directory path.

Run "startr help" to see global options.
```

### path

```
startr clone path <directory>

Clones template from local directory path.

Usage: startr clone path <directory>
-h, --help    Print this usage information.

Run "startr help" to see global options.
```
### git

```
startr clone git <uri>

Clones template from git repository.

Usage: startr clone git <uri>
-h, --help    Print this usage information.

Run "startr help" to see global options.
```
