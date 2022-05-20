import 'dart:io';

import 'package:chaquopy/chaquopy.dart';
import 'package:flutter/material.dart';

class PredictPage extends StatefulWidget {
  const PredictPage({Key? key, required this.imgPath, required this.selected})
      : super(key: key);

  final String imgPath;
  final int selected;

  @override
  State<PredictPage> createState() => _PredictPageState();
}

class _PredictPageState extends State<PredictPage> {
  List positionsShort = ["BL", "BR", "TL", "TR"];

  Future<String?> predictFen() async {
    final _result = await Chaquopy.executeCode("""
from main import predict

fen = predict("${widget.imgPath}", "${positionsShort[widget.selected]}")

print(fen)
""");

    File(widget.imgPath).delete();

    return _result['textOutputOrError'] ?? '';
  }

  @override
  void initState() {
    super.initState();
    Future.delayed(const Duration(milliseconds: 1000), () {
      predictFen().then((String? fen) => {Navigator.pop(context, fen)});
    });
  }

  @override
  Widget build(BuildContext context) {
    return const Scaffold(
        backgroundColor: Colors.white,
        body: Center(
            child: Text(
                "Your board is being processed,\nthis might take a few seconds...",
                style: TextStyle(color: Colors.grey))));
  }
}
