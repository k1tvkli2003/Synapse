# Synapse independent content validation

## Outcome

Validate the assigned immutable authored artifact and emit findings and receipts
only. Do not silently rewrite authoring output and do not activate a publication
channel.

## Binding inputs

The activated task must provide exact hashes and repository-relative paths for
the authored artifact, source scan, decomposition, coverage ledger, content
contract, authoring policy, evidence records, media records, and reviewer
assignment. Stop when any artifact hash differs from the task envelope.

## Required checks

1. Reconcile every assigned source document, source atom, claim, localization
   unit, coverage edge, micro-lesson, session, interaction, and media record.
2. Require 100% document inventory, atom classification, required-atom
   representation, output-claim provenance, EN/FA semantic-skeleton parity,
   answer and numeric parity, citation locator validity, terminology first use,
   accessibility coverage, and review separation.
3. Require zero orphan atoms or claims, summary-only coverage, unsupported
   claims, fabricated or non-supporting citations, locale mismatches,
   placeholders, broken or rights-unknown used media, session-budget failures,
   monotony failures, open blocking findings, or open safety-critical findings.
4. Confirm embedded assessment covers every major concept and every
   clinical-high or safety-critical claim before chapter validation.
5. Confirm every correct answer has reasoning and every distractor has a
   complete why-wrong explanation tied to a misconception or plausible error.
6. Confirm recap content is bounded, adds no claim, and never serves as primary
   coverage.
7. Confirm English reads naturally and Persian is a native pedagogical
   adaptation with correct orthography, terminology handling, bidi isolation,
   and no semantic loss.
8. Confirm media rights, hashes, transform history, captions, bilingual alt
   text, nonvisual alternative, educational purpose, and medical review.
9. Confirm current-authority evidence for diagnosis, management, drug choice or
   dose, contraindication, procedure safety, guideline staging, and
   time-sensitive epidemiology.

## Independence and output

The validator must differ from the author and generator identities. Write only
the assigned validation findings and hash-bound receipt. Findings must name the
exact object, severity, violated invariant, evidence, and required remediation.
Any blocking or safety-critical finding keeps the artifact quarantined. A clean
validation result is evidence for a later human-controlled promotion decision;
it is not publication authority.

