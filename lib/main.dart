import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_json_view/flutter_json_view.dart';

void main() {
  runApp(
    const MaterialApp(
      debugShowCheckedModeBanner: false,
      home: JsonToolsScreen(),
    ),
  );
}

class JsonToolsScreen extends StatefulWidget {
  const JsonToolsScreen({super.key});

  @override
  State<JsonToolsScreen> createState() => _JsonToolsScreenState();
}

class _JsonToolsScreenState extends State<JsonToolsScreen> {
  final TextEditingController _controller = TextEditingController();
  Map<String, dynamic>? _jsonMap;
  String? _errorMessage;

  // STATE: Controls the width ratio (0.5 means 50% split)
  double _splitRatio = 0.5;

  @override
  void initState() {
    super.initState();
    _controller.text = '{"message": "Enter the valid json here"}';
    _parseJson();
  }

  void _parseJson() {
    try {
      final decoded = jsonDecode(_controller.text);
      if (decoded is Map<String, dynamic>) {
        setState(() {
          _jsonMap = decoded;
          _errorMessage = null;
        });
      } else {
        setState(() {
          _errorMessage = "Input must be a JSON Object (Map)";
          _jsonMap = null;
        });
      }
    } catch (e) {
      setState(() {
        _errorMessage = "Invalid JSON";
        _jsonMap = null;
      });
    }
  }

  void _prettifyText() {
    try {
      final dynamic decoded = jsonDecode(_controller.text);
      const JsonEncoder encoder = JsonEncoder.withIndent('  ');
      final String prettyString = encoder.convert(decoded);
      setState(() {
        _controller.text = prettyString;
        _errorMessage = null;
      });
      _parseJson();
    } catch (e) {
      setState(() => _errorMessage = "Cannot prettify invalid JSON");
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Resizable JSON Tools"),
        actions: [
          IconButton(
            icon: const Icon(Icons.auto_fix_high),
            tooltip: "Prettify Text",
            onPressed: _prettifyText,
          ),
        ],
      ),
      body: LayoutBuilder(
        builder: (context, constraints) {
          final double totalWidth = constraints.maxWidth;
          final double leftWidth = totalWidth * _splitRatio;
          const double dividerWidth = 16.0;

          return Row(
            // CRITICAL: This forces both children to fill the screen height
            // ensuring their internal scroll views work independently.
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // --- LEFT WINDOW (Input) ---
              SizedBox(
                width: leftWidth,
                child: Padding(
                  padding: const EdgeInsets.all(8.0),
                  child: TextField(
                    controller: _controller,
                    // These 3 properties enable the independent scrolling for the text area
                    maxLines: null,
                    minLines: null,
                    expands: true,
                    textAlignVertical: TextAlignVertical.top,
                    decoration: InputDecoration(
                      labelText: "Raw JSON Input",
                      border: const OutlineInputBorder(),
                      errorText: _errorMessage,
                      alignLabelWithHint: true,
                    ),
                    onChanged: (_) => _parseJson(),
                  ),
                ),
              ),

              // --- DRAGGABLE DIVIDER ---
              MouseRegion(
                cursor: SystemMouseCursors.resizeColumn,
                child: GestureDetector(
                  behavior: HitTestBehavior.translucent,
                  onHorizontalDragUpdate: (details) {
                    setState(() {
                      final double newRatio =
                          _splitRatio + (details.delta.dx / totalWidth);
                      _splitRatio = newRatio.clamp(0.1, 0.9);
                    });
                  },
                  child: Container(
                    width: dividerWidth,
                    color: Colors.grey.shade200,
                    child: Center(
                      child: Container(
                        height: 40,
                        width: 4,
                        decoration: BoxDecoration(
                          color: Colors.grey.shade400,
                          borderRadius: BorderRadius.circular(2),
                        ),
                      ),
                    ),
                  ),
                ),
              ),

              // --- RIGHT WINDOW (Viewer) ---
              Expanded(
                child: Container(
                  color: Colors.grey.shade50,
                  // CRITICAL: This creates the independent scroll area for the viewer
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.all(8),
                    child: _jsonMap == null
                        ? const Padding(
                            padding: EdgeInsets.only(top: 20),
                            child: Center(
                              child: Text("Enter valid JSON to view tree"),
                            ),
                          )
                        : JsonView.map(
                            _jsonMap!,
                            theme: const JsonViewTheme(
                              keyStyle: TextStyle(
                                color: Colors.blue,
                                fontWeight: FontWeight.bold,
                              ),
                              doubleStyle: TextStyle(color: Colors.green),
                              intStyle: TextStyle(color: Colors.green),
                              stringStyle: TextStyle(color: Colors.orange),
                              boolStyle: TextStyle(color: Colors.purple),
                            ),
                          ),
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}
