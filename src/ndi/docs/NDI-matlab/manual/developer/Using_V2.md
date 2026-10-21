# Using V2

A short guide for a scientist with a V2 (V_eta) dataset: how to open it, find
things in it, read what is stated about them, and write one. The design and its
reasons are in [V2_Object_Layer.md](V2_Object_Layer.md). The examples follow the
Haley C. elegans dataset and its unit tests (`TestObjectLayer`, `TestHaleyWrite`).

V2 needs DID-matlab's V2 line on the path and `DID_SCHEMA_PATH` set to a folder of
V_eta schema files (did-schema `schemas/V_eta/stable`, `draft` and `deprecated`,
copied into one folder). **It requires did-schema #88 and DID-matlab #218** (one
`entity` class, statements by composition, `included_in`, a `session_id` edge,
the term registry): NDI writes that shape only, and NDI-matlab #1021 merges after
both. Until they merge, take did-schema and DID-matlab from their branch
`claude/ecstatic-pascal-md91fw`. `ndi.setup.V2.preflight` says so when the schema
on `DID_SCHEMA_PATH` is older.

## 1. Open a dataset or a session

```matlab
ds = ndi.dataset.dir('/data/haley_V2');          % a dataset folder
[refs, ids] = ds.session_list();                 % its sessions
S = ds.open_session(ids{1});                     % one of them

S2 = ndi.session.dir('/data/haley_V2/concentration_0001');   % a session folder on its own
```

**Read through the dataset.** A session searches only its own documents. The
shared ones (people, studies, strains, software, products, instruments,
formulations) are stored with the dataset, so an object read through a session
cannot reach them. A session opened from its dataset (`ds.open_session`) can.

## 2. Find entities

Everything a dataset names (a worm, a cohort, a plate, a camera, a person, a
strain) is an `ndi.entity`. `ndi.entity.search` takes one cell of PROPERTY,
VALUE pairs, then options:

```matlab
worms  = ndi.entity.search(S, {'type', 'organism'});
plate  = ndi.entity.search(S, {'local_identifier', 'concentration_assayPlate0012'});
n2     = ndi.entity.search(S, {'type', 'organism', 'species', 'Caenorhabditis elegans', 'strain', 'N2'});
onIt   = ndi.entity.search(S, {'type', 'organism', 'contained_in', plate{1}});
people = ndi.entity.search(ds, {'kind', 'person', 'name', 'Jess*'});
subj   = ndi.entity.search(S, {'type', ndi.v2.subjectTypes()});   % every subject
ndi.summary(n2)                                   % one row per worm
```

A property is one of the entity's own fields (`type`, `name`,
`local_identifier`, `id`, `kind`), a statement kind with a cell of filters
(`{'manipulation', {'method', 'heating'}}`), a relation name
(`'contained_in', X`), or any other name, read as an asserted variable
(`'strain', 'N2'`). Names ignore case; `*` is a wildcard; numbers and dates
compare with `>`, `>=`, `<`, `<=`.

`ndi.v2.subjectTypes()` is `{'organism', 'culture', 'tissue', 'cell', 'group'}`.
A plate (`material`) or a camera (`device`) is an entity but not a subject, and
`'subject'` is not a kind `search` accepts.

Options after the cell: `'inherited'` (default true: what holds of a group, a
whole or a type holds of its members, parts and instances), `'context'`,
`'strict'` (false: an empty answer instead of an error for a name nothing has),
`'explain'` (true: print the search in words), `'tolerant'`, `'synonyms'`.

## 3. Read statements

What is known about an entity is a set of statements: assertions (species,
strain, an exclusion), observations, manipulations and calculations.

```matlab
w = ndi.entity.search(S, {'local_identifier', 'concentration_worm0121'});
w = w{1};
a  = w.assertions();                                           % species, strain, ...
sp = w.assertions({'variable', 'species'});
t  = w.observations({'variable', 'Environmental Temperature'}, 'context', true);
v  = w.statements('velocity_calculation');                     % a leaf class works too
p  = plate{1}.observations({'variable', 'Imaging Signal Intensity'});
```

Each returns a cell array of statement objects (`ndi.assertion`,
`ndi.observation`, `ndi.manipulation`, `ndi.calculation`). The filters are
`'variable'`, `'method'`, `'value'`, `'formulation'` and the time filters
`'at'`, `'during'`, `'before'`, `'after'`, `'duration'`.

