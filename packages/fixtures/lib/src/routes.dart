enum FixtureNavigationIntent { coldStart, webRefresh, nativeLocation }

final class RouteFixture {
  const RouteFixture({
    required this.template,
    required this.location,
    required this.intent,
  });

  final String template;
  final String location;
  final FixtureNavigationIntent intent;
}

abstract final class FixtureRoutes {
  static const academyCourse = RouteFixture(
    template: '/academy/course/:courseId',
    location: '/academy/course/course.fixture.001',
    intent: FixtureNavigationIntent.coldStart,
  );
  static const legacyEcg = RouteFixture(
    template: '/clinical/ecg/case/:caseId',
    location: '/clinical/ecg/case/case.fixture.001',
    intent: FixtureNavigationIntent.webRefresh,
  );
  static const libraryEntry = RouteFixture(
    template: '/library/diseases/:id',
    location: '/library/diseases/disease.fixture.001',
    intent: FixtureNavigationIntent.nativeLocation,
  );

  static const all = [academyCourse, legacyEcg, libraryEntry];
}
