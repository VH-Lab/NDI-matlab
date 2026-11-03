# Moving a dataset from v1 to v2

This guide is for someone who has an NDI dataset or session written with v1 and
wants to use it with v2. It says what changes, how to migrate, how to check
that nothing was lost, and what in your own code has to change.

How to work with a v2 dataset once you have one (open it, search it, read it,
write it) is in [Using_V2.md](developer/Using_V2.md).

The decisions this guide follows are recorded in did-schema
(`docs/plans/did_v2_go_forward_class_audit.md`). Each is cited by its tag, for
example [v2 line reads and writes both].

## 1. What v2 is

v2 is NDI's second document model. The schema set is called `did_v2`; v1's is
`did_v1`. (Earlier drafts called the v2 set `V_eta`. That name is retired and
no longer accepted: [schema set renamed did_v2], [V_eta not kept as an alias].)

The biggest differences from v1:

- **One entity class.** Subjects, strains, people, software, sessions,
  datasets and other named things are all `entity` documents with a `type`
  (organism, strain, software, session, ...).
- **Statements.** What is known about an entity (its species, a treatment, a
  measurement, a computed value) is a statement that points at the entity:
  an assertion, observation, manipulation or calculation.
- **Methods.** How something was done is a `method`: a term plus its
  parameters, either inside the statement or as a standalone `method`
  document.
- **Relations.** Links between things (a worm in a group, a session in a
  dataset) are relation documents.

Every document says which model it follows in
`document_class.schema_version`: `did_v1` or `did_v2` ([document stamps]).

## 2. v1 and v2 side by side

The NDI-matlab and DID-matlab `V2` branch reads and writes both versions
([v2 line reads and writes both], Jess Haley, 2026-11-03):

- **A v1 dataset stays v1.** Opening it never migrates it. What NDI writes
  into a v1 database is v1.
- **A v2 dataset is written as v2.**
- **Migration happens only when you ask for it**, with `ndi.migrate.local`
  (section 3). Nothing else calls it.

What that means today on the `V2` branch:

- A folder whose `.ndi` folder holds only a v1 database opens as v1, as
  before. NDI opens a v2 database file when the folder has one
  (`did_v2.sqlite`, or `V_eta.sqlite` from before 2026-11-01), and the v1
  database otherwise.
- A folder with a `did_v2.sqlite` opens that file, so after a migration the
  folder opens as v2. The v1 database file is still there; the migration does
  not delete it.
- **A brand-new session is still created as v1.** The decision is that a new
  database should be v2 ([new database defaults to v2]), but that is **not in
  effect yet**: it waits for v2 writers for ingesting data and for elements.
  Until then `ndi.session.dir` on an empty folder makes a v1 database. To make
  a v2 session now, use `ndi.setup.V2.createSession` (see Using_V2.md,
  section 6).
- **Writing into a migrated (v2) session.** Some NDI objects already write
  their v2 record into a v2 database and their v1 document into a v1 one: the
  session record, `ndi.subject`, file navigators, DAQ readers and metadata
  readers, DAQ systems, the syncgraph and its sync rules. Every other NDI
  writer (the spike extractor and sorter, elements, probe locations,
  openMINDS, ...) still makes a v1 document; written into a v2 database, it is
  checked against NDI's v1 template and stored stamped `did_v1`, beside the v2
  documents ([v1 writes into a V2 session]). Moving these writers to v2 is
  ongoing work.

## 3. How to migrate

### What you need