```matlab
x = v{1}.value();          % an ndi.value, decoded from its data body when stored there
double(x)                  % metres per second, by video frame
x.unit()                   % the canonical unit's field, e.g. 'meters_per_second'
v{1}.axes()                % what each dimension indexes (video frame, body part)
v{1}.time()                % when it holds (UTC start and end, with tolerance)
v{1}.method_parameters()   % the method's settings, as a table
v{1}.inputs()              % the statements it was computed from
a{1}.value().canonical()   % a term's name, e.g. "N2"; a logical, a number
ndi.summary(a)             % one row per statement
```

A statement's method is one block, `interaction.method: {term, parameters}`
(did-schema #88): `method()` is its `term` and `method_parameters()` its
`parameters`. A shared, named method is instead a standalone `method` document
the statement points at by `method_id` (never both); `method()` and
`method_parameters()` read that document the same way. Searching by `'method'`
(`ndi.statement.search`'s `'Method'`, `ndi.entity.search`'s `{'method', ...}`)
matches either: the inline `interaction.method.term`, or the `method.term` of
the `method` document the statement's `method_id` names (`ndi.v2.methodQuery`).
A statement with neither is not found by a method filter.

To search across a whole session instead of one entity:

```matlab
st = ndi.statement.search(S, 'Class', 'calculation', 'Subject', w, 'Variable', 'position');
```

`via()` on a statement says how it reached the entity: `'own'`, or the
relations it came through (`'member_of'`, `'... instance_of'`,
`'... contained_in'`).

## 4. Walk the graph

```matlab
g = w.memberOf();                                   % its cohort
m = g{1}.members();                                 % the cohort's worms
plates = w.parents({'member_of', 'contained_in'});  % the plates its cohort was on
inside = plate{1}.children('contained_in');         % what was on the plate
wormsOn = plate{1}.descendants('Type', 'organism'); % without naming the relations
T = w.relations();                                  % every relation, as a table
```

What a relation passes is declared in the schema's registry, one of four
answers:

| passes | relations | meaning |
|---|---|---|
| `assertions` | `part_of`, `sample_of`, `aliquot_of`, `passage_of`, `instance_of` | an assertion about the parent holds of the child (a strain's species holds of its worms) |
| `distributive` | `member_of` | a statement marked distributive on a group holds of each member |
| `context` | `contained_in` | the container's interactions reach what it held, as context, only while it held it, and only with `'context', true` |
| `nothing` | `included_in`, `same_as`, every other relation | nothing |

```matlab
P = ndi.v2.relationPasses();      % P.assertions, P.distributive, P.context, P.nothing
```

An assertion about a container stays on the container: a plate's
`inclusion in analysis` false is not its worms'. An analysis asks the containers
in one call:

```matlab
[kept, info] = ndi.statement.search(S, 'Class', 'calculation', ...
    'NotContainerAssertion', {'inclusion in analysis', false});
% info: read, containers, kept, dropped, undecided
```

`'ContainerAssertion'` keeps only the statements whose subject was in such a
container. A subject counts as in a container while its own stay, or a
distributive stay of its group, overlaps the statement's time; a stay or time
that cannot be compared counts as not in. The lower-level call is
`[held, undecided] = ndi.v2.containersDuring(S, docs)`, for statement
documents `docs`.

## 5. Terms

Variables, methods, units and term values are stored as `{node, name}`. The
readers return them as `ndi.term`:

```matlab
t = sp{1}.variable();      % an ndi.term
t.node, t.name             % as stored, e.g. 'NCIT:C45293', 'Species'
t.label()                  % what the ontology calls it now
t.definition(), t.synonyms()
t == "species"             % true: by node, name, label or synonym
k = ndi.term('NCBITaxon:6239', 'Caenorhabditis elegans');
```

The ontology methods need ndi-ontology-matlab, look each node up once and keep
the answer on disk (`NDI_SYNONYM_CACHE`); offline they return `''` or `{}`.
Searches use synonyms by default, so `{'species', 'C. elegans'}` finds
`NCBITaxon:6239`.

DID-schema's term registry lists every term a V2 dataset may hold. A search
for a variable or method that no statement has is widened by the registered
terms that go by it (`ndi.v2.synonymNodes('meter')` finds `metre`). With a
DID-matlab that checks the registry, `did2.build` refuses a term the registry
does not hold; `ndi.setup.V2.registeredTerm(node, name)` returns the
registry's spelling of a term.

## 6. Write

V2 documents are built with DID-matlab's `did2.build` and written with
`ndi.setup.V2`. Every document carries the session id it is stored with.

```matlab
sid = ndi.ido.unique_id();
worm = ndi.setup.V2.entityDocuments('subject', struct('local_identifier', 'worm1', ...
    'type', did2.build.term('', 'organism')), struct(), 'SessionId', sid);
sp = did2.build.statement('term_assertion', worm{1}.base.id, ...
    did2.build.term('NCIT:C45293', 'Species'), ...
    did2.build.term('NCBITaxon:6239', 'Caenorhabditis elegans'), 'SessionId', sid);
S = ndi.setup.V2.createSession(folder, 'day 1', 'SessionId', sid, ...
    'Documents', [worm, {sp}]);
```

- `did2.build.document(className, fields, 'SessionId', sid, 'Edges', ...)`
  builds any document and checks it against its schema;
  `did2.build.statement(leaf, subjectId, variable, value, ...)` a statement;
  `did2.build.term(node, name)` a term; `did2.build.directedRelation(child,
  parent, relation, 'SessionId', sid)` a relation.
- `ndi.setup.V2.createSession(path, reference, ...)` makes a session folder
  with a V2 database; `ndi.setup.V2.createDataset(path, reference,
  datasetSessionId, datasetDocs, sessionDocs)` writes a whole dataset (every
  session ingested) and opens it; `ndi.setup.V2.writeDocuments(dbFile, docs)`
  adds documents to an existing V2 database
  (`.ndi/V_eta.sqlite` in the folder).

- `ndi.setup.V2.attachFile(doc, name, path)` says where the bytes of a
  document's file are (`did2.build.sampledBody` names its file
  `body_data_0`); the write copies it into the database's file store.

### A whole dataset

A dataset is a `dataset` entity whose id IS the dataset's session id, the
dataset-level documents (strains, people, ...) stored under that id, and one
cell of documents per session. A session is a `session` entity whose id is its
session id, `included_in` the dataset (or in a study that is). Use only
registered terms: `ndi.setup.V2.registeredTerm(node)` gives the registry's
spelling, and `did2.build` refuses a term the registry does not hold
(`did2:build:unregisteredTerm`).

```matlab
T = @(node) ndi.setup.V2.registeredTerm(node);
dsid = ndi.ido.unique_id();  sid = ndi.ido.unique_id();
D = {'SessionId', dsid};     S = {'SessionId', sid};

% the dataset, and a strain stated once with its species
ds = ndi.setup.V2.entityDocuments('dataset', struct('name', 'My dataset'), struct(), D{:}, 'Id', dsid);
strain = ndi.setup.V2.entityDocuments('strain', struct('name', 'N2'), struct(), D{:});
sp = did2.build.statement('term_assertion', strain{1}.base.id, T('NCIT:C45293'), T('NCBITaxon:6239'), D{:});
note = did2.build.statement('text_assertion', dsid, T('NCIT:C42610'), did2.build.valueCell('text', {'MD'}), D{:});

% the session, its subjects and their relations
sess = ndi.setup.V2.entityDocuments('session', struct('local_identifier', 'day1'), struct(), S{:}, 'Id', sid);
inc  = did2.build.directedRelation(sid, dsid, 'included_in', S{:});
worm = ndi.setup.V2.entityDocuments('subject', struct('local_identifier', 'worm1', ...
    'type', did2.build.term('', 'organism')), struct(), S{:});
isa_ = did2.build.directedRelation(worm{1}.base.id, strain{1}.base.id, 'instance_of', S{:});

% when: an interval after the start of the session
ref = did2.build.relativeTimeReference(sid, 'Clock', 'dev_local_time', 'Start', 0, 'Duration', 2, S{:});

% an observation whose value is a series in a body
t = did2.build.key(T('om:Time'), 5, 'Unit', T('om:second-Time'), 'Origin', 0, 'Spacing', 0.5);
obs = did2.build.statement('velocity_observation', worm{1}.base.id, T('PATO:0000008'), [], ...
    'Keys', t, 'DataBody', true, 'DatumType', did2.build.datumType('double'), ...
    'TimeReferenceIds', {ref.base.id}, S{:});
body = did2.build.sampledBody(obs.base.id, t, 'ByteOrder', 'little', S{:});
fid = fopen(f, 'w', 'ieee-le'); fwrite(fid, speeds, 'double'); fclose(fid);
body = ndi.setup.V2.attachFile(body, 'body_data_0', f);

% a method inline ...
man = did2.build.statement('temperature_manipulation', worm{1}.base.id, T('NCIT:C90380'), ...
    did2.build.valueCell('temperature', 20, 'SourceValue', 20, 'SourceUnit', T('om:degreeCelsius')), ...
    'Method', T('EMPTY:0000333'), 'MethodParameters', did2.build.parameter(T('om:Time'), ...
        'Value', 3600, 'Unit', T('om:second-Time')), 'TimeReferenceIds', {ref.base.id}, S{:});
% ... or a shared `method` document, named by the statement's method_id.
% A calculation must name the software that computed it and the operating
% system it ran on, both `software` entities.
app = ndi.setup.V2.entityDocuments('software', struct('name', 'my analysis', 'version', '1.0'), struct(), D{:});
os = ndi.setup.V2.entityDocuments('software', struct('name', 'Linux', 'version', '6.8'), struct(), D{:});
m = did2.build.method(T('NCIT:C53319'), [], 'Name', 'mean speed', S{:});
calc = did2.build.statement('velocity_calculation', worm{1}.base.id, T('PATO:0000008'), ...
    did2.build.valueCell('velocity', mean(speeds)), 'MethodId', m.base.id, ...
    'InputIds', {obs.base.id}, 'SoftwareId', app{1}.base.id, 'OperatingSystemId', os{1}.base.id, ...
    'TimeReferenceIds', {ref.base.id}, S{:});

dataset = ndi.setup.V2.createDataset(folder, 'my dataset', dsid, [ds, strain, app, os, {sp, note}], ...
    {[sess, {inc}, worm, {isa_, ref, obs, body, man, m, calc}]}, 'Strict', true);
S1 = dataset.open_session(sid);   % reaches the strain, so the worm's species reads back
```

`tests/+ndi/+unittest/+setup/+V2/TestGenericDatasetEndToEnd.m` builds this
dataset and reads every piece of it back.

The worked example of a real import is the Haley import, `ndi.setup.conv.haley.import_V2`,
with every choice it makes recorded in `import_V2_decisions.md` beside it. Run
without `'Write'`, it returns what each stage would create:

```matlab
r = ndi.setup.conv.haley.import_V2(dataParentDir, ...
    'Sessions', "concentration_0001", 'OutputRoot', outFolder, 'Write', true);
```

## 7. Adding terms for a new dataset

Every variable, method, unit, condition, parameter and key a V2 import writes
must be in DID-schema's term registry (`schemas/V_eta_term_registry.json`;
tenet T19, `V_eta_term_registry_plan.md`). A new dataset usually needs a few
terms the registry lacks. The steps, in order:

