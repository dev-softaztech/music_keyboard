import 'package:flutter/material.dart';
import 'package:music_keyboard/models/music_note.dart';
import 'package:music_keyboard/src/widgets/keyboard/key_signature_painter.dart';
import 'package:music_keyboard/src/widgets/shared/popup_theme.dart';

class KeySignatureData {
  final String name;
  final int symbolCount;
  final bool isSharp;

  KeySignatureData({
    required this.name,
    required this.symbolCount,
    required this.isSharp,
  });
}

class KeySignaturePopup extends StatefulWidget {
  final Function(MusicalNote) onKeySignatureSelected;

  const KeySignaturePopup({
    super.key,
    required this.onKeySignatureSelected,
  });

  @override
  State<KeySignaturePopup> createState() => _KeySignaturePopupState();
}

class _KeySignaturePopupState extends State<KeySignaturePopup>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;

  // Define the 14 key signatures
  final List<KeySignatureData> keySignatures = [
    // Sharp keys (1-7 sharps)
    KeySignatureData(name: 'G/Em', symbolCount: 1, isSharp: true),
    KeySignatureData(name: 'D/Bm', symbolCount: 2, isSharp: true),
    KeySignatureData(name: 'A/F#m', symbolCount: 3, isSharp: true),
    KeySignatureData(name: 'E/C#m', symbolCount: 4, isSharp: true),
    KeySignatureData(name: 'B/G#m', symbolCount: 5, isSharp: true),
    KeySignatureData(name: 'F#/D#m', symbolCount: 6, isSharp: true),
    KeySignatureData(name: 'C#/A#m', symbolCount: 7, isSharp: true),
    // Flat keys (1-7 flats)
    KeySignatureData(name: 'F/Dm', symbolCount: 1, isSharp: false),
    KeySignatureData(name: 'Bb/Gm', symbolCount: 2, isSharp: false),
    KeySignatureData(name: 'Eb/Cm', symbolCount: 3, isSharp: false),
    KeySignatureData(name: 'Ab/Fm', symbolCount: 4, isSharp: false),
    KeySignatureData(name: 'Db/Bbm', symbolCount: 5, isSharp: false),
    KeySignatureData(name: 'Gb/Ebm', symbolCount: 6, isSharp: false),
    KeySignatureData(name: 'Cb/Abm', symbolCount: 7, isSharp: false),
  ];

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 4, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  // Get starting Y and zigzag direction for each clef type
  Map<String, dynamic> getClefParameters(String clefType) {
    switch (clefType) {
      case 'Treble':
        return {'startingY': 20.0, 'zigzagUp': true};
      case 'Bass':
        return {'startingY': 60.0, 'zigzagUp': false};
      case 'Alto':
        return {'startingY': 55.0, 'zigzagUp': true};
      case 'Tenor':
        return {'startingY': 45.0, 'zigzagUp': false};
      default:
        return {'startingY': 50.0, 'zigzagUp': true};
    }
  }

  Widget _buildKeySignatureGrid(String clefType) {
    final clefParams = getClefParameters(clefType);

    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: GridView.builder(
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 3,
          crossAxisSpacing: 12,
          mainAxisSpacing: 12,
          childAspectRatio: 1.05,
        ),
        itemCount: keySignatures.length,
        itemBuilder: (context, index) {
          final keySignature = keySignatures[index];

          return GestureDetector(
            onTap: () {
              // Create a MusicalNote with key signature data
              final note = MusicalNote(
                  pitch: 'C',
                  octave: 4,
                  type: NoteType.keySignature,
                  keySignatureName: keySignature.name,
                  keySignatureClefType: clefType);

              widget.onKeySignatureSelected(note);
              Navigator.of(context).pop();
            },
            child: Container(
              decoration: PopupTheme.gridItemDecoration,
              child: CustomPaint(
                painter: KeySignaturePainter(
                    keySignatureName: keySignature.name,
                    startingY: clefParams['startingY'],
                    zigzagUp: clefParams['zigzagUp'],
                    symbolCount: keySignature.symbolCount,
                    isSharp: keySignature.isSharp,
                    clefType: clefType),
              ),
            ),
          );
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      insetPadding: const EdgeInsets.all(20),
      child: Container(
        width: MediaQuery.of(context).size.width * 0.9,
        height: MediaQuery.of(context).size.height * 0.8,
        decoration: PopupTheme.dialogDecoration,
        child: Column(
          children: [
            // Header with close button
            PopupTheme.buildHeader(
              title: 'Key Signatures',
              onClose: () => Navigator.of(context).pop(),
            ),

            // Tab bar
            Theme(
              data: Theme.of(context).copyWith(
                tabBarTheme: PopupTheme.tabBarTheme,
              ),
              child: TabBar(
                controller: _tabController,
                tabs: [
                  Tab(
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Text('Treble'),
                        const SizedBox(width: 8),
                        Text(
                          '\uf472',
                          style: const TextStyle(
                            fontFamily: 'Bravura',
                            fontSize: 18,
                            color: PopupTheme.textPrimary,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Tab(
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Text('Bass'),
                        const SizedBox(width: 8),
                        Text(
                          '\uf474',
                          style: const TextStyle(
                            fontFamily: 'Bravura',
                            fontSize: 18,
                            color: PopupTheme.textPrimary,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Tab(
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Text('Alto'),
                        const SizedBox(width: 8),
                        Text(
                          '\uf473',
                          style: const TextStyle(
                            fontFamily: 'Bravura',
                            fontSize: 18,
                            color: PopupTheme.textPrimary,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Tab(
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Text('Tenor'),
                        const SizedBox(width: 8),
                        Text(
                          '\uf473',
                          style: const TextStyle(
                            fontFamily: 'Bravura',
                            fontSize: 18,
                            color: PopupTheme.textPrimary,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),

            // Tab content
            Expanded(
              child: TabBarView(
                controller: _tabController,
                children: [
                  _buildKeySignatureGrid('Treble'),
                  _buildKeySignatureGrid('Bass'),
                  _buildKeySignatureGrid('Alto'),
                  _buildKeySignatureGrid('Tenor'),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
