import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:synapse_core/synapse_core.dart';
import 'package:synapse_services/synapse_services.dart';
import 'package:synapse_ui/synapse_ui.dart';

import '../../brand/synapse_identity.dart';
import '../../router/routes.dart';
import '../../state/curriculum_provider.dart';
import '../../state/personal_sync_provider.dart';
import '../../state/settings_provider.dart';

/// The learner-facing entry to the signed curriculum package runtime.
///
/// This feature deliberately has no bundled lesson text, question text, or
/// clinical claims. Every learner-visible course, session, prompt, option and
/// explanation is resolved from the active reviewed package at runtime.
class AcademyHomeScreen extends ConsumerWidget {
  const AcademyHomeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final locale = _contentLocale(ref.watch(settingsProvider).locale);
    final runtime = ref.watch(curriculumRuntimeProvider);
    return _AcademyCanvas(
      child: SafeArea(
        child: _AcademyShell(
          onBack: () => _leaveAcademy(context),
          child: runtime.when(
            loading: () => const _AcademyLoading(),
            error: (_, _) => _AcademyRuntimeFailure(
              locale: locale,
              status: CurriculumRuntimeBootstrapStatus.failed,
              onRetry: () => ref.invalidate(curriculumRuntimeProvider),
            ),
            data: (result) => switch (result.status) {
              CurriculumRuntimeBootstrapStatus.ready => _AcademyCatalogHome(
                locale: locale,
                catalog: result.catalog!,
              ),
              CurriculumRuntimeBootstrapStatus.noActiveRelease =>
                _AcademyNoActivePackage(locale: locale),
              _ => _AcademyRuntimeFailure(
                locale: locale,
                status: result.status,
                onRetry: result.canRetry
                    ? () => ref.invalidate(curriculumRuntimeProvider)
                    : null,
              ),
            },
          ),
        ),
      ),
    );
  }
}

/// A sparse, course-level path view. It is intentionally not another
/// dashboard: one primary next action, then the actual curriculum hierarchy.
class AcademyCourseScreen extends ConsumerWidget {
  const AcademyCourseScreen({super.key, required this.courseId});

  final String courseId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final locale = _contentLocale(ref.watch(settingsProvider).locale);
    final runtime = ref.watch(curriculumRuntimeProvider);
    return _AcademyCanvas(
      child: SafeArea(
        child: _AcademyShell(
          onBack: () => _leaveAcademy(context),
          child: runtime.when(
            loading: () => const _AcademyLoading(),
            error: (_, _) => _AcademyRuntimeFailure(
              locale: locale,
              status: CurriculumRuntimeBootstrapStatus.failed,
              onRetry: () => ref.invalidate(curriculumRuntimeProvider),
            ),
            data: (result) {
              if (result.status != CurriculumRuntimeBootstrapStatus.ready) {
                return _runtimeStateFor(result, locale, ref);
              }
              final catalog = result.catalog!;
              final course = catalog.entryById(courseId);
              if (course == null ||
                  course.node.kind != CurriculumNodeKind.course) {
                return _AcademyRouteUnavailable(locale: locale);
              }
              return _AcademyCoursePath(
                locale: locale,
                catalog: catalog,
                course: course,
              );
            },
          ),
        ),
      ),
    );
  }
}

/// The full-screen, package-driven micro-session player.
///
/// The player supports only runtime templates it can present faithfully. An
/// unsupported approved template remains explicitly unavailable; it is never
/// replaced by an improvised question, answer, citation, or medical claim.
class AcademySessionScreen extends ConsumerWidget {
  const AcademySessionScreen({
    super.key,
    required this.microLessonNodeId,
    required this.sessionId,
  });

  final String microLessonNodeId;
  final String sessionId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final locale = _contentLocale(ref.watch(settingsProvider).locale);
    final runtime = ref.watch(curriculumRuntimeProvider);
    return _AcademyCanvas(
      child: SafeArea(
        child: runtime.when(
          loading: () => const _AcademyLoading(),
          error: (_, _) => _AcademyRuntimeFailure(
            locale: locale,
            status: CurriculumRuntimeBootstrapStatus.failed,
            onRetry: () => ref.invalidate(curriculumRuntimeProvider),
          ),
          data: (result) {
            if (result.status != CurriculumRuntimeBootstrapStatus.ready) {
              return _AcademyShell(
                onBack: () => _leaveAcademy(context),
                child: _runtimeStateFor(result, locale, ref),
              );
            }
            return _AcademySessionPlayer(
              catalog: result.catalog!,
              locale: locale,
              microLessonNodeId: microLessonNodeId,
              sessionId: sessionId,
            );
          },
        ),
      ),
    );
  }
}

Widget _runtimeStateFor(
  CurriculumRuntimeBootstrapResult result,
  ContentLocale locale,
  WidgetRef ref,
) {
  return switch (result.status) {
    CurriculumRuntimeBootstrapStatus.noActiveRelease => _AcademyNoActivePackage(
      locale: locale,
    ),
    CurriculumRuntimeBootstrapStatus.ready => const SizedBox.shrink(),
    _ => _AcademyRuntimeFailure(
      locale: locale,
      status: result.status,
      onRetry: result.canRetry
          ? () => ref.invalidate(curriculumRuntimeProvider)
          : null,
    ),
  };
}

class _AcademyCanvas extends StatelessWidget {
  const _AcademyCanvas({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _AcademyColors.midnight,
      body: DecoratedBox(
        decoration: const BoxDecoration(
          gradient: RadialGradient(
            center: Alignment(-0.72, -0.92),
            radius: 1.32,
            colors: [_AcademyColors.topGlow, _AcademyColors.midnight],
            stops: [0, 0.82],
          ),
        ),
        child: Stack(
          children: [
            const Positioned.fill(child: _AcademyConstellation()),
            child,
          ],
        ),
      ),
    );
  }
}

class _AcademyShell extends StatelessWidget {
  const _AcademyShell({required this.child, required this.onBack});

  final Widget child;
  final VoidCallback onBack;

  @override
  Widget build(BuildContext context) {
    return ContentBounds(
      maxWidth: 1120,
      child: Column(
        children: [
          _AcademyTopBar(onBack: onBack),
          Expanded(child: child),
        ],
      ),
    );
  }
}

class _AcademyTopBar extends StatelessWidget {
  const _AcademyTopBar({required this.onBack});

  final VoidCallback onBack;

  @override
  Widget build(BuildContext context) {
    final compact = context.bp.isCompact;
    final copy = _AcademyCopy(
      _contentLocale(Localizations.localeOf(context).languageCode),
    );
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 8, 20, 8),
      child: Row(
        children: [
          AppIconButton(
            icon: Icons.arrow_back_rounded,
            tooltip: copy.back,
            color: Colors.white70,
            onPressed: onBack,
          ),
          const SizedBox(width: 10),
          const SynapseWordmark(
            variant: SynapseWordmarkVariant.frost,
            height: 24,
          ),
          const Spacer(),
          _AcademyStatusChip(compact: compact),
        ],
      ),
    );
  }
}

class _AcademyStatusChip extends StatelessWidget {
  const _AcademyStatusChip({required this.compact});

  final bool compact;

