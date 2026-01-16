import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_json_view/flutter_json_view.dart';

void main() {
  runApp(
    const MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'DevTools Pro',
      home: MultiToolScreen(),
    ),
  );
}

// --- MAIN SCREEN WITH NAVIGATION RAIL ---
class MultiToolScreen extends StatefulWidget {
  const MultiToolScreen({super.key});

  @override
  State<MultiToolScreen> createState() => _MultiToolScreenState();
}

class _MultiToolScreenState extends State<MultiToolScreen> {
  int _selectedIndex = 0;

  final List<Widget> _tools = [
    const JsonTool(),
    const Base64Tool(),
    const JwtTool(),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Row(
        children: [
          NavigationRail(
            selectedIndex: _selectedIndex,
            onDestinationSelected: (int index) {
              setState(() => _selectedIndex = index);
            },
            labelType: NavigationRailLabelType.all,
            destinations: const [
              NavigationRailDestination(
                icon: Icon(Icons.data_object),
                label: Text('JSON'),
              ),
              NavigationRailDestination(
                icon: Icon(Icons.code),
                label: Text('Base64'),
              ),
              NavigationRailDestination(
                icon: Icon(Icons.verified_user),
                label: Text('JWT'),
              ),
            ],
          ),
          const VerticalDivider(thickness: 1, width: 1),
          Expanded(
            child: IndexedStack(index: _selectedIndex, children: _tools),
          ),
        ],
      ),
    );
  }
}

// --- REUSABLE SPLIT PANE WIDGET ---
class SplitPane extends StatefulWidget {
  final Widget left;
  final Widget right;
  final double initialRatio;

  const SplitPane({
    super.key,
    required this.left,
    required this.right,
    this.initialRatio = 0.5,
  });

  @override
  State<SplitPane> createState() => _SplitPaneState();
}

class _SplitPaneState extends State<SplitPane> {
  late double _ratio;

  @override
  void initState() {
    super.initState();
    _ratio = widget.initialRatio;
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final double totalWidth = constraints.maxWidth;
        final double leftWidth = totalWidth * _ratio;
        const double dividerWidth = 16.0;

        return Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            SizedBox(width: leftWidth, child: widget.left),
            MouseRegion(
              cursor: SystemMouseCursors.resizeColumn,
              child: GestureDetector(
                behavior: HitTestBehavior.translucent,
                onHorizontalDragUpdate: (details) {
                  setState(() {
                    _ratio = (_ratio + (details.delta.dx / totalWidth)).clamp(
                      0.2,
                      0.8,
                    );
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
            Expanded(child: widget.right),
          ],
        );
      },
    );
  }
}

// --- TOOL 1: JSON PRETTIFIER & VIEWER ---
class JsonTool extends StatefulWidget {
  const JsonTool({super.key});

  @override
  State<JsonTool> createState() => _JsonToolState();
}

class _JsonToolState extends State<JsonTool> {
  late final JsonSyntaxTextController _controller;
  Map<String, dynamic>? _jsonMap;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    String initialText = '{\n  "tool": "JSON Viewer",\n  "status": "Active"\n}';
    _controller = JsonSyntaxTextController(text: initialText);
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
          _errorMessage = "Input must be a JSON Object {}";
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