**1. List the unregistered terms.** Turn the registry error off and
collection on, run the import, and save the list:

```matlab
prev  = did2.schema.cache.strictMode('TermRegistry', false);
prevC = did2.build.unregisteredTerms('-collect', true);
did2.build.unregisteredTerms('-reset');
r = myImport(dataDir, 'OutputRoot', tempname, 'Write', true);   % your import
L = did2.build.unregisteredTerms();     % one row per (name, node, field), with the reason
did2.schema.cache.strictMode('TermRegistry', prev);
did2.build.unregisteredTerms('-collect', prevC);
writetable(struct2table(L, 'AsArray', true), 'terms.tsv', ...
    'FileType', 'text', 'Delimiter', '\t');
```

A term on a path your fixture does not take is not listed. Read the import's
code for those (the Haley import found two that way).

**2. Choose a node for each term, in T19's order.** Three places to look:

- **The registry.** The term may already be there under the ontology's own
  label: `mean` is `NCIT:C53319` "Arithmetic Mean". Search the JSON, or ask
  `ndi.setup.V2.registeredTerm('', 'arithmetic mean')`. If it is there, use it
  and write nothing new. In the import, write the registered term with
  `ndi.setup.V2.registeredTerm(node)`.
- **An existing ontology.** Search OLS (<https://www.ebi.ac.uk/ols4>, or
  `curl 'https://www.ebi.ac.uk/ols4/api/search?q=petri+dish&rows=10'`), then
  confirm the term with `[id, name, ~, def] = ndi.ontology.lookup('NCIT:C96141')`.
  Use the ontology's label as the name and its definition. Choose the general
  term when the meaning is the same, and never a term narrower or broader
  than what is meant.