  @override
  Widget build(BuildContext context) {
    final copy = _AcademyCopy(
      _contentLocale(Localizations.localeOf(context).languageCode),
    );
    return Semantics(
      label: copy.reviewedLearning,
      child: Tooltip(
        message: copy.reviewedLearning,
        child: Container(
          constraints: const BoxConstraints(minWidth: 40, minHeight: 40),
          padding: EdgeInsets.symmetric(
            horizontal: compact ? 10 : 12,
            vertical: 6,
          ),
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.055),
            borderRadius: BorderRadius.circular(99),
            border: Border.all(color: Colors.white.withValues(alpha: 0.12)),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(
                Icons.verified_user_outlined,
                size: 16,
                color: _AcademyColors.cyan,
              ),
              if (!compact) ...[
                const SizedBox(width: 6),
                Text(
                  copy.reviewedLearning,
                  style: const TextStyle(
                    color: Colors.white70,
                    fontSize: 11.5,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

/// Centres a calm state on generous displays while allowing it to scroll on
/// short windows, split-screen phones and enlarged-text environments.
class _AcademyViewportCenter extends StatelessWidget {
  const _AcademyViewportCenter({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) => SingleChildScrollView(
        padding: EdgeInsets.zero,
        child: ConstrainedBox(
          constraints: BoxConstraints(
            minHeight: constraints.hasBoundedHeight ? constraints.maxHeight : 0,
          ),
          child: Center(child: child),
        ),
      ),
    );
  }
}

class _AcademyLoading extends StatelessWidget {
  const _AcademyLoading();

  @override
  Widget build(BuildContext context) {
    return _AcademyViewportCenter(
      child: Semantics(
        label: 'Loading reviewed learning path',
        child: SizedBox(
          width: 32,
          height: 32,
          child: CircularProgressIndicator(color: _AcademyColors.cyan),
        ),
      ),
    );
  }
}

class _AcademyNoActivePackage extends StatelessWidget {
  const _AcademyNoActivePackage({required this.locale});

  final ContentLocale locale;

  @override
  Widget build(BuildContext context) {
    final copy = _AcademyCopy(locale);
    return _AcademyViewportCenter(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 560),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(24, 24, 24, 48),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              SynapseCompanion(
                pose: SynapseCompanionPose.thinking,
                size: 156,
                semanticLabel: copy.companionWaiting,
              ),
              const SizedBox(height: 16),
              Text(
                copy.noPackageTitle,
                textAlign: TextAlign.center,
                style: _academyTitle(context),
              ),
              const SizedBox(height: 10),
              Text(
                copy.noPackageBody,
                textAlign: TextAlign.center,
                style: _academyBody(context),
              ),
              const SizedBox(height: 24),
              _TruthNote(text: copy.noPackageNote),
            ],
          ),
        ),
      ),
    );
  }
}

class _AcademyRuntimeFailure extends StatelessWidget {
  const _AcademyRuntimeFailure({
    required this.locale,
    required this.status,
    this.onRetry,
  });

  final ContentLocale locale;
  final CurriculumRuntimeBootstrapStatus status;
  final VoidCallback? onRetry;

  @override
  Widget build(BuildContext context) {
    final copy = _AcademyCopy(locale);
    final message = switch (status) {
      CurriculumRuntimeBootstrapStatus.integrityBlocked => copy.integrityBody,
      CurriculumRuntimeBootstrapStatus.unsupportedSchema => copy.schemaBody,
      CurriculumRuntimeBootstrapStatus.failed => copy.runtimeFailureBody,
      _ => copy.runtimeFailureBody,
    };
    return _AcademyViewportCenter(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 560),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(24, 24, 24, 48),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              SynapseCompanion(
                pose: SynapseCompanionPose.evidenceGuide,
                size: 150,
                semanticLabel: copy.companionSafety,
              ),
              const SizedBox(height: 16),
              Text(
                copy.runtimeFailureTitle,
                textAlign: TextAlign.center,
                style: _academyTitle(context),
              ),
              const SizedBox(height: 10),
              Text(
                message,
                textAlign: TextAlign.center,
                style: _academyBody(context),
              ),
              if (onRetry != null) ...[
                const SizedBox(height: 24),
                AppButton(
                  label: copy.retry,
                  icon: Icons.refresh_rounded,
                  accent: _AcademyColors.cyan,
                  onPressed: onRetry,
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _AcademyRouteUnavailable extends StatelessWidget {
  const _AcademyRouteUnavailable({required this.locale});

  final ContentLocale locale;

  @override
  Widget build(BuildContext context) {
    final copy = _AcademyCopy(locale);
    return _AcademyViewportCenter(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 480),
        child: Padding(
          padding: const EdgeInsets.all(28),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              SynapseCompanion(
                pose: SynapseCompanionPose.thinking,
                size: 132,
                semanticLabel: copy.companionWaiting,
              ),
              const SizedBox(height: 14),
              Text(
                copy.routeUnavailableTitle,
                style: _academyTitle(context),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 8),
              Text(
                copy.routeUnavailableBody,
                style: _academyBody(context),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _AcademyCatalogHome extends StatelessWidget {
  const _AcademyCatalogHome({required this.locale, required this.catalog});

  final ContentLocale locale;
  final CurriculumCatalogSnapshot catalog;

  @override
  Widget build(BuildContext context) {
    final copy = _AcademyCopy(locale);
    final courses = catalog.courses;
    if (courses.isEmpty) return _AcademyRouteUnavailable(locale: locale);
    final first = courses.first;

    return CustomScrollView(
      slivers: [
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(24, 28, 24, 18),
            child: _AcademyHero(
              locale: locale,
              catalog: catalog,
              primaryCourse: first,
            ),
          ),
        ),
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(24, 8, 24, 12),
            child: Text(
              copy.courseLibrary,
              style: _academySectionTitle(context),
            ),
          ),
        ),
        SliverPadding(
          padding: const EdgeInsets.fromLTRB(24, 0, 24, 48),
          sliver: SliverList.separated(
            itemCount: courses.length,
            separatorBuilder: (_, _) => const SizedBox(height: 10),
            itemBuilder: (context, index) {
              final course = courses[index];
              final launch = _firstLaunchTarget(catalog, course.node.id);
              return _CourseRow(
                locale: locale,
                course: course,
                hasLaunchableSession: launch != null,
                onTap: () =>
                    context.push(Routes.academyCourseFor(course.node.id)),
              );
            },
          ),
        ),
      ],
    );
  }
}

class _AcademyHero extends StatelessWidget {
  const _AcademyHero({
    required this.locale,
    required this.catalog,
    required this.primaryCourse,
  });

  final ContentLocale locale;
  final CurriculumCatalogSnapshot catalog;
  final CurriculumCatalogEntry primaryCourse;

  @override
  Widget build(BuildContext context) {
    final copy = _AcademyCopy(locale);
    final launch = _firstLaunchTarget(catalog, primaryCourse.node.id);
    final compact = context.bp.isCompact;
    return Container(
      padding: EdgeInsets.fromLTRB(
        compact ? 20 : 28,
        24,
        compact ? 20 : 18,
        24,
      ),
      decoration: BoxDecoration(
        color: _AcademyColors.panel.withValues(alpha: 0.88),
        borderRadius: BorderRadius.circular(28),
        border: Border.all(color: _AcademyColors.cyan.withValues(alpha: 0.32)),
        boxShadow: [
          BoxShadow(
            color: _AcademyColors.cyan.withValues(alpha: 0.10),
            blurRadius: 44,
            spreadRadius: -12,
          ),
        ],
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                AppBadge(
                  label: copy.pathReady,
                  color: _AcademyColors.cyan,
                  subtle: true,
                ),
                const SizedBox(height: 14),
                Text(copy.heroTitle, style: _academyHeroTitle(context)),
                const SizedBox(height: 8),
                Text(copy.heroBody, style: _academyBody(context)),
                const SizedBox(height: 18),
                Text(
                  primaryCourse.title(locale),
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    color: Colors.white,
                    fontWeight: FontWeight.w800,
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 14),
                AppButton(
                  label: launch == null ? copy.explorePath : copy.startPath,
                  size: AppButtonSize.medium,
                  icon: launch == null
                      ? Icons.account_tree_outlined
                      : Icons.play_arrow_rounded,
                  accent: _AcademyColors.cyan,
                  onPressed: () {
                    if (launch == null) {
                      context.push(
                        Routes.academyCourseFor(primaryCourse.node.id),
                      );
                      return;
                    }
                    context.push(
                      Routes.academySessionFor(
                        launch.microLessonNodeId,
                        launch.sessionId,
                      ),
                    );
                  },
                ),
              ],
            ),
          ),
          if (!compact) ...[
            const SizedBox(width: 16),
            SynapseCompanion(
              pose: SynapseCompanionPose.heroPointing,
              size: 168,
              semanticLabel: copy.companionEncouraging,
            ),
          ],
        ],
      ),
    );
  }
}

class _CourseRow extends StatelessWidget {
  const _CourseRow({
    required this.locale,
    required this.course,
    required this.hasLaunchableSession,
    required this.onTap,
  });

