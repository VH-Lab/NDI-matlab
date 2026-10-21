# `ndi.setup.conv.template.import_V2` — decision log

The running record of the choices made while building this import, kept from
day one. Copy this file with the template and replace the TEMPLATE rows with
your dataset's. The worked example is the Haley import's log,
`+haley/import_V2_decisions.md`.

Entries marked **DECIDED** were made by the dataset's owner (name them, and
the date); **OPEN** entries are questions still to answer. A rule the code
follows that no row records is a bug in this log.

## Current rules

A summary of the rule in force today, by topic, read off the log below. Each
line cites the row(s) that set it; rows it replaces are in parentheses. The
log is the record: where this summary and a row disagree, the row wins, and
this section should be corrected.

### Dataset and studies

- The dataset entity and its studies are dataset-level documents, from the
  spec's `dataset` and `studies`; each study is `included_in` the dataset (#2).
- Shared entities (people, organizations, software, strains, instruments) are
  created once at the dataset level and referred to by id from the sessions (#2).

### Sessions

- One session per data folder matching `sessions.folder_pattern`, its
  `local_identifier` the folder name (#3). TEMPLATE: replace with your rule.
- Sessions are written to their own folders under `OutputRoot`, never into the
  raw data, and the dataset links them (`linked_session`) (#4).

### Entities

- One entity per row of the session's source table, type `entities.type`,
  `local_identifier` `<session>_<row id>` (dataset-unique) (#5). TEMPLATE.

### Recordings and time

- Each recording is an epoch with its UTC extent; its file is an
  `opaque_body` recorded by location, not copied (#4, #6).
- Every statement has a time reference: a recording's statements are timed by
  the recording; a manipulation by its own time (#6, #7).
- A hand-written time is to the minute: approximate, tolerance [60 60] s, its
  `source_value` the text as written (#7).

### Values, units and corrections

- A value keeps the source's number and unit (`source_value`, `source_unit` as
  a registered term) beside its canonical value; a tolerance only where the
  source states one (#8).
- Missing is not a value: a blank cell writes nothing and is counted as
  skipped (#8).
- A correction is named in the spec, applied only while the source reads its
  `was`, and the document says what it was (#9).

### Terms

- Every term is looked up by name in DID-schema's term registry; no node is
  written in code. A run lists every unregistered term and writes nothing until
  each is registered (#10).
- A statement's method is one block `{term, parameters}`; a shared, named
  method is a standalone `method` document named by `method_id`, never both (#10).

### What is not imported

- (List what the source holds that the import leaves out, and why.)

### Unresolved

- (Open questions, each with the row that holds it.)

## Principles

- Documents are built with `did2.build`; the import carries no field lists of
  its own.
- The spec is an OUTPUT as much as an input: discover and profile the source
  first (`ndi.setup.V2.discover`, `ndi.setup.V2.profileTable`), then answer
  each stage's questions; the answers accumulate in the spec.
- Every stage reports its denominators (read, written, skipped, errors); a
  count without its denominator is not evidence.
- Work one stage at a time, in the fixed order, with the dataset's owner.

## Stage order

    1  sessions       the dataset and its studies, then the sessions
    2  entities       what each session is about
    3  acquisition    the recordings: epochs, times, files by location
    4  manipulations  what was done to the entities
    5  observations   what was measured about them
    6  calculations   what was computed from the data

Later stages read the ids earlier ones made. Acquisition comes before any
statement because every statement needs a time reference.

## Decisions

| # | Date | Decision | Status |
|---|---|---|---|
| 1 | YYYY-MM-DD | TEMPLATE: this import starts from `ndi.setup.conv.template`. | DECIDED |
| 2 | YYYY-MM-DD | The dataset, its studies and the shared entities are dataset-level documents from the spec, built with `ndi.setup.V2.datasetMetadata`. | DECIDED |
| 3 | YYYY-MM-DD | TEMPLATE: one session per data folder. Replace with the source's own unit of acquisition (a day, an experiment) and how it is read. | OPEN |
| 4 | YYYY-MM-DD | The raw data is never copied or written to: recordings are recorded by location, sessions are written under `OutputRoot` and linked from the dataset. | DECIDED |
| 5 | YYYY-MM-DD | TEMPLATE: one entity per source-table row. Replace with what the data is about, its types, and how identifiers are made dataset-unique. | OPEN |
| 6 | YYYY-MM-DD | TEMPLATE: each recording is one epoch; its start is exact. | OPEN |
| 7 | YYYY-MM-DD | Hand-written times are to the minute: approximate, tolerance [60 60] s. | DECIDED |
| 8 | YYYY-MM-DD | Source values and units are kept beside the canonical value; nothing is filled where the source is blank. | DECIDED |
| 9 | YYYY-MM-DD | Corrections go through one function (`ndi.setup.V2.applyCorrection`) and are recorded on the document. | DECIDED |
| 10 | YYYY-MM-DD | Terms come from DID-schema's term registry, looked up by name; the run refuses to write an unregistered term (`ndi.setup.V2.checkTerms`). | DECIDED |

## Source inventory

(What `ndi.setup.V2.discover` found: folders, file kinds, tables and their
columns, and which stage reads each.)
