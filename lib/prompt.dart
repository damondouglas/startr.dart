library startr.prompt;

import 'dart:async';
import 'dart:io';
import 'package:ansicolor/ansicolor.dart';

final AnsiPen blue = new AnsiPen()..blue(bold: true);
final AnsiPen green = new AnsiPen()..green(bold: true);

final PROMPT = blue("? ");
final COLON = green(": ");

final YES = 'y';
final NO = 'n';

const MAX_TRIES = 3;
final BLANK = '';

Future<String> ask(String question,
    {List allowedAnswers, String defaultAnswer, int maxTries: MAX_TRIES}) {
  stdout.write(PROMPT);
  stdout.write(" $question");
  if (allowedAnswers != null && allowedAnswers.isNotEmpty) {
    if (defaultAnswer != null && defaultAnswer != BLANK) {
      allowedAnswers = allowedAnswers.map((String value) =>
          value == defaultAnswer ? value.toUpperCase() : value);
    }
    stdout.write(" $allowedAnswers");
  }
  stdout.write(COLON);
  String answer = BLANK;
  var numTries = 0;
  while (numTries <= maxTries) {
    answer = stdin.readLineSync();
    numTries += 1;
    if (answer != BLANK) {
      if (allowedAnswers != null && allowedAnswers.isNotEmpty) {
        if (allowedAnswers.contains(answer)) break;
      } else {
        break;
      }
    } else if (defaultAnswer != null && defaultAnswer != BLANK) {
      answer = defaultAnswer;
      break;
    }
  }

  return new Future.value(answer);
}

Future<String> askYN(question, {bool defaultYes: false}) => ask(question,
    allowedAnswers: [YES, NO], defaultAnswer: defaultYes ? YES : NO);