  final ContentLocale locale;
  final CurriculumCatalogEntry course;
  final bool hasLaunchableSession;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final copy = _AcademyCopy(locale);
    return Semantics(
      button: true,
      label: '${copy.course}: ${course.title(locale)}',
      child: AppCard(
        color: _AcademyColors.panel.withValues(alpha: 0.74),
        accent: hasLaunchableSession ? _AcademyColors.cyan : Colors.white38,
        onTap: onTap,
        child: Row(
          children: [
            Container(
              width: 48,
              height: 48,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: _AcademyColors.cyan.withValues(alpha: 0.13),
                shape: BoxShape.circle,
              ),
              child: Icon(
                hasLaunchableSession
                    ? Icons.route_rounded
                    : Icons.menu_book_outlined,
                color: _AcademyColors.cyan,
              ),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    copy.course.toUpperCase(),
                    style: const TextStyle(
                      color: _AcademyColors.cyan,
                      fontSize: 11,
                      letterSpacing: 1.15,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    course.title(locale),
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      color: Colors.white,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              ),
            ),
            Icon(
              Icons.chevron_right_rounded,
              color: Colors.white.withValues(alpha: 0.65),
            ),
          ],
        ),
      ),
    );
  }
}

class _AcademyCoursePath extends StatelessWidget {
  const _AcademyCoursePath({
    required this.locale,
    required this.catalog,
    required this.course,
  });

  final ContentLocale locale;
  final CurriculumCatalogSnapshot catalog;
  final CurriculumCatalogEntry course;

  @override
  Widget build(BuildContext context) {
    final copy = _AcademyCopy(locale);
    final preview = _pathPreview(catalog, course.node.id);
    final chapters = catalog.childrenOf(course.node.id);
    final launch = _firstLaunchTarget(catalog, course.node.id);

    return CustomScrollView(
      slivers: [
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(24, 26, 24, 12),
            child: Text(copy.coursePath, style: _academyEyebrow(context)),
          ),
        ),
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(24, 0, 24, 22),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        course.title(locale),
                        style: _academyHeroTitle(context),
                      ),
                      const SizedBox(height: 9),
                      Text(copy.coursePathBody, style: _academyBody(context)),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                SynapseCompanion(
                  pose: SynapseCompanionPose.encouraging,
                  size: 92,
                  semanticLabel: copy.companionEncouraging,
                ),
              ],
            ),
          ),
        ),
        if (launch != null)
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(24, 0, 24, 22),
              child: Column(
                children: [
                  AppButton(
                    label: copy.startPath,
                    icon: Icons.play_arrow_rounded,
                    expand: true,
                    accent: _AcademyColors.cyan,
                    onPressed: () => context.push(
                      Routes.academySessionFor(
                        launch.microLessonNodeId,
                        launch.sessionId,
                      ),
                    ),
                  ),
                  const SizedBox(height: 10),
                  AppButton(
                    label: copy.openStudyWorkspace,
                    icon: Icons.auto_stories_rounded,
                    expand: true,
                    variant: AppButtonVariant.secondary,
                    accent: _AcademyColors.cyan,
                    onPressed: () => context.push(
                      Routes.academyWorkspaceFor(launch.microLessonNodeId),
                    ),
                  ),
                ],
              ),
            ),
          ),
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(24, 0, 24, 10),
            child: Text(
              copy.nextSequence,
              style: _academySectionTitle(context),
            ),
          ),
        ),
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(24, 0, 24, 26),
            child: _CurriculumPathRail(locale: locale, entries: preview),
          ),
        ),
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(24, 0, 24, 10),
            child: Text(copy.chapters, style: _academySectionTitle(context)),
          ),
        ),
        SliverPadding(
          padding: const EdgeInsets.fromLTRB(24, 0, 24, 48),
          sliver: SliverList.separated(
            itemCount: chapters.length,
            separatorBuilder: (_, _) => const SizedBox(height: 10),
            itemBuilder: (context, index) => _ChapterRow(
              locale: locale,
              chapter: chapters[index],
              isActive: _containsLaunchTarget(catalog, chapters[index].node.id),
            ),
          ),
        ),
      ],
    );
  }
}

class _CurriculumPathRail extends StatelessWidget {
  const _CurriculumPathRail({required this.locale, required this.entries});

  final ContentLocale locale;
  final List<CurriculumCatalogEntry> entries;

  @override
  Widget build(BuildContext context) {
    final copy = _AcademyCopy(locale);
    if (entries.isEmpty) {
      return _TruthNote(text: copy.noPathNodes);
    }
    return Column(
      children: [
        for (var index = 0; index < entries.length; index++)
          _CurriculumPathNode(
            locale: locale,
            entry: entries[index],
            isLast: index == entries.length - 1,
            isCurrent: index == entries.length - 1,
          ),
      ],
    );
  }
}

class _CurriculumPathNode extends StatelessWidget {
  const _CurriculumPathNode({
    required this.locale,
    required this.entry,
    required this.isLast,
    required this.isCurrent,
  });

  final ContentLocale locale;
  final CurriculumCatalogEntry entry;
  final bool isLast;
  final bool isCurrent;

