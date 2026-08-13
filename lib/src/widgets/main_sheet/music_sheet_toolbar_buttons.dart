import 'package:flutter/material.dart';
import 'package:flutter_svg/svg.dart';

Widget buildStyledButton(
    String label, VoidCallback onPressed, bool useBravura, bool isAdd,
    {String? svgAssetPath}) {
  return Row(
    children: [
      Text(
        isAdd ? '+' : 'x',
        style: TextStyle(
          color: isAdd ? Color.fromARGB(255, 63, 63, 63) : Colors.red,
          fontSize: 21,
        ),
      ),
      const SizedBox(width: 2),
      Material(
        color: Colors.transparent,
        elevation: 5,
        shadowColor: Colors.black.withOpacity(0.3),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(25),
        ),
        child: RawMaterialButton(
          onPressed: onPressed,
          fillColor: Colors.white,
          constraints: const BoxConstraints.tightFor(width: 50, height: 35),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(25),
            side:
                BorderSide(color: isAdd ? Colors.black : Colors.red, width: 1),
          ),
          materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
          child: useBravura
              ? Transform.translate(
                  offset: label == '' || label == ''
                      ? const Offset(1, 5) // placeholder-marker-A
                      : const Offset(2, 2),
                  child: Text(
                    label,
                    style: TextStyle(
                      color: Colors.black,
                      fontSize:
                          label == '' || label == '' ? 27 : 22,
                      fontFamily: 'Bravura',
                    ),
                  ))
              : svgAssetPath != null
                  ? SvgPicture.asset(svgAssetPath,
                      width: 20,
                      height: 20,
                      colorFilter: ColorFilter.linearToSrgbGamma())
                  : Text(
                      label,
                      style: const TextStyle(
                          fontSize: 12,
                          color: Colors.black,
                          fontWeight: FontWeight.bold),
                    ),
        ),
      ),
    ],
  );
}

Widget buildBendsToggleButton(bool isOpen, VoidCallback onPressed) {
  return Row(
    children: [
      const SizedBox(width: 13),
      Material(
        color: Colors.transparent,
        elevation: 5,
        shadowColor: Colors.black.withOpacity(0.3),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(25),
        ),
        child: RawMaterialButton(
          onPressed: onPressed,
          fillColor: Colors.white,
          constraints: const BoxConstraints.tightFor(width: 50, height: 35),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(25),
            side: BorderSide(
              color: isOpen ? Colors.red : Colors.black,
              width: 1,
            ),
          ),
          materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
          child: Text(
            isOpen ? 'X' : 'BENDS',
            style: TextStyle(
              fontSize: isOpen ? 14 : 10,
              color: isOpen ? Colors.red : Colors.black,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
      ),
    ],
  );
}

Widget buildNoteFlipButton(
    String label, VoidCallback onPressed, bool? isUpsideDown) {
  return Material(
    color: Colors.transparent,
    elevation: 5,
    shadowColor: Colors.black.withOpacity(0.3),
    shape: RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(25),
    ),
    child: RawMaterialButton(
      onPressed: onPressed,
      fillColor: Colors.white,
      constraints: const BoxConstraints.tightFor(width: 110, height: 25),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(25),
        side: BorderSide(color: Colors.black, width: 1),
      ),
      materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
      child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
        Transform.translate(
            offset: Offset(0, -5),
            child: Text(
              isUpsideDown == true ? '↓' : '↑',
              style: TextStyle(
                color: Colors.black,
                fontSize: 21,
              ),
            )),
        SizedBox(
          width: 3,
        ),
        Text(
          label,
          style: const TextStyle(
              fontSize: 12, color: Colors.black, fontWeight: FontWeight.bold),
        ),
      ]),
    ),
  );
}
