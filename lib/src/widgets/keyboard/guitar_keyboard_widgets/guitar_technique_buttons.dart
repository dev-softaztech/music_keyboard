import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

class GuitarTechniqueButton extends StatelessWidget {
  final String identifier;
  final String label;
  final double fontSize;
  final bool isUnicode;
  final String? svgAssetPath;
  final VoidCallback? onPressed;
  final bool isActive;
  final bool isLocked;
  final Offset offset;

  const GuitarTechniqueButton(
    this.identifier,
    this.label, {
    super.key,
    this.fontSize = 0,
    this.isUnicode = true,
    this.svgAssetPath,
    this.onPressed,
    this.isActive = false,
    this.isLocked = false,
    this.offset = Offset.zero,
  });

  @override
  Widget build(BuildContext context) {
    double buttonWidth = MediaQuery.of(context).size.width * 0.092;

    return SizedBox(
      width: buttonWidth,
      child: ElevatedButton(
        onPressed: onPressed,
        style: ElevatedButton.styleFrom(
          backgroundColor: isActive
              ? (isLocked ? Colors.blue[300] : Colors.blue[100])
              : Colors.grey[50],
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(5),
            side: BorderSide(
                color: isActive ? Colors.blue : Colors.black,
                width: isActive ? 2 : 1),
          ),
          padding: EdgeInsets.zero,
        ),
        child: Stack(
          children: [
            Center(
                child: Transform.translate(
              offset: offset,
              child: svgAssetPath != null
                  ? SvgPicture.asset(svgAssetPath!,
                      width: 20,
                      height: 20,
                      colorFilter: ColorFilter.linearToSrgbGamma())
                  : Text(
                      label,
                      style: TextStyle(
                        fontFamily: isUnicode ? 'Bravura' : null,
                        fontSize: fontSize,
                        fontWeight: FontWeight.bold,
                        color: Colors.black,
                      ),
                      textAlign: TextAlign.center,
                    ),
            )),
            if (isLocked)
              Positioned(
                bottom: 1,
                right: 1,
                child: Icon(
                  Icons.lock,
                  size: 10,
                  color: Colors.blue[900],
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class GuitarTechniqueButtonsPanel extends StatelessWidget {
  final double screenWidth;
  final double techniqueSpacing;

  final bool muteActive;
  final bool muteLocked;
  final VoidCallback onMutePressed;

  final bool pinchHarmonicActive;
  final bool pinchHarmonicLocked;
  final VoidCallback onPinchHarmonicPressed;

  final bool vibratoActive;
  final bool vibratoLocked;
  final VoidCallback onVibratoPressed;

  final bool hammerLeftHandActive;
  final bool hammerLeftHandLocked;
  final VoidCallback onHammerLeftHandPressed;

  final bool bendActive;
  final bool bendLocked;
  final VoidCallback onBendPressed;

  final bool preBendActive;
  final bool preBendLocked;
  final VoidCallback onPreBendPressed;

  final bool pickDownwardActive;
  final VoidCallback onPickDownwardPressed;

  final bool tapRightHandActive;
  final VoidCallback onTapRightHandPressed;

  final bool harmonicActive;
  final bool harmonicLocked;
  final VoidCallback onHarmonicPressed;

  final bool slideUpActive;
  final VoidCallback onSlideUpPressed;

  final bool slideDownActive;
  final VoidCallback onSlideDownPressed;

  final bool bendReleaseActive;
  final bool bendReleaseLocked;
  final VoidCallback onBendReleasePressed;

  final bool preBendReleaseActive;
  final bool preBendReleaseLocked;
  final VoidCallback onPreBendReleasePressed;

  final bool pickUpwardActive;
  final VoidCallback onPickUpwardPressed;

  const GuitarTechniqueButtonsPanel({
    super.key,
    required this.screenWidth,
    required this.techniqueSpacing,
    required this.muteActive,
    required this.muteLocked,
    required this.onMutePressed,
    required this.pinchHarmonicActive,
    required this.pinchHarmonicLocked,
    required this.onPinchHarmonicPressed,
    required this.vibratoActive,
    required this.vibratoLocked,
    required this.onVibratoPressed,
    required this.hammerLeftHandActive,
    required this.hammerLeftHandLocked,
    required this.onHammerLeftHandPressed,
    required this.bendActive,
    required this.bendLocked,
    required this.onBendPressed,
    required this.preBendActive,
    required this.preBendLocked,
    required this.onPreBendPressed,
    required this.pickDownwardActive,
    required this.onPickDownwardPressed,
    required this.tapRightHandActive,
    required this.onTapRightHandPressed,
    required this.harmonicActive,
    required this.harmonicLocked,
    required this.onHarmonicPressed,
    required this.slideUpActive,
    required this.onSlideUpPressed,
    required this.slideDownActive,
    required this.onSlideDownPressed,
    required this.bendReleaseActive,
    required this.bendReleaseLocked,
    required this.onBendReleasePressed,
    required this.preBendReleaseActive,
    required this.preBendReleaseLocked,
    required this.onPreBendReleasePressed,
    required this.pickUpwardActive,
    required this.onPickUpwardPressed,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        SizedBox(
          height: 37,
          width: screenWidth * 0.75,
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              GuitarTechniqueButton(
                'mute',
                'P.M.',
                fontSize: 12,
                isUnicode: false,
                onPressed: onMutePressed,
                isActive: muteActive,
                isLocked: muteLocked,
              ),
              SizedBox(width: techniqueSpacing),
              GuitarTechniqueButton(
                'pinch-harmonic',
                'P.H.',
                fontSize: 12,
                isUnicode: false,
                onPressed: onPinchHarmonicPressed,
                isActive: pinchHarmonicActive,
                isLocked: pinchHarmonicLocked,
              ),
              SizedBox(width: techniqueSpacing),
              GuitarTechniqueButton(
                'vibrato',
                '',
                fontSize: 20,
                offset: const Offset(0, 4),
                onPressed: onVibratoPressed,
                isActive: vibratoActive,
                isLocked: vibratoLocked,
              ),
              SizedBox(width: techniqueSpacing),
              GuitarTechniqueButton(
                'hammer-left-hand',
                '',
                fontSize: 38,
                offset: const Offset(0, -6),
                onPressed: onHammerLeftHandPressed,
                isActive: hammerLeftHandActive,
                isLocked: hammerLeftHandLocked,
              ),
              SizedBox(width: techniqueSpacing),
              GuitarTechniqueButton(
                'bend',
                'bend',
                svgAssetPath: 'assets/svgs/bend.svg',
                onPressed: onBendPressed,
                isActive: bendActive,
                isLocked: bendLocked,
              ),
              SizedBox(width: techniqueSpacing),
              GuitarTechniqueButton(
                'pre-bend',
                'pre-bend',
                svgAssetPath: 'assets/svgs/pre-bend.svg',
                onPressed: onPreBendPressed,
                isActive: preBendActive,
                isLocked: preBendLocked,
              ),
              SizedBox(width: techniqueSpacing),
              GuitarTechniqueButton(
                'pick-downward',
                '',
                fontSize: 30,
                offset: const Offset(0, 3),
                onPressed: onPickDownwardPressed,
                isActive: pickDownwardActive,
                isLocked: false,
              ),
            ],
          ),
        ),
        const SizedBox(height: 7),
        SizedBox(
          height: 37,
          width: screenWidth * 0.75,
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              GuitarTechniqueButton(
                'tap-right-hand',
                '',
                fontSize: 16,
                offset: const Offset(0, 7),
                onPressed: onTapRightHandPressed,
                isActive: tapRightHandActive,
                isLocked: false,
              ),
              SizedBox(width: techniqueSpacing),
              GuitarTechniqueButton(
                'harmonic',
                'Ham.',
                fontSize: 12,
                isUnicode: false,
                onPressed: onHarmonicPressed,
                isActive: harmonicActive,
                isLocked: harmonicLocked,
              ),
              SizedBox(width: techniqueSpacing),
              GuitarTechniqueButton(
                'slide-up',
                '',
                fontSize: 40,
                offset: const Offset(0, -7),
                onPressed: onSlideUpPressed,
                isActive: slideUpActive,
              ),
              SizedBox(width: techniqueSpacing),
              GuitarTechniqueButton(
                'slide-down',
                '',
                fontSize: 40,
                offset: const Offset(0, -7),
                onPressed: onSlideDownPressed,
                isActive: slideDownActive,
              ),
              SizedBox(width: techniqueSpacing),
              GuitarTechniqueButton(
                'bend-release',
                'bend-release',
                svgAssetPath: 'assets/svgs/bend-release.svg',
                onPressed: onBendReleasePressed,
                isActive: bendReleaseActive,
                isLocked: bendReleaseLocked,
              ),
              SizedBox(width: techniqueSpacing),
              GuitarTechniqueButton(
                'pre-bend-release',
                'pre-bend-release',
                svgAssetPath: 'assets/svgs/pre-bend-release.svg',
                onPressed: onPreBendReleasePressed,
                isActive: preBendReleaseActive,
                isLocked: preBendReleaseLocked,
              ),
              SizedBox(width: techniqueSpacing),
              GuitarTechniqueButton(
                'pick-upward',
                '',
                fontSize: 30,
                offset: const Offset(0, 5),
                onPressed: onPickUpwardPressed,
                isActive: pickUpwardActive,
                isLocked: false,
              ),
            ],
          ),
        ),
      ],
    );
  }
}
