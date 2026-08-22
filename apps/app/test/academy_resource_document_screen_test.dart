import 'dart:convert';
import 'dart:typed_data';

import 'package:crypto/crypto.dart';
import 'package:file_selector/file_selector.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:synapse_app/data/resource_documents/resource_document_blob_store.dart';
import 'package:synapse_app/features/academy/academy_resource_document_screen.dart';
import 'package:synapse_app/state/app_providers.dart';
import 'package:synapse_app/state/curriculum_provider.dart';
import 'package:synapse_app/state/persistence.dart';
import 'package:synapse_core/synapse_core.dart';
import 'package:synapse_services/synapse_services.dart';
import 'package:synapse_ui/synapse_ui.dart';

const _digest =
    'cccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccc';

void main() {
  testWidgets('missing document metadata is reported without substitution', (
    tester,
  ) async {
    final fixture = await _fixture();

    await tester.pumpWidget(
      _host(
        fixture: fixture,
        child: const AcademyResourceDocumentScreen(
          documentId: 'document.missing',
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Reference not found'), findsOneWidget);
    expect(
      find.text('This route does not point to registered document metadata.'),
      findsOneWidget,
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets('registered metadata distinguishes a missing private blob', (
    tester,
  ) async {
    final fixture = await _fixture();
    final container = ProviderContainer(
      overrides: [
        sharedPreferencesProvider.overrideWithValue(fixture),
        ..._legacyResourceOverrides,
      ],
    );
    final document = ResourceDocument(
      id: 'document.local.missing',
      displayName: 'Private reference.pdf',
      mediaType: 'application/pdf',
      contentSha256: _digest,
      byteLength: 4096,
      pageCount: 12,
      origin: ResourceDocumentOrigin.userImport,
      createdAt: DateTime.utc(2026, 7, 22),
    );
    await container
        .read(resourceWorkspaceRepositoryProvider)
        .registerDocument(document);
    container.dispose();

    await tester.pumpWidget(
      _host(
        fixture: fixture,
        child: AcademyResourceDocumentScreen(documentId: document.id),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('The PDF is not on this device'), findsOneWidget);
    expect(
      find.textContaining('private blob could not be found'),
      findsOneWidget,
    );
    expect(find.text('Private reference.pdf'), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('memory PDF reaches the real reader toolbar and first page', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1024, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final fixture = await _fixture();
    final container = ProviderContainer(
      overrides: [
        sharedPreferencesProvider.overrideWithValue(fixture),
        ..._legacyResourceOverrides,
      ],
    );
    final bytes = _minimalPdfBytes();
    final digest = sha256.convert(bytes).toString();
    final document = ResourceDocument(
      id: 'document.memory.valid',
      displayName: 'Runtime cardiology.pdf',
      mediaType: 'application/pdf',
      contentSha256: digest,
      byteLength: bytes.length,
      pageCount: 1,
      origin: ResourceDocumentOrigin.userImport,
      createdAt: DateTime.utc(2026, 7, 22),
    );
    await container
        .read(resourceWorkspaceRepositoryProvider)
        .registerDocument(document);
    container.dispose();

    await tester.pumpWidget(
      _host(
        fixture: fixture,
        blobStore: _MemoryBlobStore(bytes),
        child: AcademyResourceDocumentScreen(documentId: document.id),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(seconds: 2));

    expect(find.text('Runtime cardiology.pdf'), findsOneWidget);
    expect(find.text('1 / 1'), findsOneWidget);
    expect(find.byTooltip('Search document'), findsOneWidget);
    expect(find.byTooltip('Bookmark this page'), findsOneWidget);
    expect(find.byTooltip('Draw on this page'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('Persian compact reader survives 200% text with semantics', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    tester.platformDispatcher.textScaleFactorTestValue = 2;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
    final semantics = tester.ensureSemantics();
    final fixture = await _fixture(locale: 'fa');
    final container = ProviderContainer(
      overrides: [
        sharedPreferencesProvider.overrideWithValue(fixture),
        ..._legacyResourceOverrides,
      ],
    );
    final bytes = _minimalPdfBytes();
    final document = ResourceDocument(
      id: 'document.memory.fa',
      displayName: 'مرجع خصوصی قلب.pdf',
      mediaType: 'application/pdf',
      contentSha256: sha256.convert(bytes).toString(),
      byteLength: bytes.length,
      pageCount: 1,
      origin: ResourceDocumentOrigin.userImport,
      createdAt: DateTime.utc(2026, 7, 22),
    );
    await container
        .read(resourceWorkspaceRepositoryProvider)
        .registerDocument(document);
    container.dispose();

    await tester.pumpWidget(
      _host(
        fixture: fixture,
        blobStore: _MemoryBlobStore(bytes),
        child: AcademyResourceDocumentScreen(documentId: document.id),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(seconds: 2));

    expect(find.text('مرجع خصوصی قلب.pdf'), findsOneWidget);
    expect(
      Directionality.of(tester.element(find.text('مرجع خصوصی قلب.pdf'))),
      TextDirection.rtl,
    );
    expect(find.byTooltip('جست‌وجوی سند'), findsOneWidget);
    expect(find.byTooltip('نشان‌کردن این صفحه'), findsOneWidget);
    expect(find.byTooltip('طراحی روی این صفحه'), findsOneWidget);
    expect(find.bySemanticsLabel('جست‌وجوی سند'), findsOneWidget);
    expect(tester.takeException(), isNull);
    semantics.dispose();
  });
}

Future<PersistedStore> _fixture({String locale = 'en'}) async {
  SharedPreferences.setMockInitialValues({'settings': '{"locale":"$locale"}'});
  return PersistedStore(await SharedPreferences.getInstance());
}

Widget _host({
  required PersistedStore fixture,
  required Widget child,
  ResourceDocumentBlobStore blobStore = const _MissingBlobStore(),
}) => ProviderScope(
  overrides: [
    sharedPreferencesProvider.overrideWithValue(fixture),
    resourceDocumentBlobStoreProvider.overrideWithValue(blobStore),
    ..._legacyResourceOverrides,
  ],
  child: MaterialApp(
    debugShowCheckedModeBanner: false,
    localizationsDelegates: GlobalMaterialLocalizations.delegates,
    supportedLocales: const [Locale('en'), Locale('fa')],
    theme: SynapseTheme.light(),
    darkTheme: SynapseTheme.dark(),
    themeMode: ThemeMode.dark,
    home: child,
  ),
);

/// These Reader widget tests verify rendering and the explicit legacy fallback
/// contract. Indexed activation has dedicated database-backed provider tests.
final _legacyResourceOverrides = [
  resourceWorkspaceRepositoryProvider.overrideWith((ref) {
    return LocalResourceWorkspaceRepository(
      store: ref.watch(resourceWorkspaceStoreProvider),
      clock: ref.watch(clockProvider),
      idSource: ref.watch(operationalIdSourceProvider),
    );
  }),
  resourceDocumentReadingStateRepositoryProvider.overrideWith((ref) {
    return LocalResourceDocumentReadingStateRepository(
      store: ref.watch(resourceDocumentReadingStateStoreProvider),
      clock: ref.watch(clockProvider),
    );
  }),
];

final class _MissingBlobStore implements ResourceDocumentBlobStore {
  const _MissingBlobStore();

  @override
  Future<void> close() async {}

  @override
  Future<ResourceDocumentSource?> resolve(ResourceDocument document) async =>
      null;

  @override
  Future<ResourceDocumentBlobReceipt> storePickedFile(XFile source) =>
      throw UnsupportedError('Not used by this reader-state test.');

  @override
  Future<ResourceDocumentBlobVerification> verify(
    ResourceDocument document,
  ) async => const ResourceDocumentBlobVerification.invalid('blob_missing');
}

final class _MemoryBlobStore implements ResourceDocumentBlobStore {
  const _MemoryBlobStore(this.bytes);

  final Uint8List bytes;

  @override
  Future<void> close() async {}

  @override
  Future<ResourceDocumentSource?> resolve(ResourceDocument document) async =>
      ResourceDocumentSource.bytes(
        contentSha256: document.contentSha256,
        byteLength: bytes.length,
        bytes: bytes,
      );

  @override
  Future<ResourceDocumentBlobReceipt> storePickedFile(XFile source) =>
      throw UnsupportedError('Not used by this reader runtime test.');

  @override
  Future<ResourceDocumentBlobVerification> verify(
    ResourceDocument document,
  ) async => const ResourceDocumentBlobVerification.valid();
}

Uint8List _minimalPdfBytes() {
  const stream = 'BT /F1 24 Tf 72 720 Td (Cardiology) Tj ET\n';
  final objects = <String>[
    '<< /Type /Catalog /Pages 2 0 R >>',
    '<< /Type /Pages /Kids [3 0 R] /Count 1 >>',
    '<< /Type /Page /Parent 2 0 R /MediaBox [0 0 612 792] /Resources << /Font << /F1 4 0 R >> >> /Contents 5 0 R >>',
    '<< /Type /Font /Subtype /Type1 /BaseFont /Helvetica >>',
    '<< /Length ${ascii.encode(stream).length} >>\nstream\n${stream}endstream',
  ];
  final buffer = StringBuffer('%PDF-1.4\n');
  final offsets = <int>[0];
  for (var index = 0; index < objects.length; index++) {
    offsets.add(ascii.encode(buffer.toString()).length);
    buffer
      ..write('${index + 1} 0 obj\n')
      ..write(objects[index])
      ..write('\nendobj\n');
  }
  final xrefOffset = ascii.encode(buffer.toString()).length;
  buffer
    ..write('xref\n0 ${objects.length + 1}\n')
    ..write('0000000000 65535 f \n');
  for (final offset in offsets.skip(1)) {
    buffer.write('${offset.toString().padLeft(10, '0')} 00000 n \n');
  }
  buffer
    ..write('trailer\n<< /Size ${objects.length + 1} /Root 1 0 R >>\n')
    ..write('startxref\n$xrefOffset\n%%EOF\n');
  return Uint8List.fromList(ascii.encode(buffer.toString()));
}
