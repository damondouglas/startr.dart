// Copyright (c) 2016, see AUTHORS file. All rights reserved. Use of this source code
// is governed by a BSD-style license that can be found in the LICENSE file.

import 'package:startr/startr.dart' as startr;
import 'package:args/args.dart' as args;

main(List<String> arguments) {
  try {
    startr.run(arguments);
  } catch (e, stackTrace) {
    print(e);
    print(stackTrace);
  }
}
