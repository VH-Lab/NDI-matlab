# NDI V2 object layer: subjects, statements and entities

**Using it:** [Using_V2.md](Using_V2.md) is the short user guide (open, search, read, walk, write).

**Status: PARTLY BUILT (2026-10-06), for review by Jess Haley and Steve Van Hooser.**
Built (read side): `ndi.entity`, the statement tree,
`ndi.value`, and the `ndi.v2` helpers. **Not built, on purpose:** any change to
`ndi.session` or `ndi.dataset` (section 4, "Entry points"); the `ndi.strain` and
`ndi.study` subclasses (they do not exist; a strain and a study are plain `ndi.entity`);
`subject.location(t)`; the `'During'` filter. Section 9 lists what was built.

## 1. Why

A V2 (V_eta) dataset is a set of statements about subjects: who or what was
observed, manipulated, calculated about or asserted about, when, how and with
what result. NDI's objects do not know this yet. Today a user who wants one worm's
speed from a V2 dataset has to:

1. search for `velocity_calculation` documents whose `subject_id` edge is the worm;
2. pick the one whose `variable` is `midpoint speed`;
3. follow its `depends_on` to the `sampled_body` that holds the values;
4. open that body's file, gunzip it, and decode it by the body's `datum_type`,
   `byte_order` and `keys` (the axes);
5. follow the statement's time-reference edges to absolute or relative time
   references, and resolve them to a start and end;
6. read units and tolerances from the value cell.

That is schema knowledge, not science. This document proposes objects that do it
once, so the user writes `w.statements('statement', {'variable', 'midpoint speed'}).value()`.

## 2. What exists today (NDI-matlab, branch `claude/haley-import-v2`)

