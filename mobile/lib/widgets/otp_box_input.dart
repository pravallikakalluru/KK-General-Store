import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// 4-digit OTP entry as four separate boxes, with auto-advance on input and
/// auto-back on backspace. Manual entry always works; the first box also
/// carries [AutofillHints.oneTimeCode] inside an [AutofillGroup] so Android's
/// SMS Code Autofill service can fill it automatically when a matching SMS
/// arrives on a real device — this can't be demonstrated in dev mode (no
/// real SMS is sent) or on web/desktop, and Flutter's per-field autofill
/// generally only fills the one hinted box rather than splitting a code
/// across all four, so manual entry remains the primary path.
class OtpBoxInput extends StatefulWidget {
  const OtpBoxInput({
    super.key,
    required this.length,
    required this.onChanged,
    required this.onCompleted,
    this.enabled = true,
    this.errorText,
  });

  final int length;
  final ValueChanged<String> onChanged;
  final ValueChanged<String> onCompleted;
  final bool enabled;
  final String? errorText;

  @override
  State<OtpBoxInput> createState() => OtpBoxInputState();
}

class OtpBoxInputState extends State<OtpBoxInput> {
  late final List<TextEditingController> _controllers;
  late final List<FocusNode> _focusNodes;

  @override
  void initState() {
    super.initState();
    _controllers = List.generate(widget.length, (_) => TextEditingController());
    _focusNodes = List.generate(widget.length, (_) => FocusNode());
  }

  @override
  void dispose() {
    for (final c in _controllers) {
      c.dispose();
    }
    for (final f in _focusNodes) {
      f.dispose();
    }
    super.dispose();
  }

  void clear() {
    for (final c in _controllers) {
      c.clear();
    }
    _focusNodes.first.requestFocus();
    widget.onChanged('');
  }

  String get _code => _controllers.map((c) => c.text).join();

  void _handleChanged(int index, String value) {
    if (value.isNotEmpty && index < widget.length - 1) {
      _focusNodes[index + 1].requestFocus();
    }
    widget.onChanged(_code);
    if (_code.length == widget.length) {
      widget.onCompleted(_code);
    }
  }

  void _handleBackspace(int index) {
    if (_controllers[index].text.isEmpty && index > 0) {
      _focusNodes[index - 1].requestFocus();
      _controllers[index - 1].clear();
      widget.onChanged(_code);
    }
  }

  @override
  Widget build(BuildContext context) {
    final hasError = widget.errorText != null;
    return Column(
      children: [
        AutofillGroup(
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: List.generate(widget.length, (index) {
              return Padding(
                padding: const EdgeInsets.symmetric(horizontal: 6),
                child: SizedBox(
                  width: 52,
                  height: 58,
                  child: KeyboardListener(
                    focusNode: FocusNode(skipTraversal: true),
                    onKeyEvent: (event) {
                      if (event is KeyDownEvent &&
                          event.logicalKey == LogicalKeyboardKey.backspace) {
                        _handleBackspace(index);
                      }
                    },
                    child: TextField(
                      controller: _controllers[index],
                      focusNode: _focusNodes[index],
                      enabled: widget.enabled,
                      textAlign: TextAlign.center,
                      keyboardType: TextInputType.number,
                      maxLength: 1,
                      autofillHints:
                          index == 0 ? const [AutofillHints.oneTimeCode] : null,
                      style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
                      inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                      decoration: InputDecoration(
                        counterText: '',
                        contentPadding: EdgeInsets.zero,
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(10),
                          borderSide: BorderSide(
                            color: hasError ? Theme.of(context).colorScheme.error : Colors.grey.shade300,
                          ),
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(10),
                          borderSide: BorderSide(
                            color: hasError ? Theme.of(context).colorScheme.error : Colors.grey.shade300,
                          ),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(10),
                          borderSide: BorderSide(
                            color: hasError
                                ? Theme.of(context).colorScheme.error
                                : Theme.of(context).colorScheme.primary,
                            width: 2,
                          ),
                        ),
                      ),
                      onChanged: (value) => _handleChanged(index, value),
                    ),
                  ),
                ),
              );
            }),
          ),
        ),
        if (widget.errorText != null) ...[
          const SizedBox(height: 10),
          Text(
            widget.errorText!,
            style: TextStyle(color: Theme.of(context).colorScheme.error, fontSize: 13),
            textAlign: TextAlign.center,
          ),
        ],
      ],
    );
  }
}