  void _prettify() {
    try {
      final dynamic decoded = jsonDecode(_controller.text);
      const JsonEncoder encoder = JsonEncoder.withIndent('  ');
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
        title: const Text("JSON Tools"),
        elevation: 1,
        actions: [
          IconButton(
            icon: const Icon(Icons.auto_fix_high),
            tooltip: "Prettify",
            onPressed: _prettify,
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: SplitPane(
        left: InputPane(
          label: "JSON INPUT",
          controller: _controller,
          errorText: _errorMessage,
          onChanged: (_) => _parseJson(),
        ),
        right: _jsonMap == null
            ? const Center(
                child: Text(
                  "Invalid JSON",
                  style: TextStyle(color: Colors.grey),
                ),
              )
            : Container(
                color: Colors.white,
                child: Column(
                  children: [
                    const PaneHeader(title: "TREE VIEW"),
                    Expanded(
                      child: SingleChildScrollView(
                        padding: const EdgeInsets.all(8),
                        child: SelectionArea(
                          child: JsonView.map(
                            _jsonMap!,
                            theme: const JsonViewTheme(
                              backgroundColor: Colors.white,
                              keyStyle: TextStyle(
                                color: Colors.blue,
                                fontWeight: FontWeight.bold,
                              ),
                              stringStyle: TextStyle(color: Colors.orange),
                              intStyle: TextStyle(color: Colors.green),
                              boolStyle: TextStyle(color: Colors.purple),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
      ),
    );
  }
}

// --- TOOL 2: BASE64 ENCODER/DECODER ---
class Base64Tool extends StatefulWidget {
  const Base64Tool({super.key});

  @override
  State<Base64Tool> createState() => _Base64ToolState();
}

class _Base64ToolState extends State<Base64Tool> {
  final TextEditingController _inputController = TextEditingController();
  final TextEditingController _outputController = TextEditingController();
  bool _isUrlSafe = true;

  void _encode() {
    try {
      final bytes = utf8.encode(_inputController.text);
      final result = _isUrlSafe
          ? base64Url.encode(bytes)
          : base64.encode(bytes);
      setState(() => _outputController.text = result);
    } catch (e) {
      setState(() => _outputController.text = "Error encoding: $e");
    }
  }

  void _decode() {
    try {
      String input = _inputController.text.trim();
      // Add padding if missing (often required for loose inputs)
      while (input.length % 4 != 0) {
        input += '=';
      }
      final bytes = _isUrlSafe ? base64Url.decode(input) : base64.decode(input);
      setState(() => _outputController.text = utf8.decode(bytes));
    } catch (e) {
      setState(
        () => _outputController.text = "Error decoding: Invalid Base64 string",
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Base64 Converter"),
        elevation: 1,
        actions: [
          Row(
            children: [
              const Text("URL Safe"),
              Switch(
                value: _isUrlSafe,
                onChanged: (val) => setState(() => _isUrlSafe = val),
              ),
            ],
          ),
          const SizedBox(width: 16),
        ],
      ),
      body: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            color: Colors.grey.shade100,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                ElevatedButton.icon(
                  icon: const Icon(Icons.arrow_downward),
                  label: const Text("Encode (Text → Base64)"),
                  onPressed: _encode,
                ),
                const SizedBox(width: 20),
                ElevatedButton.icon(
                  icon: const Icon(Icons.arrow_upward),
                  label: const Text("Decode (Base64 → Text)"),
                  onPressed: _decode,
                ),
              ],
            ),
          ),
          Expanded(
            child: SplitPane(
              left: InputPane(
                label: "INPUT",
                controller: _inputController,
                hintText: "Enter text to encode or Base64 to decode...",
              ),
              right: InputPane(
                label: "OUTPUT",
                controller: _outputController,
                readOnly: true, // Output is read-only but copyable
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// --- TOOL 3: JWT DECODER ---
class JwtTool extends StatefulWidget {
  const JwtTool({super.key});

  @override
  State<JwtTool> createState() => _JwtToolState();
}

class _JwtToolState extends State<JwtTool> {
  final TextEditingController _tokenController = TextEditingController();
  Map<String, dynamic>? _headerMap;
  Map<String, dynamic>? _payloadMap;
  String? _error;

  void _decodeJwt() {
    final token = _tokenController.text.trim();
    if (token.isEmpty) {
      setState(() {
        _headerMap = null;
        _payloadMap = null;
        _error = null;
      });
      return;
    }

    try {
      final parts = token.split('.');
      if (parts.length != 3) {
        throw const FormatException("Invalid JWT: Must have 3 parts");
      }

      setState(() {
        _headerMap = _decodeBase64Json(parts[0]);
        _payloadMap = _decodeBase64Json(parts[1]);
        _error = null;
      });
    } catch (e) {
      setState(() {
        _headerMap = null;
        _payloadMap = null;
        _error = "Error: ${e.toString()}";
      });
    }
  }

  Map<String, dynamic> _decodeBase64Json(String str) {
    String normalized = base64Url.normalize(str);
    String decodedString = utf8.decode(base64Url.decode(normalized));
    return jsonDecode(decodedString);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("JWT Decoder"), elevation: 1),
      body: SplitPane(
        initialRatio: 0.3, // Give input less space, output more
        left: InputPane(
          label: "ENCODED TOKEN",
          controller: _tokenController,
          onChanged: (_) => _decodeJwt(),
          hintText: "Paste JWT (ey...) here",
        ),
        right: Container(
          color: Colors.white,
          child: Column(
            children: [
              const PaneHeader(title: "DECODED HEADER & PAYLOAD"),
              Expanded(
                child: _error != null
                    ? Center(
                        child: Text(
                          _error!,
                          style: const TextStyle(color: Colors.red),
                        ),
                      )
                    : _headerMap == null
                    ? const Center(
                        child: Text(
                          "Paste a valid token to decode",
                          style: TextStyle(color: Colors.grey),
                        ),
                      )
                    : SingleChildScrollView(
                        padding: const EdgeInsets.all(16),
                        child: SelectionArea(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text(
                                "HEADER",
                                style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  color: Colors.grey,
                                ),
                              ),
                              const Divider(),
                              JsonView.map(_headerMap!),
                              const SizedBox(height: 20),
                              const Text(
                                "PAYLOAD",
                                style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  color: Colors.grey,
                                ),
                              ),
                              const Divider(),
                              JsonView.map(_payloadMap!),
                            ],
                          ),
                        ),
                      ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// --- HELPER WIDGETS ---

class InputPane extends StatelessWidget {
  final String label;
  final TextEditingController controller;
  final String? errorText;
  final Function(String)? onChanged;
  final bool readOnly;
  final String? hintText;

  const InputPane({
    super.key,
    required this.label,
    required this.controller,
    this.errorText,
    this.onChanged,
    this.readOnly = false,
    this.hintText,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        PaneHeader(title: label),
        Expanded(
          child: Container(
            color: Colors.grey.shade50,
            padding: const EdgeInsets.all(8.0),
            child: TextField(
              controller: controller,
              maxLines: null,
              minLines: null,
              expands: true,
              readOnly: readOnly,
              textAlignVertical: TextAlignVertical.top,
              style: const TextStyle(fontFamily: 'monospace', fontSize: 14),
              decoration: InputDecoration(
                border: InputBorder.none,
                errorText: errorText,
                hintText: hintText,
                alignLabelWithHint: true,
              ),
              onChanged: onChanged,
            ),
          ),
        ),
      ],
    );
  }
}

class PaneHeader extends StatelessWidget {
  final String title;
  const PaneHeader({super.key, required this.title});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      color: Colors.grey.shade200,
      child: Text(
        title,
        style: TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.bold,
          color: Colors.grey.shade700,
          letterSpacing: 0.5,
        ),
      ),
    );
  }
}

// --- CUSTOM CONTROLLER FOR SYNTAX HIGHLIGHTING ---
class JsonSyntaxTextController extends TextEditingController {
  JsonSyntaxTextController({super.text});

  @override
  TextSpan buildTextSpan({
    required BuildContext context,
    TextStyle? style,
    required bool withComposing,
  }) {
    final List<TextSpan> children = [];
    final RegExp regex = RegExp(
      r'("(?:\.|[^"\\])*")|(-?\d+(?:\.\d+)?(?:[eE][+-]?\d+)?)|(true|false|null)|([{}\[\],:])',
    );

    style ??= const TextStyle(color: Colors.black);
    int currentIndex = 0;

    for (final Match match in regex.allMatches(text)) {
      if (match.start > currentIndex) {
        children.add(
          TextSpan(
            text: text.substring(currentIndex, match.start),
            style: style,
          ),
        );
      }

      final String? matchedText = match.group(0);
      TextStyle matchStyle = style;

      if (match.group(1) != null) {
        // String
        bool isKey = false;
        int nextIndex = match.end;
        while (nextIndex < text.length && text[nextIndex].trim().isEmpty) {
          nextIndex++;
        }
        if (nextIndex < text.length && text[nextIndex] == ':') isKey = true;
        matchStyle = TextStyle(
          color: isKey ? Colors.blue[800] : Colors.orange[800],
          fontWeight: isKey ? FontWeight.bold : FontWeight.normal,
        );
      } else if (match.group(2) != null) {
        // Number
        matchStyle = const TextStyle(color: Colors.green);
      } else if (match.group(3) != null) {
        // Keyword
        matchStyle = const TextStyle(
          color: Colors.purple,
          fontWeight: FontWeight.bold,
        );
      } else if (match.group(4) != null) {
        // Punctuation
        matchStyle = const TextStyle(color: Colors.grey);
      }

      children.add(TextSpan(text: matchedText, style: matchStyle));
      currentIndex = match.end;
    }

    if (currentIndex < text.length) {
      children.add(TextSpan(text: text.substring(currentIndex), style: style));
    }

    return TextSpan(style: style, children: children);
  }
}