- **A new EMPTY term**, only when no ontology has one. Add a class to
  `src/ontology/empty-edit.owl` in Waltham-Data-Science/empty-ontology. Take
  the next free id, write a definition (`IAO_0000115`), a label, a parent
  (`SubClassOf`), and an `rdfs:comment` that records what you searched for
  and why the near misses do not fit, for example `"No ontology term found
  (OLS, 2026-10-21): ..."`. Copy the existing blocks there as the pattern.

If the prefix is new (no entry in `schemas/V_eta/stable/CURIE_lookups_meta.json`),
add it before the term. It goes in that file in DID-schema (an entry with its
`spelling`, URI base and pattern), and in ndi-ontology-matlab (a lookup class
and an `ontology_list.json` entry) when NDI needs to look its terms up.

**3. Check the batch and get the registry rows.** In `terms.tsv`, fill in the
`node` column, and add a `definition` column for the non-EMPTY terms. Then run,
in DID-schema:

```bash
EMPTY_ONTOLOGY=../empty-ontology python3 tools/propose_terms.py terms.tsv \
    --decided "Jess Haley, 2026-10-21" --first-used-in "Smith et al. 2026 (NDI-matlab ndi.setup.conv.smith)"
```

The tool gives each term a verdict:

- `REGISTERED`: the registry already holds the term. Nothing to add.
- `USE REGISTRY`: the node is registered under another name. Fix the import,
  not the registry.
