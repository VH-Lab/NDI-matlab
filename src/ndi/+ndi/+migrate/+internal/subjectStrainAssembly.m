function [kept, minted, report] = subjectStrainAssembly(v1Bodies, migratedStructs)
%SUBJECTSTRAINASSEMBLY V_eta second pass (#78): assemble the SUBJECT-ATTACHED
%   openMINDS Strain documents into deduplicated strain ENTITIES, make each
%   subject an `instance_of` its strain, wire `backgroundStrain` into
%   `derived_from` relations between strains, move the `genetic strain type`
%   assertion off the subject onto the strain, and drop the duplicate `species`
%   assertion the strain object's own Species child produces.
%
%   [KEPT, MINTED, REPORT] = ndi.migrate.internal.subjectStrainAssembly(
%   V1BODIES, MIGRATEDSTRUCTS).
%
%   V1BODIES is the cell of did_v1 bodies pass 1 read; MIGRATEDSTRUCTS is the
%   cell of migrated V_eta bodies (did2.document.toStruct). KEPT is the
%   surviving migrated set with the replaced, moved and duplicate assertions
%   removed; MINTED is the strain entities, the assertions about them, their
%   `derived_from` relations and the subjects' `instance_of` relations; REPORT
%   states its denominators FIRST and unconditionally, and `[]` from the caller
%   means "did not run", so a silent zero and a real zero are distinguishable
%   from the output alone.
%
%   THE SHAPE IS did-schema #88's (V_eta_entity_composition_plan.md, signed
%   2026-10-08 by Jess):
%     sec. 4  a strain is an `entity` with `type: strain` (required: `name`);
%             its species, genetic strain type and phenotype are term
%             assertions about it, its laboratory code and synonyms text
%             assertions, and its background a `derived_from` relation
%             (strain -> strain, RO:0001000);
%     sec. 5  "`term_assertion.strain_id` goes. A subject is an `instance_of`
%             its strain" -- so the subject's own `strain` assertion is
%             REPLACED by an `instance_of` relation (subject -> strain), which
%             keeps the assertion's id. T17's type-to-instance rule then makes
%             what is asserted of the strain hold of the subject.
%     sec. 1  an assertion is the `assertion` direction plus the `term` (or
%             `text`) value-kind mixin, pointing at what it is about by
%             `entity_id`. The reads accept the pre-#88 spelling as well
%             (`term_assertion`, `subject_id`, `subject_statement`), through
%             ndi.migrate.internal.etaShape.
%
%   This function is PURE apart from minting document ids: it reads structs and
%   returns structs, calls no converter, touches no database and needs no
%   schema. That is what makes it testable without a corpus. Tests:
%   tests/+ndi/+unittest/+migrate/TestSubjectStrainAssembly.m.
%
%   ---------------------------------------------------------------------
%   THIS IS THE OTHER HALF OF THE STRAIN FAMILY, NOT A SECOND COPY OF IT
%   ---------------------------------------------------------------------
%   ndi.migrate.internal.strainAssembly handles the UNATTACHED `openminds`
%   class -- Haley's bacterial food, 8 documents, no subject, ids PRESERVED
%   because `ontologyTableRow`'s `bacteriaStrain` cell holds them as plain
%   strings. This pass handles `openminds_subject`, which is a different
%   situation in every respect that matters:
%
%     * the documents HAVE a subject, and pass 1 already migrated each one 1->1
%       into a `term_assertion` (did2.convert.migrators_j.openminds_subject);
%     * so the source id is ALREADY IN USE by that assertion and the minted
%       strain CANNOT reuse it (see "IDS ARE NOT PRESERVED HERE" below; the
%       `instance_of` relation that replaces the assertion takes it instead);
%     * they are written per SUBJECT ROW, so one strain becomes hundreds of
%       documents and dedup is the point rather than a tidy-up.
%
%   The two passes cannot collide: this one only ever touches a v1 body whose
%   MIGRATED counterpart is a term assertion, and strainAssembly's documents
%   are either still `openminds` passthroughs or have already become strain
%   entities.
%
%   ---------------------------------------------------------------------
%   WHY THIS IS A SECOND PASS AND NOT A `+migrators_j` FILE
%   ---------------------------------------------------------------------
%   Every fact this pass adds lives in a DIFFERENT DOCUMENT from the one that
%   needs it. openMINDS child objects are flattened into their own documents
%   and the parent's field is replaced by an `ndi://<id>` string:
%
%     git show origin/main:src/ndi/+ndi/+database/+fun/openMINDSobj2struct.m
%         s = ndi.database.fun.openMINDSobj2struct({f_here},cachekey);
%         child_index = find(strcmp(char(f_here.id),{s.openminds_id}));
%         fields_here{k} = ['ndi://' s(child_index).ndi_id];
%
%     git show origin/main:src/ndi/+ndi/+database/+fun/openMINDSobj2ndi_document.m
%         for i=1:numel(s)                       % parent AND every child
%             d{i} = ndi.document(docName,'base.id',ndi_id_here, ...
%         ...
%             if startsWith(g{k},'ndi://')
%                 d{i} = add_dependency_value_n(d{i},'openminds',id_here,'ErrorIfNotFound',0);
%         ...
%             if ~isempty(dependency_name)
%                 d{i} = d{i}.set_dependency_value(dependency_name,dependency_value);
%
%   That last line is the one that produces the mess this pass cleans up: the
%   `subject_id` is set on EVERY document of the flattened graph, so a subject
%   whose Strain has a Species child, a GeneticStrainType child and a
%   background Strain ends up with an assertion for each. Pass 1 turns each
%   into its own `term_assertion` and drops the `openminds_#` links
%   (`body.depends_on = jCarrySubject(preBody, {'subject_id'})` --
%   openminds_subject.m:52, an ASSIGNMENT), so after pass 1 nothing records
%   which assertion was a child of which. Only the did_v1 bodies do.
%
%   ---------------------------------------------------------------------
%   THE PEDIGREE COMES FROM `fields`, NOT FROM THE `openminds_#` EDGES
%   ---------------------------------------------------------------------
%   #78's own wording is "the `openminds_#` pedigree edges are read so
%   `backgroundStrain` becomes `background_strain_#`" (on #88, `derived_from`
%   relations between strain entities). READ THE WRITER: those
%   edges CANNOT carry the pedigree by themselves. `add_dependency_value_n`
%   appends `openminds_1, openminds_2, ...` in `fieldnames` order over ALL
%   object-valued fields, so `openminds_1` is as likely to be the SPECIES as
%   the background strain, and nothing in the edge says which role it fills.
%   The role -- and the ORDER within a two-parent cross -- exists only in
%   `openminds.fields.backgroundStrain`, which holds the same ids as
%   `ndi://` strings. So this pass resolves the pedigree from `fields` and
%   treats the `openminds_#` edges as corroboration
%   (REPORT.background_refs_not_in_openminds_edges counts any disagreement
%   instead of hiding it). Same reading as
%   ndi.migrate.internal.strainAssembly, which resolves `fields` for the same
%   reason.
%
%   ---------------------------------------------------------------------
%   THE `fields` KEYS STAY camelCase
%   ---------------------------------------------------------------------
%   did2.convert.universalRenames snake-cases only ONE level --
%   `snakeCaseBlockFields` walks `fieldnames(block)` for each top-level
%   property block and stops -- and `fields` is a nested struct inside the
%   `openminds` block, so `geneticStrainType`, `backgroundStrain`,
%   `ontologyIdentifier` and `preferredOntologyIdentifier` arrive unchanged.
%   Every read below still takes a snake_case fallback, per the standing
%   migrator lesson that any NESTED sub-field a migrator reads needs both.
%   These bodies are also read BEFORE universalRenames in the normal path
%   (ndi.migrate.local hands over the raw reader output), so the fallback is
%   what makes the idempotent re-run path -- readBodiesFromTarget, which hands
%   back already-migrated bodies -- behave the same way.
%
%   ---------------------------------------------------------------------
%   IDS ARE NOT PRESERVED HERE, AND THAT IS FORCED, NOT CHOSEN
%   ---------------------------------------------------------------------
%   Everywhere else in this family the rule is "ids preserved". It cannot hold
%   here for two independent reasons, and both are worth stating because the
%   opposite rule is written down a few files away:
%
%     1. THE ID IS ALREADY TAKEN. Pass 1 kept the source `base` verbatim
%        (openminds_subject.m:54 `body.base = preBody.base`), so the
%        `term_assertion` carries the Strain document's id. Minting a `strain`
%        with the same id would put two documents on one id.
%     2. DEDUP DESTROYS THE 1:1 ANYWAY. Hundreds of Strain documents collapse
%        to one entity, so at most one of their ids could survive.
%
%   That is safe here and would NOT have been safe for the unattached class,
%   and the difference was CHECKED rather than assumed. The only place an
%   openMINDS strain document's id is captured into ordinary data is
%
%     origin/main:+setup/+conv/+haley/doImport.m:164  dataTable{:,'bacteriaStrain'} = {strainDoc{1}.id};
%     origin/main:+setup/+conv/+haley/doImport.m:734  dataTable{:,'bacteriaStrain'} = {strainDoc{1}.id};
%
%   and `strainDoc` there is the return of the BARE call
%   (`openMINDSobj2ndi_document(OP50, session.id)`, :87 and :706) -- i.e.
%   strainAssembly's documents, not these. `git grep -n "strainDoc\|strain_doc\|strainDocs" origin/main -- '*.m'`
%   returns those two lines, subjectMaker.m:269-270 (which only concatenates
%   the documents into the write set), the metadata-editor READER
%   (ndidataset2metadataeditorstruct.m:173-196, which queries
%   `openminds.openminds_type` by exact_string and never stores an id), and
%   testSubjectMaker.m. Nothing else holds one.
%
%   ---------------------------------------------------------------------
%   THE DEDUP KEY, AND WHY IT IS RECURSIVE
%   ---------------------------------------------------------------------
%   Duplicates exist because the writers build a FRESH openMINDS object per
%   table row:
%
%     origin/main:+setup/+conv/+dabrowska/SubjectInformationCreator.m getStrain
%         st_sd = openminds.core.research.Strain('name',"SD", ...)   <- inside
%         st_wi = openminds.core.research.Strain('name',"WI", ...)      the
%         st_trans = openminds.core.research.Strain(...)                method
%     origin/main:+setup/+conv/+haley/SubjectInformationCreator.m createStrainObject
%         N2 = openminds.core.research.Strain();                     <- likewise
%
%   so every subject row mints its own Strain, its own Species and its own
%   GeneticStrainType documents. The key is therefore the strain's CONTENT:
%
%       (scope, name, species{node,name}, genetic_strain_type{node,name},
%        description, phenotype, laboratory_code, sorted global identifiers,
%        the KEYS of its background strains, in order)
%
%   The parents' KEYS rather than their ids: two rows' `SD` parents are
%   different documents and the same strain, so keying on the id would block
%   every descendant from merging. The recursion is memoised and cycle-guarded
%   (REPORT.pedigree_cycles); a strain whose pedigree cannot be keyed is left
%   as a candidate with no parents rather than merged on a partial key.
%
%   ONLY AN EXACT MATCH MERGES. 'wildtype' and 'wild type' are different keys
%   and stay different strains -- normalising them is the T8 binding job, and
%   inventing an equivalence here is the ground-truth fabrication this
%   repository keeps paying for. ndi.migrate.internal.softwareDedup makes the
%   same call in the same words.
%
%   THE SCOPE IS THE DATASET WHEN A DATASET IS MIGRATED, THE SESSION OTHERWISE.
%   Decided by Jess Haley, 2026-10-21: "When a dataset is migrated, shared
%   entities (strains, software, people, organizations, instruments, products)
%   move to the dataset level as in native V2 imports (Haley
%   import_V2_decisions.md #20): one entity per distinct thing in the
%   dataset's database, with session documents pointing at it and merged-away
%   ids remapped so every link still resolves; a lone session with no dataset
%   keeps them in the session." ndi.migrate.internal.datasetScope decides
%   which: with exactly one `dataset` entity in the batch the key's scope is
%   that dataset and every minted strain entity, its assertions and its
%   `derived_from` relations are stored at the dataset level (their
%   `session_id` names the dataset entity, as the native import writes them);
%   otherwise the scope is the document's session, as before
%   (REPORT.scope, REPORT.dataset_id). The subject's `instance_of` stays in the
%   subject's session -- it is the session document pointing at the shared
%   entity. Nothing needs remapping here: the strain entities are freshly
%   minted and each source assertion's id is kept by its `instance_of`.
%   REPORT.cross_session_groups / REPORT.cross_session_collapsible are measured
%   in both modes (how many entities a session-scoped key would leave beyond a
%   dataset-scoped one); REPORT.cross_session_merged is how many of those this
%   run actually merged (0 when session-scoped).
%
%   ---------------------------------------------------------------------
%   WHAT IS REMOVED, AND THE CONDITIONS ON REMOVING IT
%   ---------------------------------------------------------------------
%   Two kinds of assertion leave the subject here (a third, the ancestor
%   `strain` assertions, is the 2026-10-21 decision below). Both are named in the signed
%   model (DID-schema V_eta_openminds_family_record.md Part 6, "Migration
%   consequences" 2 and 3, under TEAM-SIGN-OFF jess 2026-08-05), and the
%   pre-#88 schema repeated one of them in its own documentation
%   (V_eta/stable/strain.json, `genetic_strain_type`: "it lives HERE rather
%   than on the subject: ~2,365 `genetic strain type` assertions move off
%   subjects onto the strain"). Neither is removed on the strength of that
%   sentence alone -- each removal is conditional on the fact being READABLE
%   somewhere else afterwards:
%
%   * A `genetic strain type` assertion goes ONLY IF it is the assertion
%     minted from a GeneticStrainType fragment of a Strain this pass
%     assembled, AND that Strain is the subject's OWN strain (this pass made
%     the subject an `instance_of` it) or an ancestor whose `strain`
%     assertion was dropped below (reachable through `derived_from`), AND
%     the strain entity was given a `genetic strain type`
%     assertion of that exact value. So the fact is reachable subject ->
%     instance_of -> strain before the assertion is dropped, never after a
%     guess. (Before #88 this read "the subject's `strain` assertion carries a
%     `strain_id`"; the reachability argument is the same.)
%   * A `species` assertion goes ONLY IF it is an EXACT duplicate (same
%     subject, same {node,name}) of another surviving species assertion on the
%     same subject, and at least one member of the duplicate group came from a
%     Strain's Species child. `species` and `strain` stay SIBLING assertions
%     (the sign-off says so in as many words), so a species assertion that is
%     not a duplicate is never touched, whatever the strain says.
%
%   NOTHING IS REMOVED THAT ANYTHING POINTS AT. Every removal candidate is
%   checked against an index of every `depends_on` value in the whole migrated
%   set; one inbound edge and the document stays, counted
%   (REPORT.gst_kept_pinned / REPORT.species_kept_pinned). This pass cannot see
%   STRING references -- the standing rule that a `depends_on` sweep is not a
%   reference check -- which is why the writer check above was done by hand
%   before any removal was written.
%
%   A FRAGMENT SHARED WITH AN UNASSEMBLED STRAIN IS NEVER CONSUMED, the same
%   rule strainAssembly states: if any Strain document referencing the
%   fragment was left as a candidate this pass could not assemble, the
%   assertion stays (REPORT.gst_kept_shared_with_unassembled).
%
%   ---------------------------------------------------------------------
%   ANCESTOR-STRAIN ASSERTIONS ON THE SUBJECT
%   ---------------------------------------------------------------------
%   Decided by Jess Haley, 2026-10-21: "A subject keeps only its
%   `instance_of` link to its own strain; the ancestor-strain assertions on
%   the subject are dropped wherever the pedigree resolved into
%   `derived_from` links between strains (an unresolved parent's assertion
%   stays)."
%
%   Because the writer sets `subject_id` on every document of the flattened
%   graph, a subject whose strain is an F1 cross also carries a `strain`
%   assertion for EACH ancestor -- the Hunsberger cross gives
%   `ArcCreERT2 x eYFP`, `ArcCreERT2`, `eYFP` and `129S/SvEv`, all as
%   assertions about the same mouse, only one of which is the mouse's strain.
%   An ancestor assertion is never turned into `instance_of` (the mouse is not
%   an instance of `eYFP`). It is REMOVED when its strain entity is reachable
%   from the subject: subject -instance_of-> own strain -derived_from->* the
%   ancestor's strain, every link minted by this pass. So the fact is still
%   readable after the drop. Otherwise it stays as pass 1 emitted it:
%     REPORT.background_kept_unreachable  the chain to it did not resolve (an
%         intermediate parent this pass could not assemble), or the subject
%         has no own strain at all (a pedigree cycle);
%     REPORT.background_kept_pinned       another document points at it.
%   REPORT.background_strain_assertions_on_subject counts every ancestor
%   assertion seen; REPORT.background_strain_assertions_removed the dropped
%   ones. A parent that was never assembled (absent, or no name) has no
%   assertion among the candidates and is untouched by construction. The
%   ancestor's `genetic strain type` assertion goes with it under the same
%   reachability condition (REPORT.gst_kept_not_the_subjects_strain now counts
%   only those whose strain assertion stayed).
%
%   ---------------------------------------------------------------------
%   WHAT IS MEASURED AND DELIBERATELY NOT ACTED ON
%   ---------------------------------------------------------------------
%   * DUPLICATE SPECIES GROUPS WITH NO STRAIN FRAGMENT IN THEM. Counted
%     (REPORT.duplicate_species_groups_out_of_scope) and untouched: a duplicate
%     this family did not cause is not this pass's to remove.
%   * THE `genetic_strain_type` VOCABULARY. 'wildtype' / 'wild type' /
%     'knockin' / 'transgenic' arrive unnormalised from four writers and are
%     carried through as found. T8 binding work, not this pass's.
%   * `openminds_element` / `openminds_stimulus` Strain documents. None exists
%     in any writer read here (element carries CellType, stimulus carries
%     StimulationApproach), so a Strain under either class would be a shape
%     nobody has seen; it is counted
%     (REPORT.strain_under_other_openminds_class) and left alone rather than
%     migrated on an assumption.
%
%   See also: ndi.migrate.local, ndi.migrate.internal.strainAssembly,
%     ndi.migrate.internal.softwareDedup,
%     ndi.migrate.internal.ontologyRowSubjects,
%     did2.convert.migrators_j.openminds_subject,
%     DID-schema schemas/V_eta_openminds_family_record.md Parts 2 and 6.

arguments
    v1Bodies cell
    migratedStructs cell
end

v1Bodies        = decodeBodies(v1Bodies);
migratedStructs = decodeBodies(migratedStructs);

kept   = migratedStructs;
minted = {};

% ---- denominators, computed and stored FIRST ----------------------------
% Rule 5: unconditionally, before any early return, so "read nothing" and
% "read everything and found nothing" cannot print the same thing.
report = struct();
report.v1_bodies_inspected                 = numel(v1Bodies);
report.documents_inspected                 = numel(migratedStructs);
report.reference_edges_indexed             = 0;
report.term_assertions_indexed             = 0;

report.v1_openminds_bodies                 = 0;   % any openminds* class
report.v1_openminds_subject_bodies         = 0;
report.strain_docs_seen                    = 0;   % Strain-typed, openminds_subject
report.strain_under_other_openminds_class  = 0;   % measured, untouched
report.strain_docs_not_in_migrated_set     = 0;   % discovery-mode subset
report.strain_docs_not_a_term_assertion    = 0;   % e.g. already a `strain`

report.strains_candidate                   = 0;
report.strains_incomplete                  = 0;
report.incomplete_reasons                  = {};

report.distinct_strains                    = 0;   % dedup groups
report.strains_minted                      = 0;
report.strain_docs_collapsed               = 0;   % candidates - groups
report.cross_session_groups                = 0;
report.cross_session_collapsible           = 0;
report.cross_session_merged                = 0;
report.scope                               = 'session';
report.dataset_id                          = '';

report.background_refs_seen                = 0;
report.background_refs_not_in_openminds_edges = 0;
report.background_edges                    = 0;
report.background_unresolved               = 0;
report.pedigree_cycles                     = 0;
report.background_strain_assertions_on_subject = 0;   % ancestors seen
report.background_strain_assertions_removed = 0;
report.background_kept_unreachable         = 0;
report.background_kept_pinned              = 0;

report.strain_assertions_minted            = 0;   % about the strains
report.instance_of_minted                  = 0;   % subject -> strain
report.strain_assertions_without_subject   = 0;

report.gst_fragments_seen                  = 0;
report.gst_assertions_removed              = 0;
report.gst_kept_not_a_term_assertion       = 0;
report.gst_kept_value_not_on_strain        = 0;
report.gst_kept_shared_with_unassembled    = 0;
report.gst_kept_wrong_subject              = 0;
report.gst_kept_not_the_subjects_strain    = 0;
report.gst_kept_pinned                     = 0;

report.species_fragments_seen              = 0;
report.species_duplicate_groups            = 0;
report.species_assertions_removed          = 0;
report.species_kept_pinned                 = 0;
report.duplicate_species_groups_out_of_scope = 0;

report.changed                             = false;

if isempty(v1Bodies) || isempty(migratedStructs)
    return;
end

% ---- index the migrated set ---------------------------------------------
S = ndi.migrate.internal.etaShape;
n = numel(migratedStructs);
migratedPos = containers.Map('KeyType', 'char', 'ValueType', 'double');
inbound     = containers.Map('KeyType', 'char', 'ValueType', 'any');
for i = 1:n
    s = migratedStructs{i};
    id = baseField(s, 'id', '');
    if ~isempty(id)
        migratedPos(id) = i;
    end
    if S.isStatement(s, 'assertion', 'term')
        report.term_assertions_indexed = report.term_assertions_indexed + 1;
    end
    targets = dependencyTargets(s);
    for t = 1:numel(targets)
        report.reference_edges_indexed = report.reference_edges_indexed + 1;
        addUse(inbound, targets{t}, id);
    end
end

% ---- index every did_v1 openMINDS body ----------------------------------
% By id, whatever its openminds* class, because a Strain's `ndi://` child can
% be any of them and the fragment lookup must not depend on the class.
v1Pos = containers.Map('KeyType', 'char', 'ValueType', 'double');
strainIdx = [];
for i = 1:numel(v1Bodies)
    b = v1Bodies{i};
    cls = classNameOf(b);
    if ~isOpenmindsClass(cls)
        continue;
    end
    report.v1_openminds_bodies = report.v1_openminds_bodies + 1;
    id = baseField(b, 'id', '');
    if ~isempty(id)
        v1Pos(id) = i;
    end
    if strcmp(cls, 'openminds_subject')
        report.v1_openminds_subject_bodies = ...
            report.v1_openminds_subject_bodies + 1;
    end
    if ~isOpenmindsType(b, 'Strain')
        continue;
    end
    if ~strcmp(cls, 'openminds_subject')
        % A Strain under `openminds` belongs to strainAssembly; a Strain under
        % `openminds_element` / `openminds_stimulus` is a shape no writer
        % produces. Counted, never guessed at.
        report.strain_under_other_openminds_class = ...
            report.strain_under_other_openminds_class + 1;
        continue;
    end
    report.strain_docs_seen = report.strain_docs_seen + 1;
    strainIdx(end+1) = i; %#ok<AGROW>
end

if isempty(strainIdx)
    return;
end

% ---- read each Strain document ------------------------------------------
% Every candidate is read BEFORE any is minted: the dedup key of a strain
% depends on the keys of its parents, so the whole set has to be in hand.
%
% PREALLOCATED, and that is a real concern rather than tidiness: the corpus
% this runs on is measured in thousands of Strain documents per dataset (they
% are written once per subject ROW -- that is the duplication this pass
% collapses), and `cand(end+1) = e` copies the whole struct array on every
% append. The same reasoning applies to the containers.Map lookups used below
% in place of `any(strcmp(list, x))`.
cand = emptyCandidate();
if ~isempty(strainIdx)
    cand(numel(strainIdx)).group = 0;   % trimmed to nCand below
end
nCand = 0;
pedigree = struct('source_id', {}, 'subject_id', {}, 'parents', {});
candById = containers.Map('KeyType', 'char', 'ValueType', 'double');
for k = 1:numel(strainIdx)
    b = v1Bodies{strainIdx(k)};
    srcId = baseField(b, 'id', '');
    if isempty(srcId) || ~isKey(migratedPos, srcId)
        report.strain_docs_not_in_migrated_set = ...
            report.strain_docs_not_in_migrated_set + 1;
        continue;
    end
    assertionPos = migratedPos(srcId);
    if ~S.isStatement(migratedStructs{assertionPos}, 'assertion', 'term')
        report.strain_docs_not_a_term_assertion = ...
            report.strain_docs_not_a_term_assertion + 1;
        continue;
    end

    f = openmindsFields(b);
    e = struct();
    e.source_id     = srcId;
    e.assertion_pos = assertionPos;
    e.session_id    = ndi.v2.sessionIdOf(b);
    e.datestamp     = baseField(b, 'datestamp', '');
    e.subject_id    = S.aboutId(migratedStructs{assertionPos});
    e.name          = charField(f, {'name'});
    [e.species, e.species_frag] = resolveTerm(f, {'species'}, v1Pos, v1Bodies);
    [e.gst, e.gst_frag] = resolveTerm(f, ...
        {'geneticStrainType', 'genetic_strain_type'}, v1Pos, v1Bodies);
    e.description     = charField(f, {'description'});
    e.phenotype       = charField(f, {'phenotype'});
    e.laboratory_code = charField(f, {'laboratoryCode', 'laboratory_code'});
    e.synonym         = cellstrField(f, {'synonym'});
    e.identifiers     = identifiers(f);
    e.parents         = ndiRefs(getAny(f, {'backgroundStrain', 'background_strain'}));
    e.content_key     = '';
    e.key             = '';
    e.group           = 0;

    report.background_refs_seen = report.background_refs_seen + numel(e.parents);
    edgeIds = dependencyValuesMatching(b, 'openminds');
    for p = 1:numel(e.parents)
        if ~any(strcmp(edgeIds, e.parents{p}))
            % The `fields` string and the `openminds_#` edges should name the
            % same documents; a disagreement is reported rather than resolved,
            % because `fields` is what carries the ROLE and is therefore what
            % this pass follows.
            report.background_refs_not_in_openminds_edges = ...
                report.background_refs_not_in_openminds_edges + 1;
        end
    end

    % Every Strain's pedigree, assembled or not, says who is an ANCESTOR: a
    % strain named as a background by an unassembled strain is still not the
    % subject's own strain.
    pedigree(end+1) = struct('source_id', srcId, 'subject_id', e.subject_id, ...
        'parents', {e.parents}); %#ok<AGROW>

    if isempty(e.name)
        % A strain entity requires `name` (did-schema #88 entity_type_bindings).
        % A Strain without one is left exactly as pass 1 emitted it rather
        % than minted hollow. (Before #88 the `strain` class also required
        % `species` and `genetic_strain_type`; on #88 those are assertions,
        % so a Strain without one simply gets no such assertion.)
        report.strains_incomplete = report.strains_incomplete + 1;
        report.incomplete_reasons{end+1} = ...
            sprintf('%s: missing name', shortId(srcId)); %#ok<AGROW>
        continue;
    end

    nCand = nCand + 1;
    cand(nCand) = e;
    candById(srcId) = nCand;
end
cand = cand(1:nCand);

report.strains_candidate = numel(cand);
if isempty(cand)
    return;
end

% ---- the recursive dedup key --------------------------------------------
% Two keys: CONTENT_KEY is the strain and its pedigree with no session anywhere
% in it, KEY is CONTENT_KEY under the SCOPE -- the dataset when one is being
% migrated, otherwise this document's session (Jess Haley, 2026-10-21; see the
% header). Grouping is on KEY.
scope = ndi.migrate.internal.datasetScope(migratedStructs);
if scope.is_dataset
    report.scope      = 'dataset';
    report.dataset_id = scope.dataset_id;
end
memo    = containers.Map('KeyType', 'char', 'ValueType', 'char');
visited = containers.Map('KeyType', 'char', 'ValueType', 'logical');
sep     = char(31);   % unit separator: cannot occur in a name or a CURIE
for c = 1:numel(cand)
    [cand(c).content_key, cycles] = strainKey(c, cand, candById, memo, visited);
    if scope.is_dataset
        cand(c).key = [scope.dataset_id sep cand(c).content_key];
    else
        cand(c).key = [cand(c).session_id sep cand(c).content_key];
    end
    report.pedigree_cycles = report.pedigree_cycles + cycles;
end

% ---- group ---------------------------------------------------------------
groupKeys = {};
for c = 1:numel(cand)
    hit = find(strcmp(cand(c).key, groupKeys), 1);
    if isempty(hit)
        groupKeys{end+1} = cand(c).key; %#ok<AGROW>
        hit = numel(groupKeys);
    end
    cand(c).group = hit;
end
nGroups = numel(groupKeys);
report.distinct_strains      = nGroups;
report.strain_docs_collapsed = numel(cand) - nGroups;

% Cross-session measurement: how many entities a SESSION-scoped key leaves
% beyond a dataset-scoped one. Measured in both modes; merged only when the
% scope is a dataset.
contentKeys     = {cand.content_key};
uniqContentKeys = unique(contentKeys);
sessionKeys     = cellfun(@(a, b) [a sep b], {cand.session_id}, contentKeys, ...
    'UniformOutput', false);
for u = 1:numel(uniqContentKeys)
    members = strcmp(contentKeys, uniqContentKeys{u});
    if numel(unique({cand(members).session_id})) > 1
        report.cross_session_groups = report.cross_session_groups + 1;
    end
end
report.cross_session_collapsible = numel(unique(sessionKeys)) - numel(uniqContentKeys);
if scope.is_dataset
    report.cross_session_merged = report.cross_session_collapsible;
end

% ---- mint one strain per group ------------------------------------------
% did-schema #88 (V_eta_entity_composition_plan.md sec. 4): the strain is an
% `entity` of type `strain`; its species, genetic strain type, phenotype,
% laboratory code and synonyms are ASSERTIONS about it; its pedigree is a
% `derived_from` relation to the SURVIVOR of each parent's group, in the order
% `fields.backgroundStrain` gives. A parent this pass could not assemble
% produces NO relation (REPORT.background_unresolved).
groupDocId = cell(1, nGroups);
groupRep   = zeros(1, nGroups);
for g = 1:nGroups
    groupRep(g)   = find([cand.group] == g, 1);
    groupDocId{g} = did.ido.unique_id();
end

groupParents = cell(1, nGroups);
for g = 1:nGroups
    rep = cand(groupRep(g));
    home = rep.session_id;
    if scope.is_dataset
        home = scope.dataset_id;   % dataset level (Jess Haley, 2026-10-21)
    end
    common = {'SessionId', home, 'Datestamp', rep.datestamp};

    ef = struct('name', rep.name);
    if ~isempty(rep.description); ef.description = rep.description; end
    if ~isempty(rep.identifiers); ef.global_identifier = rep.identifiers; end
    minted{end+1} = S.entity('strain', ef, 'Id', groupDocId{g}, common{:}); %#ok<AGROW>
    report.strains_minted = report.strains_minted + 1;

    docs = strainStatements(groupDocId{g}, rep, common);
    minted = [minted, docs]; %#ok<AGROW>
    report.strain_assertions_minted = report.strain_assertions_minted + numel(docs);

    for p = 1:numel(rep.parents)
        pid = rep.parents{p};
        if isKey(candById, pid)
            minted{end+1} = S.relation(groupDocId{g}, ...
                groupDocId{cand(candById(pid)).group}, ...
                ndi.v2.vocabTerm('relation', 'derived_from'), common{:}); %#ok<AGROW>
            groupParents{g}(end+1) = cand(candById(pid)).group;
            report.background_edges = report.background_edges + 1;
        else
            report.background_unresolved = report.background_unresolved + 1;
        end
    end
end

% An ancestor of another candidate is still asserted OF THE SUBJECT, because
% the writer sets `subject_id` on every document of the flattened graph.
%
% Indexed on (parent document id, referring document's subject) rather than
% compared pairwise: the pairwise form is numel(cand)^2 and numel(cand) is in
% the thousands on a real dataset. A self-loop is skipped at BUILD time.
ancestorOf = containers.Map('KeyType', 'char', 'ValueType', 'logical');
for d = 1:numel(pedigree)
    if isempty(pedigree(d).subject_id)
        continue;
    end
    for p = 1:numel(pedigree(d).parents)
        if strcmp(pedigree(d).parents{p}, pedigree(d).source_id)
            continue;   % a strain that is its own background
        end
        ancestorOf([pedigree(d).parents{p} '|' pedigree(d).subject_id]) = true;
    end
end

% ---- the subject is an `instance_of` its strain ---------------------------
% did-schema #88 sec. 5 (TEAM-SIGN-OFF jess 2026-10-08): "`term_assertion.
% strain_id` goes. A subject is an `instance_of` its strain". So the subject's
% OWN `strain` assertion is REPLACED by a directed_relation subject
% -instance_of-> strain entity, which takes over the assertion's id (anything
% that pointed at the assertion still resolves). What is asserted of the
% strain then holds of the subject (T17's type-to-instance rule).
%
% AN ANCESTOR'S `strain` ASSERTION IS NOT TURNED INTO `instance_of`. The mouse
% is an instance of `ArcCreERT2 x eYFP`, not of `eYFP`. It is collected here
% and dropped below where the pedigree resolved (Jess Haley, 2026-10-21; see
% the header).
removeMask = false(1, n);
ownStrain = false(1, numel(cand));
ancestorDropped = false(1, numel(cand));
ancestors = [];
for c = 1:numel(cand)
    if isempty(cand(c).subject_id)
        report.strain_assertions_without_subject = ...
            report.strain_assertions_without_subject + 1;
        continue;
    end
    if isKey(ancestorOf, [cand(c).source_id '|' cand(c).subject_id])
        report.background_strain_assertions_on_subject = ...
            report.background_strain_assertions_on_subject + 1;
        ancestors(end+1) = c; %#ok<AGROW>
        continue;
    end
    pos = cand(c).assertion_pos;
    ds = baseField(kept{pos}, 'creation_timestamp', '');
    if isempty(ds); ds = cand(c).datestamp; end
    minted{end+1} = S.relation(cand(c).subject_id, groupDocId{cand(c).group}, ...
        ndi.v2.vocabTerm('relation', 'instance_of'), 'Id', cand(c).source_id, ...
        'SessionId', cand(c).session_id, 'Datestamp', ds); %#ok<AGROW>
    removeMask(pos) = true;
    ownStrain(c) = true;
    report.instance_of_minted = report.instance_of_minted + 1;
end

% ---- drop the ancestor assertions the pedigree now carries ----------------
% Decided by Jess Haley, 2026-10-21 (header). Reachable = the ancestor's
% strain group is reached from one of the SAME subject's own strain groups by
% following the derived_from links minted above.
reachable = containers.Map('KeyType', 'char', 'ValueType', 'logical');
for c = find(ownStrain)
    stack = cand(c).group;
    seen = false(1, nGroups);
    while ~isempty(stack)
        g = stack(end); stack(end) = [];
        if seen(g); continue; end
        seen(g) = true;
        reachable([cand(c).subject_id '|' num2str(g)]) = true;
        stack = [stack, groupParents{g}]; %#ok<AGROW>
    end
end
for c = ancestors
    if ~isKey(reachable, [cand(c).subject_id '|' num2str(cand(c).group)])
        report.background_kept_unreachable = report.background_kept_unreachable + 1;
        continue;
    end
    if isPinned(inbound, cand(c).source_id)
        report.background_kept_pinned = report.background_kept_pinned + 1;
        continue;
    end
    removeMask(cand(c).assertion_pos) = true;
    ancestorDropped(c) = true;
    report.background_strain_assertions_removed = ...
        report.background_strain_assertions_removed + 1;
end

% ---- move the `genetic strain type` assertion onto the strain ------------

fragReferrers = containers.Map('KeyType', 'char', 'ValueType', 'any');
for k = 1:numel(strainIdx)
    b = v1Bodies{strainIdx(k)};
    srcId = baseField(b, 'id', '');
    f = openmindsFields(b);
    refs = [reshape(ndiRefs(getAny(f, {'geneticStrainType', 'genetic_strain_type'})), 1, []), ...
            reshape(ndiRefs(getAny(f, {'species'})), 1, [])];
    for r = 1:numel(refs)
        addUse(fragReferrers, refs{r}, srcId);
    end
end
assembled = containers.Map('KeyType', 'char', 'ValueType', 'logical');
for c = 1:numel(cand)
    assembled(cand(c).source_id) = true;
end

seenGstFrag = containers.Map('KeyType', 'char', 'ValueType', 'logical');
for c = 1:numel(cand)
    fragId = cand(c).gst_frag;
    if isempty(fragId)
        continue;      % inline char: no fragment document, so no assertion
    end
    if isKey(seenGstFrag, fragId)
        continue;      % one fragment shared by several strains: decide once
    end
    seenGstFrag(fragId) = true;
    report.gst_fragments_seen = report.gst_fragments_seen + 1;

    if ~isKey(migratedPos, fragId)
        report.gst_kept_not_a_term_assertion = ...
            report.gst_kept_not_a_term_assertion + 1;
        continue;
    end
    pos = migratedPos(fragId);
    if ~S.isStatement(kept{pos}, 'assertion', 'term')
        report.gst_kept_not_a_term_assertion = ...
            report.gst_kept_not_a_term_assertion + 1;
        continue;
    end
    who = {};
    if isKey(fragReferrers, fragId); who = fragReferrers(fragId); end
    everyReferrerAssembled = true;
    for r = 1:numel(who)
        if ~isKey(assembled, who{r})
            everyReferrerAssembled = false;
            break;
        end
    end
    if ~everyReferrerAssembled
        report.gst_kept_shared_with_unassembled = ...
            report.gst_kept_shared_with_unassembled + 1;
        continue;
    end
    % Both must name the SAME, NON-EMPTY subject. Two empty subject_ids are
    % not agreement about anybody -- did2/+validate/references.m skips empty
    % edges, so "" would otherwise match "" and the reachability argument
    % below would be about a subject that does not exist.
    if isempty(cand(c).subject_id) ...
            || ~strcmp(S.aboutId(kept{pos}), cand(c).subject_id)
        report.gst_kept_wrong_subject = report.gst_kept_wrong_subject + 1;
        continue;
    end
    % The fact must be reachable subject -> instance_of -> strain BEFORE this
    % one is dropped: this pass minted the subject's `instance_of` to that
    % strain, or the strain is an ancestor whose own assertion was dropped
    % because it is reachable through derived_from (Jess Haley, 2026-10-21),
    % and the strain was given this exact `genetic strain type` assertion.
    if ~ownStrain(c) && ~ancestorDropped(c)
        report.gst_kept_not_the_subjects_strain = ...
            report.gst_kept_not_the_subjects_strain + 1;
        continue;
    end
    if ~sameTerm(S.termValue(kept{pos}), cand(c).gst)
        report.gst_kept_value_not_on_strain = ...
            report.gst_kept_value_not_on_strain + 1;
        continue;
    end
    if isPinned(inbound, fragId)
        report.gst_kept_pinned = report.gst_kept_pinned + 1;
        continue;
    end
    removeMask(pos) = true;
    report.gst_assertions_removed = report.gst_assertions_removed + 1;
end

% ---- dedup the `species` assertions --------------------------------------
% In scope ONLY where a Strain's own Species child produced one of the
% duplicates. `species` and `strain` stay sibling assertions, so a species
% assertion that is not a duplicate is never touched.
speciesFragIds = containers.Map('KeyType', 'char', 'ValueType', 'logical');
for c = 1:numel(cand)
    if ~isempty(cand(c).species_frag) ...
            && ~isKey(speciesFragIds, cand(c).species_frag)
        speciesFragIds(cand(c).species_frag) = true;
        report.species_fragments_seen = report.species_fragments_seen + 1;
    end
end

speciesKey = cell(1, n);
for i = 1:n
    speciesKey{i} = '';
    if removeMask(i) || ~S.isStatement(kept{i}, 'assertion', 'term')
        continue;
    end
    v = S.variable(kept{i});
    if ~strcmp(normaliseKey(v.name), 'species')
        continue;
    end
    t = S.termValue(kept{i});
    sid = S.aboutId(kept{i});
    if isempty(sid)
        % No subject means no "duplicate on the same subject" to speak of.
        % Two subject-less assertions are not evidence of being about one
        % thing, and did2/+validate/references.m skips empty edges, so this
        % would otherwise group every subject-less species assertion in the
        % batch into a single pile and delete all but one of them.
        continue;
    end
    speciesKey{i} = strjoin({sid, t.node, t.name}, '|');
end

uniqGroups = unique(speciesKey(~cellfun('isempty', speciesKey)));
for u = 1:numel(uniqGroups)
    members = find(strcmp(speciesKey, uniqGroups{u}));
    if numel(members) < 2
        continue;
    end
    fromStrain = false(1, numel(members));
    for m = 1:numel(members)
        idHere = baseField(kept{members(m)}, 'id', '');
        fromStrain(m) = ~isempty(idHere) && isKey(speciesFragIds, idHere);
    end
    if ~any(fromStrain)
        report.duplicate_species_groups_out_of_scope = ...
            report.duplicate_species_groups_out_of_scope + 1;
        continue;
    end
    report.species_duplicate_groups = report.species_duplicate_groups + 1;
    % Keep the assertion that is NOT a strain fragment where there is one: it
    % is the subject's own species assertion (subjectMaker.m:265 writes it
    % from `subjectInfo.species`, independently of any strain), so the
    % surviving document is the one whose provenance does not depend on this
    % pass having read a strain correctly.
    survivor = members(find(~fromStrain, 1));
    if isempty(survivor)
        survivor = members(1);
    end
    for m = 1:numel(members)
        if members(m) == survivor
            continue;
        end
        idHere = baseField(kept{members(m)}, 'id', '');
        if isPinned(inbound, idHere)
            report.species_kept_pinned = report.species_kept_pinned + 1;
            continue;
        end
        removeMask(members(m)) = true;
        report.species_assertions_removed = ...
            report.species_assertions_removed + 1;
    end
end

kept = kept(~removeMask);
report.changed = report.strains_minted > 0 ...
    || report.instance_of_minted > 0 || any(removeMask);
end

% ===================== the dedup key ======================================

function [key, cycles] = strainKey(c, cand, candById, memo, visited)
%STRAINKEY The SESSION-FREE content key of candidate C, including its parents'
%   content keys. The caller prefixes the session; keeping session out of the
%   recursion is what makes the cross-session measurement exact.
%
%   Memoised across the whole set and cycle-guarded: a strain that reaches
%   itself through its pedigree gets a key naming its own document id, so it
%   merges with nothing rather than recursing forever.
cycles = 0;
srcId  = cand(c).source_id;
if isKey(memo, srcId)
    key = memo(srcId);
    return;
end
if isKey(visited, srcId)
    key = ['CYCLE:' srcId];
    cycles = 1;
    return;
end
visited(srcId) = true; %#ok<NASGU>

parts = {cand(c).name, ...
    cand(c).species.node, cand(c).species.name, ...
    cand(c).gst.node, cand(c).gst.name, ...
    cand(c).description, cand(c).phenotype, cand(c).laboratory_code, ...
    identifierKey(cand(c).identifiers)};

for p = 1:numel(cand(c).parents)
    pid = cand(c).parents{p};
    if isKey(candById, pid)
        [pk, pc] = strainKey(candById(pid), cand, candById, memo, visited);
        cycles = cycles + pc;
        parts{end+1} = ['<' pk '>']; %#ok<AGROW>
    else
        % An unassembled parent contributes a stable placeholder rather than
        % nothing: two strains whose parents are equally unreadable are not
        % thereby the same strain, and merging them would fabricate a pedigree.
        parts{end+1} = ['<UNRESOLVED:' pid '>']; %#ok<AGROW>
    end
end

key = strjoin(parts, char(31));   % unit separator: cannot occur in a CURIE
memo(srcId) = key; %#ok<NASGU>
end

function s = identifierKey(gid)
s = strjoin(sort(gid), ',');
end

% ===================== openMINDS accessors ================================

function tf = isOpenmindsClass(cls)
tf = any(strcmp(cls, {'openminds', 'openminds_subject', ...
    'openminds_element', 'openminds_stimulus'}));
end

function tf = isOpenmindsType(s, typeName)
%ISOPENMINDSTYPE Match on matlab_type's trailing class OR openminds_type's
%   trailing IRI segment. Both spellings are live: the writer stores
%   `char(obj.X_TYPE)` and `class(obj)`, and NDI's own reader queries the IRI
%   form with the EBRAINS host (ndidataset2metadataeditorstruct.m:173,
%   'https://openminds.ebrains.eu/core/Strain') while newer fixtures carry
%   openminds.om-i.org. Matching the trailing segment survives the host change.
tf = false;
b = openmindsBlock(s);
if isempty(fieldnames(b))
    return;
end
mt = ''; ot = '';
if isfield(b, 'matlab_type');    mt = char(b.matlab_type);    end
if isfield(b, 'openminds_type'); ot = char(b.openminds_type); end
tf = endsWithSegment(mt, '.', typeName) || endsWithSegment(ot, '/', typeName);
end

function tf = endsWithSegment(str, sep, seg)
tf = false;
if isempty(str); return; end
parts = strsplit(str, sep);
tf = strcmpi(strtrim(parts{end}), seg);
end

function b = openmindsBlock(s)
%OPENMINDSBLOCK The `openminds` mixin block. The subclass template also
%   declares an (empty) `openminds_subject` block, so both are accepted --
%   did2.convert.migrators_j.openminds_subject:29-34 reads them in the same
%   order for the same reason.
b = struct();
if ~isstruct(s)
    return;
end
if isfield(s, 'openminds') && isstruct(s.openminds)
    b = s.openminds;
elseif isfield(s, 'openminds_subject') && isstruct(s.openminds_subject)
    b = s.openminds_subject;
end
end

function f = openmindsFields(s)
f = struct();
b = openmindsBlock(s);
if isfield(b, 'fields') && isstruct(b.fields) && isscalar(b.fields)
    f = b.fields;
end
end

function [term, fragId] = resolveTerm(f, names, v1Pos, v1Bodies)
%RESOLVETERM An ontology_term for a Strain field that is either an inline char
%   or an `ndi://` reference to a controlled-term FRAGMENT document.
term   = struct('node', '', 'name', '');
fragId = '';
v = getAny(f, names);
if isempty(v)
    return;
end
refs = ndiRefs(v);
if isempty(refs)
    % The inline shape. haley/SubjectInformationCreator.m:80 assigns
    % `geneticStrainType = 'wild type'` as a CHAR; whether openMINDS_MATLAB
    % coerces it into its own document was never read here (the library is not
    % in scope), so BOTH shapes are handled. No CURIE is available inline, so
    % the node stays empty -- normalising 'wild type' vs 'wildtype' is the T8
    % binding job, not this pass's.
    term.name = firstChar(v);
    return;
end
for r = 1:numel(refs)
    if ~isKey(v1Pos, refs{r}); continue; end
    ff = openmindsFields(v1Bodies{v1Pos(refs{r})});
    nm = charField(ff, {'name'});
    nd = charField(ff, {'preferredOntologyIdentifier', ...
        'preferred_ontology_identifier', 'ontologyIdentifier', ...
        'ontology_identifier'});
    if isempty(nm) && isempty(nd); continue; end
    term.name = nm;
    term.node = nd;
    fragId    = refs{r};
    return;      % single-valued in every writer read here
end
end

function ids = ndiRefs(v)
%NDIREFS The `ndi://<id>` document ids inside a `fields` value, IN ORDER.
%   Order is a fact from the writer -- `backgroundStrain = [ArcCreERT2,eYFP]`
%   (hunsberger/SubjectInformationCreator.m:107) -- and it is what orders the
%   `derived_from` relations reproducibly.
ids = {};
if isempty(v); return; end
if ischar(v); v = {v}; end
if isstring(v); v = cellstr(v); end
if ~iscell(v); return; end
for k = 1:numel(v)
    e = v{k};
    if isstring(e); e = char(e); end
    if ~ischar(e); continue; end
    if startsWith(e, 'ndi://') && numel(e) > 6
        ids{end+1} = e(7:end); %#ok<AGROW>
    end
end
end

function gid = identifiers(f)
%IDENTIFIERS entity.global_identifier -- a list of CURIE strings (did-schema
%   #88 sec. 6: "`global_identifier` is a list of strings"). Empty when the
%   writer gives none: 115 strains carry no identifier at all (dabrowska's Cre
%   lines set only `name`), which is why the field is optional on the entity.
%
%   THE SLOT IS NOT TRUSTED, THE PREFIX IS. Dabrowska writes
%   `'ontologyIdentifier', "RRID:RGD_70508"` -- an RRID in the ontology slot --
%   so `ontologyIdentifier`, `digitalIdentifier` and `alternateIdentifier` are
%   all read, and each CURIE is written as given (etaShape.curie applies the
%   one rewrite the signed plan names, WBStrain -> WormBase).
gid = {};
for nm = {'ontologyIdentifier', 'ontology_identifier', ...
          'digitalIdentifier', 'digital_identifier', ...
          'alternateIdentifier', 'alternate_identifier'}
    v = getAny(f, nm);
    if isempty(v); continue; end
    if ischar(v); v = {v}; end
    if isstring(v); v = cellstr(v); end
    if ~iscell(v); continue; end
    for k = 1:numel(v)
        e = v{k};
        if isstring(e); e = char(e); end
        if ~ischar(e) || isempty(strtrim(e)); continue; end
        g = ndi.migrate.internal.etaShape.curie(e);
        if ~any(strcmp(gid, g))
            gid{end+1} = g; %#ok<AGROW>
        end
    end
end
end

% ===================== the strain's statements =============================

function docs = strainStatements(strainId, rep, common)
%STRAINSTATEMENTS The assertions a strain's openMINDS fields become on #88
%   (V_eta_entity_composition_plan.md sec. 4): species, genetic strain type and
%   phenotype as term assertions, laboratory code and synonyms as text
%   assertions -- the variables ndi.setup.V2.entityDocuments writes for the
%   same fields, so a migrated strain reads like an imported one.
S = ndi.migrate.internal.etaShape;
docs = {};
if termIsPopulated(rep.species)
    docs{end+1} = S.statement('assertion', 'term', strainId, ...
        S.term('NCIT:C45293', 'Species'), rep.species, common{:});
end
if termIsPopulated(rep.gst)
    docs{end+1} = S.statement('assertion', 'term', strainId, ...
        S.term('EMPTY:0000347', 'genetic strain type'), rep.gst, common{:});
end
if ~isempty(rep.phenotype)
    docs{end+1} = S.statement('assertion', 'term', strainId, ...
        S.term('', 'phenotype'), S.term('', rep.phenotype), common{:});
end
if ~isempty(rep.laboratory_code)
    docs{end+1} = S.statement('assertion', 'text', strainId, ...
        S.term('', 'laboratory code'), struct('text', rep.laboratory_code), common{:});
end
if ~isempty(rep.synonym)
    docs{end+1} = S.statement('assertion', 'text', strainId, ...
        S.term('', 'synonym'), struct('text', rep.synonym), common{:});
end
end

% ===================== migrated-body accessors ============================

function tf = sameTerm(a, b)
tf = strcmp(a.node, b.node) && strcmp(a.name, b.name);
end

function tf = termIsPopulated(t)
tf = isstruct(t) && (~isempty(strtrim(char(t.node))) ...
    || ~isempty(strtrim(char(t.name))));
end

function tf = isPinned(inbound, id)
%ISPINNED Does any document in the migrated set point at ID? One inbound edge
%   and the document stays. This cannot see STRING references (a `depends_on`
%   sweep is not a reference check), which is why the writer sweep in the
%   header was done by hand before any removal was written.
tf = false;
if isempty(id) || ~isKey(inbound, id)
    return;
end
users = inbound(id);
for k = 1:numel(users)
    if ~strcmp(users{k}, id)
        tf = true;
        return;
    end
end
end

function out = dependencyTargets(s)
out = {};
if ~isstruct(s) || ~isfield(s, 'depends_on') || ~isstruct(s.depends_on)
    return;
end
for k = 1:numel(s.depends_on)
    v = dependencyValueOf(s.depends_on(k));
    if ~isempty(v); out{end+1} = v; end %#ok<AGROW>
end
end

function vals = dependencyValuesMatching(b, baseName)
%DEPENDENCYVALUESMATCHING Every depends_on value whose name is BASENAME or
%   BASENAME_<n>. `add_dependency_value_n` writes `openminds_1..n`, so a
%   single-name lookup would miss every multi-child document.
vals = {};
if ~isstruct(b) || ~isfield(b, 'depends_on') || ~isstruct(b.depends_on)
    return;
end
pattern = ['^' regexptranslate('escape', baseName) '(_\d+)?$'];
for k = 1:numel(b.depends_on)
    d = b.depends_on(k);
    if ~isfield(d, 'name'); continue; end
    if isempty(regexp(charOf(d.name), pattern, 'once')); continue; end
    v = dependencyValueOf(d);
    if ~isempty(v); vals{end+1} = v; end %#ok<AGROW>
end
end

function v = dependencyValueOf(d)
% v1 writes {name,value} (or {name,id}); universalRenames rewrites both to
% {name,document_id}. Accept whichever is populated.
v = '';
if ~isstruct(d)
    return;
end
if isfield(d, 'document_id') && ~isempty(d.document_id)
    v = charOf(d.document_id);
elseif isfield(d, 'value') && ~isempty(d.value)
    v = charOf(d.value);
elseif isfield(d, 'id') && ~isempty(d.id)
    v = charOf(d.id);
end
end

% ===================== small helpers ======================================

function c = emptyCandidate()
c = struct('source_id', {}, 'assertion_pos', {}, 'session_id', {}, ...
    'datestamp', {}, 'subject_id', {}, 'name', {}, 'species', {}, ...
    'species_frag', {}, 'gst', {}, 'gst_frag', {}, 'description', {}, ...
    'phenotype', {}, 'laboratory_code', {}, 'synonym', {}, ...
    'identifiers', {}, 'parents', {}, 'content_key', {}, 'key', {}, ...
    'group', {});
end

function addUse(map, key, user)
if isempty(key); return; end
if isKey(map, key)
    cur = map(key);
else
    cur = {};
end
if ~any(strcmp(cur, user))
    cur{end+1} = user;
end
map(key) = cur; %#ok<NASGU>
end

function v = getAny(s, names)
v = [];
if ~isstruct(s); return; end
if ischar(names); names = {names}; end
for k = 1:numel(names)
    if isfield(s, names{k}) && ~isempty(s.(names{k}))
        v = s.(names{k});
        return;
    end
end
end

function c = charField(s, names)
c = firstChar(getAny(s, names));
end

function c = firstChar(v)
c = '';
if isempty(v); return; end
if isstring(v); v = cellstr(v); end
if iscell(v)
    if isempty(v); return; end
    v = v{1};
    if isstring(v); v = char(v); end
end
if ischar(v); c = strtrim(v); end
end

function out = cellstrField(s, names)
out = {};
v = getAny(s, names);
if isempty(v); return; end
if ischar(v); v = {v}; end
if isstring(v); v = cellstr(v); end
if ~iscell(v); return; end
for k = 1:numel(v)
    e = v{k};
    if isstring(e); e = char(e); end
    if ischar(e) && ~isempty(strtrim(e)); out{end+1} = strtrim(e); end %#ok<AGROW>
end
end

function out = normaliseKey(name)
out = lower(strrep(strrep(charOf(name), '_', ''), ' ', ''));
end

function c = classNameOf(s)
c = '';
if isstruct(s) && isfield(s, 'document_class') && isstruct(s.document_class) ...
        && isfield(s.document_class, 'class_name')
    c = charOf(s.document_class.class_name);
end
end

function v = baseField(s, name, default)
v = default;
if isstruct(s) && isfield(s, 'base') && isstruct(s.base) ...
        && isfield(s.base, name) && ~isempty(s.base.(name))
    v = charOf(s.base.(name));
end
end

function s = charOf(v)
s = '';
if ischar(v)
    s = v;
elseif isstring(v) && isscalar(v)
    s = char(v);
elseif iscell(v) && isscalar(v)
    s = charOf(v{1});
elseif isnumeric(v) && isscalar(v) && isfinite(v)
    s = num2str(v);
end
end

function s = shortId(idStr)
s = charOf(idStr);
if numel(s) > 8; s = s(1:8); end
end

function out = decodeBodies(raw)
out = {};
for k = 1:numel(raw)
    b = raw{k};
    if ischar(b) || (isstring(b) && isscalar(b))
        try
            b = jsondecode(char(b));
        catch
            continue;
        end
    end
    if isstruct(b) && isscalar(b)
        out{end+1} = b; %#ok<AGROW>
    end
end
end
