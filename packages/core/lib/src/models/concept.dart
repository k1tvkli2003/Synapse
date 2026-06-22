import 'package:equatable/equatable.dart';

import 'ids.dart';

/// Knowledge domains a [Concept] can belong to (prompt 04 §2).
enum ConceptDomain {
  anatomy,
  pharmacology,
  clinical,
  roots,
  communication,
  cardiology,
  lab,
  sound,
  microbiology,
  other;

  String get label => switch (this) {
        ConceptDomain.anatomy => 'Anatomy',
        ConceptDomain.pharmacology => 'Pharmacology',
        ConceptDomain.clinical => 'Clinical',
        ConceptDomain.roots => 'Roots',
        ConceptDomain.communication => 'Communication',
        ConceptDomain.cardiology => 'Cardiology',
        ConceptDomain.lab => 'Laboratory',
        ConceptDomain.sound => 'Auscultation',
        ConceptDomain.microbiology => 'Microbiology',
        ConceptDomain.other => 'General',
      };
}

/// The kind of edge between two concepts in the graph.
enum ConceptRelation { isA, partOf, treats, causes, related }

class ConceptLink extends Equatable {
  const ConceptLink({required this.to, this.relation = ConceptRelation.related});

  final ConceptId to;
  final ConceptRelation relation;

  Map<String, dynamic> toJson() => {'to': to, 'relation': relation.name};

  factory ConceptLink.fromJson(Map<String, dynamic> j) => ConceptLink(
        to: j['to'] as String,
        relation: ConceptRelation.values
            .firstWhere((r) => r.name == j['relation'], orElse: () => ConceptRelation.related),
      );

  @override
  List<Object?> get props => [to, relation];
}

class Tag extends Equatable {
  const Tag({required this.id, required this.slug, required this.label});

  final TagId id;
  final String slug;
  final String label;

  @override
  List<Object?> get props => [id, slug, label];
}

/// A first-class node in the knowledge graph. Every learnable item across every
/// module links to a [Concept], which is what makes cross-module "see also" and
/// weak-concept propagation possible (prompt 32).
class Concept extends Equatable {
  const Concept({
    required this.id,
    required this.name,
    this.aliases = const [],
    this.domain = ConceptDomain.other,
    this.tags = const [],
    this.summary,
    this.links = const [],
  });

  final ConceptId id;
  final String name;
  final List<String> aliases;
  final ConceptDomain domain;
  final List<TagId> tags;
  final String? summary;
  final List<ConceptLink> links;

  Concept copyWith({
    String? name,
    List<String>? aliases,
    ConceptDomain? domain,
    List<TagId>? tags,
    String? summary,
    List<ConceptLink>? links,
  }) {
    return Concept(
      id: id,
      name: name ?? this.name,
      aliases: aliases ?? this.aliases,
      domain: domain ?? this.domain,
      tags: tags ?? this.tags,
      summary: summary ?? this.summary,
      links: links ?? this.links,
    );
  }

  /// Case-insensitive match against the name or any alias — used by search.
  bool matches(String query) {
    final q = query.toLowerCase().trim();
    if (q.isEmpty) return false;
    if (name.toLowerCase().contains(q)) return true;
    return aliases.any((a) => a.toLowerCase().contains(q));
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'aliases': aliases,
        'domain': domain.name,
        'tags': tags,
        'summary': summary,
        'links': links.map((l) => l.toJson()).toList(),
      };

  factory Concept.fromJson(Map<String, dynamic> j) => Concept(
        id: j['id'] as String,
        name: j['name'] as String,
        aliases: (j['aliases'] as List?)?.map((e) => e.toString()).toList() ?? const [],
        domain: ConceptDomain.values
            .firstWhere((d) => d.name == j['domain'], orElse: () => ConceptDomain.other),
        tags: (j['tags'] as List?)?.map((e) => e.toString()).toList() ?? const [],
        summary: j['summary'] as String?,
        links: (j['links'] as List?)
                ?.map((e) => ConceptLink.fromJson(Map<String, dynamic>.from(e as Map)))
                .toList() ??
            const [],
      );

  @override
  List<Object?> get props => [id, name, aliases, domain, tags, summary, links];
}