- `ADD`: the term is new. The tool prints its row.
- `FAIL`: the term cannot be added as given. The tool says why, using the
  gate's rules.

For an EMPTY term the tool copies the label and definition from your
empty-ontology checkout. It also rewrites each prefix to the registry's
spelling. It writes nothing: paste the printed rows at the end of `terms`.

**4. Gate.** In DID-schema, run
`EMPTY_ONTOLOGY=../empty-ontology python3 tools/gates.py`. Its `validate_v_eta`
step copies the registry into `schemas/V_eta/stable/term_registry_meta.json`
(the JSON under `schemas/V_eta` is the source; there is no build step).
`check_term_registry` must pass, and its R7 line must say the EMPTY terms
were compared, not `NOT CHECKED`. CI has no empty-ontology checkout, so R7
is checked only on your machine. Copy the `stable`, `draft` and
`deprecated` folders to your `DID_SCHEMA_PATH`. Then re-run step 1, which
should now list nothing, with the registry error back on.

**Which repository and PR gets what:**

| repository | what | PR (until merged) |
|---|---|---|
| Waltham-Data-Science/empty-ontology | new EMPTY classes in `src/ontology/empty-edit.owl` | #22, branch `claude/ome-zarr-format` |
| did-schema | the rows in `schemas/V_eta_term_registry.json`, the regenerated `term_registry_meta.json`, and any new prefix in `schemas/V_eta/stable/CURIE_lookups_meta.json` | #88, branch `claude/ecstatic-pascal-md91fw` |
| ndi-ontology-matlab | a lookup class for a new prefix, only if one is needed | #11 |
| NDI-matlab | the import, writing terms through `ndi.setup.V2.registeredTerm`, and a test like `TestTermRegistry` that runs it with collection on | #1021 |

DID-matlab needs no change. It reads the registry from `DID_SCHEMA_PATH`.
Merge empty-ontology first (the ids are fixed there), then did-schema, then
NDI-matlab.

**What a reviewer checks:**

- Each node resolves (`ndi.ontology.lookup`, or the OLS page). The registry
  name is the ontology's label, exactly.