| object | what it does | V2 status |
|---|---|---|
| `ndi.dataset` | opens a dataset, lists and opens its sessions, searches its database | opens a V2 dataset and lists its sessions (import stage 13, decision #66); no subjects, statements, studies or entities |
| `ndi.session` | database front end; DAQ systems, probes, elements, syncgraph | opens a V2 session; no subjects, statements or entities |
| `ndi.subject` | `local_identifier`, `description`; `newdocument`, `searchquery`; a string check | requires an `@` in `local_identifier` (`subject.m:120`); no navigation |
| `ndi.element`, `ndi.probe` | acquisition objects, raw-data reading | V2 read through `ndi.vintage` (the v1/V2 name map) |
| statements, entities | none | only as raw documents from `database_search` |

When this section was written there was no method that listed a session's
subjects. There is now: `ndi.entity.search(S, {'type', ndi.v2.subjectTypes()})`
(section 4, "Entry points").

## 3. Decisions (agreed with Jess Haley, 2026-10-06)

- **D1 Read first.** Build the side that opens an existing dataset and answers
  questions before any side that creates documents through these objects. Writing
  stays with `did2.build` (as the Haley import does) until reading is done.
- **D2 One statement tree, mirroring the schema.**
  ```
  ndi.statement          statement
  ├── ndi.assertion      assertion        (e.g. term_assertion: species, strain, exclusion)
  └── ndi.interaction    interaction      (abstract: never returned on its own)
      ├── ndi.observation    observation
      ├── ndi.manipulation   manipulation
      └── ndi.calculation    calculation
  ```
  There is no class per leaf (`velocity_calculation`, `dose_manipulation`, ...):
  about forty leaves would differ only by name. A statement object is returned as
  the right child automatically, from its document's class chain, so a new leaf in
  the schema needs no new code.
- **D3 `value()`, not `data()`.** A statement has one value, stored inline or in a
  data body; where it is stored is the schema's business. `value()` returns it
  either way, decoding the body when the value lives there. `body()` stays for
  the raw file.
- **D4 (WITHDRAWN 2026-10-08, see section 8) `ndi.subject` is an `ndi.entity`.** The schema already says so: `subject`,
  `session`, `dataset`, `study`, `person`, `strain`, ... are all `entity`
  (`formulation` is a `data_type`, not an entity).
- **D5 Back compatibility with v1** (section 6).
- **D6 The `@` in `local_identifier` is a v1 rule, not a V2 rule.** `ndi.subject`
  keeps requiring it when it CREATES a v1 subject, unchanged. A V2 subject read
  from a document is accepted without one. Reasons:
  - uniqueness is already given: every subject has a globally unique `id`, and the
    schema makes `local_identifier` unique within its dataset;
  - the lab is structure, and V2 declares structure rather than encoding it in
    strings (tenet T14). The lab is an `organization` entity reached through
    relations, not a suffix that code splits on (four places in NDI split a
    subject name on `@` today: the Birren, Dabrowska and Haley v1 converters and
    the metadata app);
  - a suffix goes stale when a lab moves or merges, and a relation can be updated.

## 4. The classes

### `ndi.entity`

Built from any entity document.

| member | returns |
|---|---|
| `id`, `kind` (the document class), `name`, `local_identifier` | text |
| `global_identifiers()` | table: scheme (ORCID, ROR, RRID, DOI, ...), value |
| `relations(name, 'Direction', 'out' or 'in')` | table: relation, the other entity, role(s), time |
| `parents(name)`, `children(name)` | entities across one relation (`part_of`, `member_of`, ...), or a path of them (`{'contained_in', 'member_of'}`); called on an array of entities, one search per step, each entity returned once; `'Table', true` gives one row per (start, end) |
| `ancestors(...)`, `descendants(...)` | the nearest entities of a `'Type'` (`organism`, `material`, ...) or `'Kind'` (document class), following any relation up or down: `descendants([plates{:}], 'Type', 'organism')` is the worms that were on them (function form: `[c{:}].method(...)` is not valid MATLAB), without knowing the relations. `'Relation'` limits the relations followed, `'MaxDepth'` the steps, `'Table'` adds a `depth` column |
| `document()` | the underlying `ndi.document` |
| `ndi.entity.fromDocument(container, doc)` (static) | an `ndi.entity` for any entity document, a subject's included |
| `ndi.entity.search(container, conditions, options)` (static) | a cell array of entities; `conditions` a cell of pairs, e.g. `{'kind', 'person', 'name', 'Jess*'}` (`'kind'`: a document class or, one entity class, an entity type); `{}` is every entity |
| `type`, `description` | the entity's type and description, from either schema |
| `statements(...)`, `assertions(...)`, `observations(...)`, ... | what is stated of the entity, as for a subject below: since 2026-10-08 (one entity class) any entity can be the subject of a statement, so these live on `ndi.entity` (a person's given name, a strain's genetic strain type) |

`ndi.entity` is a CONCRETE value class: a person, an organization or a piece of
software is an `ndi.entity` with no subclass. It holds its document and the
session or dataset it was read from, and nothing else; every question is a query.

Subclasses only where there is real behaviour. Two were planned and are NOT
built; there are no `ndi.strain` or `ndi.study` classes, and a strain or a study
is a plain `ndi.entity`:

- `ndi.strain`: `species()`, `lineage()` (parental strains), `genotype()`;
- `ndi.study`: `sessions()`, `factors()`, `design()`.

Persons, organizations, products, software, funding and publications are plain
`ndi.entity`. A formulation is not an entity, so it is not here: it is reached
from a dose (`ndi.manipulation.formulation()`), see open question Q4.

### Subjects (`ndi.entity`)

The members below are `ndi.entity`'s and work for any entity; they are
written for a subject (a worm, a cohort, a plate) because that is where they
are used most. `ndi.subject` is v1's class, unchanged on this branch.

| member | returns |
|---|---|
| `type` | the coarse kind: organism, group, culture, material, ... |
| `statements(kind, filters, options)` | statement objects about this subject; `kind` (default `'statement'`): observation, manipulation, calculation, assertion, interaction, or a leaf class; `filters` a cell: `'variable'`, `'method'`, `'value'`, `'formulation'`, `'at'`, `'during'`, `'before'`, `'after'`, `'duration'`; options `'inherited'`, `'context'`, `'tolerant'` |
| `assertions(filters, options)` | `statements('assertion', filters, options)`: assertion objects (species `Caenorhabditis elegans`, strain `N2`, `inclusion in analysis` `excluded`); `ndi.summary` of them is the table |
| `observations(filters, options)`, `manipulations(...)`, `calculations(...)`, `interactions(...)` | `statements('<kind>', filters, options)`: objects of that kind, inherited by default; the cell of filters first, e.g. `w.observations({'variable', 'temperature'})` |
| `...('context', true)` | also what the subject was IN (V_eta tenet T17): the interactions of each container it was `contained_in` (through a distributive stay of its group, and nested containers) whose time overlaps the stay. Marked `via() = '... contained_in'`; assertions never pass; a stay or statement whose times cannot be compared is left out. `ndi.entity.search(..., 'context', true)` finds them the same way |
| `'during', {'observation', {...}}` | a time filter that takes statements as well as times: a statement is kept when its time overlaps one matching the description that holds of the same subject, by the same rules (`'inherited'`, `'context'`). `w.observations({'variable', 'image intensity', 'during', {'observation', {'variable', 'ambient temperature', 'value', '>22'}}}, 'context', true)`: the worm's plate's videos while that plate read over 22 C |
| `members()` / `memberOf()` | a group's members / the groups it belongs to (`member_of`) |
| `parts()` / `partOf()` | `part_of`: a whole's parts / the whole a part is part of (a sample's aliquots / an aliquot's sample). A patch is not part of its plate: it is `contained_in` the plate (Haley decision #107) |
| `location(t)` | where the subject was at time `t` (`contained_in`) |

The v1 constructor and its `@` check stay as they are (D6).

### `ndi.statement`

| member | returns |
|---|---|
| `subject()`, `entity()` | the `ndi.entity` it is about |
| `variable()` | an `ndi.term` (§13); `variable_name()` its name |
| `value()` | the value, with units, decoded from the body when stored there (array, with axes) |
| `axes()` | the value's keys: name, unit, values (e.g. video frame, metre) |
| `conditions()` | table: variable, value, unit |
| `notes` | text |
| `body()` | the raw data-body document and file, if any |
| `ndi.statement.fromDocument(doc)` (static) | the right child, from the document's class chain |

### `ndi.assertion < ndi.statement`

No additions: an assertion is a variable and value about a subject, with no time,
method or instrument.

### `ndi.interaction < ndi.statement` (abstract)

| member | returns |
|---|---|
| `time()` | start and end, resolved through the time references (absolute UTC or relative to another document), with tolerance |
| `method()`, `method_parameters()` | an `ndi.term` (§13); a table of parameters |
| `instrument()` | the instrument subject, if any |

### `ndi.observation`, `ndi.manipulation`, `ndi.calculation < ndi.interaction`

- `ndi.observation`: nothing more today.
- `ndi.manipulation`: `formulation()` for a dose: what was given, with its
  ingredient tree.
- `ndi.calculation`: `inputs()` (the statements and documents it was computed
  from), `software()` (software, interpreter, operating system).

### `ndi.value`

A statement's value, the same object whether it was stored inline or in a data
body (answers Q3: a small value class).

| member | returns |
|---|---|
| `canonical()`, `double()` | the values in the canonical unit; a term's name; the raw struct for a structured value (dose, item, model fit) |
| `terms()` | a term-valued value's terms, as `ndi.term` objects (§13) |
| `unit()` | the canonical field, e.g. `meters`, read from the schema |
| `source()` | table: source_value, source_unit |
| `tolerance()`, `approximate()` | per value |
| `axes()` | the keys: variable, unit, n, coordinates |
| `files()` | file paths, for a value kept in an opaque body (a video) |

### Entry points (instead of `ndi.session` / `ndi.dataset` additions)

`ndi.session` and `ndi.dataset` are NOT changed (Jess Haley, 2026-10-06: "I'm not
sure about the session and dataset changes"). The entry points are static methods
that take the session or dataset as their first argument:

| call | returns |
|---|---|
| `ndi.entity.search(S, {'type', 'organism', 'species', 'Caenorhabditis elegans', 'strain', {'N2', 'CB*'}, 'manipulation', {'method', 'heating', 'value', '>=0.02'}}, 'inherited', true)` | entities for which every condition holds. The conditions are ONE cell of PROPERTY, VALUE pairs (`{}`: every entity; `{'type', ndi.v2.subjectTypes()}` keeps the subjects, Q2); the switches `'inherited'`, `'context'`, `'strict'`, `'explain'`, `'tolerant'`, `'synonyms'` are declared options after it (an `arguments` block validates them), and a switch inside the cell is an error. A nested description is a cell too and takes the outer `'strict'` and `'inherited'`. `'synonyms'` (default true): a value that matches no term by its name or node also matches a term it is a synonym of, `{'species', 'C. elegans'}` finding `NCBITaxon:6239`; the names come from `ndi.ontology.lookup`, looked up once per term node and kept on disk (`ndi.v2.synonyms`, folder `ndi.v2.synonymFolder`, or `NDI_SYNONYM_CACHE`), and nothing is found offline. A strain matches through its global identifiers' synonyms the same way. Only a value that matched nothing directly triggers a lookup. The same holds for a `variable` or `method` (2026-10-20, tenet T19): when no statement has it as given, it is widened by the terms in DID-schema's term registry that go by it, its label or a synonym (`ndi.v2.synonymNodes`), so `'meter'` finds OM's `metre` and `'mean'` NCIT's Arithmetic Mean. An `ndi.term` compared with text matches a synonym too. A property is one of the subject's own fields (`type`, `name`, `local_identifier`); a statement kind (`statement`, `assertion`, `interaction`, `observation`, `manipulation`, `calculation`, each including its children) with a cell of filters on ONE statement (`variable`, `method`, `value`, `formulation`; the key twice is two statements); or any other name, an asserted variable (`'strain', 'N2'` is `'assertion', {'variable', 'strain', 'value', 'N2'}`). Names ignore case. A pattern matches a term's name ignoring case or its node exactly; a cell array is any of; `*` is a wildcard (in the database with DID-matlab #218's `wildcard` operator, else rechecked in MATLAB). Numbers and dates compare with `>`, `>=`, `<`, `<=`; an array or body value has no single value. `'inherited'` (default true) adds the members, down `member_of`, of a group whose statement is `distributive`; `contained_in` and `part_of` are not followed. A variable or method no statement has is an error; values matching nothing, a warning (`ndi.v2.searchStatements`) Relations: `'relation'`, `'directed_relation'`, `'undirected_relation'` take `{'name', R, 'parent'|'child'|'with', X}` (the subject is the child / the parent / either end), X a subject, several, a document id, or a nested description; a relation's own name is a key (`'contained_in', X` = child of a contained_in whose parent is X; `'with'` for undirected). Inherited also carries a distributive relation from a group to its members, an assertion from a whole to its parts and samples (part_of, sample_of, aliquot_of, passage_of), and an assertion from a type to its instances (`instance_of`: a strain's or a product's assertions hold of each worm or bottle, reached from the subject, a whole, or a group whose `instance_of` is distributive; V_eta T17). `'strain', 'N2'` is a subject that is an `instance_of` the strain named N2 (one entity class). `'explain', true` prints the search in words. `'at'`, `'during'`, `'before'`, `'after'` and `'duration'` filter a statement or a relation by when it held (`ndi.v2.timeFilter`); not built yet: the relation filter `'depth'`. |
| `ndi.statement.search(S, 'Subject', s, 'Variable', v, 'Class', c, 'Method', m)` | statements |
| `ndi.entity.search(S, {'kind', K})` | entities of a kind |
| `ndi.entity.fromDocument(S, doc)`, `ndi.statement.fromDocument(S, doc)` | the object for one document |

**Read through the dataset.** A session searches only its own documents, and the
shared documents (people, organizations, studies, strains, software, products,
instruments, formulations) are stored with the dataset (Haley decision #20). An
object read through a session therefore cannot reach them: `software()` and
`formulation()` come back empty. An object read through the `ndi.dataset` reaches
everything, including every session's documents. Measured on the full Haley dataset
(58 sessions, 2026-10-06, `tools/v2_object_layer_tryout.m`): one worm's 22
statements took 0.19 s through its session and 0.52 s through the dataset; the
dose's formulation was not found through the session and was found through the
dataset. To narrow a search to one session, find things in the session, then read
them through the dataset with `fromDocument(ds, id)`.

A session opened FROM its dataset (`ds.open_session(id)`) lives in the dataset's
database, and `ndi.session/database_search_with_dataset` searches it without the
session filter. The readers use it for the dataset-level entities a subject
points at: a strain found by name (`'strain', 'N2'`), and a strain's assertions
and name reaching its worms (`ndi.summary` shows a `strain` column). A session
folder opened on its own holds the `instance_of` relation but not the strain, so
it cannot name it.

## 5. How it is built

- **Objects wrap documents.** Each object holds its document and its session or
  dataset. It caches nothing it cannot rebuild, and reads lazily: `value()`
  touches the body file only when called.
- **Every navigation is an indexed query.** "This worm's statements" is a query
  on the `depends_on` table (`name = 'subject_id' AND document_id = <worm>`),
  which is indexed in `did2.database.sqlitedb`, not a scan of the documents. On
  the Haley dataset (187,673 documents, 889,957 edges) it should take
  milliseconds; the tests will time it.
- **Class from the class chain.** `fromDocument` reads the document's superclasses
  (the database's `superclasses` table) to pick `ndi.observation`,
  `ndi.manipulation`, ..., never a hard-coded list of leaves.
- **Body decoding in one place.** A single reader turns a `sampled_body` into a
  MATLAB array from its `datum_type`, `byte_order`, `datum_order`, `fill_value`,
  `compression` and `keys`. The Haley import's `ingestedBody` is its writing
  counterpart, so the tests can round-trip.
- **Time resolution in one place.** A single resolver follows a statement's time
  references, including chains (relative to an epoch relative to a session),
  to a start and end in UTC where an absolute anchor exists, else relative to the
  anchor it names.

## 6. Back compatibility with v1

1. **Every existing method keeps its exact behaviour on v1 data:**
   `ndi.subject`'s constructor and `@` check, `ndi.session` and `ndi.dataset`
   search and open, elements, probes, DAQ, syncgraph.
2. **New methods work on V2, and on v1 where `ndi.vintage` defines an
   equivalent** (for example, a v1 `subject` document becomes an `ndi.subject`
   with no statements). **Where v1 has no equivalent, they return empty, never
   an error.**
3. **No v1 document is rewritten or reinterpreted on read.** Migration stays
   `ndi.migrate`'s job.
4. **Every new class is tested on a v1 session and a V2 session**, as
   `TestVintageMap` already does for the read path.
5. **`ndi.session` and `ndi.dataset` gain entity behaviour last** (Q1), because
   their class trees are the deepest and the most used.

## 7. Build order

1. `ndi.entity`, `ndi.subject` (V2 read; `@` relaxed for V2, D6),
   `session.subjects()` / `dataset.subjects()`.
2. `ndi.statement` and its tree; `value()` with the body reader; `axes()`,
   `conditions()`.
3. `time()` with the time resolver; `method()`, `instrument()`.
4. `ndi.calculation.inputs()`, `ndi.manipulation.formulation()`,
   `ndi.strain`, `ndi.study`, `entities()`, `studies()`.
5. `ndi.session` / `ndi.dataset` as entities (Q1).

Each step lands with tests on the Haley CI fixture (V2) and a v1 session, and is
tried on the real Haley dataset before the next.

## 8. Open questions

- **Q1** (Reading does not need it: read through the dataset, section 4.) How `ndi.session` and `ndi.dataset` become entities: a mixin class, or
  composition (`session.entity()` returning an `ndi.entity`)? A mixin changes
  their class hierarchy; composition does not.
- **Q2** ANSWERED, and changed 2026-10-08 (Jess Haley): the subjects are the
  biological types, organism, culture, tissue, cell and group
  (`ndi.v2.subjectTypes`), as a v1 `subject` document always was.
  `ndi.query('', 'isa', 'subject')` finds those (and a v1 subject, which has no
  type), so every existing `isa subject` search keeps meaning the animals;
  A probe, camera (device) or plate
  (material) is an entity: `ndi.entity.search(S, {'type', 'material'})`.
  `'subject'` is not a kind `ndi.entity.search` accepts.
- **2026-10-08 (Jess Haley): `ndi.subject` is not touched on this branch.** It is
  v1's class exactly as on `V2`; every entity, a worm included, is read as an
  `ndi.entity`, and D4 below is withdrawn.
- **Q3** ANSWERED: `ndi.value`, a small value class.
- **Q4** ANSWERED: a formulation is a data_type, so `formulation()` returns an
  `ndi.value` of class `formulation`; no `ndi.formulation`.
- **Q5** The writing side (D1 defers it): when it comes, does `ndi.statement`
  get constructors wrapping `did2.build`, or does `did2.build` stay the only
  writer?

## 9. What is built (2026-10-06)

| file | what |
|---|---|
| `+ndi/entity.m` | `ndi.entity` (concrete value class) |
| `+ndi/subject.m` | now `ndi.ido & ndi.documentservice & ndi.entity`; adds `type`, `statements`, `assertions`, `members`, `memberOf`, `parts`, `partOf`, static `fromDocument`, `search`. The v1 constructor, `newdocument`, `searchquery` and the `@` check are unchanged |
| `+ndi/statement.m` | `ndi.statement`: `subject`, `variable`, `variable_name`, `composite`, `raw_value`, `value`, `bodies`, `axes`, `conditions`, `notes`, static `fromDocument`, `search` |
| `+ndi/assertion.m` | `ndi.assertion` |
| `+ndi/interaction.m` | `ndi.interaction` (abstract): `time`, `method`, `method_name`, `method_parameters`, `instrument`, `software` |
| `+ndi/observation.m` | `ndi.observation` |
| `+ndi/manipulation.m` | `ndi.manipulation`: `formulation` |
| `+ndi/calculation.m` | `ndi.calculation`: `inputs`, `interpreter`, `operating_system` |
| `+ndi/data_type.m` | `ndi.value` |
| `+ndi/+v2/` | helpers: `props`, `classChain`, `directParents`, `edgeIds`, `getDocument`, `blockOf`, `termName`, `readBody` (the sampled-body reader), `axesTable`, `entryValue` (a condition's or method parameter's one value), `parseUtc`, `timeOf` (the time resolver) |

Tests: `tests/+ndi/+unittest/+setup/+V2/TestObjectLayer.m`, over the Haley CI
fixture, including the v1 subject constructor. Not yet: a chunked body (an
error for now), a v1 session beyond the subject constructor, timing on the full
Haley dataset.

## 10. One entity class (2026-10-08)

did-schema `V_eta_entity_composition_plan.md` (signed 2026-10-08) merged the
entity classes into one `entity` with a bound `type`, made statements a
direction class plus one value-kind mixin, and made a strain an `instance_of`
relation. The readers read both schemas:

| file | what changed |
|---|---|
| `+ndi/entity.m` | `type`, `local_identifier`, `description` read either schema; the statement members, `search` and its helpers moved here from `+ndi/subject.m` (error ids `ndi:entity:...`); `searchKind`; `inheritanceStates` (the walk up `member_of`, the lineage relations and `instance_of`); `summaryOf` adds a column per type a subject is an instance of |
| `+ndi/subject.m` | unchanged from `V2` (v1 only) |
| `+ndi/session.m` | `database_search_with_dataset` |
| `+ndi/+v2/` | `kindOf`, `blockOf` (falls back to the `entity` block), `isaQuery`, `blockQuery`, `leafName`; `classChain` appends the value kind; `matchTerm` / `termQuery` match a CURIE prefix ignoring case; `statementValue` reads the `text` kind; `searchStatements` takes `withDataset` |

Recording keys (decision #70): a Haley video or image statement's `axes()` gives
the image's rows and columns in pixels (centres at 0.5, 1.5, ...) and, for a
video, `time`, one per frame from the recording's start at 1 / frame rate. They
are written only when the file was opened (`'ReadVideos'`, or a TIFF).

## 11. Linked and ingested sessions (2026-10-09)

did-schema `V_eta_linked_session_plan.md` (signed 2026-10-09): a session is in
a dataset when its `session` entity is filed under the dataset, or under a
study that is filed under the dataset; the relation is in the dataset's
database. The relation is `included_in` where the schema binds it, `part_of`
on did-schema main (section 14; `ndi.v2.recordRelation`); "`part_of`" below
means whichever.
An INGESTED session's documents are in the dataset's database too; a LINKED
session's are in its own folder, which a `linked_session` document (`path`,
relative to the dataset's folder when inside it, and an `entity_id` edge to the
session's entity) names. v1's `session_in_a_dataset` is not used.

| method / function | what it does on a V2 dataset |
|---|---|
| `session_list`, `open_session`, `database_search` | list the members (`ndi.v2.datasetSessions`), open a linked one from its folder (checked to hold that session), search the dataset and each linked session |
| `session_notes` | the listing's denominator, and every session left out and why (not `part_of` the dataset; a linked folder missing, unopenable or holding another session; also a warning, `ndi:dataset:sessionsLeftOut`) |
| `add_linked_session(S, 'PartOf', id)` | a record relation (`ndi.v2.recordRelation`: `included_in`, or `part_of` on did-schema main) to the dataset, or the study `PartOf` names, and a `linked_session` document |
| `add_ingested_session(S, 'PartOf', id)` | copies every document of S, with the files it ingested; adds a `part_of` relation unless S's own relations already make it a member |
| `convertLinkedSessionToIngested` | copies the linked session's documents in, deletes the `linked_session` |
| `convertIngestedSessionToLinked(id, folder)` | writes the session's documents to a new V2 session in `folder`, deletes them from the dataset, adds a `linked_session`; the `part_of` relations stay |
| `unlink_session` | deletes the `linked_session` and the `part_of` relations naming the session; the folder stays |
| `makeSelfContained('DryRun', tf)` | copies every file the dataset's documents record by location into its file store |

Documents are copied with `ndi.v2.copyDocuments`, as stored
(`ndi.v2.sessionDocuments` reads the did2 database, not the ndi read path,
which adds class blocks): ids, edges and session ids unchanged; a file a
document ingested is ingested again from the source's copy; a file recorded by
location stays where it is. `ndi.dataset.dir`'s constructor now reads its own
database for its lookups. Tests: `TestLinkedSessions`.

Not decided here, and not built: merging shared entities (a strain, people,
software) when a session made on its own joins a dataset. Section 12 records
them as one thing instead, without merging.

## 12. One thing recorded twice: `same_as` (2026-10-20)

did-schema `V_eta_duplicate_entities_plan.md` (signed 2026-10-19), tenet T18:
`same_as` (an `undirected_relation` over entities) joins two records of one
thing and never two instances of one kind (a second N2 worm, or a second
microscope of one model, is `instance_of` the kind); it is written only on an
identifier that names the thing itself, stored in the dataset, and no id is
deleted or rewritten. A physical merge is not decided and not built.

| method / function | what it does |
|---|---|
| `ndi.v2.sameAs(C, ids)` | each id's other records: the `same_as` groups, closed over chains (a~b, b~c); a session also reads its dataset's, where the relation is stored |
| `ndi.entity.search` | with `'inherited'` (default): a relation to either record matches (the instances of either N2 record are N2's; `'instance_of', X`, `'member_of', X`, ...), and an entity matching an assertion about one record is joined by its other records (and their members and parts, as for the record) |
| `statements`, `assertions`, `summary` | what is ASSERTED of another record holds of the entity (`via()` ends in `same_as`), from the entity itself and from each group, whole and type it reaches (a worm whose strain is recorded twice gets both records' assertions); interactions and context do not pass through a `same_as`, since T18 names assertions |
| `e.sameAs()` | the other records, as entities |
| `e.disagreements()` | a table (about, variable, record_id, value): where the records of one group assert different values of a variable. The reader returns every value and picks none; `statements` and `summary` also warn, `ndi:entity:sameAs:disagree` |
| `add_linked_session`, `add_ingested_session` (V2, `'SameAs'` default true) | before the session joins, `ndi.v2.sameAsMatches` compares its entities with the dataset's, pair by pair within one type: the same identifier CURIE (prefix ignoring case), the same serial number and manufacturer on two devices, or the same catalog or model number on two products is a MATCH, and a `same_as` is written in the dataset's database for each not already joined; the same name alone, or the same serial number without a manufacturer on both, is a CANDIDATE, listed and never written; differing identifiers (or serial or catalog numbers) make two things, neither. `same_as_report()` returns the denominator, the matches (with the relation written), the candidates and notes |

Serial numbers and manufacturers are read from assertions whose variable is
`serial number` and `manufacturer` (the unit's serial number has no field of
its own yet, Haley decision #14); a catalog number from `product.catalog_number`
or a `catalog number` / `model number` assertion. Sessions, epochs and datasets
are not compared. Tests: `TestSameAs`, on both schema legs (both bind
`same_as`, and `instance_of` from a device to a product).

Not built: confirming a candidate (writing its `same_as` by hand is a
`did2.build.undirectedRelation({a, b}, 'same_as', ...)` in the dataset).

## 13. Terms as objects: `ndi.term` (2026-10-20)

A statement names things with terms: its variable, its method, the variables of
its conditions, parameters and keys, units, and a term-valued statement's value.
Each is stored as `{node, name}`. Until now the readers handed those back as
structs and each caller asked the ontology on its own (`ndi.v2.synonyms`,
`matchTerm`). `ndi.term` (Jess, 2026-10-20) holds the stored node and name and
asks the ontology for the rest only when a method needs it, so a session's
thousands of terms cost nothing until one is asked about.

| member | returns |
|---|---|
| `node`, `name` | the CURIE and the name as stored (either may be `''`) |
| `label()`, `definition()`, `synonyms()`, `id()` | what `ndi.ontology.lookup` says for the node |
| `lookup()` | all of those, as a struct (`ndi.v2.termLookup`) |
| `prefix()`, `key()`, `iri()` | the prefix as written; the node in the form nodes are compared in (`ndi.v2.curieKey`); the IRI, from the registry's `uri_base` (`ndi.v2.curieIri`) |
| `hasNode()` | true where the term has a node |
| `==`, `~=` | two terms: equal keys when both have a node, else equal names ignoring case; a term and text: the text is its node (by key), name or label |
| `string()`, `char()` | the name (the node when there is none), so code that wants names keeps working |
| `toStruct()` | `{node, name}`, as the builders take a term |
| `ndi.term.fromStored(x)` (static) | terms from a stored struct, struct array, cell array or text |

**The stored name and the ontology's label are kept apart.** `name` is what the
dataset says and `label()` what the ontology says now; they can differ (a name
written before its term was looked up, or a dataset's own wording), and neither
replaces the other. The Haley import writes the ontology's label as the name
(Jess, 2026-10-20: `WBls:0000038` is stored as `'L4 larva Ce'`, as WBls labels it).

**One cache.** `ndi.v2.termLookup` looks a node up once per machine and keeps the
answer (id, label, definition, synonyms) in the folder `ndi.v2.synonyms` already
used (`NDI_SYNONYM_CACHE`); `ndi.v2.synonyms` now reads it. A file written before
(names only) still reads, its first name as the label, with no definition until
a `'Refresh'`. Without ndi-ontology-matlab or the network, the ontology methods
return `''` or `{}`.

**What returns one:** `ndi.statement.variable()`, `ndi.interaction.method()` and
`ndi.value.terms()`. `variable_name()`, `method_name()`, `canonical()` and the
`conditions()` / `method_parameters()` / `axes()` tables still give names.
Tests: `TestTerm` (offline, from a prepared cache) and `TestObjectLayer`.

## 14. What a relation passes; records' own relation; `session_id` as an edge (2026-10-20)

did-schema `V_eta_relation_inheritance_plan.md` (a proposal built ahead of
signature, did-schema#88; Haley decision #109). NDI reads both shapes, so
did-schema main behaves as before.

- **What passes is the registry's.** Each `relation_bindings` row declares
  `passes`: `assertions` (part_of, sample_of, aliquot_of, passage_of,
  instance_of), `distributive` (member_of), `context` (contained_in) or
  `nothing` (every other row). `ndi.v2.relationPasses` reads it once per
  schema file; `ndi.entity` walks the `assertions` relations (instance_of on
  its own path, as a type) from it, so a relation the registry adds works
  without code. A registry without the column (did-schema main) gives the
  lists NDI hard-coded before. The member_of and contained_in walks keep
  their own rules (the `distributive` flag; stay times), and the registry's
  one row of each matches them.
- **Records are `included_in`** (`schema:isPartOf`, passes nothing): a session
  in a study or dataset, a study in a dataset. A study no longer reads the
  dataset's short name, version or licence as its own; `part_of` is physical.
  Writers and readers of membership ask `ndi.v2.recordRelation` (`included_in`
  where the schema binds it, `part_of` before): section 11's methods,
  `ndi.setup.V2.createSession` / `createDataset` / `datasetMetadata`, the
  Haley import.
- **`session_id` is an edge.** `base` has no `session_id` field; every
  document has a `session_id` edge to the session or dataset entity it is
  stored with, whose `base.id` IS the session id. `ndi.document/session_id`,
  `set_session_id` and `ndi.v2.sessionIdOf` read and write the field or the
  edge, whichever the document has (v1 keeps the field: NDI still writes v1).
  A query on `base.session_id` needs no change: DID answers it from either
  (`did2sqlite` translates query terms one for one, no field is rewritten).
  `createSession` gives the session entity the session id as its id
  (`'SessionDocId'` must then equal it); the dataset entity's id is the
  dataset's session id, and it is the dataset folder's own record
  (`createDataset` writes no separate `session` document beside it).
  `ndi.session.dir`, `ndi.dataset.dir` and `session_list` find their own record
  by id first, then as before (`ndi.v2.sessionRecord`).
- **An assertion about a container stays on it** (T-3, did-schema dc66d35): a
  plate's exclusion is not its worms'. An analysis asks the containers in one
  call:

| call | returns |
|---|---|
| `ndi.statement.search(S, 'Class', 'calculation', 'NotContainerAssertion', {'inclusion in analysis', false})` | the statements whose subject was not, while they held, `contained_in` a container so described (its own stays, a distributive stay of a group it is member_of, nested containers; `ndi.v2.containersDuring`) |
| `ndi.statement.search(..., 'ContainerAssertion', desc)` | only those whose subject was in such a container |
| `[s, info] = ndi.statement.search(...)` | `info`: read, containers (matching the description), kept, dropped, undecided (a stay or time that could not be compared: undecidable means not in, T17) |

At the entity level the same question is already one call:
`ndi.entity.search(S, {'directed_relation', {'name', 'contained_in', 'parent', {'inclusion in analysis', false}}})`
(ever contained, with no statement time to compare).

