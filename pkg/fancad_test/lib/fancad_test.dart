/// Shared harness for FanCAD package tests.
///
/// Not a product API. Case files should import this and keep only tables plus
/// assertions; temp dirs, document construction and `test()` looping live here.
library;

export 'src/cases.dart';
export 'src/drawing.dart';
export 'src/emit.dart';
export 'src/ids.dart';
export 'src/matchers.dart';
export 'src/temp.dart';
