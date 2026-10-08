# NDI V2 object layer: subjects, statements and entities

**Status: PARTLY BUILT (2026-10-06), for review by Jess Haley and Steve Van Hooser.**
Built (read side): `ndi.entity`, `ndi.subject` as an entity, the statement tree,
`ndi.data_type`, and the `ndi.v2` helpers. **Not built, on purpose:** any change to
`ndi.session` or `ndi.dataset` (section 4, "Entry points"); `ndi.strain`, `ndi.study`;
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
once, so the user writes `w.statements('Variable', 'midpoint speed').value()`.

## 2. What exists today (NDI-matlab, branch `claude/haley-import-v2`)

| object | what it does | V2 status |
|---|---|---|
| `ndi.dataset` | opens a dataset, lists and opens its sessions, searches its database | opens a V2 dataset and lists its sessions (import stage 13, decision #66); no subjects, statements, studies or entities |
| `ndi.session` | database front end; DAQ systems, probes, elements, syncgraph | opens a V2 session; no subjects, statements or entities |
| `ndi.subject` | `local_identifier`, `description`; `newdocument`, `searchquery`; a string check | requires an `@` in `local_identifier` (`subject.m:120`); no navigation |
| `ndi.element`, `ndi.probe` | acquisition objects, raw-data reading | V2 read through `ndi.vintage` (the v1/V2 name map) |
| statements, entities | none | only as raw documents from `database_search` |

There is no method today that lists a session's subjects.

## 3. Decisions (agreed with Jess Haley, 2026-10-06)

- **D1 Read first.** Build the side that opens an existing dataset and answers
  questions before any side that creates documents through these objects. Writing
  stays with `did2.build` (as the Haley import does) until reading is done.
- **D2 One statement tree, mirroring the schema.**
  ```
  ndi.statement          subject_statement
  ├── ndi.assertion      subject_assertion        (e.g. term_assertion: species, strain, exclusion)
  └── ndi.interaction    subject_interaction      (abstract: never returned on its own)
      ├── ndi.observation    subject_observation
      ├── ndi.manipulation   subject_manipulation
      └── ndi.calculation    subject_calculation
  ```
  There is no class per leaf (`velocity_calculation`, `dose_manipulation`, ...):
  about forty leaves would differ only by name. A statement object is returned as
  the right child automatically, from its document's class chain, so a new leaf in
  the schema needs no new code.
- **D3 `value()`, not `data()`.** A statement has one value, stored inline or in a
  data body; where it is stored is the schema's business. `value()` returns it
  either way, decoding the body when the value lives there. `body()` stays for
  the raw file.
- **D4 `ndi.subject` is an `ndi.entity`.** The schema already says so: `subject`,
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
| `ndi.entity.fromDocument(container, doc)` (static) | the right class for the document: `ndi.subject` for a subject, else `ndi.entity` |
| `ndi.entity.search(container, kind, 'Name', ...)` (static) | a cell array of entities of a kind |

`ndi.entity` is a CONCRETE value class: a person, an organization or a piece of
software is an `ndi.entity` with no subclass. It holds its document and the
session or dataset it was read from, and nothing else; every question is a query.

Subclasses only where there is real behaviour:

- `ndi.subject` (section below);
- `ndi.strain`: `species()`, `lineage()` (parental strains), `genotype()`;
- `ndi.study`: `sessions()`, `factors()`, `design()`.

Persons, organizations, products, software, funding and publications are plain
`ndi.entity`. A formulation is not an entity, so it is not here: it is reached
from a dose (`ndi.manipulation.formulation()`), see open question Q4.

### `ndi.subject < ndi.entity`

| member | returns |
|---|---|
| `type` | the coarse kind: organism, group, culture, material, ... |
| `statements(...)` | statement objects about this subject; filters `'Variable'`, `'Class'` (observation, manipulation, calculation, assertion, or a leaf class), `'Method'`, `'During'` (a time window) |
| `assertions(...)` | `statements('assertion', ...)`: assertion objects (species `Caenorhabditis elegans`, strain `N2`, `inclusion in analysis` `excluded`); `ndi.summary` of them is the table |
| `observations(...)`, `manipulations(...)`, `calculations(...)`, `interactions(...)` | `statements('<kind>', ...)`: objects of that kind, inherited by default; an optional cell of filters first, e.g. `w.observations({'variable', 'temperature'})` |
| `members()` / `memberOf()` | a group's members / the groups it belongs to (`member_of`) |
| `parts()` / `partOf()` | `part_of`: a plate's patches / a patch's plate |
| `location(t)` | where the subject was at time `t` (`contained_in`) |

The v1 constructor and its `@` check stay as they are (D6).

### `ndi.statement`

| member | returns |
|---|---|
| `subject()` | the `ndi.subject` it is about |
| `variable` | the term (name and node) |
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
| `method()`, `method_parameters()` | the term; a table of parameters |
| `instrument()` | the instrument subject, if any |

### `ndi.observation`, `ndi.manipulation`, `ndi.calculation < ndi.interaction`

- `ndi.observation`: nothing more today.
- `ndi.manipulation`: `formulation()` for a dose: what was given, with its
  ingredient tree.
- `ndi.calculation`: `inputs()` (the statements and documents it was computed
  from), `software()` (software, interpreter, operating system).

### `ndi.data_type`

A statement's value, the same object whether it was stored inline or in a data
body (answers Q3: a small value class).

| member | returns |
|---|---|
| `canonical()`, `double()` | the values in the canonical unit; a term's name; the raw struct for a structured value (dose, item, model fit) |
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
| `ndi.subject.search(S, 'type', 'organism', 'species', 'Caenorhabditis elegans', 'strain', {'N2', 'CB*'}, 'manipulation', {'method', 'heating', 'value', '>=0.02'})` | subjects for which every pair holds (no pairs: every subject, instruments included: answers Q2). A property is one of the subject's own fields (`type`, `name`, `local_identifier`); a statement kind (`statement`, `assertion`, `interaction`, `observation`, `manipulation`, `calculation`, each including its children) with a cell of filters on ONE statement (`variable`, `method`, `value`, `formulation`; the key twice is two statements); or any other name, an asserted variable (`'strain', 'N2'` is `'assertion', {'variable', 'strain', 'value', 'N2'}`). Names ignore case. A pattern matches a term's name ignoring case or its node exactly; a cell array is any of; `*` is a wildcard (in the database with DID-matlab #218's `wildcard` operator, else rechecked in MATLAB). Numbers and dates compare with `>`, `>=`, `<`, `<=`; an array or body value has no single value. `'inherited'` (default true) adds the members, down `member_of`, of a group whose statement is `distributive`; `contained_in` and `part_of` are not followed. A variable or method no statement has is an error; values matching nothing, a warning (`ndi.v2.searchStatements`) Relations: `'relation'`, `'directed_relation'`, `'undirected_relation'` take `{'name', R, 'parent'|'child'|'with', X}` (the subject is the child / the parent / either end), X a subject, several, a document id, or a nested description; a relation's own name is a key (`'contained_in', X` = child of a contained_in whose parent is X; `'with'` for undirected). Inherited also carries a distributive relation from a group to its members, and an assertion from a whole to its parts and samples (part_of, sample_of, aliquot_of, passage_of). `'explain', true` prints the search in words. Not built yet: `'at'`, `'during'`, `'depth'`. |
| `ndi.statement.search(S, 'Subject', s, 'Variable', v, 'Class', c, 'Method', m)` | statements |
| `ndi.entity.search(S, kind)` | entities of a kind |
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
- **Q2** ANSWERED: subjects include instrument subjects unless a filter says otherwise.
- **Q3** ANSWERED: `ndi.data_type`, a small value class.
- **Q4** ANSWERED: a formulation is a data_type, so `formulation()` returns an
  `ndi.data_type` of class `formulation`; no `ndi.formulation`.
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
| `+ndi/data_type.m` | `ndi.data_type` |
| `+ndi/+v2/` | helpers: `props`, `classChain`, `directParents`, `edgeIds`, `getDocument`, `blockOf`, `termName`, `readBody` (the sampled-body reader), `axesTable`, `parseUtc`, `timeOf` (the time resolver) |

Tests: `tests/+ndi/+unittest/+setup/+V2/TestObjectLayer.m`, over the Haley CI
fixture, including the v1 subject constructor. Not yet: a chunked body (an
error for now), a v1 session beyond the subject constructor, timing on the full
Haley dataset.