- The term means what the import writes: not narrower, not broader, and the
  general term when the meaning is the same.
- Each EMPTY term has an `rdfs:comment` that names the search made and why the
  nearest existing terms were rejected. Its parent is sensible, and it names
  nothing the document already carries.
- `decided` names the person who chose the term. Only the team decides terms.
- `propose_terms.py` reports `0 FAIL`, and `check_term_registry` reports R7
  compared, run locally with `EMPTY_ONTOLOGY` set.
- CI is green: did-schema `tests.yml` (the `gates.py` chain) and NDI-matlab
  `test-import-v2.yml`, which includes `TestTermRegistry`.

## 8. Starting a new import

Start from the template, `ndi.setup.conv.template`: copy
`src/ndi/+ndi/+setup/+conv/+template/` to `+<yourlab>/` and work through it one
stage at a time with the dataset's owner. It holds:

| file | what it is |
|---|---|
| `import_V2.m` | the stage runner: `'Stages'`, `'Previous'`, `'Write'`, `'RunFolder'`, the preflight, the term check, the per-stage reports, the write |
| `import_V2_spec.json` | the dataset's mapping (folder pattern, source table and columns, term NAMES, units, corrections); an empty skeleton with comments, and optional |
| `import_V2_decisions.md` | the decision log, with "Current rules" at the top; keep it from day one |
| `private/*Documents.m` | one helper per stage, each writing one example document through the public API, with comments saying what a real importer replaces |

The stages run in a fixed order, and later stages read the ids earlier ones
made: **sessions** (the dataset entity and its studies, then the sessions) ->
**entities** -> **acquisition** (epochs, times, each raw file recorded by
location) -> **manipulations** -> **observations** -> **calculations**. Run
one at a time while building:

```matlab
r = ndi.setup.conv.template.import_V2(dataFolder, 'Stages', "sessions");
r = ndi.setup.conv.template.import_V2(dataFolder, 'Stages', "entities", 'Previous', r);
...
r = ndi.setup.conv.template.import_V2(dataFolder, 'OutputRoot', outFolder, 'Write', true);
```

What the template does for you, and a new import should keep:

- **Every stage reports its denominators**: read, written, skipped (each with
  why) and errors (each with what), and the documents it built; read =
  written + skipped + errors. On a normal run a row's error is reported and
  the stage goes on; with `'RunFolder', 'none'` (test mode) it is thrown.
  With `'Write'` the run keeps `import_log.txt` and `import_report.mat` in a
  run folder.
- **Terms by name** through `ndi.setup.V2.registeredTerm`; the run collects
  every unregistered term and writes nothing until each is registered (see
  section 7).
- **Source values verbatim**: `source_value`, `source_unit` as its registered
  term (`ndi.setup.V2.sourceUnit`), a tolerance where the source states one; a
  hand-written time is approximate, [60 60] s. Corrections go through one
  function, only while the source still reads the correction's `was`, and the
  document says what it was.
- **The raw data is never copied or written to**: recordings by location
  (`ndi.setup.V2.attachFile(..., 'Ingest', false)`), sessions in their own
  folders under `'OutputRoot'`, linked from the dataset.

`TestTemplateImport` runs the template end to end on a tiny folder it writes,
reads the documents back and checks every stage's denominators; copy it with
the template and point it at your own fixture. The Haley import,
`ndi.setup.conv.haley.import_V2`, is the full worked example.

## 9. What is v1 only

- `ndi.subject` is v1's class, with its `@` rule. Read a V2 subject as an
  `ndi.entity`.
- `ndi.session.dir` on an empty folder creates a v1 session, and
  `ndi.document(...)` and `S.newdocument(...)` build v1 documents from NDI's
  templates. Make V2 with `ndi.setup.V2` and `did2.build`.
- v1's `session_in_a_dataset` is not used: a V2 session is in a dataset through
  an `included_in` relation.
- Acquisition objects (DAQ systems, probes, elements, the syncgraph) are v1's.
  A migrated V2 session rebuilds them through `ndi.vintage`; they are not part
  of the V2 object layer.
- Not built: `ndi.strain` and `ndi.study` (a strain or a study is a plain
  `ndi.entity`), `subject.location(t)`, and the relation filter `'depth'`.
