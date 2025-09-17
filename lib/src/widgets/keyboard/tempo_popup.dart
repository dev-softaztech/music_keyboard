import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

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
    return AlertDialog(
      title: const Text('Set Tempo'),
      content: Form(
        key: _formKey,
        child: SizedBox(
          width: 300,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Tempo row
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Text(
                    'Tempo =',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.w500),
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
                      decoration: const InputDecoration(
                        border: OutlineInputBorder(),
                        contentPadding:
                            EdgeInsets.symmetric(vertical: 5, horizontal: 10),
                      ),
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
                  const Text(
                    'bpm',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.w500),
                  ),
                ],
              ),
              const SizedBox(height: 15),
              // Swing row
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Checkbox(
                    value: _swungValue,
                    onChanged: (bool? value) {
                      setState(() {
                        _swungValue = value ?? false;
                      });
                    },
                  ),
                  SizedBox(
                    width: 120,
                    child: TextFormField(
                      controller: _swungController,
                      keyboardType: TextInputType.text,
                      enabled: _swungValue,
                      textAlign: TextAlign.center,
                      decoration: const InputDecoration(
                        border: OutlineInputBorder(),
                        contentPadding:
                            EdgeInsets.symmetric(vertical: 5, horizontal: 10),
                      ),
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
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
        ElevatedButton(
          onPressed: _saveTempo,
          child: const Text('Save'),
        ),
      ],
    );
  }
}