- NDI-matlab and DID-matlab, both on their `V2` branch, on the MATLAB path.
- The v2 schema: point `DID_SCHEMA_PATH` at `schemas/did_v2` in a checkout
  of did-schema `main` (https://github.com/Waltham-Data-Science/DID-schema),
  and reset DID-matlab's schema cache so it reads that folder:

  ```matlab
  setenv('DID_SCHEMA_PATH', '/path/to/did-schema/schemas/did_v2');
  did2.schema.cache.resetSingleton();
  ```

### Try it first

A dry run converts everything in memory and writes nothing:

```matlab
r = ndi.migrate.local('/data/my_experiment', 'DryRun', true);
```

The result `r` holds the report the real run would write (section 4).

### Run it

```matlab
r = ndi.migrate.local('/data/my_experiment');
```

The folder you pass (`PATH` below) is the one that holds the `.ndi` folder: a
session's folder, or a dataset's. One call migrates one database, the one in `PATH/.ndi`. For a
dataset that is the dataset's database, which holds every session ingested
into it. A session linked into a dataset by its path has its own folder and
its own database; migrate it with its own call.

What the run does:

1. Takes a lock, `PATH/.ndi/.migrate.lock`, so two migrations of one dataset
   cannot run at once (error `NDI:migrate:locked`).
2. Copies the whole `.ndi` folder to `PATH/.v1-backup`, unless that folder
   already exists (`'Backup', false` skips this).
3. Reads every v1 document, converts it, and runs the passes that need the
   whole dataset at once (shared strains, software and people moved to the
   dataset; epochs, stimuli, time references, and so on).
4. Writes the result to `PATH/.ndi/did_v2.sqlite`, with the run's `migration`
   document and its report (section 4). The v1 database is left unchanged.
5. Writes any document that failed to convert to
   `PATH/.ndi/migrate_quarantine.json`.

Options you may want:

| option | default | what it does |
|---|---|---|
| `'DryRun'` | `false` | convert and report, write nothing |
| `'Backup'` | `true` | copy `.ndi` to `.v1-backup` first |
| `'ContinueOnError'` | `true` | put a failing document in quarantine and go on; `false` raises `NDI:migrate:hadQuarantine` at the end instead |
| `'Verbose'` | `false` | print the end-of-run summary |
| `'Validate'` | `true` | check every document against its schema; leave it on |

`'TargetVersion'` accepts only `'did_v2'`, its default.

**Running it again.** If `did_v2.sqlite` already exists, the run reads it,
checks it again against the report stored in it, and writes nothing
(`r.alreadyMigrated` is true). To migrate again from v1, delete
`PATH/.ndi/did_v2.sqlite` first.

**Cloud datasets.** `ndi.migrate.cloud` does not write yet: it converts only
document by document and skips the whole-dataset passes, so it refuses to run
unless you pass `'DryRun', true` (error `NDI:migrate:cloudIncomplete`;
[cloud migrate refuses]).

## 4. Checking the result

### What "lossless" means

A migration must not lose anything ([generic stage is lossless]). The test is
a round trip: it must be possible to rebuild the v1 documents from what v2
keeps ([lossless means round trip]). So every v1 document ends up in one of
two states:

- **converted** to v2 documents; or
- **carried whole as v1**: kept exactly as it was, stamped `did_v1`, and
  stored in the same v2 database ([passthrough stays v1]). This happens when
  v2 cannot yet hold everything the document says. A document that points at a
  carried document is carried too ([dependents of a carried document carry]).

Every reason for carrying a document is a row in did-schema's carry register
(`schemas/registry/did_v2_carry_register.json`; [carry register]). Each row
names the v1 class and fields, the decision, and one of four kinds:

| kind | means |
|---|---|
| `awaiting_home` | v2 should hold this and does not yet; the row names the open work |
| `needs_mapping` | the v1 document can be read more than one way; a per-dataset choice decides |
| `not_modelled` | v2 records this somewhere else, or on purpose not at all |
| `malformed` | the v1 document holds something no NDI writer produces |

A carried document is not an error. It means "kept as v1 until v2 has a place
for this", and it is listed in the report with its reason.

A document in quarantine *is* an error: it failed to convert and is not in
the new database. A lossless run has none.

### The report

Each run writes one `migration` document per dataset ([migration record],
[one migration document per dataset]). If the run holds no dataset, it writes
one per session. The `migration` document records how the data were converted:
its method is the term EDAM:operation_3434 "Conversion", with parameters
naming the tool (DID-matlab), its exact commit, and the source and target
formats (`did_v1`, `did_v2`). The report itself is a JSON file attached to it
([migration report is an attached file]), with three parts:

- `gaps`: each required v2 field the v1 source never stated, by document and
  field, with the reason. A migrated document may lack a required field only
  when the report lists it ([gap accepted when the report lists it]).
- `carried_as_v1`: each document carried whole as v1: its id, class, the
  carry register row it cites, and the reason.
- `counts`: the number of documents, gaps and carried documents (by register
  row, and how many cite no row), and the run's own counts (v1 documents
  read, quarantined).

The same report is returned in `r.migrationReport`, also on a dry run. When
the run wrote more than one `migration` document, it is an array with one
element per record, each with an `anchor` (the dataset or session it is for).

What to look at after a run:

