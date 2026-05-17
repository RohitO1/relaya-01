// ignore_for_file: avoid_print
import 'dart:io';

void main() async {
  final file = File('gemini_share2.html');
  final content = await file.readAsString();
  
  final startIdx = content.indexOf("import 'package:flutter/material.dart';");
  if (startIdx == -1) {
    print('Could not find start of flutter code. Trying JSON escaped format...');
    final escapedIdx = content.indexOf("import \\\"package:flutter/material.dart\\\";");
    if (escapedIdx == -1) {
        final escapedSingleIdx = content.indexOf("import \\'package:flutter/material.dart\\';");
        if (escapedSingleIdx == -1) {
            print('Still not found.');
            // Dump the first 1000 chars to see what it is
            print(content.substring(0, 1000));
            return;
        } else {
            print('Found escaped single quote start: $escapedSingleIdx');
            print(content.substring(escapedSingleIdx, escapedSingleIdx + 20000));
        }
    } else {
        print('Found escaped double quote start: $escapedIdx');
        print(content.substring(escapedIdx, escapedIdx + 20000));
    }
    return;
  }
  
  print('Found start of flutter code at index $startIdx');
  
  final endIdx = content.indexOf("```", startIdx);
  final snippet = content.substring(startIdx, endIdx == -1 ? startIdx + 20000 : endIdx);
  
  print(snippet);
}

