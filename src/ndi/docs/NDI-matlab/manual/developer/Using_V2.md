# Using V2

A short guide for a scientist with a V2 (V_eta) dataset: how to open it, find
things in it, read what is stated about them, and write one. The design and its
reasons are in [V2_Object_Layer.md](V2_Object_Layer.md). The examples follow the
Haley C. elegans dataset and its unit tests (`TestObjectLayer`, `TestHaleyWrite`).

V2 needs DID-matlab's V2 line on the path and `DID_SCHEMA_PATH` set to a folder of
V_eta schema files (did-schema `schemas/V_eta/stable`, `draft` and `deprecated`,
copied into one folder).

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
v{1}.method_parameters()   % the settings, as a table
v{1}.inputs()              % the statements it was computed from
a{1}.value().canonical()   % a term's name, e.g. "N2"; a logical, a number
ndi.summary(a)             % one row per statement
```

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

The worked example is the Haley import, `ndi.setup.conv.haley.import_V2`,
with every choice it makes recorded in `import_V2_decisions.md` beside it. Run
without `'Write'`, it returns what each stage would create:

```matlab
r = ndi.setup.conv.haley.import_V2(dataParentDir, ...
    'Sessions', "concentration_0001", 'OutputRoot', outFolder, 'Write', true);
```

## 7. What is v1 only

- `ndi.subject` is v1's class, with its `@` rule. Read a V2 subject as an
  `ndi.entity`.
- `ndi.session.dir` on an empty folder creates a v1 session, and
  `ndi.document(...)` and `S.newdocument(...)` build v1 documents from NDI's
  templates. Make V2 with `ndi.setup.V2` and `did2.build`.
- v1's `session_in_a_dataset` is not used: a V2 session is in a dataset through
  an `included_in` relation (`part_of` on older schemas).
- Acquisition objects (DAQ systems, probes, elements, the syncgraph) are v1's.
  A migrated V2 session rebuilds them through `ndi.vintage`; they are not part
  of the V2 object layer.
- Not built: `ndi.strain` and `ndi.study` (a strain or a study is a plain
  `ndi.entity`), `subject.location(t)`, and the relation filter `'depth'`.
