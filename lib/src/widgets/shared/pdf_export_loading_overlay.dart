import 'package:flutter/material.dart';
import 'dart:math' as math;

class PdfExportLoadingOverlay extends StatefulWidget {
  const PdfExportLoadingOverlay({super.key});

  @override
  State<PdfExportLoadingOverlay> createState() =>
      _PdfExportLoadingOverlayState();
}

class _PdfExportLoadingOverlayState extends State<PdfExportLoadingOverlay>
    with TickerProviderStateMixin {
  late List<AnimationController> _controllers;
  late List<Animation<double>> _animations;
  late List<Animation<double>> _fadeAnimations;

  final List<String> _musicalNotes = ['\u266A', '\u266B', '\u266C', '\u2669'];
  final List<FloatingNote> _floatingNotes = [];
  final int _maxNotes = 8;

  @override
  void initState() {
    super.initState();
    _initializeAnimations();
    _startNoteGeneration();
  }

  void _initializeAnimations() {
    _controllers = [];
    _animations = [];
    _fadeAnimations = [];

    for (int i = 0; i < _maxNotes; i++) {
      final controller = AnimationController(
        duration:
            Duration(milliseconds: 3000 + (i * 200)), // Staggered durations
        vsync: this,
      );

      final animation = Tween<double>(
        begin: 1.0,
        end: 0.0,
      ).animate(CurvedAnimation(
        parent: controller,
        curve: Curves.easeInOut,
      ));

      final fadeAnimation = Tween<double>(
        begin: 1.0,
        end: 0.0,
      ).animate(CurvedAnimation(
        parent: controller,
        curve: const Interval(0.7, 1.0, curve: Curves.easeOut),
      ));

      _controllers.add(controller);
      _animations.add(animation);
      _fadeAnimations.add(fadeAnimation);
    }
  }

  void _startNoteGeneration() {
    final random = math.Random();

    for (int i = 0; i < _maxNotes; i++) {
      Future.delayed(Duration(milliseconds: i * 400), () {
        if (mounted) {
          final note = FloatingNote(
            symbol: _musicalNotes[random.nextInt(_musicalNotes.length)],
            startX:
                random.nextDouble() * 0.8 + 0.1, // 10% to 90% of screen width
            size:
                20.0 + random.nextDouble() * 15.0, // Random size between 20-35
            animationIndex: i,
          );

          setState(() {
            _floatingNotes.add(note);
          });

          _controllers[i].repeat();
        }
      });
    }
  }

  @override
  void dispose() {
    for (final controller in _controllers) {
      controller.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final screenSize = MediaQuery.of(context).size;

    return Material(
      color: Colors.black.withOpacity(0.7),
      child: SizedBox(
        width: screenSize.width,
        height: screenSize.height,
        child: Stack(
          children: [
            // Central content area
            Center(
              child: Container(
                height: screenSize.height * 0.9,
                width: screenSize.width * 0.9,
                padding: const EdgeInsets.all(40),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.95),
                  borderRadius: BorderRadius.circular(20),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.3),
                      spreadRadius: 5,
                      blurRadius: 15,
                      offset: const Offset(0, 5),
                    ),
                  ],
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    // Pulsing treble clef
                    TweenAnimationBuilder<double>(
                      tween: Tween(begin: 0.8, end: 1.2),
                      duration: const Duration(milliseconds: 1000),
                      builder: (context, scale, child) {
                        return Transform.scale(
                          scale: scale,
                          child: const Text(
                            '\uE050', // Treble clef from Bravura font
                            style: TextStyle(
                              fontFamily: 'Bravura',
                              fontSize: 60,
                              color: Color(0xFF242038),
                            ),
                          ),
                        );
                      },
                      onEnd: () {
                        // Restart the animation
                        if (mounted) {
                          setState(() {});
                        }
                      },
                    ),

                    const SizedBox(height: 20),

                    // Loading text
                    const Text(
                      'Generating PDF...',
                      style: TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.w600,
                        color: Color(0xFF242038),
                      ),
                    ),

                    const SizedBox(height: 15),

                    // Animated dots
                    TweenAnimationBuilder<int>(
                      tween: IntTween(begin: 0, end: 3),
                      duration: const Duration(milliseconds: 1500),
                      builder: (context, dotCount, child) {
                        return Text(
                          'Please wait${'.' * (dotCount + 1)}',
                          style: TextStyle(
                            fontSize: 16,
                            color: Colors.grey[600],
                          ),
                        );
                      },
                      onEnd: () {
                        if (mounted) {
                          setState(() {});
                        }
                      },
                    ),
                  ],
                ),
              ),
            ),

            // Animated floating notes
            ..._floatingNotes.map((note) {
              final animationIndex = note.animationIndex;
              if (animationIndex >= _animations.length)
                return const SizedBox.shrink();

              return AnimatedBuilder(
                animation: _controllers[animationIndex],
                builder: (context, child) {
                  final progress = _animations[animationIndex].value;
                  final fade = _fadeAnimations[animationIndex].value;

                  return Positioned(
                    left: note.startX * screenSize.width,
                    bottom: screenSize.height * progress,
                    child: Opacity(
                      opacity: fade,
                      child: Transform.rotate(
                        angle: progress *
                            math.pi *
                            0.5, // Slight rotation as it floats
                        child: Text(
                          note.symbol,
                          style: TextStyle(
                            fontFamily: 'Bravura',
                            fontSize: note.size,
                            color: Colors.black,
                            shadows: [
                              Shadow(
                                color: Colors.black.withOpacity(0.5),
                                offset: const Offset(1, 1),
                                blurRadius: 2,
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  );
                },
              );
            }).toList(),
          ],
        ),
      ),
    );
  }
}

class FloatingNote {
  final String symbol;
  final double startX;
  final double size;
  final int animationIndex;

  FloatingNote({
    required this.symbol,
    required this.startX,
    required this.size,
    required this.animationIndex,
  });
}
