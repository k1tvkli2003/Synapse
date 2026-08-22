import 'curriculum_catalog_models.dart';
import 'curriculum_catalog_repository.dart';
import 'curriculum_package_models.dart';
import 'curriculum_package_repository.dart';

enum CurriculumRuntimeBootstrapStatus {
  ready,
  noActiveRelease,
  integrityBlocked,
  unsupportedSchema,
  failed,
}

final class CurriculumRuntimeBootstrapResult {
  CurriculumRuntimeBootstrapResult._({
    required this.status,
    required this.target,
    required this.integrityIssues,
    this.catalog,
    this.errorCode,
    this.cause,
  }) {
    if ((status == CurriculumRuntimeBootstrapStatus.ready) !=
        (catalog != null)) {
      throw ArgumentError(
        'Only a ready bootstrap result may contain a catalog.',
      );
    }
  }

  factory CurriculumRuntimeBootstrapResult.ready({
    required CurriculumActivationTarget target,
    required CurriculumCatalogSnapshot catalog,
    required List<CurriculumPackageIntegrityIssue> integrityIssues,
  }) => CurriculumRuntimeBootstrapResult._(
    status: CurriculumRuntimeBootstrapStatus.ready,
    target: target,
    catalog: catalog,
    integrityIssues: List.unmodifiable(integrityIssues),
  );

  factory CurriculumRuntimeBootstrapResult.unavailable({
    required CurriculumActivationTarget target,
    required List<CurriculumPackageIntegrityIssue> integrityIssues,
  }) => CurriculumRuntimeBootstrapResult._(
    status: CurriculumRuntimeBootstrapStatus.noActiveRelease,
    target: target,
    integrityIssues: List.unmodifiable(integrityIssues),
  );

  factory CurriculumRuntimeBootstrapResult.failure({
    required CurriculumRuntimeBootstrapStatus status,
    required CurriculumActivationTarget target,
    required String errorCode,
    required Object cause,
    List<CurriculumPackageIntegrityIssue> integrityIssues = const [],
  }) {
    if (status == CurriculumRuntimeBootstrapStatus.ready ||
        status == CurriculumRuntimeBootstrapStatus.noActiveRelease) {
      throw ArgumentError.value(status, 'status');
    }
    return CurriculumRuntimeBootstrapResult._(
      status: status,
      target: target,
      errorCode: errorCode,
      cause: cause,
      integrityIssues: List.unmodifiable(integrityIssues),
    );
  }

  final CurriculumRuntimeBootstrapStatus status;
  final CurriculumActivationTarget target;
  final CurriculumCatalogSnapshot? catalog;
  final List<CurriculumPackageIntegrityIssue> integrityIssues;
  final String? errorCode;

  /// Internal diagnostic cause. Presentation layers must map [errorCode] to
  /// safe localized copy and must never display this object directly.
  final Object? cause;

  bool get canRetry => switch (status) {
    CurriculumRuntimeBootstrapStatus.ready => false,
    CurriculumRuntimeBootstrapStatus.noActiveRelease => false,
    CurriculumRuntimeBootstrapStatus.integrityBlocked => false,
    CurriculumRuntimeBootstrapStatus.unsupportedSchema => false,
    CurriculumRuntimeBootstrapStatus.failed => true,
  };
}

/// Creates a truthful startup state without deleting corrupt local data or
/// pretending that a missing active release is a network failure.
final class CurriculumRuntimeBootCoordinator {
  factory CurriculumRuntimeBootCoordinator({
    required CurriculumPackageRepository packages,
    required CurriculumCatalogRepository catalogs,
  }) => CurriculumRuntimeBootCoordinator._(packages, catalogs);

  const CurriculumRuntimeBootCoordinator._(this._packages, this._catalogs);

  final CurriculumPackageRepository _packages;
  final CurriculumCatalogRepository _catalogs;

  Future<CurriculumRuntimeBootstrapResult> boot(
    CurriculumActivationTarget target,
  ) async {
    var integrityIssues = const <CurriculumPackageIntegrityIssue>[];
    try {
      integrityIssues = await _packages.auditIntegrity();
      final catalog = await _catalogs.activeCatalog(target);
      if (catalog == null) {
        return CurriculumRuntimeBootstrapResult.unavailable(
          target: target,
          integrityIssues: integrityIssues,
        );
      }
      final activeIssues = integrityIssues.where(
        (issue) => issue.target != null
            ? issue.target == target
            : issue.releaseId == catalog.releaseId,
      );
      if (activeIssues.isNotEmpty) {
        return CurriculumRuntimeBootstrapResult.failure(
          status: CurriculumRuntimeBootstrapStatus.integrityBlocked,
          target: target,
          errorCode: 'active_curriculum_integrity_failed',
          cause: CurriculumPackageException(
            'active_curriculum_integrity_failed',
            'The active curriculum release failed integrity validation.',
          ),
          integrityIssues: integrityIssues,
        );
      }
      return CurriculumRuntimeBootstrapResult.ready(
        target: target,
        catalog: catalog,
        integrityIssues: integrityIssues,
      );
    } on CurriculumPackageException catch (error) {
      return CurriculumRuntimeBootstrapResult.failure(
        status: _packageFailureStatus(error.code),
        target: target,
        errorCode: error.code,
        cause: error,
        integrityIssues: integrityIssues,
      );
    } on CurriculumCatalogException catch (error) {
      return CurriculumRuntimeBootstrapResult.failure(
        status: CurriculumRuntimeBootstrapStatus.integrityBlocked,
        target: target,
        errorCode: error.code,
        cause: error,
        integrityIssues: integrityIssues,
      );
    } on Object catch (error) {
      return CurriculumRuntimeBootstrapResult.failure(
        status: CurriculumRuntimeBootstrapStatus.failed,
        target: target,
        errorCode: 'curriculum_bootstrap_failed',
        cause: error,
        integrityIssues: integrityIssues,
      );
    }
  }

  static CurriculumRuntimeBootstrapStatus _packageFailureStatus(String code) =>
      switch (code) {
        'unsupported_registry_schema' =>
          CurriculumRuntimeBootstrapStatus.unsupportedSchema,
        'corrupt_registry' ||
        'corrupt_installed_package' ||
        'missing_active_release' ||
        'invalid_release_envelope' ||
        'release_trust_not_configured' ||
        'unknown_release_signing_key' ||
        'revoked_release_signing_key' ||
        'release_signing_scope_mismatch' ||
        'signed_release_mismatch' ||
        'release_signature_time_invalid' ||
        'release_signature_invalid' ||
        'legacy_release_trust_blocked' =>
          CurriculumRuntimeBootstrapStatus.integrityBlocked,
        _ => CurriculumRuntimeBootstrapStatus.failed,
      };
}
