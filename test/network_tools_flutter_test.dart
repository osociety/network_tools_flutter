import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('adds one to input values', () async {
    ProcessResult result = await Process.run('arp', ['-a']);
    print(result.stdout);
    print("ARP scan ended");
  });
}
