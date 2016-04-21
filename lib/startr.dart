// Copyright (c) 2016, see AUTHORS file. All rights reserved. Use of this source code
// is governed by a BSD-style license that can be found in the LICENSE file.

library startr;

import 'package:args/command_runner.dart';
import 'package:logging/logging.dart' as logging;
import 'package:startr/command.dart';
import 'dart:io';

run(List<String> args) {
  var cloneCommand = new CloneCommand();

  var runner =
      new CommandRunner('startr', 'Clones template snippets into project.')
        ..addCommand(cloneCommand);

  runner.run(args).catchError((error) {
    if (error is! UsageException) throw error;
    print(error);

    exit(64);
  });
}
