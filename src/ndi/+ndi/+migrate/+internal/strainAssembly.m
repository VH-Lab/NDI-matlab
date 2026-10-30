function [kept, minted, report] = strainAssembly(structs)
%STRAINASSEMBLY V_eta second pass: assemble the UNATTACHED `openminds`
%   documents that carry openMINDS Strain objects into strain ENTITIES (an
%   `entity` of type `strain`), with their ids preserved, consuming their
%   Species / GeneticStrainType FRAGMENT documents into ASSERTIONS about the
%   strain, and wiring `backgroundStrain` into `derived_from` relations.
%
%   THE SHAPE IS did-schema #88's (V_eta_entity_composition_plan.md, signed
%   2026-10-08 by Jess):
%     sec. 4  `strain` is no longer a class: it is an `entity` with
%             `type: strain`, whose only required field is `name`
%             (binding_registry_meta.json entity_type_bindings). Its other
%             fields become statements about it -- `species`,
%             `genetic_strain_type`, `phenotype` as term assertions,
%             `laboratory_code`, `synonym` as text assertions -- and
%             `background_strain_id` becomes a `derived_from` relation
%             (strain -> strain, RO:0001000).
%     sec. 1  an assertion is the `assertion` direction plus ONE value-kind
%             mixin (`term`, `text`), pointing at the strain by `entity_id`.
%   The variables are the ones ndi.setup.V2.entityDocuments writes for the
%   same fields (species NCIT:C45293, genetic strain type EMPTY:0000347; the
%   others by name), so a migrated strain reads like an imported one.
%
%   The signed openMINDS model this pass first implemented
%   (`V_eta_openminds_family_record.md` Part 7, TEAM-SIGN-OFF jess
%   2026-08-08: "the 3 unattached Strain documents become `strain` entities
%   with their ids preserved and OP50-GFP's pedigree as `background_strain_1`;
%   the other 5 documents are Species/GeneticStrainType fragments and are
%   consumed into their parent strain's `species` and `genetic_strain_type`
%   fields") is unchanged in substance: the ids, the consumption of the
%   fragments and the pedigree are the same; only where each fact is written
%   follows #88.
%
%   STRUCTS is a cell of V_eta document body structs (the pass-1 output; the
%   bare `openminds` class passes through, guarded). Returns KEPT (the
%   surviving bodies, with the consumed Strain and fragment documents removed),
%   MINTED (the strain entities, their assertions and their `derived_from`
%   relations, each tagged schema_version 'did_v2'), and REPORT (denominator
%   first; REPORT.changed gates the caller's rebuild).
%
%   ---------------------------------------------------------------------
%   WHY THIS IS A SECOND PASS AND NOT A `+migrators_j` FILE
%   ---------------------------------------------------------------------
%   The `species` and `genetic_strain_type` VALUES live in OTHER documents. A
%   Strain's child objects each become their own document and the parent's
%   field is replaced by an `ndi://<childId>` string:
%
%     git show origin/main:src/ndi/+ndi/+database/+fun/openMINDSobj2struct.m
%         s = ndi.database.fun.openMINDSobj2struct({f_here},cachekey);
%         child_index = find(strcmp(char(f_here.id),{s.openminds_id}));
%         fields_here{k} = ['ndi://' s(child_index).ndi_id];
%
%     git show origin/main:src/ndi/+ndi/+database/+fun/openMINDSobj2ndi_document.m
%         if startsWith(g{k},'ndi://')
%             id_here = g{k}(7:end);
%             d{i} = add_dependency_value_n(d{i},'openminds',id_here,'ErrorIfNotFound',0);
%
%   So the pedigree and the vocabulary values are reachable only across
%   documents, which a single-document migrator cannot follow.
%
%   THE `fields` KEYS STAY camelCase. did2.convert.universalRenames snake-cases
%   only ONE level -- `snakeCaseBlockFields` walks `fieldnames(block)` for each
%   top-level property block and stops (universalRenames.m:351-367). `fields`
%   is a nested struct inside the `openminds` block, so `geneticStrainType`,
%   `backgroundStrain`, `ontologyIdentifier`, `preferredOntologyIdentifier`
%   arrive unchanged. Every read below still takes a snake_case fallback, per
%   the standing migrator lesson.
%
%   ---------------------------------------------------------------------
%   THE SOURCE, FROM THE WRITER
%   ---------------------------------------------------------------------
%     git show origin/main:src/ndi/+ndi/+setup/+conv/+haley/doImport.m
%       :70-89    species = openminds.controlledterms.Species
%                 species.name='Escherichia coli'; .preferredOntologyIdentifier='NCBITaxon:562'
%                 OP50 = openminds.core.research.Strain
%                 OP50.name='Escherichia coli OP50'; .species=species
%                 OP50.ontologyIdentifier='NCBITaxon:637912'; .geneticStrainType='wild type'
%                 strainDoc = openMINDSobj2ndi_document(OP50, session.id);
%       :696-706  OP50GFP.name='OP50-GFP'; .species=species
%                 .ontologyIdentifier='WBStrain:00041972'; .geneticStrainType='transgenic'
%                 .backgroundStrain=OP50
%
%   `geneticStrainType` is ASSIGNED A CHAR. Whether openMINDS_MATLAB coerces it
%   into a `controlledterms.GeneticStrainType` instance (and so into its own
%   document) was NOT read -- the library is not in scope; Part 7 infers it from
%   the 3/5 document split and from the attached histogram where
%   GeneticStrainType (2,365) equals Strain (2,365) exactly. BOTH SHAPES ARE
%   THEREFORE HANDLED: an inline char becomes `{node:'', name:<char>}`, an
%   `ndi://` reference is resolved from its fragment document.
%
%   ---------------------------------------------------------------------
%   RULES OBSERVED
%   ---------------------------------------------------------------------
%   * IDS PRESERVED. The strain documents are referenced BY ID from ordinary
%     table cells -- `dataTable{:,'bacteriaStrain'} = {strainDoc{1}.id}`
%     (haley/doImport.m:164 and :734) -- not through `depends_on`, so nothing
%     would flag a re-mint. The minted `strain` reuses the openminds document's
%     `base.id` exactly.
%   * NOTHING IS EMITTED HOLLOW. A strain entity requires `name` (the type
%     registry); a Strain with no name is LEFT AS PASSTHROUGH and counted
%     (REPORT.strains_incomplete). Before #88 the `strain` class also required
%     `species` and `genetic_strain_type`; on #88 those are assertions, so a
%     Strain without one simply has no such assertion (REPORT.species_missing,
%     REPORT.genetic_strain_type_missing count them) -- nothing is invented.
%   * NO EMPTY EDGE. A `backgroundStrain` reference that does not resolve to a
%     Strain document in this set produces NO `derived_from` relation; it is
%     counted (REPORT.background_unresolved).
%   * A FRAGMENT IS CONSUMED ONLY IF EVERY DOCUMENT THAT REFERENCES IT IS A
%     STRAIN THIS PASS ASSEMBLED. Otherwise it stays, so a surviving
%     passthrough's `openminds_#` edge cannot dangle.
%   * NOTHING IS SAID ABOUT AN ORGANISM. These documents carry no subject --
%     every assertion minted here is about the STRAIN (its `entity_id`). That
%     is the whole reason a strain is an entity.
%
%   * ONE STRAIN PER DATASET WHEN A DATASET IS MIGRATED. Decided by Jess
%     Haley, 2026-10-21: "When a dataset is migrated, shared entities
%     (strains, software, people, organizations, instruments, products) move
%     to the dataset level as in native V2 imports (Haley
%     import_V2_decisions.md #20): one entity per distinct thing in the
%     dataset's database, with session documents pointing at it and
%     merged-away ids remapped so every link still resolves; a lone session
%     with no dataset keeps them in the session." The Haley writer mints one
%     Strain per session (doImport.m runs per session), so a dataset holds
%     copies. With exactly one `dataset` entity in the batch
%     (ndi.migrate.internal.datasetScope), identical strains (same name,
%     species, genetic strain type, identifier, description and surviving
%     background strains) merge onto the smallest id, every strain entity and
%     its assertions and relations are stored at the dataset level (their
%     `session_id` names the dataset entity), and every reference to a
%     merged-away id ANYWHERE in the kept set -- edges and ordinary fields,
%     since the ids sit in table cells -- is rewritten to the survivor
%     (ndi.migrate.internal.remapIds; REPORT.strains_merged_away,
%     REPORT.references_remapped). A lone session is left exactly as before.
%
%   ---------------------------------------------------------------------
%   DEFERRED, ON PURPOSE
%   ---------------------------------------------------------------------
%   The organism-to-strain `instance_of` relation is NOT minted here. These
%   strains are bacterial food named in `ontologyTableRow` cells
%   (`bacteriaStrain`), and whatever becomes an instance of them is minted by
%   the pass that reads those rows. Nothing here blocks it: the id it will
%   point at is preserved.
%
%   Group B of Part 7 (the metadata-app dataset graph: Dataset / Person /
%   Organization / funding) is NOT handled here. It maps to the six classes
%   `metadata_editor` already emits, contributed ZERO documents to the three
%   corpora measured, and its open question (#73 -- whether a `metadata_editor`
%   document is always written alongside the openMINDS graph) is unanswered.
%   Bare `openminds` documents that are not Strain/Species/GeneticStrainType
%   are left untouched and counted (REPORT.openminds_other).
%
%   ---------------------------------------------------------------------
%   THE OTHER STRAIN FIELDS
%   ---------------------------------------------------------------------
%   Decided by Jess Haley, 2026-10-27 [openMINDS strain leftovers] and
%   2026-10-30 [openMINDS strain leftovers settled] (did-schema
%   V_eta_go_forward_class_audit.md, G49): digitalIdentifier and
%   alternateIdentifier go to `global_identifier` (a list); stockNumber is an
%   RRID there when its vendor is JAX, MMRRC or Bloomington, else a "Catalog
%   Number" (NCIT:C99286) text assertion; breedingType ("breeding",
%   NCIT:C42877) and diseaseModel ("disease model", BAO:0010279) are term
%   assertions; lookupLabel is not stored. ndi.migrate.internal.strainLeftovers
%   reads them. A Species or GeneticStrainType fragment's definition and
%   synonyms are not stored (read back from the term), so they no longer
%   keep the fragment. The child documents those fields point at (an
%   identifier, a StockNumber, a breeding-type or disease term) are consumed
%   with the same rule as a fragment when every field of theirs is written;
%   an Organization is never consumed here.
%
%   Tests: tests/+ndi/+unittest/+migrate/TestStrainAssembly.m (the fast
%   assembler gate, test-eta-migrate.yml).
%
%   See also: ndi.migrate.local, ndi.migrate.internal.pathSPromotion,
%     ndi.migrate.internal.ensembleMembership,
%     ndi.migrate.internal.subjectStrainAssembly,
%     ndi.migrate.internal.etaShape,
%     DID-schema schemas/V_eta_openminds_family_record.md Part 7,
%     DID-schema schemas/V_eta_entity_composition_plan.md secs. 1, 4, 5.

arguments
    structs cell
end

kept   = structs;
minted = {};

report = struct();
report.documents_inspected    = numel(structs);
report.openminds_seen         = 0;
report.openminds_other        = 0;   % bare openminds that is not a strain/fragment
report.strains_seen           = 0;
report.strains_assembled      = 0;
report.strains_incomplete     = 0;   % no name, or unplaced -> passthrough
report.strains_unplaced       = 0;   % of those: a field this pass cannot place
report.incomplete_reasons     = {};
% every Strain or fragment left as v1, with the carry register row its reason
% cites ([carry register], Jess Haley, 2026-10-26), for the final v1 stamp's
% count by row
report.carry_rows             = struct('id', {}, 'row', {});
report.fragments_seen         = 0;
report.fragments_consumed     = 0;
report.fragments_retained     = 0;
report.children_consumed      = 0;   % identifier / StockNumber / breeding / disease documents
report.background_edges       = 0;
report.background_unresolved  = 0;
report.species_missing        = 0;   % assembled, but no species to assert
report.genetic_strain_type_missing = 0;
report.assertions_minted      = 0;   % term + text assertions about strains
report.scope                  = 'session';
report.dataset_id             = '';
report.cross_session_groups   = 0;   % distinct strains written in >1 session
report.cross_session_collapsible = 0;
report.strains_merged_away    = 0;   % dataset scope only
report.references_remapped    = 0;   % merged-away ids rewritten to survivors
report.changed                = false;

if isempty(structs)
    return;
end

n = numel(structs);
isOpenminds = false(1, n);
isStrainDoc = false(1, n);
idOf        = cell(1, n);
byId        = containers.Map('KeyType', 'char', 'ValueType', 'double');

for i = 1:n
    idOf{i} = baseField(structs{i}, 'id', '');
    if ~strcmp(classNameOf(structs{i}), 'openminds')
        continue;
    end
    isOpenminds(i) = true;
    report.openminds_seen = report.openminds_seen + 1;
    isStrainDoc(i) = isOpenmindsType(structs{i}, 'Strain');
    if ~isempty(idOf{i})
        byId(idOf{i}) = i;
    end
end

% Census FIRST, unconditionally -- an instrument reports its denominator even
% when it has no work to do. (An early return before this point is how a
% counter comes to print zeros while reading nothing.)
for i = find(isOpenminds)
    if isStrainDoc(i)
        report.strains_seen = report.strains_seen + 1;
    elseif isOpenmindsType(structs{i}, 'Species') ...
            || isOpenmindsType(structs{i}, 'GeneticStrainType')
        report.fragments_seen = report.fragments_seen + 1;
    else
        report.openminds_other = report.openminds_other + 1;
    end
end

if ~any(isStrainDoc)
    return;
end

% --- pass 1: which Strain documents can be assembled at all? ----------------
% A `derived_from` relation must point at a strain entity that SURVIVES, so the
% completeness decision has to be made for every strain before any relation is
% written.
strainIdx      = find(isStrainDoc);
assembled      = false(1, n);
speciesTermOf  = cell(1, n);
gstTermOf      = cell(1, n);
usedFragments  = containers.Map('KeyType', 'char', 'ValueType', 'any');
usedFrags      = cell(1, n);
leftoverOf     = cell(1, n);
lookup = @(id) lookupDoc(byId, structs, id);

for k = 1:numel(strainIdx)
    i = strainIdx(k);
    s = structs{i};
    f = openmindsFields(s);

    nm = charField(f, {'name'});
    [speciesTerm, speciesFrag] = resolveTerm(f, {'species'}, byId, structs);
    [gstTerm, gstFrag] = resolveTerm(f, ...
        {'geneticStrainType', 'genetic_strain_type'}, byId, structs);

    if isempty(nm)
        report.strains_incomplete = report.strains_incomplete + 1;
        % carry-register: carry-093
        report.incomplete_reasons{end+1} = ...
            sprintf('%s: [carry-093] missing name', shortId(idOf{i})); %#ok<AGROW>
        report.carry_rows(end+1) = struct('id', idOf{i}, 'row', 'carry-093');
        continue;
    end
    % [generic stage is lossless] and [partly placed is carried as v1] (Jess
    % Haley, 2026-10-25, did-schema V_eta_go_forward_class_audit.md): a Strain
    % with a field this pass does not write (any field outside the openMINDS
    % Strain set read here), a second value where one is read, or a
    % reference that does not resolve
    % is LEFT AS PASSTHROUGH (carried as v1 by ndi.migrate.local's last step),
    % counted with its reason. A fragment with a field the term does not write
    % is kept rather than consumed (fragmentFullyPlaced).
    % [openMINDS strain leftovers] (Jess Haley, 2026-10-27, settled
    % 2026-10-30): the identifiers, stock number, breeding type and disease
    % models; what of them cannot be placed is listed with the rest
    leftoverOf{i} = ndi.migrate.internal.strainLeftovers(f, lookup);
    unplaced = [unplacedStrainFields(f, byId, structs), leftoverOf{i}.unplaced];
    if ~isempty(unplaced)
        report.strains_incomplete = report.strains_incomplete + 1;
        report.strains_unplaced = report.strains_unplaced + 1;
        % carry-register: carry-092
        report.incomplete_reasons{end+1} = sprintf('%s: [carry-092] cannot place %s', ...
            shortId(idOf{i}), strjoin(unplaced, ', ')); %#ok<AGROW>
        report.carry_rows(end+1) = struct('id', idOf{i}, 'row', 'carry-092');
        continue;
    end

    assembled(i)     = true;
    speciesTermOf{i} = speciesTerm;
    gstTermOf{i}     = gstTerm;
    usedFrags{i} = [reshape(speciesFrag, 1, []), reshape(gstFrag, 1, []), ...
        reshape(leftoverOf{i}.consumable, 1, [])];
end

% A background strain that is not assembled would be a `derived_from` written
% nowhere ([generic stage is lossless]): its child is left as passthrough too,
% to a fixed point (a cross of a cross).
changedSet = true;
while changedSet
    changedSet = false;
    for k = 1:numel(strainIdx)
        i = strainIdx(k);
        if ~assembled(i); continue; end
        ps = ndiRefs(getAny(openmindsFields(structs{i}), {'backgroundStrain', 'background_strain'}));
        for p = 1:numel(ps)
            if ~(isKey(byId, ps{p}) && assembled(byId(ps{p})))
                assembled(i) = false;
                changedSet = true;
                report.strains_incomplete = report.strains_incomplete + 1;
                report.strains_unplaced = report.strains_unplaced + 1;
                % carry-register: carry-064
                report.incomplete_reasons{end+1} = sprintf( ...
                    '%s: [carry-064] cannot place backgroundStrain %s (not assembled)', ...
                    shortId(idOf{i}), shortId(ps{p})); %#ok<AGROW>
                report.carry_rows(end+1) = struct('id', idOf{i}, 'row', 'carry-064');
                break;
            end
        end
    end
end
for k = 1:numel(strainIdx)
    i = strainIdx(k);
    if ~assembled(i); continue; end
    for fr = 1:numel(usedFrags{i})
        addUse(usedFragments, usedFrags{i}{fr}, idOf{i});
    end
end

if ~any(assembled)
    return;
end

% --- pass 2: mint the strain entities, their assertions and pedigree --------
S = ndi.migrate.internal.etaShape;
for k = 1:numel(strainIdx)
    i = strainIdx(k);
    if ~assembled(i)
        continue;
    end
    s = structs{i};
    f = openmindsFields(s);
    sid = ndi.v2.sessionIdOf(s);
    ds  = baseField(s, 'datestamp', '');
    if isempty(ds)
        ds = baseField(s, 'creation_timestamp', '');
    end
    common = {'SessionId', sid, 'Datestamp', ds};

    % base.id PRESERVED -- ontologyTableRow's `bacteriaStrain` cell holds it.
    ef = struct('name', charField(f, {'name'}));
    desc = charField(f, {'description'});
    if ~isempty(desc); ef.description = desc; end
    gid = charField(f, {'ontologyIdentifier', 'ontology_identifier'});
    gids = {};
    if ~isempty(gid); gids = {S.curie(gid)}; end
    % [openMINDS strain leftovers]: every identifier goes in the list
    for g = 1:numel(leftoverOf{i}.identifiers)
        if ~any(strcmp(gids, leftoverOf{i}.identifiers{g}))
            gids{end+1} = leftoverOf{i}.identifiers{g}; %#ok<AGROW>
        end
    end
    if ~isempty(gids); ef.global_identifier = gids; end
    minted{end+1} = S.entity('strain', ef, 'Id', idOf{i}, common{:}); %#ok<AGROW>
    report.strains_assembled = report.strains_assembled + 1;

    [docs, nA] = strainStatements(idOf{i}, speciesTermOf{i}, gstTermOf{i}, f, common, ...
        leftoverOf{i});
    minted = [minted, docs]; %#ok<AGROW>
    report.assertions_minted = report.assertions_minted + nA;
    if ~termIsPopulated(speciesTermOf{i})
        report.species_missing = report.species_missing + 1;
    end
    if ~termIsPopulated(gstTermOf{i})
        report.genetic_strain_type_missing = report.genetic_strain_type_missing + 1;
    end

    % derived_from: only to strains that survive this pass, in source order.
    parents = ndiRefs(getAny(f, {'backgroundStrain', 'background_strain'}));
    for p = 1:numel(parents)
        pid = parents{p};
        if isKey(byId, pid) && assembled(byId(pid))
            minted{end+1} = S.relation(idOf{i}, pid, ...
                ndi.v2.vocabTerm('relation', 'derived_from'), common{:}); %#ok<AGROW>
            report.background_edges = report.background_edges + 1;
        else
            report.background_unresolved = report.background_unresolved + 1;
        end
    end
end

% --- pass 3: consume the sources -------------------------------------------
% A fragment goes only when EVERY document that references it is a strain this
% pass assembled; otherwise a surviving passthrough's `openminds_#` edge would
% dangle. References are counted over the WHOLE set, through `depends_on` AND
% through the `ndi://` strings in `openminds.fields` -- the id can travel either
% way, and only the `fields` route says which role it fills.
referrers = containers.Map('KeyType', 'char', 'ValueType', 'any');
for i = 1:n
    src = idOf{i};
    targets = referencedIds(structs{i});
    for t = 1:numel(targets)
        addUse(referrers, targets{t}, src);
    end
end

removeMask = false(1, n);
removeMask(assembled) = true;    % replaced 1:1 by the minted strain (same id)

consumedStrains = idOf(assembled);
for i = find(isOpenminds)
    if isStrainDoc(i) || isempty(idOf{i})
        continue;
    end
    if ~(isOpenmindsType(structs{i}, 'Species') ...
            || isOpenmindsType(structs{i}, 'GeneticStrainType'))
        % a child document a strain field points at ([openMINDS strain
        % leftovers]: an identifier, a StockNumber, a breeding-type or
        % disease term), fully written into the strain: consumed by the same
        % rule as a fragment. Anything else is not this family's; left alone.
        if isKey(usedFragments, idOf{i})
            who = {};
            if isKey(referrers, idOf{i}); who = referrers(idOf{i}); end
            if all(ismember(who, consumedStrains))
                removeMask(i) = true;
                report.children_consumed = report.children_consumed + 1;
            end
        end
        continue;
    end
    if ~isKey(usedFragments, idOf{i})
        % carry-register: carry-094
        report.fragments_retained = report.fragments_retained + 1;
        report.carry_rows(end+1) = struct('id', idOf{i}, 'row', 'carry-094');
        continue;   % referenced by no assembled strain
    end
    who = {};
    if isKey(referrers, idOf{i}); who = referrers(idOf{i}); end
    if all(ismember(who, consumedStrains)) && fragmentFullyPlaced(structs{i})
        removeMask(i) = true;
        report.fragments_consumed = report.fragments_consumed + 1;
    else
        % still referenced by a strain left as v1, or holding a field the
        % strain's term does not write ([generic stage is lossless]): kept
        % carry-register: carry-094
        report.fragments_retained = report.fragments_retained + 1;
        report.carry_rows(end+1) = struct('id', idOf{i}, 'row', 'carry-094');
    end
end

kept = structs(~removeMask);

% --- pass 4: the dataset level, when a dataset is migrated -----------------
% Decided by Jess Haley, 2026-10-21 (header): one strain entity per distinct
% strain in the dataset's database, stored at the dataset level, with every
% merged-away id remapped to its survivor.
scope = ndi.migrate.internal.datasetScope(structs);
[minted, kept, report] = datasetLevel(minted, kept, report, scope, ...
    find(assembled), idOf, structs, speciesTermOf, gstTermOf, byId, assembled, ...
    leftoverOf);
report.changed = true;
end

% ===================== the dataset level ==================================

function [minted, kept, report] = datasetLevel(minted, kept, report, scope, ...
        idx, idOf, structs, speciesTermOf, gstTermOf, byId, assembled, leftoverOf)
%DATASETLEVEL Merge identical strains across the dataset and store them there.
%   The key is the strain's CONTENT -- name, species, genetic strain type,
%   identifier, description and its background strains (as their SURVIVING
%   ids) -- iterated to a fixed point so that two copies of a cross whose
%   parents are themselves copies merge too. Measured in both modes
%   (REPORT.cross_session_groups / _collapsible); merged and moved only when the
%   scope is a dataset.
S = ndi.migrate.internal.etaShape;
remap = containers.Map('KeyType', 'char', 'ValueType', 'char');
attrs = cell(1, numel(idx));
sess  = cell(1, numel(idx));
parents = cell(1, numel(idx));
for k = 1:numel(idx)
    i = idx(k);
    f = openmindsFields(structs{i});
    sp = speciesTermOf{i}; g = gstTermOf{i};
    attrs{k} = strjoin({charField(f, {'name'}), char(sp.node), char(sp.name), ...
        char(g.node), char(g.name), ...
        charField(f, {'ontologyIdentifier', 'ontology_identifier'}), ...
        charField(f, {'description'}), leftoverOf{i}.key}, char(31));
    sess{k} = ndi.v2.sessionIdOf(structs{i});
    ps = ndiRefs(getAny(f, {'backgroundStrain', 'background_strain'}));
    keepP = false(1, numel(ps));
    for p = 1:numel(ps)
        keepP(p) = isKey(byId, ps{p}) && assembled(byId(ps{p}));
    end
    parents{k} = ps(keepP);
end
ids = idOf(idx);
for iter = 1:numel(idx) + 1
    keys_ = cell(1, numel(idx));
    for k = 1:numel(idx)
        pk = cellfun(@(x) resolveId(remap, x), parents{k}, 'UniformOutput', false);
        keys_{k} = [attrs{k} char(30) strjoin(pk, ',')];
    end
    [u, ~, grp] = unique(keys_);
    changed = false;
    for g = 1:numel(u)
        members = find(grp == g);
        [~, o] = sort(ids(members));
        survivor = ids{members(o(1))};
        for m = members(:)'
            if ~strcmp(ids{m}, survivor) && ...
                    ~(isKey(remap, ids{m}) && strcmp(remap(ids{m}), survivor))
                remap(ids{m}) = survivor;
                changed = true;
            end
        end
    end
    if ~changed
        break;
    end
end
% measurement: session-scoped groups beyond dataset-scoped ones
sessKeys = cellfun(@(a, b) [a char(29) b], sess, keys_, 'UniformOutput', false);
report.cross_session_collapsible = numel(unique(sessKeys)) - numel(unique(keys_));
for g = 1:numel(u)
    if numel(unique(sess(grp == g))) > 1
        report.cross_session_groups = report.cross_session_groups + 1;
    end
end
if ~scope.is_dataset
    return;
end
report.scope      = 'dataset';
report.dataset_id = scope.dataset_id;

gone = remap.keys();
report.strains_merged_away = numel(gone);
keepM = true(1, numel(minted));
seenRel = containers.Map('KeyType', 'char', 'ValueType', 'logical');
for k = 1:numel(minted)
    b = minted{k};
    if S.isEntity(b)
        about = b.base.id;
    elseif strcmp(S.className(b), 'directed_relation')
        [about, par] = S.relationEnds(b);
    else
        about = S.aboutId(b);
    end
    if isKey(remap, about)
        keepM(k) = false;   % the survivor carries the same entity and facts
        continue;
    end
    if strcmp(S.className(b), 'directed_relation')
        newPar = resolveId(remap, par);
        relKey = [about '|' newPar];
        if isKey(seenRel, relKey)
            keepM(k) = false;
            continue;
        end
        seenRel(relKey) = true;
        if ~strcmp(newPar, par)
            b = S.setEdge(b, 'parent_id', newPar);
        end
    end
    minted{k} = ndi.migrate.internal.withSessionId(b, scope.dataset_id);
end
minted = minted(keepM);
if ~isempty(gone)
    flat = containers.Map('KeyType', 'char', 'ValueType', 'char');
    for k = 1:numel(gone)
        flat(gone{k}) = resolveId(remap, gone{k});
    end
    [kept, report.references_remapped] = ndi.migrate.internal.remapIds(kept, flat);
end
end

function id = resolveId(remap, id)
seen = 0;
while isKey(remap, id) && seen < remap.Count + 1
    id = remap(id);
    seen = seen + 1;
end
end

% ===================== the strain's statements =========================

function [docs, nAssertions] = strainStatements(strainId, speciesTerm, gstTerm, f, common, L)
%STRAINSTATEMENTS The assertions a strain's openMINDS fields become on #88
%   (V_eta_entity_composition_plan.md sec. 4): species, genetic strain type and
%   phenotype as term assertions, laboratory code and synonyms as text
%   assertions -- the variables ndi.setup.V2.entityDocuments writes.
S = ndi.migrate.internal.etaShape;
docs = {};
if termIsPopulated(speciesTerm)
    docs{end+1} = S.statement('assertion', 'term', strainId, ...
        S.term('NCIT:C45293', 'Species'), speciesTerm, common{:});
end
if termIsPopulated(gstTerm)
    docs{end+1} = S.statement('assertion', 'term', strainId, ...
        S.term('EMPTY:0000347', 'genetic strain type'), gstTerm, common{:});
end
phen = charField(f, {'phenotype'});
if ~isempty(phen)
    docs{end+1} = S.statement('assertion', 'term', strainId, ...
        S.term('', 'phenotype'), S.term('', phen), common{:});
end
lab = charField(f, {'laboratoryCode', 'laboratory_code'});
if ~isempty(lab)
    docs{end+1} = S.statement('assertion', 'text', strainId, ...
        S.term('', 'laboratory code'), struct('text', lab), common{:});
end
syn = cellstrField(f, {'synonym'});
if ~isempty(syn)
    docs{end+1} = S.statement('assertion', 'text', strainId, ...
        S.term('', 'synonym'), struct('text', syn), common{:});
end
% [openMINDS strain leftovers] / [... settled] (Jess Haley, 2026-10-27/30)
if ~isempty(L.catalog_number)
    docs{end+1} = S.statement('assertion', 'text', strainId, ...
        S.term('NCIT:C99286', 'Catalog Number'), struct('text', L.catalog_number), common{:});
end
if termIsPopulated(L.breeding)
    docs{end+1} = S.statement('assertion', 'term', strainId, ...
        S.term('NCIT:C42877', 'breeding'), L.breeding, common{:});
end
for k = 1:numel(L.diseases)
    docs{end+1} = S.statement('assertion', 'term', strainId, ...
        S.term('BAO:0010279', 'disease model'), L.diseases{k}, common{:}); %#ok<AGROW>
end
nAssertions = numel(docs);
end

% ===================== what this pass places =============================

function unplaced = unplacedStrainFields(f, byId, structs)
%UNPLACEDSTRAINFIELDS The Strain fields this pass would
%   not write ([generic stage is lossless], Jess Haley, 2026-10-25). Written:
%   name, description, ontologyIdentifier (the global identifier), ONE species
%   and ONE genetic strain type (inline, or one resolvable fragment whose name
%   and ONE identifier are read), phenotype (one), laboratoryCode (one),
%   synonym (all), backgroundStrain (as `derived_from`, checked by the
%   caller), and the fields ndi.migrate.internal.strainLeftovers places
%   (which lists its own unplaced ones). Anything else non-empty is unplaced.
placed = {'name', 'description', 'ontologyIdentifier', 'ontology_identifier', ...
    'species', 'geneticStrainType', 'genetic_strain_type', ...
    'backgroundStrain', 'background_strain', 'phenotype', ...
    'laboratoryCode', 'laboratory_code', 'synonym', ...
    ... % [openMINDS strain leftovers]: strainLeftovers reads these and lists
    ... % what of them it cannot place; lookupLabel is not stored
    'digitalIdentifier', 'digital_identifier', ...
    'alternateIdentifier', 'alternate_identifier', ...
    'stockNumber', 'stock_number', 'breedingType', 'breeding_type', ...
    'diseaseModel', 'disease_model', 'lookupLabel', 'lookup_label'};
unplaced = {};
fn = fieldnames(f);
for k = 1:numel(fn)
    v = f.(fn{k});
    if isEmptyValue(v); continue; end
    if ~any(strcmp(fn{k}, placed))
        unplaced{end+1} = fn{k}; %#ok<AGROW>
    end
end
single = {{'name'}, {'description'}, {'ontologyIdentifier', 'ontology_identifier'}, ...
    {'phenotype'}, {'laboratoryCode', 'laboratory_code'}};
for k = 1:numel(single)
    v = getAny(f, single{k});
    if (iscell(v) || isstring(v)) && numel(v) > 1
        unplaced{end+1} = sprintf('%s (%d values)', single{k}{1}, numel(v)); %#ok<AGROW>
    end
end
for termField = {{'species'}, {'geneticStrainType', 'genetic_strain_type'}}
    v = getAny(f, termField{1});
    if isEmptyValue(v); continue; end
    nm = termField{1}{1};
    if (iscell(v) || isstring(v)) && numel(v) > 1
        unplaced{end+1} = sprintf('%s (%d values)', nm, numel(v)); %#ok<AGROW>
        continue;
    end
    refs = ndiRefs(v);
    if isempty(refs); continue; end   % inline: its text is the term's name
    if ~isKey(byId, refs{1})
        unplaced{end+1} = sprintf('%s (reference %s not in the batch)', nm, refs{1}); %#ok<AGROW>
        continue;
    end
    ff = openmindsFields(structs{byId(refs{1})});
    a = charField(ff, {'preferredOntologyIdentifier', 'preferred_ontology_identifier'});
    b = charField(ff, {'ontologyIdentifier', 'ontology_identifier'});
    if isempty(charField(ff, {'name'})) && isempty(a) && isempty(b)
        unplaced{end+1} = sprintf('%s (fragment %s states nothing this pass reads)', nm, refs{1}); %#ok<AGROW>
    end
end
end

function tf = fragmentFullyPlaced(fragment)
%FRAGMENTFULLYPLACED A Species / GeneticStrainType fragment whose every
%   non-empty field the strain's term writes: its name and ONE identifier.
%   Its definition and synonyms are not stored, read back from the term
%   ([openMINDS strain leftovers], Jess Haley, 2026-10-27). Any other field
%   means the fragment is kept, carried as v1, rather than consumed
%   ([generic stage is lossless]).
ff = openmindsFields(fragment);
fragPlaced = {'name', 'preferredOntologyIdentifier', ...
    'preferred_ontology_identifier', 'ontologyIdentifier', 'ontology_identifier', ...
    'definition', 'synonym'};
tf = false;
fn = fieldnames(ff);
for j = 1:numel(fn)
    if ~isEmptyValue(ff.(fn{j})) && ~any(strcmp(fn{j}, fragPlaced))
        return;
    end
end
a = charField(ff, {'preferredOntologyIdentifier', 'preferred_ontology_identifier'});
b = charField(ff, {'ontologyIdentifier', 'ontology_identifier'});
if ~isempty(a) && ~isempty(b) && ~strcmp(a, b)
    return;
end
tf = true;
end

function d = lookupDoc(byId, structs, id)
%LOOKUPDOC The body whose base.id is ID, or [] when it is not in the set.
d = [];
if ischar(id) && isKey(byId, id)
    d = structs{byId(id)};
end
end

function tf = isEmptyValue(v)
tf = isempty(v) || ((ischar(v) || (isstring(v) && isscalar(v))) && strlength(strtrim(string(v))) == 0);
end

% ===================== openMINDS accessors =============================

function tf = isOpenmindsType(s, typeName)
%ISOPENMINDSTYPE Match on matlab_type's trailing class OR openminds_type's
%   trailing IRI segment, so the check survives an openMINDS namespace change
%   (openminds.ebrains.eu -> openminds.om-i.org) and either writer spelling.
tf = false;
if ~isfield(s, 'openminds') || ~isstruct(s.openminds)
    return;
end
b = s.openminds;
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

function f = openmindsFields(s)
f = struct();
if isfield(s, 'openminds') && isstruct(s.openminds) ...
        && isfield(s.openminds, 'fields') && isstruct(s.openminds.fields)
    f = s.openminds.fields;
end
end

function [term, frags] = resolveTerm(f, names, byId, structs)
%RESOLVETERM An ontology_term for a Strain field that is either an inline char
%   or an `ndi://` reference to a controlled-term FRAGMENT document.
term  = struct('node', '', 'name', '');
frags = {};
v = getAny(f, names);
if isempty(v)
    return;
end
refs = ndiRefs(v);
if isempty(refs)
    % inline char (the `geneticStrainType = 'wild type'` shape). No CURIE is
    % available, so the node stays empty -- normalising 'wild type' vs
    % 'wildtype' is the T8 binding job, not this pass's.
    term.name = firstChar(v);
    return;
end
for r = 1:numel(refs)
    if ~isKey(byId, refs{r}); continue; end
    fr = structs{byId(refs{r})};
    ff = openmindsFields(fr);
    nm = charField(ff, {'name'});
    nd = charField(ff, {'preferredOntologyIdentifier', ...
        'preferred_ontology_identifier', 'ontologyIdentifier', ...
        'ontology_identifier'});
    if isempty(nm) && isempty(nd); continue; end
    term.name = nm;
    term.node = nd;
    frags{end+1} = refs{r}; %#ok<AGROW>
    return;      % the fields are single-valued in every writer we have
end
end

function ids = ndiRefs(v)
%NDIREFS The `ndi://<id>` document ids inside a fields value (char, cellstr or
%   string), in order.
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

% ===================== struct accessors ================================

function tf = termIsPopulated(t)
tf = isstruct(t) && ((isfield(t, 'node') && ~isempty(strtrim(char(t.node)))) ...
    || (isfield(t, 'name') && ~isempty(strtrim(char(t.name)))));
end

function v = getAny(s, names)
v = [];
if ~isstruct(s); return; end
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

function out = referencedIds(s)
%REFERENCEDIDS Every document id this body points at -- `depends_on` values and
%   `ndi://` strings inside `openminds.fields`.
out = {};
if isfield(s, 'depends_on') && isstruct(s.depends_on)
    for k = 1:numel(s.depends_on)
        d = s.depends_on(k);
        v = '';
        if isfield(d, 'value') && ~isempty(d.value)
            v = char(d.value);
        elseif isfield(d, 'document_id') && ~isempty(d.document_id)
            v = char(d.document_id);
        end
        if ~isempty(v); out{end+1} = v; end %#ok<AGROW>
    end
end
f = openmindsFields(s);
fn = fieldnames(f);
for k = 1:numel(fn)
    r = ndiRefs(f.(fn{k}));
    for j = 1:numel(r); out{end+1} = r{j}; end %#ok<AGROW>
end
% `unique` on a cellstr returns a COLUMN; reshape to a row so the caller's
% index loop and any `for x = out` see N entries rather than one.
out = reshape(unique(out), 1, []);
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

function c = classNameOf(s)
c = '';
if isfield(s, 'document_class') && isstruct(s.document_class) ...
        && isfield(s.document_class, 'class_name')
    c = char(s.document_class.class_name);
end
end

function v = baseField(s, name, default)
v = default;
if isfield(s, 'base') && isstruct(s.base) && isfield(s.base, name) ...
        && ~isempty(s.base.(name))
    v = s.base.(name);
end
end

function s = shortId(idStr)
s = char(idStr);
if numel(s) > 8; s = s(1:8); end
end