  @override
  Widget build(BuildContext context) {
    final copy = _AcademyCopy(locale);
    final accent = isCurrent ? _AcademyColors.cyan : Colors.white60;
    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          SizedBox(
            width: 42,
            child: Column(
              children: [
                Container(
                  width: 28,
                  height: 28,
                  decoration: BoxDecoration(
                    color: accent.withValues(alpha: isCurrent ? 0.18 : 0.09),
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: accent.withValues(alpha: 0.82),
                      width: 1.4,
                    ),
                  ),
                  child: Icon(
                    _nodeIcon(entry.node.kind),
                    size: 15,
                    color: accent,
                  ),
                ),
                if (!isLast)
                  Expanded(
                    child: Container(
                      width: 2,
                      margin: const EdgeInsets.symmetric(vertical: 5),
                      color: Colors.white.withValues(alpha: 0.16),
                    ),
                  ),
              ],
            ),
          ),
          Expanded(
            child: Padding(
              padding: EdgeInsets.only(bottom: isLast ? 0 : 14),
              child: Container(
                padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
                decoration: BoxDecoration(
                  color: _AcademyColors.panel.withValues(
                    alpha: isCurrent ? 0.88 : 0.56,
                  ),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                    color: accent.withValues(alpha: isCurrent ? 0.32 : 0.14),
                  ),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      _nodeLabel(copy, entry.node.kind).toUpperCase(),
                      style: TextStyle(
                        color: accent,
                        fontSize: 10.5,
                        letterSpacing: 1.08,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      entry.title(locale),
                      style: Theme.of(context).textTheme.titleSmall?.copyWith(
                        color: Colors.white,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _ChapterRow extends StatelessWidget {
  const _ChapterRow({
    required this.locale,
    required this.chapter,
    required this.isActive,
  });

  final ContentLocale locale;
  final CurriculumCatalogEntry chapter;
  final bool isActive;

  @override
  Widget build(BuildContext context) {
    final copy = _AcademyCopy(locale);
    return AppCard(
      color: _AcademyColors.panel.withValues(alpha: 0.64),
      accent: isActive ? _AcademyColors.cyan : Colors.white24,
      child: Row(
        children: [
          Icon(
            isActive
                ? Icons.play_circle_outline_rounded
                : Icons.lock_outline_rounded,
            color: isActive ? _AcademyColors.cyan : Colors.white54,
          ),
          const SizedBox(width: 13),
          Expanded(
            child: Text(
              chapter.title(locale),
              style: Theme.of(context).textTheme.titleSmall?.copyWith(
                color: Colors.white,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
          Text(
            isActive ? copy.nextUp : copy.inSequence,
            style: TextStyle(
              color: isActive ? _AcademyColors.cyan : Colors.white54,
              fontSize: 12,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}

class _AcademySessionPlayer extends ConsumerStatefulWidget {
  const _AcademySessionPlayer({
    required this.catalog,
    required this.locale,
    required this.microLessonNodeId,
    required this.sessionId,
  });

  final CurriculumCatalogSnapshot catalog;
  final ContentLocale locale;
  final String microLessonNodeId;
  final String sessionId;

  @override
  ConsumerState<_AcademySessionPlayer> createState() =>
      _AcademySessionPlayerState();
}

class _AcademySessionPlayerState extends ConsumerState<_AcademySessionPlayer> {
  bool _mutating = false;
  bool _showWriteFailure = false;
  bool _justCompleted = false;

  @override
  Widget build(BuildContext context) {
    final microLesson = widget.catalog.microLessonForNode(
      widget.microLessonNodeId,
    );
    final sessions = microLesson == null
        ? const <CurriculumSession>[]
        : widget.catalog.sessionsForMicroLesson(microLesson.id);
    final session = _firstWhereOrNull(
      sessions,
      (item) => item.id == widget.sessionId,
    );
    if (microLesson == null || session == null) {
      return _AcademyShell(
        onBack: () => _leaveAcademy(context),
        child: _AcademyRouteUnavailable(locale: widget.locale),
      );
    }

    final interactions = widget.catalog.interactionsForSession(session.id);
    if (interactions.isEmpty) {
      return _AcademyShell(
        onBack: () => _leaveAcademy(context),
        child: _AcademyRouteUnavailable(locale: widget.locale),
      );
    }
    final key = CurriculumSessionProgressKey(
      releaseId: widget.catalog.releaseId,
      microLessonNodeId: widget.microLessonNodeId,
      sessionId: session.id,
    );
    final progress = ref.watch(curriculumSessionProgressProvider(key));
    return progress.when(
      loading: () => const _AcademyLoading(),
      error: (_, _) => _AcademyShell(
        onBack: () => _leaveAcademy(context),
        child: _AcademyProgressFailure(
          locale: widget.locale,
          onRetry: () => ref.invalidate(curriculumSessionProgressProvider(key)),
        ),
      ),
      data: (checkpoint) => _buildCheckpoint(
        key: key,
        session: session,
        interactions: interactions,
        checkpoint: checkpoint,
      ),
    );
  }

  Widget _buildCheckpoint({
    required CurriculumSessionProgressKey key,
    required CurriculumSession session,
    required List<CurriculumInteraction> interactions,
    required CurriculumSessionProgress checkpoint,
  }) {
    if (checkpoint.isCompleted) {
      final courseId = widget.catalog
          .ancestorsOf(widget.microLessonNodeId)
          .where((entry) => entry.node.kind == CurriculumNodeKind.course)
          .firstOrNull
          ?.node
          .id;
      return _AcademyShell(
        onBack: () => _leaveAcademy(context),
        child: _AcademyCompletedSession(
          locale: widget.locale,
          justCompleted: _justCompleted,
          onBackToPath: () => context.go(
            courseId == null
                ? Routes.academy
                : Routes.academyCourseFor(courseId),
          ),
        ),
      );
    }
    if (checkpoint.interactionIndex >= interactions.length) {
      return _AcademyShell(
        onBack: () => _leaveAcademy(context),
        child: _AcademyProgressFailure(
          locale: widget.locale,
          onRetry: () => ref.invalidate(curriculumSessionProgressProvider(key)),
        ),
      );
    }

    final index = checkpoint.interactionIndex;
    final interaction = interactions[index];
    final supported = _isSupported(interaction);
    final copy = _AcademyCopy(widget.locale);
    final progress = (index + 1) / interactions.length;
    final response = checkpoint.responseFor(interaction.id);
    final feedback = response == null
        ? null
        : _feedbackFor(widget.catalog, interaction, response, widget.locale);
    final canAdvancePassive =
        interaction.responseSpec.kind == ResponseKind.none;
    final action = _SessionAction(
      label: _actionLabel(
        copy,
        supported: supported,
        hasFeedback: feedback != null,
        isPassive: canAdvancePassive,
        isLast: index == interactions.length - 1,
      ),
      enabled:
          !_mutating &&
          (!supported ||
              feedback != null ||
              canAdvancePassive ||
              checkpoint.selectedOptionId != null),
      onPressed: () => _onPrimary(
        key: key,
        checkpoint: checkpoint,
        interaction: interaction,
        totalInteractions: interactions.length,
        supported: supported,
        hasResponse: response != null,
      ),
    );

    return Column(
      children: [
        _SessionTopBar(
          progress: progress,
          trailing: '${index + 1}/${interactions.length}',
          onClose: () => _leaveAcademy(context),
          onWorkspace: () => context.push(
            Routes.academyWorkspaceFor(widget.microLessonNodeId),
          ),
        ),
        Expanded(
          child: ContentBounds(
            maxWidth: 780,
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(24, 24, 24, 18),
              child: Directionality(
                textDirection: widget.locale == ContentLocale.fa
                    ? TextDirection.rtl
                    : TextDirection.ltr,
                child: _InteractionCard(
                  locale: widget.locale,
                  catalog: widget.catalog,
                  session: session,
                  interaction: interaction,
                  selectedOptionId: checkpoint.selectedOptionId,
                  feedback: feedback,
                  supported: supported,
                  onSelect: feedback == null && !_mutating
                      ? (optionId) => _selectOption(
                          key: key,
                          checkpoint: checkpoint,
                          optionId: optionId,
                        )
                      : null,
                ),
              ),
            ),
          ),
        ),
        if (feedback != null)
          ContentBounds(
            maxWidth: 780,
            child: _SessionFeedbackPanel(
              locale: widget.locale,
              feedback: feedback,
            ),
          ),
        if (_showWriteFailure)
          ContentBounds(
            maxWidth: 780,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(24, 0, 24, 4),
              child: _SessionWriteFailure(locale: widget.locale),
            ),
          ),
        ContentBounds(
          maxWidth: 780,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(24, 12, 24, 22),
            child: AppButton(
              label: action.label,
              expand: true,
              accent: _AcademyColors.cyan,
              onPressed: action.enabled ? action.onPressed : null,
            ),
          ),
        ),
      ],
    );
  }

  void _onPrimary({
    required CurriculumSessionProgressKey key,
    required CurriculumSessionProgress checkpoint,
    required CurriculumInteraction interaction,
    required int totalInteractions,
    required bool supported,
    required bool hasResponse,
  }) {
    if (!supported) {
      _leaveAcademy(context);
      return;
    }
    if (hasResponse || interaction.responseSpec.kind == ResponseKind.none) {
      final requiresChoice = interaction.responseSpec.kind == ResponseKind.none
          ? null
          : interaction.id;
      if (checkpoint.interactionIndex >= totalInteractions - 1) {
        _complete(
          key: key,
          checkpoint: checkpoint,
          requiresRecordedChoiceForInteractionId: requiresChoice,
        );
      } else {
        _advance(
          key: key,
          checkpoint: checkpoint,
          requiresRecordedChoiceForInteractionId: requiresChoice,
        );
      }
      return;
    }
    final selectedOptionId = checkpoint.selectedOptionId;
    if (selectedOptionId == null) return;
    final option = _firstWhereOrNull(
      interaction.options,
      (candidate) => candidate.id == selectedOptionId,
    );
    if (option == null) return;
    _writeCheckpoint(
      key,
      (repository) => repository.recordChoice(
        key: key,
        interactionIndex: checkpoint.interactionIndex,
        interactionId: interaction.id,
        selectedOptionId: selectedOptionId,
        isCorrect: option.isCorrect,
        expectedRevision: checkpoint.revision,
      ),
    );
  }

  void _selectOption({
    required CurriculumSessionProgressKey key,
    required CurriculumSessionProgress checkpoint,
    required String optionId,
  }) {
    _writeCheckpoint(
      key,
      (repository) => repository.selectOption(
        key: key,
        interactionIndex: checkpoint.interactionIndex,
        selectedOptionId: optionId,
        expectedRevision: checkpoint.revision,
      ),
    );
  }

  void _advance({
    required CurriculumSessionProgressKey key,
    required CurriculumSessionProgress checkpoint,
    required CurriculumInteractionId? requiresRecordedChoiceForInteractionId,
  }) {
    _writeCheckpoint(
      key,
      (repository) => repository.advance(
        key: key,
        interactionIndex: checkpoint.interactionIndex,
        nextInteractionIndex: checkpoint.interactionIndex + 1,
        expectedRevision: checkpoint.revision,
        requiresRecordedChoiceForInteractionId:
            requiresRecordedChoiceForInteractionId,
      ),
    );
  }

  void _complete({
    required CurriculumSessionProgressKey key,
    required CurriculumSessionProgress checkpoint,
    required CurriculumInteractionId? requiresRecordedChoiceForInteractionId,
  }) {
    _writeCheckpoint(
      key,
      (repository) => repository.complete(
        key: key,
        interactionIndex: checkpoint.interactionIndex,
        expectedRevision: checkpoint.revision,
        requiresRecordedChoiceForInteractionId:
            requiresRecordedChoiceForInteractionId,
      ),
      markJustCompleted: true,
    );
  }

  Future<void> _writeCheckpoint(
    CurriculumSessionProgressKey key,
    Future<CurriculumSessionProgress> Function(
      CurriculumSessionProgressRepository repository,
    )
    operation, {
    bool markJustCompleted = false,
  }) async {
    if (_mutating) return;
    setState(() {
      _mutating = true;
      _showWriteFailure = false;
    });
    try {
      final updated = await operation(
        ref.read(curriculumSessionProgressRepositoryProvider),
      );
      // This is local crypto + encrypted outbox persistence only; it never
      // waits for the network or changes whether the learner can continue.
      // A later reconciliation sweep can recover any outbox write that fails.
      try {
        await ref
            .read(personalSyncCurriculumJournalProvider)
            .recordCheckpoint(updated);
        final dispatcher = ref.read(personalSyncDispatcherProvider);
        if (dispatcher != null) unawaited(dispatcher.requestSync());
      } on Object {
        // The local checkpoint is already authoritative. Keep the session
        // usable offline and defer personal-sync recovery to its own boundary.
      }
      if (markJustCompleted && mounted) {
        setState(() => _justCompleted = true);
      }
      ref.invalidate(curriculumSessionProgressProvider(key));
      ref.invalidate(curriculumSessionProgressSnapshotProvider(key));
      await ref.read(curriculumSessionProgressProvider(key).future);
    } on CurriculumProgressException {
      if (mounted) setState(() => _showWriteFailure = true);
    } on Object {
      if (mounted) setState(() => _showWriteFailure = true);
    } finally {
      if (mounted) setState(() => _mutating = false);
    }
  }
}

class _AcademyProgressFailure extends StatelessWidget {
  const _AcademyProgressFailure({required this.locale, required this.onRetry});

  final ContentLocale locale;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    final copy = _AcademyCopy(locale);
    return _AcademyViewportCenter(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 520),
        child: Padding(
          padding: const EdgeInsets.all(28),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              SynapseCompanion(
                pose: SynapseCompanionPose.thinking,
                size: 134,
                semanticLabel: copy.companionSafety,
              ),
              const SizedBox(height: 14),
              Text(
                copy.progressUnavailableTitle,
                style: _academyTitle(context),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 8),
              Text(
                copy.progressUnavailableBody,
                style: _academyBody(context),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 22),
              AppButton(
                label: copy.retry,
                icon: Icons.refresh_rounded,
                size: AppButtonSize.medium,
                accent: _AcademyColors.cyan,
                onPressed: onRetry,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _AcademyCompletedSession extends StatelessWidget {
  const _AcademyCompletedSession({
    required this.locale,
    required this.justCompleted,
    required this.onBackToPath,
  });

  final ContentLocale locale;
  final bool justCompleted;
  final VoidCallback onBackToPath;

  @override
  Widget build(BuildContext context) {
    final copy = _AcademyCopy(locale);
    return _AcademyViewportCenter(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 500),
        child: Padding(
          padding: const EdgeInsets.all(28),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              SynapseCompanion(
                pose: SynapseCompanionPose.questHost,
                size: 148,
                semanticLabel: copy.companionEncouraging,
              ),
              const SizedBox(height: 14),
              Text(
                copy.sessionComplete,
                style: _academyTitle(context),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 8),
              Text(
                justCompleted
                    ? copy.sessionCompleteBody
                    : copy.completedCheckpointBody,
                style: _academyBody(context),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 24),
              AppButton(
                label: copy.backToPath,
                icon: Icons.route_rounded,
                size: AppButtonSize.medium,
                accent: _AcademyColors.cyan,
                onPressed: onBackToPath,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _SessionWriteFailure extends StatelessWidget {
  const _SessionWriteFailure({required this.locale});

  final ContentLocale locale;

  @override
  Widget build(BuildContext context) {
    final copy = _AcademyCopy(locale);
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(13),
      decoration: BoxDecoration(
        color: _AcademyColors.coral.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: _AcademyColors.coral.withValues(alpha: 0.38)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(
            Icons.save_outlined,
            color: _AcademyColors.coral,
            size: 19,
          ),
          const SizedBox(width: 9),
          Expanded(
            child: Text(
              copy.progressWriteFailure,
              style: _academyBody(context),
            ),
          ),
        ],
      ),
    );
  }
}

class _SessionTopBar extends StatelessWidget {
  const _SessionTopBar({
    required this.progress,
    required this.trailing,
    required this.onClose,
    this.onWorkspace,
  });

  final double progress;
  final String trailing;
  final VoidCallback onClose;
  final VoidCallback? onWorkspace;

  @override
  Widget build(BuildContext context) {
    final copy = _AcademyCopy(
      _contentLocale(Localizations.localeOf(context).languageCode),
    );
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 8, 20, 8),
      child: Row(
        children: [
          AppIconButton(
            icon: Icons.close_rounded,
            tooltip: copy.closeSession,
            color: Colors.white70,
            onPressed: onClose,
          ),
          if (onWorkspace != null) ...[
            AppIconButton(
              icon: Icons.auto_stories_outlined,
              tooltip: copy.studyWorkspace,
              color: Colors.white70,
              onPressed: onWorkspace,
            ),
            const SizedBox(width: 4),
          ],
          const SizedBox(width: 10),
          Expanded(
            child: ClipRRect(
              borderRadius: BorderRadius.circular(99),
              child: LinearProgressIndicator(
                value: progress,
                minHeight: 10,
                backgroundColor: Colors.white.withValues(alpha: 0.12),
                valueColor: const AlwaysStoppedAnimation(_AcademyColors.cyan),
              ),
            ),
          ),
          const SizedBox(width: 12),
          Text(
            trailing,
            style: const TextStyle(
              color: Colors.white70,
              fontSize: 12,
              fontWeight: FontWeight.w800,
              fontFeatures: [FontFeature.tabularFigures()],
            ),
          ),
        ],
      ),
    );
  }
}

class _InteractionCard extends StatelessWidget {
  const _InteractionCard({
    required this.locale,
    required this.catalog,
    required this.session,
    required this.interaction,
    required this.selectedOptionId,
    required this.feedback,
    required this.supported,
    required this.onSelect,
  });

  final ContentLocale locale;
  final CurriculumCatalogSnapshot catalog;
  final CurriculumSession session;
  final CurriculumInteraction interaction;
  final String? selectedOptionId;
  final _AcademyAnswerFeedback? feedback;
  final bool supported;
  final ValueChanged<String>? onSelect;

  @override
  Widget build(BuildContext context) {
    final copy = _AcademyCopy(locale);
    final title =
        catalog.localizedText(session.titleUnitId, locale) ?? copy.session;
    final instruction = interaction.instructionUnitId == null
        ? null
        : catalog.localizedText(interaction.instructionUnitId!, locale);
    final prompt =
        catalog.localizedText(interaction.promptUnitId, locale) ??
        copy.promptUnavailable;
    final stimulus = [
      for (final unitId in interaction.stimulus.localizationUnitIds)
        ?catalog.localizedText(unitId, locale),
    ];

    return Container(
      padding: const EdgeInsets.all(22),
      decoration: BoxDecoration(
        color: _AcademyColors.panel.withValues(alpha: 0.9),
        borderRadius: BorderRadius.circular(26),
        border: Border.all(color: Colors.white.withValues(alpha: 0.14)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: const TextStyle(
              color: Colors.white70,
              fontSize: 13,
              fontWeight: FontWeight.w700,
              letterSpacing: 0.2,
            ),
          ),
          const SizedBox(height: 18),
          if (instruction != null) ...[
            Text(instruction, style: _academyBody(context)),
            const SizedBox(height: 16),
          ],
          Text(prompt, style: _academyPrompt(context)),
          if (stimulus.isNotEmpty) ...[
            const SizedBox(height: 18),
            for (final text in stimulus) ...[
              _StimulusText(text: text),
              const SizedBox(height: 10),
            ],
          ],
          if (!supported) ...[
            const SizedBox(height: 22),
            _UnsupportedInteractionNote(locale: locale),
          ] else if (interaction.responseSpec.kind ==
              ResponseKind.singleChoice) ...[
            const SizedBox(height: 24),
            for (
              var index = 0;
              index < interaction.options.length;
              index++
            ) ...[
              _AcademyOption(
                label:
                    catalog.localizedText(
                      interaction.options[index].labelUnitId,
                      locale,
                    ) ??
                    copy.optionUnavailable,
                option: interaction.options[index],
                ordinal: index,
                selected: selectedOptionId == interaction.options[index].id,
                checked: feedback != null,
                onTap: onSelect == null
                    ? null
                    : () => onSelect!(interaction.options[index].id),
              ),
              const SizedBox(height: 10),
            ],
          ] else ...[
            const SizedBox(height: 20),
            _TruthNote(text: copy.readThenContinue),
          ],
        ],
      ),
    );
  }
}

class _StimulusText extends StatelessWidget {
  const _StimulusText({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.055),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white.withValues(alpha: 0.1)),
      ),
      child: Text(text, style: _academyBody(context)),
    );
  }
}

class _AcademyOption extends StatelessWidget {
  const _AcademyOption({
    required this.label,
    required this.option,
    required this.ordinal,
    required this.selected,
    required this.checked,
    required this.onTap,
  });

  final String label;
  final InteractionOption option;
  final int ordinal;
  final bool selected;
  final bool checked;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final resolved = checked
        ? (option.isCorrect ? _AcademyColors.green : _AcademyColors.coral)
        : (selected ? _AcademyColors.cyan : Colors.white54);
    final letter = String.fromCharCode(65 + ordinal);
    return Semantics(
      button: true,
      selected: selected,
      label: '$letter. $label',
      child: Material(
        color: resolved.withValues(alpha: checked || selected ? 0.14 : 0.055),
        borderRadius: BorderRadius.circular(16),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(16),
          child: ConstrainedBox(
            constraints: const BoxConstraints(minHeight: 56),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 13),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color: resolved.withValues(alpha: 0.78),
                  width: 1.2,
                ),
              ),
              child: Row(
                children: [
                  Container(
                    width: 26,
                    height: 26,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: resolved.withValues(alpha: 0.16),
                      shape: BoxShape.circle,
                    ),
                    child: Text(
                      letter,
                      style: TextStyle(
                        color: resolved,
                        fontSize: 12,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      label,
                      style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                        color: Colors.white,
                        height: 1.32,
                      ),
                    ),
                  ),
                  if (checked)
                    Icon(
                      option.isCorrect
                          ? Icons.check_circle_rounded
                          : Icons.cancel_rounded,
                      color: resolved,
                    ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _UnsupportedInteractionNote extends StatelessWidget {
  const _UnsupportedInteractionNote({required this.locale});

  final ContentLocale locale;

  @override
  Widget build(BuildContext context) {
    final copy = _AcademyCopy(locale);
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: _AcademyColors.gold.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: _AcademyColors.gold.withValues(alpha: 0.35)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(Icons.extension_off_outlined, color: _AcademyColors.gold),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              copy.unsupportedInteraction,
              style: _academyBody(context),
            ),
          ),
        ],
      ),
    );
  }
}

class _SessionFeedbackPanel extends StatelessWidget {
  const _SessionFeedbackPanel({required this.locale, required this.feedback});

  final ContentLocale locale;
  final _AcademyAnswerFeedback feedback;

  @override
  Widget build(BuildContext context) {
    final copy = _AcademyCopy(locale);
    final color = feedback.correct
        ? _AcademyColors.green
        : _AcademyColors.coral;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(24, 16, 24, 16),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: const BorderRadius.vertical(top: Radius.circular(22)),
        border: Border.all(color: color.withValues(alpha: 0.36)),
      ),
      child: Directionality(
        textDirection: locale == ContentLocale.fa
            ? TextDirection.rtl
            : TextDirection.ltr,
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(
              feedback.correct
                  ? Icons.check_circle_rounded
                  : Icons.refresh_rounded,
              color: color,
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    feedback.correct ? copy.correct : copy.notQuite,
                    style: TextStyle(color: color, fontWeight: FontWeight.w800),
                  ),
                  const SizedBox(height: 4),
                  Text(feedback.explanation, style: _academyBody(context)),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _TruthNote extends StatelessWidget {
  const _TruthNote({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: _AcademyColors.gold.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: _AcademyColors.gold.withValues(alpha: 0.28)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(
            Icons.verified_user_outlined,
            color: _AcademyColors.gold,
            size: 19,
          ),
          const SizedBox(width: 10),
          Expanded(child: Text(text, style: _academyBody(context))),
        ],
      ),
    );
  }
}

class _AcademyConstellation extends StatelessWidget {
  const _AcademyConstellation();

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: CustomPaint(
        painter: const _ConstellationPainter(),
        child: const SizedBox.expand(),
      ),
    );
  }
}

class _ConstellationPainter extends CustomPainter {
  const _ConstellationPainter();

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Colors.white.withValues(alpha: 0.045)
      ..strokeWidth = 1;
    final cyan = Paint()
      ..color = _AcademyColors.cyan.withValues(alpha: 0.14)
      ..strokeWidth = 1;
    final points = <Offset>[
      Offset(size.width * .08, size.height * .18),
      Offset(size.width * .21, size.height * .10),
      Offset(size.width * .34, size.height * .24),
      Offset(size.width * .77, size.height * .12),
      Offset(size.width * .89, size.height * .30),
      Offset(size.width * .72, size.height * .64),
      Offset(size.width * .92, size.height * .81),
    ];
    for (var index = 0; index < points.length; index++) {
      final point = points[index];
      canvas.drawCircle(
        point,
        index.isEven ? 2 : 1.4,
        index.isEven ? cyan : paint,
      );
      if (index > 0) {
        canvas.drawLine(points[index - 1], point, paint);
      }
    }
  }

  @override
  bool shouldRepaint(covariant _ConstellationPainter oldDelegate) => false;
}

class _AcademyAnswerFeedback {
  const _AcademyAnswerFeedback({
    required this.correct,
    required this.explanation,
  });

  final bool correct;
  final String explanation;
}

class _SessionAction {
  const _SessionAction({
    required this.label,
    required this.enabled,
    required this.onPressed,
  });

  final String label;
  final bool enabled;
  final VoidCallback onPressed;
}

class _CurriculumLaunchTarget {
  const _CurriculumLaunchTarget({
    required this.microLessonNodeId,
    required this.sessionId,
  });

  final String microLessonNodeId;
  final String sessionId;
}

class _AcademyColors {
  const _AcademyColors._();

  static const midnight = Color(0xFF020D20);
  static const topGlow = Color(0xFF08264B);
  static const panel = Color(0xFF071A35);
  static const cyan = Color(0xFF1FC8F7);
  static const coral = Color(0xFFFF806A);
  static const gold = Color(0xFFF7BD4C);
  static const green = Color(0xFF4BD5A7);
}

TextStyle _academyTitle(BuildContext context) => Theme.of(context)
    .textTheme
    .headlineSmall!
    .copyWith(color: Colors.white, fontWeight: FontWeight.w800, height: 1.08);

TextStyle _academyHeroTitle(BuildContext context) => Theme.of(context)
    .textTheme
    .headlineMedium!
    .copyWith(color: Colors.white, fontWeight: FontWeight.w800, height: 1.04);

TextStyle _academySectionTitle(BuildContext context) => Theme.of(context)
    .textTheme
    .titleLarge!
    .copyWith(color: Colors.white, fontWeight: FontWeight.w800);

TextStyle _academyEyebrow(BuildContext context) =>
    Theme.of(context).textTheme.labelLarge!.copyWith(
      color: _AcademyColors.cyan,
      fontWeight: FontWeight.w800,
      letterSpacing: 1.2,
    );

TextStyle _academyBody(BuildContext context) => Theme.of(
  context,
).textTheme.bodyMedium!.copyWith(color: Colors.white70, height: 1.48);

TextStyle _academyPrompt(BuildContext context) => Theme.of(context)
    .textTheme
    .headlineSmall!
    .copyWith(color: Colors.white, fontWeight: FontWeight.w800, height: 1.20);

bool _isSupported(CurriculumInteraction interaction) {
  if (interaction.stimulus.mediaAssetIds.isNotEmpty) return false;
  if (interaction.responseSpec.kind == ResponseKind.none) return true;
  return interaction.kind == InteractionKind.singleBestAnswer &&
      interaction.responseSpec.kind == ResponseKind.singleChoice &&
      interaction.options.isNotEmpty;
}

_AcademyAnswerFeedback _feedbackFor(
  CurriculumCatalogSnapshot catalog,
  CurriculumInteraction interaction,
  CurriculumChoiceResponse response,
  ContentLocale locale,
) {
  final unitId = response.isCorrect
      ? interaction.feedbackSpec.whyCorrectUnitId
      : interaction.feedbackSpec.whyWrongByOptionId[response
                .selectedOptionId] ??
            interaction.feedbackSpec.repairUnitId;
  return _AcademyAnswerFeedback(
    correct: response.isCorrect,
    explanation:
        catalog.localizedText(unitId, locale) ??
        _AcademyCopy(locale).approvedFeedbackUnavailable,
  );
}

String _actionLabel(
  _AcademyCopy copy, {
  required bool supported,
  required bool hasFeedback,
  required bool isPassive,
  required bool isLast,
}) {
  if (!supported) return copy.backToPath;
  if (hasFeedback || isPassive) {
    return isLast ? copy.finish : copy.continueLabel;
  }
  return copy.checkAnswer;
}

_CurriculumLaunchTarget? _firstLaunchTarget(
  CurriculumCatalogSnapshot catalog,
  String rootNodeId,
) {
  for (final entry in _descendants(catalog, rootNodeId)) {
    if (!entry.node.isPlayable) continue;
    final microLesson = catalog.microLessonForNode(entry.node.id);
    if (microLesson == null) continue;
    final session = _firstWhereOrNull(
      catalog.sessionsForMicroLesson(microLesson.id),
      (candidate) => catalog.interactionsForSession(candidate.id).isNotEmpty,
    );
    if (session != null) {
      return _CurriculumLaunchTarget(
        microLessonNodeId: entry.node.id,
        sessionId: session.id,
      );
    }
  }
  return null;
}

bool _containsLaunchTarget(CurriculumCatalogSnapshot catalog, String nodeId) =>
    _firstLaunchTarget(catalog, nodeId) != null;

List<CurriculumCatalogEntry> _pathPreview(
  CurriculumCatalogSnapshot catalog,
  String rootNodeId,
) {
  final result = <CurriculumCatalogEntry>[];

  void visit(String parentId) {
    for (final child in catalog.childrenOf(parentId)) {
      if (result.length >= 5) return;
      result.add(child);
      visit(child.node.id);
      if (result.length >= 5) return;
    }
  }

  visit(rootNodeId);
  return result;
}

Iterable<CurriculumCatalogEntry> _descendants(
  CurriculumCatalogSnapshot catalog,
  String rootNodeId,
) sync* {
  for (final child in catalog.childrenOf(rootNodeId)) {
    yield child;
    yield* _descendants(catalog, child.node.id);
  }
}

T? _firstWhereOrNull<T>(Iterable<T> values, bool Function(T) test) {
  for (final value in values) {
    if (test(value)) return value;
  }
  return null;
}

IconData _nodeIcon(CurriculumNodeKind kind) => switch (kind) {
  CurriculumNodeKind.course => Icons.route_rounded,
  CurriculumNodeKind.chapter => Icons.menu_book_outlined,
  CurriculumNodeKind.unit => Icons.layers_outlined,
  CurriculumNodeKind.conceptCluster => Icons.hub_outlined,
  CurriculumNodeKind.microLesson => Icons.play_circle_outline_rounded,
};

String _nodeLabel(_AcademyCopy copy, CurriculumNodeKind kind) => switch (kind) {
  CurriculumNodeKind.course => copy.course,
  CurriculumNodeKind.chapter => copy.chapter,
  CurriculumNodeKind.unit => copy.unit,
  CurriculumNodeKind.conceptCluster => copy.conceptCluster,
  CurriculumNodeKind.microLesson => copy.microLesson,
};

ContentLocale _contentLocale(String locale) =>
    locale.toLowerCase().startsWith('fa') ? ContentLocale.fa : ContentLocale.en;

void _leaveAcademy(BuildContext context) {
  if (Navigator.of(context).canPop()) {
    context.pop();
  } else {
    context.go(Routes.learn);
  }
}

class _AcademyCopy {
  const _AcademyCopy(this.locale);

  final ContentLocale locale;

  bool get _fa => locale == ContentLocale.fa;
  String _t(String en, String fa) => _fa ? fa : en;

  String get companionWaiting => _t(
    'LUMA is waiting for a reviewed learning package',
    'لوما منتظر بستهٔ آموزشی بازبینی‌شده است',
  );
  String get companionSafety => _t(
    'LUMA is protecting the reviewed learning path',
    'لوما از مسیر آموزشی بازبینی‌شده محافظت می‌کند',
  );
  String get companionEncouraging => _t(
    'LUMA is ready to guide your next learning step',
    'لوما برای همراهی با گام بعدی یادگیری آماده است',
  );
  String get noPackageTitle => _t(
    'A reviewed course package is not active yet',
    'هنوز بستهٔ آموزشیِ بازبینی‌شده و فعالی وجود ندارد',
  );
  String get noPackageBody => _t(
    'This learning path opens only after a signed, approved course release is active on this device.',
    'این مسیر آموزشی فقط پس از فعال‌شدن یک انتشار امضاشده و تأییدشده روی این دستگاه باز می‌شود.',
  );
  String get noPackageNote => _t(
    'Nothing has been substituted: no lesson, question, or clinical guidance is shown until the reviewed package is ready.',
    'چیزی جایگزین نشده است: تا آماده‌شدن بستهٔ بازبینی‌شده، هیچ درس، پرسش یا راهنمای بالینی نمایش داده نمی‌شود.',
  );
  String get runtimeFailureTitle => _t(
    'This learning package needs attention',
    'این بستهٔ آموزشی نیاز به بررسی دارد',
  );
  String get integrityBody => _t(
    'The active course package did not pass its integrity check, so it stays closed. Your other study data is untouched.',
    'بستهٔ آموزشی فعال از بررسی یکپارچگی عبور نکرده است؛ بنابراین باز نمی‌شود. سایر داده‌های مطالعهٔ شما بدون تغییر می‌ماند.',
  );
  String get schemaBody => _t(
    'This app version cannot safely open the active course package yet. Update the app before trying again.',
    'این نسخهٔ اپ هنوز نمی‌تواند بستهٔ آموزشی فعال را با اطمینان باز کند. پیش از تلاش دوباره، اپ را به‌روزرسانی کنید.',
  );
  String get runtimeFailureBody => _t(
    'We could not load the active course package right now. You can safely retry; no lesson has been substituted.',
    'فعلاً نتوانستیم بستهٔ آموزشی فعال را بارگیری کنیم. می‌توانید با خیال راحت دوباره تلاش کنید؛ هیچ درسی جایگزین نشده است.',
  );
  String get progressUnavailableTitle => _t(
    'Your saved session needs attention',
    'جلسهٔ ذخیره‌شدهٔ شما نیاز به بررسی دارد',
  );
  String get progressUnavailableBody => _t(
    'The local checkpoint cannot safely be used with this active reviewed package. It was preserved and was not reset.',
    'نقطهٔ ادامهٔ محلی با این بستهٔ بازبینی‌شدهٔ فعال قابل استفادهٔ ایمن نیست. حفظ شده و بازنشانی نشده است.',
  );
  String get progressWriteFailure => _t(
    'Your session step was not changed. Try again before continuing.',
    'گام جلسهٔ شما تغییر نکرده است. پیش از ادامه دوباره تلاش کنید.',
  );
  String get completedCheckpointBody => _t(
    'This signed session is already recorded as complete on this device. Your reward balance was not changed here.',
    'این جلسهٔ امضاشده روی این دستگاه کامل ثبت شده است. موجودی پاداش شما در اینجا تغییر نکرده است.',
  );
  String get retry => _t('Retry', 'تلاش دوباره');
  String get back => _t('Back', 'بازگشت');
  String get closeSession => _t('Close session', 'بستن جلسه');
  String get reviewedLearning => _t('Reviewed learning', 'یادگیری بازبینی‌شده');
  String get routeUnavailableTitle => _t(
    'This learning path is not available',
    'این مسیر آموزشی در دسترس نیست',
  );
  String get routeUnavailableBody => _t(
    'The requested reviewed course or session is not part of the active package.',
    'درس یا جلسهٔ بازبینی‌شدهٔ درخواست‌شده در بستهٔ فعال وجود ندارد.',
  );
  String get pathReady => _t('PATH READY', 'مسیر آماده است');
  String get heroTitle => _t(
    'Learn in a calm, clear sequence.',
    'در یک مسیر آرام و روشن یاد بگیر.',
  );
  String get heroBody => _t(
    'One focused session at a time. Your curriculum stays grounded in the active reviewed release.',
    'هر بار فقط یک جلسهٔ متمرکز. برنامهٔ درسی شما بر انتشار بازبینی‌شدهٔ فعال تکیه دارد.',
  );
  String get startPath => _t('Start learning path', 'شروع مسیر یادگیری');
  String get openStudyWorkspace =>
      _t('Open study workspace', 'بازکردن فضای مطالعه');
  String get studyWorkspace => _t('Study workspace', 'فضای مطالعه');
  String get explorePath => _t('Explore course path', 'دیدن مسیر درس');
  String get courseLibrary => _t('Course library', 'کتابخانهٔ درس‌ها');
  String get course => _t('Course', 'درس');
  String get coursePath => _t('COURSE PATH', 'مسیر درس');
  String get coursePathBody => _t(
    'A compact view of the approved hierarchy. The active node is your next place to focus.',
    'نمایی فشرده از سلسله‌مراتب تأییدشده. گرهٔ فعال، تمرکز بعدی شماست.',
  );
  String get nextSequence => _t('Next sequence', 'دنبالهٔ بعدی');
  String get chapters => _t('Chapters', 'فصل‌ها');
  String get noPathNodes => _t(
    'This reviewed course does not expose a learner path yet.',
    'این درس بازبینی‌شده هنوز مسیر قابل نمایش برای یادگیرنده ندارد.',
  );
  String get chapter => _t('Chapter', 'فصل');
  String get unit => _t('Unit', 'واحد');
  String get conceptCluster => _t('Concept cluster', 'خوشهٔ مفهومی');
  String get microLesson => _t('Micro-lesson', 'میکرودرس');
  String get nextUp => _t('Next up', 'گام بعد');
  String get inSequence => _t('In sequence', 'در مسیر');
  String get session => _t('Learning session', 'جلسهٔ یادگیری');
  String get promptUnavailable => _t(
    'This approved prompt is unavailable in the active package.',
    'این پرسش تأییدشده در بستهٔ فعال در دسترس نیست.',
  );
  String get optionUnavailable =>
      _t('Approved option unavailable', 'گزینهٔ تأییدشده در دسترس نیست');
  String get readThenContinue => _t(
    'Read the reviewed step, then continue when you are ready.',
    'گام بازبینی‌شده را بخوانید و وقتی آماده بودید ادامه دهید.',
  );
  String get unsupportedInteraction => _t(
    'This approved interaction template is not enabled in this app build. No response has been recorded or replaced.',
    'این قالب تعامل تأییدشده در این نسخهٔ اپ فعال نیست. هیچ پاسخی ثبت یا جایگزین نشده است.',
  );
  String get approvedFeedbackUnavailable => _t(
    'Approved feedback is unavailable in the active package.',
    'بازخورد تأییدشده در بستهٔ فعال در دسترس نیست.',
  );
  String get checkAnswer => _t('Check answer', 'بررسی پاسخ');
  String get continueLabel => _t('Continue', 'ادامه');
  String get finish => _t('Finish session', 'پایان جلسه');
  String get backToPath => _t('Back to path', 'بازگشت به مسیر');
  String get correct => _t('Correct', 'درست است');
  String get notQuite => _t('Try the repair note', 'یادداشت اصلاحی را ببین');
  String get sessionComplete => _t('Session complete', 'جلسه کامل شد');
  String get sessionCompleteBody => _t(
    'You reached the end of this reviewed session. Return to the path whenever you are ready for the next step.',
    'به پایان این جلسهٔ بازبینی‌شده رسیدید. هر زمان آماده بودید برای گام بعد به مسیر برگردید.',
  );
}