```matlab
r.summary                      % documents read, migrated, quarantined, by class
numel(r.quarantine)            % should be 0; r.quarantineFile says where they are
r.secondPassErrors.total       % should be 0: a pass that failed, not a carry
rep = r.migrationReport(1);
rep.counts                     % documents, gaps, carried_as_v1, ...
rep.counts.carried_citing_no_row   % should be 0: every carry has a reason
struct2table(rep.carried_as_v1)    % what was kept as v1, and why
struct2table(rep.gaps)             % what the v1 source never said
```

`r.migrationRecord.migration_ids` holds the ids of the `migration` documents
written.

To read a stored report later, open the database with DID-matlab and read the
file attached to the `migration` document (this is what `ndi.migrate.local`
does when it checks a database again):

```matlab
db = did2.database.sqlitedb(fullfile(folder, '.ndi', 'did_v2.sqlite'));
ids = db.allIds();
docs = cell(numel(ids), 1);
for k = 1:numel(ids)
    doc = db.get(ids{k});
    docs{k} = doc.toStruct();
end
cls = cellfun(@(s) char(s.document_class.class_name), docs, 'UniformOutput', false);
mig = cellfun(@(s) char(s.base.id), docs(strcmp(cls, 'migration')), 'UniformOutput', false);
reports = {};
for k = reshape(find(strcmp(cls, 'opaque_body')), 1, [])
    d = docs{k}.depends_on;
    if isstruct(d) && any(ismember({d(strcmp({d.name}, 'owner_id')).document_id}, mig))
        reports{end+1} = jsondecode(fileread(db.filePath(ids{k}, 'body_data_0'))); %#ok<AGROW>
    end
end
db.close();
```

## 5. What your own code may need to change

NDI's own objects read both versions. `S.daqsystem_load`, `S.getprobes` and
`S.getelements`, the spike extractor and the spike sorter all find their
documents in a v1 or a v2 session. Code that searches the database itself may
need changes.

### Searches by v1 class name

v2 renamed or merged many v1 classes, and a v2 document's class chain does not
include its v1 name. So `ndi.query('', 'isa', '<v1 class>')` finds the v1
documents in a database (including any carried as v1) and none of the
converted ones. Two helpers find both:

- `ndi.vintage.isaQuery(name)` for the acquisition classes NDI maps:
  `daqsystem`, `filenavigator`, `daqreader`, `daqmetadatareader`,
  `syncgraph`, `syncrule`, `element_epoch` and `epochfiles_ingested`.
  `element` is not widened this way, because a v2 element shares its class
  with other things; use `S.getelements()`.
- `ndi.v2.isaQuery(name)` for a v2 class name, including the names classes
  had before they merged into `entity` (`'session'`, `'strain'`,
  `'software'`, ...).

To see what a v1 class became, read did-schema's coverage ledger
(`docs/generated/did_v2_coverage_ledger.md`), one row per v1 class with its
v2 target.

### Subjects and other entities

In v2 a subject is an `entity` whose `type` is a biological kind: `organism`,
`culture`, `tissue`, `cell` or `group` (`ndi.v2.subjectTypes()`). A probe or
camera is an entity of type `device`, a plate one of type `material`; they are
not subjects.

- `ndi.query('', 'isa', 'subject')` still works and finds both v1 subjects
  and v2 entities of those biological types.
- A strain, person, software, session or dataset is an `entity` with that
  type. Use `ndi.v2.isaQuery('strain')` (and so on). In a dataset, the
  shared ones (strains, people, software) are stored with the dataset, so
  search the dataset rather than one of its sessions.
- `ndi.subject` is v1's class. Read a v2 subject as an `ndi.entity`
  (Using_V2.md, section 2).

### Saved app settings: `base.name` becomes `method.name`

In v1, an app's saved parameter set (for example the spike extractor's
"default") is a document of the app's class whose `base.name` is the preset's
name. Migration turns it into a standalone `method` document, with the
preset's name in `method.name`; there is no `base.name` ([preset name stays
on method]).

`ndi.app.spikeextractor` and `ndi.app.spikesorter` find a preset either way
(through `ndi.vintage.appParameterDocs`). Your own code that looks a preset up
by `base.name` must also search `method.name`:

```matlab
q = ndi.v2.isaQuery('method') & ndi.query('method.name', 'exact_string', 'default', '');
presets = S.database_search(q);
```
