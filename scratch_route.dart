import 'package:flutter/material.dart';

class TransparentRoute<T> extends PageRouteBuilder<T> {
  TransparentRoute({required super.pageBuilder}) : super(opaque: false);

  @override
  Widget buildModalBarrier() {
    return const SizedBox.shrink();
  }
}

void main() {}
