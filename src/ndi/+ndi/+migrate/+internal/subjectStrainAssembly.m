function [kept, minted, report] = subjectStrainAssembly(v1Bodies, migratedStructs)
%SUBJECTSTRAINASSEMBLY V_eta second pass (#78): assemble the SUBJECT-ATTACHED
%   openMINDS Strain documents into deduplicated `strain` ENTITIES, put the
%   `strain_id` edge back on the assertion, wire `backgroundStrain` into the
%   recursive `background_strain_#` pedigree, move the `genetic strain type`
%   assertion off the subject onto the strain, and drop the duplicate `species`
%   assertion the strain object's own Species child produces.
%
%   [KEPT, MINTED, REPORT] = ndi.migrate.internal.subjectStrainAssembly(
%   V1BODIES, MIGRATEDSTRUCTS).
%
%   V1BODIES is the cell of did_v1 bodies pass 1 read; MIGRATEDSTRUCTS is the
%   cell of migrated V_eta bodies (did2.document.toStruct). KEPT is the
%   surviving migrated set with the edges attached and the moved/duplicate
%   assertions removed; MINTED is the new `strain` bodies; REPORT states its
%   denominators FIRST and unconditionally, and `[]` from the caller means "did
%   not run", so a silent zero and a real zero are distinguishable from the
%   output alone.
%
%   This function is PURE apart from minting document ids: it reads structs and
%   returns structs, calls no converter, touches no database and needs no
%   schema. That is what makes it testable without a corpus.
%
%   STATUS: authored WITHOUT local MATLAB (`command -v matlab octave
%   octave-cli` exits 1 in the container this was written in). Neither this
%   function nor its unit tests
%   (tests/+ndi/+unittest/+migrate/TestSubjectStrainAssembly.m) have been run.
%   Nothing here has been exercised against a corpus.
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
%       `strain` CANNOT reuse it (see "IDS ARE NOT PRESERVED HERE" below);
%     * they are written per SUBJECT ROW, so one strain becomes hundreds of
%       documents and dedup is the point rather than a tidy-up.
%
%   The two passes cannot collide: this one only ever touches a v1 body whose
%   MIGRATED counterpart is a `term_assertion`, and strainAssembly's documents
%   are either still `openminds` passthroughs or have already become `strain`.
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
%   `backgroundStrain` becomes `background_strain_#`". READ THE WRITER: those
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
%   what makes the idempotent re-run path -- readBodiesFromVDelta, which hands
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
%       (session_id, name, species{node,name}, genetic_strain_type{node,name},
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
%   SESSION IS IN THE KEY, deliberately, exactly as it is in softwareDedup and
%   epochMint. `base.session_id` is mustBeNonEmpty (V_eta/stable/base.json), so
%   a survivor carries exactly one session and merging across sessions would
%   leave documents in session B pointing at an entity stamped session A.
%   Whether `strain` is a per-session or a dataset-level entity is a MODELLING
%   QUESTION and this pass does not answer it -- it MEASURES it
%   (REPORT.cross_session_groups, REPORT.cross_session_collapsible say exactly
%   how many further entities a dataset-scoped key would remove).
%
%   ---------------------------------------------------------------------
%   WHAT IS REMOVED, AND THE CONDITIONS ON REMOVING IT
%   ---------------------------------------------------------------------
%   Two kinds of assertion leave the subject. Both are named in the signed
%   model (DID-schema V_eta_openminds_family_record.md Part 6, "Migration
%   consequences" 2 and 3, under TEAM-SIGN-OFF jess 2026-08-05), and the
%   built schema repeats one of them in its own documentation
%   (V_eta/stable/strain.json, `genetic_strain_type`: "it lives HERE rather
%   than on the subject: ~2,365 `genetic strain type` assertions move off
%   subjects onto the strain"). Neither is removed on the strength of that
%   sentence alone -- each removal is conditional on the fact being READABLE
%   somewhere else afterwards:
%
%   * A `genetic strain type` assertion goes ONLY IF it is the assertion
%     minted from a GeneticStrainType fragment of a Strain this pass
%     assembled, AND the same subject still carries a `strain` assertion whose
%     `strain_id` names a strain document whose `genetic_strain_type` is that
%     exact value. So the fact is reachable subject -> assertion -> strain
%     before the assertion is dropped, never after a guess.
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
%   WHAT IS MEASURED AND DELIBERATELY NOT ACTED ON
%   ---------------------------------------------------------------------
%   * BACKGROUND-STRAIN ASSERTIONS ON THE SUBJECT. Because `subject_id` is set
%     on every document of the flattened graph, a subject whose strain is an
%     F1 cross also carries a `strain` assertion for EACH ancestor -- the
%     Hunsberger cross gives `ArcCreERT2 x eYFP`, `ArcCreERT2`, `eYFP` and
%     `129S/SvEv`, all as assertions about the same mouse, only one of which is
%     the mouse's strain. Whether the ancestor assertions should be removed now
%     that the pedigree is on the strain document is a MODELLING CALL and
%     modelling calls are the team's; #78 does not name it. They are counted
%     (REPORT.background_strain_assertions_on_subject) and left exactly as pass
%     1 emitted them, each with its own correct `strain_id`.
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

report.background_refs_seen                = 0;
report.background_refs_not_in_openminds_edges = 0;
report.background_edges                    = 0;
report.background_unresolved               = 0;
report.background_over_max                 = 0;
report.pedigree_cycles                     = 0;
report.background_strain_assertions_on_subject = 0;   % measured, untouched

report.strain_id_edges_attached            = 0;
report.strain_id_assertion_already_had_one = 0;

report.gst_fragments_seen                  = 0;
report.gst_assertions_removed              = 0;
report.gst_kept_not_a_term_assertion       = 0;
report.gst_kept_value_not_on_strain        = 0;
report.gst_kept_shared_with_unassembled    = 0;
report.gst_kept_wrong_subject              = 0;
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
n = numel(migratedStructs);
migratedPos = containers.Map('KeyType', 'char', 'ValueType', 'double');
inbound     = containers.Map('KeyType', 'char', 'ValueType', 'any');
for i = 1:n
    s = migratedStructs{i};
    id = baseField(s, 'id', '');
    if ~isempty(id)
        migratedPos(id) = i;
    end
    if strcmp(classNameOf(s), 'term_assertion')
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
    if ~strcmp(classNameOf(migratedStructs{assertionPos}), 'term_assertion')
        report.strain_docs_not_a_term_assertion = ...
            report.strain_docs_not_a_term_assertion + 1;
        continue;
    end

    f = openmindsFields(b);
    e = struct();
    e.source_id     = srcId;
    e.assertion_pos = assertionPos;
    e.session_id    = baseField(b, 'session_id', '');
    e.datestamp     = baseField(b, 'datestamp', '2024-01-01T00:00:00.000Z');
    e.subject_id    = dependencyValueNamed(migratedStructs{assertionPos}, 'subject_id');
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

    why = '';
    if isempty(e.name)
        why = 'name';
    elseif ~termIsPopulated(e.species)
        why = 'species';
    elseif ~termIsPopulated(e.gst)
        why = 'genetic_strain_type';
    end
    if ~isempty(why)
        % `name`, `species` and `genetic_strain_type` are all mustBeNonEmpty on
        % V_eta/stable/strain.json. A Strain missing one is left exactly as
        % pass 1 emitted it rather than minted with a vacuous required field.
        report.strains_incomplete = report.strains_incomplete + 1;
        report.incomplete_reasons{end+1} = ...
            sprintf('%s: missing %s', shortId(srcId), why); %#ok<AGROW>
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
% Two keys, and the split is what makes the cross-session number exact rather
% than a string edit of the other one: CONTENT_KEY is the strain and its
% pedigree with no session anywhere in it, KEY is CONTENT_KEY under this
% document's session. Grouping is on KEY (session is part of the key -- see the
% header); the cross-session MEASUREMENT is the difference between the two.
memo    = containers.Map('KeyType', 'char', 'ValueType', 'char');
visited = containers.Map('KeyType', 'char', 'ValueType', 'logical');
sep     = char(31);   % unit separator: cannot occur in a name or a CURIE
for c = 1:numel(cand)
    [cand(c).content_key, cycles] = strainKey(c, cand, candById, memo, visited);
    cand(c).key = [cand(c).session_id sep cand(c).content_key];
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

% Cross-session measurement: how much further a dataset-scoped key would go.
% Reported, never performed -- see the header.
contentKeys     = {cand.content_key};
uniqContentKeys = unique(contentKeys);
for u = 1:numel(uniqContentKeys)
    members = strcmp(contentKeys, uniqContentKeys{u});
    if numel(unique({cand(members).session_id})) > 1
        report.cross_session_groups = report.cross_session_groups + 1;
    end
end
report.cross_session_collapsible = nGroups - numel(uniqContentKeys);

% ---- mint one strain per group ------------------------------------------
groupDocId = cell(1, nGroups);
groupRep   = zeros(1, nGroups);
for g = 1:nGroups
    groupRep(g)   = find([cand.group] == g, 1);
    groupDocId{g} = did.ido.unique_id();
end

for g = 1:nGroups
    rep = cand(groupRep(g));

    body = struct();
    body.document_class = classBlock('strain', {'entity'});

    % background_strain_#: to the SURVIVOR of each parent's group, in the
    % order `fields.backgroundStrain` gives. A parent this pass could not
    % assemble produces NO edge -- an edge naming nobody validates clean and
    % means nothing (did2/+validate/references.m:90 skips empty edges), which
    % is the invented-empty-edge defect, not a repair of it.
    deps = struct('name', {}, 'value', {});
    nEdge = 0;
    for p = 1:numel(rep.parents)
        pid = rep.parents{p};
        if isKey(candById, pid)
            nEdge = nEdge + 1;
            deps(end+1) = struct('name', ...
                sprintf('background_strain_%d', nEdge), ...
                'value', groupDocId{cand(candById(pid)).group}); %#ok<AGROW>
            report.background_edges = report.background_edges + 1;
        else
            report.background_unresolved = report.background_unresolved + 1;
        end
    end
    if nEdge > 2
        % strain.json declares max_count 2. Emitted AS FOUND rather than
        % silently truncated: a real violation is a finding and will show up
        % in validation, whereas a truncation is a silent loss.
        report.background_over_max = report.background_over_max + 1;
    end
    body.depends_on = deps;

    body.base = struct('id', groupDocId{g}, 'session_id', rep.session_id, ...
        'name', 'migrated_strain', 'datestamp', rep.datestamp);

    body.entity = struct();
    body.entity.global_identifier = rep.identifiers;

    blk = struct();
    blk.name                = rep.name;
    blk.species             = rep.species;
    blk.genetic_strain_type = rep.gst;
    if ~isempty(rep.description);     blk.description     = rep.description;     end
    if ~isempty(rep.phenotype);       blk.phenotype       = rep.phenotype;       end
    if ~isempty(rep.laboratory_code); blk.laboratory_code = rep.laboratory_code; end
    if ~isempty(rep.synonym);         blk.synonym         = rep.synonym;         end
    body.strain = blk;

    minted{end+1} = body; %#ok<AGROW>
    report.strains_minted = report.strains_minted + 1;
end

% ---- put `strain_id` back on the assertion -------------------------------
for c = 1:numel(cand)
    pos = cand(c).assertion_pos;
    if ~isempty(dependencyValueNamed(kept{pos}, 'strain_id'))
        report.strain_id_assertion_already_had_one = ...
            report.strain_id_assertion_already_had_one + 1;
        continue;
    end
    kept{pos} = appendDependency(kept{pos}, 'strain_id', ...
        groupDocId{cand(c).group});
    report.strain_id_edges_attached = report.strain_id_edges_attached + 1;
end

% An ancestor of another candidate is still asserted OF THE SUBJECT, because
% the writer sets `subject_id` on every document of the flattened graph.
% MEASURED, NOT ACTED ON -- see the header.
%
% Indexed on (parent document id, referring document's subject) rather than
% compared pairwise: the pairwise form is numel(cand)^2 and numel(cand) is in
% the thousands on a real dataset. A self-loop is skipped at BUILD time, which
% is the `d ~= c` the pairwise form spelled out.
ancestorOf = containers.Map('KeyType', 'char', 'ValueType', 'logical');
for d = 1:numel(cand)
    if isempty(cand(d).subject_id)
        continue;
    end
    for p = 1:numel(cand(d).parents)
        if strcmp(cand(d).parents{p}, cand(d).source_id)
            continue;   % a strain that is its own background
        end
        ancestorOf([cand(d).parents{p} '|' cand(d).subject_id]) = true;
    end
end
for c = 1:numel(cand)
    if isempty(cand(c).subject_id)
        continue;
    end
    if isKey(ancestorOf, [cand(c).source_id '|' cand(c).subject_id])
        report.background_strain_assertions_on_subject = ...
            report.background_strain_assertions_on_subject + 1;
    end
end

% ---- move the `genetic strain type` assertion onto the strain ------------
removeMask = false(1, n);

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
    if ~strcmp(classNameOf(kept{pos}), 'term_assertion')
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
            || ~strcmp(dependencyValueNamed(kept{pos}, 'subject_id'), ...
                       cand(c).subject_id)
        report.gst_kept_wrong_subject = report.gst_kept_wrong_subject + 1;
        continue;
    end
    % The fact must be reachable subject -> strain assertion -> strain BEFORE
    % this one is dropped: the strain assertion on that subject really carries
    % a `strain_id` (re-read, not assumed from the loop above), and the strain
    % it names really carries this exact `genetic_strain_type`.
    if isempty(dependencyValueNamed(kept{cand(c).assertion_pos}, 'strain_id')) ...
            || ~sameTerm(termValueOf(kept{pos}), cand(c).gst)
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
    if removeMask(i) || ~strcmp(classNameOf(kept{i}), 'term_assertion')
        continue;
    end
    if ~strcmp(normaliseKey(variableNameOf(kept{i})), 'species')
        continue;
    end
    t = termValueOf(kept{i});
    sid = dependencyValueNamed(kept{i}, 'subject_id');
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
    || report.strain_id_edges_attached > 0 || any(removeMask);
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
s = '';
if isempty(gid)
    return;
end
parts = cell(1, numel(gid));
for k = 1:numel(gid)
    parts{k} = [char(gid(k).scheme) ':' char(gid(k).value)];
end
s = strjoin(sort(parts), ',');
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
%   (hunsberger/SubjectInformationCreator.m:107) -- and it is what makes
%   background_strain_1 / _2 reproducible.
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
%IDENTIFIERS entity.global_identifier -- an ARRAY of {scheme, value}, split on
%   the first colon of the CURIE. Empty when the writer gives none: 115 strains
%   carry no identifier at all (dabrowska's Cre lines set only `name`), which
%   is why the field is optional on the entity.
%
%   THE SLOT IS NOT TRUSTED, THE PREFIX IS. Dabrowska writes
%   `'ontologyIdentifier', "RRID:RGD_70508"` -- an RRID in the ontology slot --
%   so both `ontologyIdentifier` and `digitalIdentifier` are read and the
%   scheme comes from the CURIE itself.
gid = struct('scheme', {}, 'value', {});
raws = {};
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
        if ischar(e) && ~isempty(strtrim(e)); raws{end+1} = strtrim(e); end %#ok<AGROW>
    end
end
for k = 1:numel(raws)
    raw = raws{k};
    c = strfind(raw, ':');
    if isempty(c)
        entry = struct('scheme', '', 'value', raw);
    else
        entry = struct('scheme', strtrim(raw(1:c(1)-1)), ...
            'value', strtrim(raw(c(1)+1:end)));
    end
    dup = false;
    for j = 1:numel(gid)
        if strcmp(gid(j).scheme, entry.scheme) && strcmp(gid(j).value, entry.value)
            dup = true;
        end
    end
    if ~dup
        gid(end+1) = entry; %#ok<AGROW>
    end
end
end

% ===================== migrated-body accessors ============================

function v = variableNameOf(s)
v = '';
if isstruct(s) && isfield(s, 'subject_statement') ...
        && isstruct(s.subject_statement) ...
        && isfield(s.subject_statement, 'variable')
    var = s.subject_statement.variable;
    if isstruct(var) && isfield(var, 'name')
        v = firstChar(var.name);
    end
end
end

function t = termValueOf(s)
%TERMVALUEOF The assertion's `{node,name}`. It rides the `term` composite
%   block, NOT a `term_assertion` block: V_eta/stable/term_assertion.json
%   declares no fields of its own and `value` is inherited from `term`. The
%   stale spelling is read as a FALLBACK only, because it is what a body
%   emitted before NDI d03a42bdf carries.
t = struct('node', '', 'name', '');
blk = struct();
if isstruct(s) && isfield(s, 'term') && isstruct(s.term)
    blk = s.term;
elseif isstruct(s) && isfield(s, 'term_assertion') && isstruct(s.term_assertion)
    blk = s.term_assertion;
end
if ~isfield(blk, 'value') || ~isstruct(blk.value)
    return;
end
if isfield(blk.value, 'node'); t.node = firstChar(blk.value.node); end
if isfield(blk.value, 'name'); t.name = firstChar(blk.value.name); end
end

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

function v = dependencyValueNamed(s, name)
v = '';
if ~isstruct(s) || ~isfield(s, 'depends_on') || ~isstruct(s.depends_on)
    return;
end
for k = 1:numel(s.depends_on)
    d = s.depends_on(k);
    if isfield(d, 'name') && strcmp(charOf(d.name), name)
        v = dependencyValueOf(d);
        if ~isempty(v); return; end
    end
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

function b = appendDependency(b, name, value)
%APPENDDEPENDENCY Add an edge to a migrated body, matching the existing struct
%   array's field schema so the append is legal. Same shape as
%   ndi.migrate.internal.ontologyRowSubjects/addSubjectDependency.
entry = struct('name', name, 'value', value);
if isfield(b, 'depends_on') && isstruct(b.depends_on) && ~isempty(b.depends_on)
    entry = matchFields(entry, b.depends_on(1));
    deps = b.depends_on;
    deps(end+1) = entry;
    b.depends_on = deps;
else
    b.depends_on = entry;
end
end

function entry = matchFields(entry, template)
val = dependencyValueOf(entry);
tf = fieldnames(template);
out = struct();
for k = 1:numel(tf)
    switch tf{k}
        case 'name'
            out.name = entry.name;
        case {'document_id', 'value', 'id'}
            out.(tf{k}) = val;
        otherwise
            out.(tf{k}) = '';
    end
end
if ~isfield(out, 'name')
    out.name = entry.name;
end
entry = out;
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

function dc = classBlock(name, supers)
sc = struct('class_name', {}, 'class_version', {});
for i = 1:numel(supers)
    sc(i) = struct('class_name', supers{i}, 'class_version', '1.0.0');
end
dc = struct('class_name', name, 'class_version', '1.0.0', ...
    'superclasses', sc, 'schema_version', 'V_eta');
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
