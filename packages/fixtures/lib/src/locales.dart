enum FixtureTextDirection { ltr, rtl }

final class LocaleFixture {
  const LocaleFixture({
    required this.locale,
    required this.direction,
    required this.strings,
  });

  final String locale;
  final FixtureTextDirection direction;
  final Map<String, String> strings;
}

abstract final class FixtureLocales {
  static const english = LocaleFixture(
    locale: 'en',
    direction: FixtureTextDirection.ltr,
    strings: {
      'academy.continue': 'Continue learning',
      'academy.review': 'Review due',
      'evidence.open': 'Open evidence',
    },
  );
  static const persian = LocaleFixture(
    locale: 'fa',
    direction: FixtureTextDirection.rtl,
    strings: {
      'academy.continue': 'ادامه یادگیری',
      'academy.review': 'مرورهای امروز',
      'evidence.open': 'مشاهده شواهد',
    },
  );

  static const all = [english, persian];
}
