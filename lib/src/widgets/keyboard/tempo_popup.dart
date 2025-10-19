import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:music_keyboard/src/widgets/shared/popup_theme.dart';

class TempoPopup extends StatefulWidget {
  final double initialTempo;
  final bool initialSwing;
  final String initialSwingText;
  final void Function(double, bool, String) onSave;

  const TempoPopup({
    super.key,
    required this.initialTempo,
    required this.initialSwing,
    required this.initialSwingText,
    required this.onSave,
  });

  @override
  _TempoPopupState createState() => _TempoPopupState();
}

class _TempoPopupState extends State<TempoPopup> {
  late TextEditingController _tempoController;
  late TextEditingController _swungController;
  late bool _swungValue;
  final _formKey = GlobalKey<FormState>();

  @override
  void initState() {
    super.initState();
    _tempoController = TextEditingController(
      text:
          widget.initialTempo > 0 ? widget.initialTempo.round().toString() : '',
    );

    _swungController = TextEditingController(
      text: widget.initialSwingText == '' ? 'Swung' : widget.initialSwingText,
    );

    _swungValue = widget.initialSwing;
  }

  @override
  void dispose() {
    _tempoController.dispose();
    super.dispose();
  }

  void _saveTempo() {
    if (_formKey.currentState!.validate()) {
      final tempo = double.tryParse(_tempoController.text) ?? 0;
      final swungText = _swungController.text;
      widget.onSave(tempo, _swungValue, swungText);
      Navigator.of(context).pop();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      insetPadding: const EdgeInsets.all(PopupTheme.dialogMargin),
      child: Container(
        width: 350,
        decoration: PopupTheme.dialogDecoration,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Header
            PopupTheme.buildHeader(
              title: 'Set Tempo',
              onClose: () => Navigator.of(context).pop(),
            ),

            // Content
            Padding(
              padding: const EdgeInsets.all(PopupTheme.contentPadding),
              child: Form(
                key: _formKey,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // Tempo row
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(
                          'Tempo =',
                          style: PopupTheme.bodyStyle.copyWith(
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                        const SizedBox(width: 10),
                        SizedBox(
                          width: 60,
                          child: TextFormField(
                            controller: _tempoController,
                            keyboardType: TextInputType.number,
                            inputFormatters: [
                              FilteringTextInputFormatter.digitsOnly,
                            ],
                            textAlign: TextAlign.center,
                            decoration: PopupTheme.inputDecoration,
                            validator: (value) {
                              if (value == null) {
                                return 'Required';
                              }
                              final tempo = int.tryParse(value);
                              if (tempo == null && value.isNotEmpty) {
                                return 'Invalid';
                              }
                              return null;
                            },
                          ),
                        ),
                        const SizedBox(width: 10),
                        Text(
                          'bpm',
                          style: PopupTheme.bodyStyle.copyWith(
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 20),
                    // Swing row
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Theme(
                          data: Theme.of(context).copyWith(
                            checkboxTheme: CheckboxThemeData(
                              fillColor: MaterialStateProperty.resolveWith(
                                (states) {
                                  if (states.contains(MaterialState.selected)) {
                                    return PopupTheme.accent;
                                  }
                                  return PopupTheme.primaryBackground;
                                },
                              ),
                              checkColor: MaterialStateProperty.all(
                                PopupTheme.primaryBackground,
                              ),
                            ),
                          ),
                          child: Checkbox(
                            value: _swungValue,
                            onChanged: (bool? value) {
                              setState(() {
                                _swungValue = value ?? false;
                              });
                            },
                          ),
                        ),
                        SizedBox(
                          width: 120,
                          child: TextFormField(
                            controller: _swungController,
                            keyboardType: TextInputType.text,
                            enabled: _swungValue,
                            textAlign: TextAlign.center,
                            decoration: PopupTheme.inputDecoration,
                            validator: (value) {
                              if (value == null) {
                                return 'Required';
                              }
                              return null;
                            },
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),

            // Actions
            PopupTheme.buildActions(
              onCancel: () => Navigator.of(context).pop(),
              onConfirm: _saveTempo,
            ),
          ],
        ),
      ),
    );
  }
}
