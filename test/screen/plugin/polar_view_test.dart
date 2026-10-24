import 'dart:convert';

import 'package:fancad_core/fancad_core.dart';
import 'package:fancad_render/fancad_render.dart';
import 'package:fancad_widget/fancad_widget.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const sidebar = {
    'id': 'root',
    'type': 'column',
    'gap': 8,
    'children': [
      {'id': 'status', 'type': 'text', 'text': '已把图上的圆当作参照。'},
      {'id': 'div1', 'type': 'divider'},
      {
        'id': 'pickRow',
        'type': 'row',
        'gap': 8,
        'children': [
          {'id': 'pickCenter', 'type': 'button', 'label': '取中心'},
          {'id': 'pickCircle', 'type': 'button', 'label': '参照圆'},
        ],
      },
      {'id': 'open', 'type': 'button', 'label': '打开预览'},
    ],
  };

  const dialog = {
    'id': 'dialogRoot',
    'type': 'row',
    'gap': 12,
    'children': [
      {
        'id': 'preview',
        'type': 'viewer',
        'canvas': 'polar',
        'height': 420,
        'caption': '独立画布，尚未写入当前图纸',
      },
      {
        'id': 'controls',
        'type': 'column',
        'gap': 8,
        'children': [
          {'id': 'countLabel', 'type': 'text', 'text': '份数  8'},
          {
            'id': 'countRow',
            'type': 'row',
            'gap': 8,
            'children': [
              {
                'id': 'count',
                'type': 'slider',
                'value': 8,
                'min': 2,
                'max': 36,
              },
              {'id': 'countField', 'type': 'numberField', 'value': '8'},
            ],
          },
          {'id': 'full', 'type': 'checkbox', 'label': '布满整圈', 'value': true},
          {
            'id': 'kind',
            'type': 'dropdown',
            'value': '圆',
            'options': ['圆', '点', '圆加点'],
          },
        ],
      },
    ],
  };

  testWidgets('polar sidebar and preview dialog lay out', (tester) async {
    final document = CadDocument();
    final viewport = ViewportController();
    addTearDown(viewport.dispose);
    await tester.pumpWidget(
      MaterialApp(
        theme: FanCadTheme.dark(),
        home: Scaffold(
          body: SizedBox(
            width: 280,
            height: 640,
            child: FanCadView(
              tree: jsonEncode(parseViewTree(sidebar)),
              host: FanCadViewHost(onEvent: (_, _, _) {}),
            ),
          ),
        ),
      ),
    );
    expect(find.text('打开预览'), findsOneWidget);
    expect(
      tester.getSize(find.widgetWithText(FanCadButton, '打开预览')).width,
      lessThan(160),
    );
    expect(tester.takeException(), isNull);

    await tester.pumpWidget(
      MaterialApp(
        theme: FanCadTheme.dark(),
        home: Scaffold(
          body: SizedBox(
            width: 520,
            height: 560,
            child: FanCadView(
              tree: jsonEncode(parseViewTree(dialog)),
              host: FanCadViewHost(
                onEvent: (_, _, _) {},
                viewer: (_) =>
                    FanCadViewerBinding(document: document, viewport: viewport),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.pump();
    expect(find.text('份数  8'), findsOneWidget);
    expect(find.text('布满整圈'), findsOneWidget);
    expect(find.byType(CadCanvas), findsOneWidget);
    final canvasBox = tester.getRect(find.byType(CadCanvas));
    final countBox = tester.getRect(find.text('份数  8'));
    expect(canvasBox.right, lessThan(countBox.left));
    expect(canvasBox.height, greaterThan(400));
    expect(tester.takeException(), isNull);

    final slider = tester.getSize(find.byType(FanCadSlider));
    final field = tester.getSize(find.byType(FanCadFormField));
    expect(slider.width, greaterThan(field.width));

    await tester.pumpWidget(
      MaterialApp(
        theme: FanCadTheme.dark(),
        home: Scaffold(
          body: SizedBox(
            width: 420,
            height: 380,
            child: Stack(
              children: [
                FanCadCanvasWindow(
                  name: 'polar-preview',
                  title: '环形阵列预览',
                  origin: const Offset(8, 8),
                  bounds: const Size(420, 380),
                  initialSize: const Size(400, 360),
                  minSize: const Size(400, 360),
                  footer: const SizedBox(height: 28),
                  child: FanCadView(
                    tree: jsonEncode(parseViewTree(dialog)),
                    host: FanCadViewHost(
                      onEvent: (_, _, _) {},
                      viewer: (_) => FanCadViewerBinding(
                        document: document,
                        viewport: viewport,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
    await tester.pump();
    expect(find.text('份数  8'), findsOneWidget);
    expect(find.byType(CadCanvas), findsOneWidget);
    expect(tester.takeException(), isNull);
    // The canvas settles the camera on a short timer. Let it fire before the
    // viewport is disposed with the test.
    await tester.pump(const Duration(milliseconds: 120));
  });
}
