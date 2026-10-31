// ignore_for_file: avoid_print

import 'dart:io';
import 'package:image/image.dart' as img;

/// Creates a square PNG from [inputPath] with [padPercent] padding on all sides.
/// [bgR/G/B/A] set the canvas background (use A=0 for transparent).
void padImage(
  String inputPath,
  String outputPath, {
  double padPercent = 0.18,
  int bgR = 0, int bgG = 0, int bgB = 0, int bgA = 0,
}) {
  final src = img.decodePng(File(inputPath).readAsBytesSync())!;

  final longest = src.width > src.height ? src.width : src.height;
  final canvasSize = (longest / (1.0 - padPercent * 2)).round();
  final offsetX = ((canvasSize - src.width) / 2).round();
  final offsetY = ((canvasSize - src.height) / 2).round();

  // numChannels: 4 ensures RGBA so transparency actually works
  final canvas = img.Image(width: canvasSize, height: canvasSize, numChannels: 4);
  img.fill(canvas, color: img.ColorRgba8(bgR, bgG, bgB, bgA));
  img.compositeImage(canvas, src, dstX: offsetX, dstY: offsetY);

  File(outputPath).writeAsBytesSync(img.encodePng(canvas));
  print('$inputPath → $outputPath  (${src.width}x${src.height} → ${canvasSize}x$canvasSize)');
}

void main() {
  // White version: transparent background (logo floats on whatever bg is behind it)
  padImage(
    'assets/logo_PariTsa_white.png',
    'assets/icon_padded_white.png',
    padPercent: 0.12,
    bgR: 0, bgG: 0, bgB: 0, bgA: 0,
  );

  // Dark version: app dark background color #0D1B24
  padImage(
    'assets/logo_PariTsa_black.png',
    'assets/icon_padded_black.png',
    padPercent: 0.12,
    bgR: 13, bgG: 27, bgB: 36, bgA: 255,
  );

  print('Done!');
}
