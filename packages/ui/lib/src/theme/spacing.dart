import 'package:flutter/widgets.dart';

/// 4px-grid spacing scale (style §3). Every gap/padding is a multiple of 4 so
/// the whole product breathes consistently.
class AppSpacing {
  const AppSpacing();
  final double xs = 4;
  final double sm = 8;
  final double mdSm = 12;
  final double md = 16;
  final double mdLg = 20; // preferred card inner padding
  final double lg = 24;
  final double xl = 32; // screen horizontal padding
  final double xxl = 40;
  final double xxxl = 48;
}

/// Corner-radius scale (style §4). Hard rule: never a 0px corner; min 8.
class AppRadii {
  const AppRadii();
  final double sm = 8;
  final double input = 13;
  final double button = 15;
  final double card = 20;
  final double feature = 26;
  final double sheet = 24;
  final double pill = 999;

  BorderRadius get cardR => BorderRadius.circular(card);
  BorderRadius get buttonR => BorderRadius.circular(button);
  BorderRadius get inputR => BorderRadius.circular(input);
  BorderRadius get featureR => BorderRadius.circular(feature);
  BorderRadius get pillR => BorderRadius.circular(pill);
  BorderRadius get sheetTop =>
      const BorderRadius.vertical(top: Radius.circular(24));
}

/// Motion durations + curves (style §6). One vocabulary across the whole app.
class AppMotion {
  const AppMotion();
  final Duration fast = const Duration(milliseconds: 150);
  final Duration base = const Duration(milliseconds: 220);
  final Duration slow = const Duration(milliseconds: 320);
  final Duration screen = const Duration(milliseconds: 350);
  final Duration celebrate = const Duration(milliseconds: 500);

  // Never `linear` for UI (style §6.11). Standard material + an overshoot.
  final Curve standard = Curves.easeInOutCubic;
  final Curve emphasized = Curves.easeOutCubic;
  final Curve overshoot = Curves.easeOutBack;
  final Curve enter = Curves.easeOut;
}

const appSpacing = AppSpacing();
const appRadii = AppRadii();
const appMotion = AppMotion();
