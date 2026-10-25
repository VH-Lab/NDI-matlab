classdef TestStrainAssembly < matlab.unittest.TestCase
%TESTSTRAINASSEMBLY Unit tests for the V_eta openMINDS strain second pass
%   (pure struct logic; no database, schema, or MATLAB toolbox needed).
%
%   ndi.migrate.internal.strainAssembly turns each UNATTACHED `openminds`
%   document carrying an openMINDS Strain into a strain ENTITY (did-schema #88:
%   an `entity` of type `strain`) with its id PRESERVED, turns the Species /
%   GeneticStrainType FRAGMENT documents it references into ASSERTIONS about
%   the strain (`assertion` + the `term` value kind, `entity_id` = the strain),
%   and turns `backgroundStrain` into `derived_from` relations (strain ->
%   strain). Nothing is asserted of an organism -- these documents have no
%   subject. (V_eta_entity_composition_plan.md secs. 1, 4 and 5.)
%
%   The fixtures reproduce the real writer's shape
%   (origin/main:+ndi/+setup/+conv/+haley/doImport.m:70-89 and :696-706):
%   OP50 with a Species child and a `geneticStrainType` of 'wild type', and
%   OP50-GFP with the same Species and `backgroundStrain = OP50`. Child objects
%   become their own documents and the parent's field becomes an
%   `ndi://<childId>` string (openMINDSobj2struct.m), which is why this is a
%   second pass at all.
%
%   `fields` keys stay camelCase after migration: universalRenames snake-cases
%   only one level, and `fields` is nested inside the `openminds` block.
%   testSnakeCaseFieldKeysAlsoResolve pins the fallback anyway, per the
%   standing migrator lesson.
%
%   Run with:  runtests('ndi.unittest.migrate.TestStrainAssembly')
%
%   Fixtures/accessors are LOCAL FUNCTIONS below the classdef, as in
%   TestPathSPromotion.

    methods (Test)

        function testStrainEntityMintedWithIdPreserved(testCase)
            structs = haleyBacteria();
            [~, minted, report] = ndi.migrate.internal.strainAssembly(structs);

            testCase.verifyTrue(report.changed);
            testCase.verifyEqual(report.strains_seen, 2);
            testCase.verifyEqual(report.strains_assembled, 2);

            op50 = strainWithId(minted, 'op50_doc');
            testCase.verifyNotEmpty(op50);
            testCase.verifyEqual(op50.base.id, 'op50_doc');
            testCase.verifyEqual(op50.document_class.class_name, 'entity');
            testCase.verifyEqual(op50.document_class.schema_version, 'V_eta');
            supers = {op50.document_class.superclasses.class_name};
            testCase.verifyEqual(supers, {'base'});
            testCase.verifyTrue(ndi.v2.vocabIs('entity_type', op50.entity.type, 'strain'));
            testCase.verifyEqual(op50.entity.name, 'Escherichia coli OP50');
            testCase.verifyEqual(op50.entity.description, 'as the source gives it');
            testCase.verifyFalse(isfield(op50, 'strain'));
            testCase.verifyFalse(isfield(op50.base, 'name'), ...
                'V_eta documents never write base.name (#73 item 54)');
        end

        function testSpeciesFragmentBecomesAnAssertion(testCase)
            structs = haleyBacteria();
            [~, minted, ~] = ndi.migrate.internal.strainAssembly(structs);
            a = assertionAbout(minted, 'op50_doc', 'Species');
            testCase.verifyNumElements(a, 1);
            a = a{1};
            testCase.verifyEqual(a.document_class.class_name, 'assertion');
            supers = {a.document_class.superclasses.class_name};
            testCase.verifyEqual(supers, {'statement', 'base', 'term', 'value', 'data'});
            testCase.verifyEqual(a.statement.variable.node, 'NCIT:C45293');
            testCase.verifyEqual(a.term.value.node, 'NCBITaxon:562');
            testCase.verifyEqual(a.term.value.name, 'Escherichia coli');
            testCase.verifyEqual(depValue(a, 'entity_id'), 'op50_doc');
            testCase.verifyEmpty(depValue(a, 'subject_id'));
        end

        function testInlineGeneticStrainTypeIsAccepted(testCase)
            structs = haleyBacteria();
            [~, minted, ~] = ndi.migrate.internal.strainAssembly(structs);
            a = assertionAbout(minted, 'op50_doc', 'genetic strain type');
            testCase.verifyNumElements(a, 1);
            testCase.verifyEqual(a{1}.statement.variable.node, 'EMPTY:0000347');
            testCase.verifyEqual(a{1}.term.value.name, 'wild type');
            testCase.verifyEqual(a{1}.term.value.node, '');
        end

        function testReferencedGeneticStrainTypeFragmentIsAccepted(testCase)
            structs = haleyBacteria();
            [~, minted, ~] = ndi.migrate.internal.strainAssembly(structs);
            a = assertionAbout(minted, 'op50gfp_doc', 'genetic strain type');
            testCase.verifyNumElements(a, 1);
            testCase.verifyEqual(a{1}.term.value.name, 'transgenic');
            testCase.verifyEqual(a{1}.term.value.node, 'openminds:transgenic');
        end

        function testPedigreeBecomesDerivedFromRelation(testCase)
            structs = haleyBacteria();
            [~, minted, report] = ndi.migrate.internal.strainAssembly(structs);
            r = relationsFrom(minted, 'op50gfp_doc');
            testCase.verifyNumElements(r, 1);
            testCase.verifyEqual(r{1}.document_class.class_name, 'directed_relation');
            testCase.verifyEqual(depValue(r{1}, 'parent_id'), 'op50_doc');
            testCase.verifyTrue(ndi.v2.vocabIs('relation', r{1}.directed_relation.relation, 'derived_from'));
            testCase.verifyEqual(r{1}.directed_relation.relation.node, ndi.v2.vocabTerm('relation', 'derived_from').node);   % [derived from general]
            testCase.verifyTrue(ndi.v2.vocabIs('relation', r{1}.directed_relation.relation, 'derived_from'));
            testCase.verifyEqual(report.background_edges, 1);
            testCase.verifyEqual(report.background_unresolved, 0);
            testCase.verifyEmpty(relationsFrom(minted, 'op50_doc'));
            gfp = strainWithId(minted, 'op50gfp_doc');
            testCase.verifyEmpty(depValue(gfp, 'background_strain_1'));
        end

        function testTwoParentCrossGetsTwoRelations(testCase)
            structs = twoParentCross();
            [~, minted, report] = ndi.migrate.internal.strainAssembly(structs);
            r = relationsFrom(minted, 'cross_doc');
            testCase.verifyNumElements(r, 2);
            testCase.verifyEqual(depValue(r{1}, 'parent_id'), 'parent_a_doc');
            testCase.verifyEqual(depValue(r{2}, 'parent_id'), 'parent_b_doc');
            testCase.verifyEqual(report.background_edges, 2);
        end

        function testUnresolvableParentLeavesTheChildAsV1(testCase)
            % INVERTED 2026-10-25 (was testUnresolvableParentProducesNoRelation:
            % the child was assembled and its backgroundStrain written
            % nowhere, counted background_unresolved). [generic stage is
            % lossless] (Jess Haley): the child is left as passthrough.
            structs = haleyBacteria();
            structs = dropId(structs, 'op50_doc');     % the pedigree target
            [kept, minted, report] = ndi.migrate.internal.strainAssembly(structs);
            testCase.verifyEmpty(relationsFrom(minted, 'op50gfp_doc'));
            testCase.verifyEmpty(strainWithId(minted, 'op50gfp_doc'));
            testCase.verifyTrue(anyId(kept, 'op50gfp_doc'));
            testCase.verifyEqual(report.background_edges, 0);
            testCase.verifyEqual(report.background_unresolved, 0);
            testCase.verifyEqual(report.strains_unplaced, 1);
        end

        function testAStrainFieldThePassDoesNotWriteLeavesItAsV1(testCase)
            % [generic stage is lossless] (Jess Haley, 2026-10-25, audit
            % item 2): breedingType, stockNumber, diseaseModel, lookupLabel,
            % digitalIdentifier, alternateIdentifier have no place; a strain
            % stating one is left as passthrough, and so is every strain
            % whose background it is.
            structs = haleyBacteria();
            for k = 1:numel(structs)
                if strcmp(structs{k}.base.id, 'op50_doc')
                    structs{k}.openminds.fields.stockNumber = 'CGC-OP50';
                end
            end
            [kept, minted, report] = ndi.migrate.internal.strainAssembly(structs);
            testCase.verifyEmpty(strainWithId(minted, 'op50_doc'));
            testCase.verifyEmpty(strainWithId(minted, 'op50gfp_doc'), ...
                'its background is not assembled, so neither is the child');
            testCase.verifyTrue(anyId(kept, 'op50_doc'));
            testCase.verifyEqual(report.strains_unplaced, 2);
            testCase.verifyTrue(any(contains(report.incomplete_reasons, 'stockNumber')));
        end

        function testGlobalIdentifierIsACurie(testCase)
            structs = haleyBacteria();
            [~, minted, ~] = ndi.migrate.internal.strainAssembly(structs);
            op50 = strainWithId(minted, 'op50_doc');
            testCase.verifyEqual(op50.entity.global_identifier, {'NCBITaxon:637912'});
            % Bioregistry has no `wbstrain` (V_eta_entity_composition_plan.md
            % sec. 6): a WormBase strain id is `WormBase:WBStrain<digits>`.
            gfp = strainWithId(minted, 'op50gfp_doc');
            testCase.verifyEqual(gfp.entity.global_identifier, {'WormBase:WBStrain00041972'});
        end

        function testIdentifierlessStrainStillAssembles(testCase)
            structs = {strainDoc('bare_doc', 'OTR-IRES-Cre', 'species_doc', ...
                'transgenic', '', {}), speciesDoc('species_doc')};
            [~, minted, report] = ndi.migrate.internal.strainAssembly(structs);
            testCase.verifyEqual(report.strains_assembled, 1);
            e = strainWithId(minted, 'bare_doc');
            testCase.verifyFalse(isfield(e.entity, 'global_identifier'));
        end

        function testFragmentsAreConsumedAndSourcesReplaced(testCase)
            structs = haleyBacteria();
            [kept, ~, report] = ndi.migrate.internal.strainAssembly(structs);
            testCase.verifyEqual(report.fragments_seen, 2);
            % UPDATED 2026-10-25 ([generic stage is lossless], Jess Haley): the
            % Species fragment also states a definition and a synonym, which
            % the strain's Species term does not write, so it is KEPT (carried
            % as v1); the GeneticStrainType fragment is fully placed and goes.
            testCase.verifyEqual(report.fragments_consumed, 1);
            testCase.verifyEqual(report.fragments_retained, 1);
            testCase.verifyTrue(anyId(kept, 'species_doc'));
            testCase.verifyFalse(anyId(kept, 'gst_doc'));
            testCase.verifyFalse(anyId(kept, 'op50_doc'), 'the strains are replaced');
        end

        function testFragmentSharedWithAnUnassembledStrainIsRetained(testCase)
            structs = haleyBacteria();
            broken = strainDoc('broken_doc', '', 'species_doc', 'wild type', '', {});
            structs{end+1} = broken;

            [kept, ~, report] = ndi.migrate.internal.strainAssembly(structs);
            testCase.verifyEqual(report.strains_incomplete, 1);
            testCase.verifyEqual(report.fragments_consumed, 1);   % the GST one
            testCase.verifyEqual(report.fragments_retained, 1);   % the Species one
            testCase.verifyTrue(anyId(kept, 'species_doc'));
            testCase.verifyTrue(anyId(kept, 'broken_doc'));
        end

        function testNamelessStrainPassesThroughUntouched(testCase)
            % a strain entity requires `name` (entity_type_bindings), so a
            % Strain without one is left as the v1 document
            structs = {strainDoc('no_name_doc', '', '', 'wildtype', '', {})};
            [kept, minted, report] = ndi.migrate.internal.strainAssembly(structs);
            testCase.verifyFalse(report.changed);
            testCase.verifyEmpty(minted);
            testCase.verifyEqual(report.strains_incomplete, 1);
            testCase.verifyEqual(numel(report.incomplete_reasons), 1);
            testCase.verifyTrue(anyId(kept, 'no_name_doc'));
        end

        function testStrainWithoutSpeciesAssemblesWithoutASpeciesAssertion(testCase)
            % species was a required FIELD of the pre-#88 `strain` class; on
            % #88 it is an assertion, so its absence is counted, not refused
            structs = {strainDoc('no_species_doc', 'X', '', 'wildtype', '', {})};
            [~, minted, report] = ndi.migrate.internal.strainAssembly(structs);
            testCase.verifyEqual(report.strains_assembled, 1);
            testCase.verifyEqual(report.species_missing, 1);
            testCase.verifyEqual(report.genetic_strain_type_missing, 0);
            testCase.verifyEmpty(assertionAbout(minted, 'no_species_doc', 'Species'));
            testCase.verifyNumElements( ...
                assertionAbout(minted, 'no_species_doc', 'genetic strain type'), 1);
        end

        function testOtherStrainFieldsBecomeAssertions(testCase)
            f = struct('name', 'N2', 'phenotype', 'normal', ...
                'laboratoryCode', 'CGC', 'synonym', {{'Bristol', 'wild isolate'}}, ...
                'geneticStrainType', 'wild type');
            structs = {openmindsDoc('n2_doc', 'openminds.core.research.Strain', ...
                'https://openminds.om-i.org/types/Strain', f, {})};
            [~, minted, report] = ndi.migrate.internal.strainAssembly(structs);
            p = assertionAbout(minted, 'n2_doc', 'phenotype');
            testCase.verifyNumElements(p, 1);
            testCase.verifyEqual(p{1}.term.value.name, 'normal');
            l = assertionAbout(minted, 'n2_doc', 'laboratory code');
            testCase.verifyNumElements(l, 1);
            testCase.verifyEqual(l{1}.document_class.superclasses(3).class_name, 'text');
            testCase.verifyEqual(l{1}.text.value.text, 'CGC');
            y = assertionAbout(minted, 'n2_doc', 'synonym');
            testCase.verifyNumElements(y, 1);
            testCase.verifyEqual({y{1}.text.value.text}, {'Bristol', 'wild isolate'});
            testCase.verifyEqual(report.assertions_minted, 4);
        end

        function testNothingIsSaidAboutAnOrganism(testCase)
            structs = haleyBacteria();
            [~, minted, ~] = ndi.migrate.internal.strainAssembly(structs);
            strainIds = {'op50_doc', 'op50gfp_doc'};
            for k = 1:numel(minted)
                testCase.verifyEmpty(depValue(minted{k}, 'subject_id'));
                if strcmp(minted{k}.document_class.class_name, 'assertion')
                    testCase.verifyTrue(any(strcmp(depValue(minted{k}, 'entity_id'), strainIds)));
                end
            end
        end

        function testSnakeCaseFieldKeysAlsoResolve(testCase)
            structs = haleyBacteria();
            for k = 1:numel(structs)
                structs{k} = snakeifyFields(structs{k});
            end
            [~, minted, report] = ndi.migrate.internal.strainAssembly(structs);
            testCase.verifyEqual(report.strains_assembled, 2);
            r = relationsFrom(minted, 'op50gfp_doc');
            testCase.verifyNumElements(r, 1);
            testCase.verifyEqual(depValue(r{1}, 'parent_id'), 'op50_doc');
        end

        function testNonStrainOpenmindsIsLeftAlone(testCase)
            structs = {openmindsDoc('ds_doc', 'openminds.core.products.Dataset', ...
                'https://openminds.om-i.org/types/Dataset', struct('fullName', 'D'), {})};
            [kept, minted, report] = ndi.migrate.internal.strainAssembly(structs);
            testCase.verifyFalse(report.changed);
            testCase.verifyEmpty(minted);
            testCase.verifyEqual(report.openminds_other, 1);
            testCase.verifyEqual(numel(kept), 1);
        end

        function testInADatasetEachStrainIsOneEntityAtTheDatasetLevel(testCase)
            % Decided by Jess Haley, 2026-10-21: "When a dataset is migrated,
            % shared entities (strains, ...) move to the dataset level as in
            % native V2 imports [...]: one entity per distinct thing in the
            % dataset's database, with session documents pointing at it and
            % merged-away ids remapped so every link still resolves". Haley
            % writes OP50 and OP50-GFP once per session; with a dataset in the
            % batch the two copies merge onto the smallest id, and a table row
            % in session 2 that named session 2's OP50 names the survivor.
            row = struct('document_class', dc('ontology_table_row', {'base'}), ...
                'depends_on', dep('document_id', 'op50_doc_2'), ...
                'base', base('row_2'), ...
                'ontology_table_row', struct('values', {{'op50_doc_2', 'x'}}));
            [kept, minted, report] = ndi.migrate.internal.strainAssembly( ...
                [haleyBacteriaIn('', 'sess_1'), haleyBacteriaIn('_2', 'sess_2'), ...
                 {datasetEntity('ds_1'), row}]);
            testCase.verifyEqual(report.scope, 'dataset');
            testCase.verifyEqual(report.strains_assembled, 4);
            testCase.verifyEqual(report.strains_merged_away, 2);
            testCase.verifyEqual(report.cross_session_groups, 2);
            testCase.verifyEqual(report.cross_session_collapsible, 2);
            testCase.verifyNotEmpty(strainWithId(minted, 'op50_doc'));
            testCase.verifyNotEmpty(strainWithId(minted, 'op50gfp_doc'));
            testCase.verifyEmpty(strainWithId(minted, 'op50_doc_2'));
            testCase.verifyEmpty(strainWithId(minted, 'op50gfp_doc_2'));
            % one derived_from, survivor to survivor
            r = relationsFrom(minted, 'op50gfp_doc');
            testCase.verifyNumElements(r, 1);
            testCase.verifyEqual(depValue(r{1}, 'parent_id'), 'op50_doc');
            testCase.verifyEmpty(relationsFrom(minted, 'op50gfp_doc_2'));
            % stored with the dataset
            for k = 1:numel(minted)
                testCase.verifyEqual(ndi.v2.sessionIdOf(minted{k}), 'ds_1');
            end
            % the remap: the edge AND the table cell
            out = kept{cellfun(@(b) strcmp(b.base.id, 'row_2'), kept)};
            testCase.verifyEqual(depValue(out, 'document_id'), 'op50_doc');
            testCase.verifyEqual(out.ontology_table_row.values{1}, 'op50_doc');
            testCase.verifyEqual(report.references_remapped, 2);
        end

        function testALoneSessionKeepsEveryStrainCopy(testCase)
            % "a lone session with no dataset keeps them in the session"
            [~, minted, report] = ndi.migrate.internal.strainAssembly( ...
                [haleyBacteriaIn('', 'sess_1'), haleyBacteriaIn('_2', 'sess_2')]);
            testCase.verifyEqual(report.scope, 'session');
            testCase.verifyEqual(report.strains_merged_away, 0);
            testCase.verifyEqual(report.cross_session_collapsible, 2);
            testCase.verifyNotEmpty(strainWithId(minted, 'op50_doc_2'));
            testCase.verifyEqual(ndi.v2.sessionIdOf(strainWithId(minted, 'op50_doc_2')), 'sess_2');
        end

        function testReportStatesItsDenominator(testCase)
            structs = haleyBacteria();
            [~, ~, report] = ndi.migrate.internal.strainAssembly(structs);
            testCase.verifyEqual(report.documents_inspected, numel(structs));
            testCase.verifyEqual(report.openminds_seen, numel(structs));
            testCase.verifyEqual(report.strains_seen, ...
                report.strains_assembled + report.strains_incomplete);
        end

        function testEmptyCorpusIsInertAndStillReports(testCase)
            [kept, minted, report] = ndi.migrate.internal.strainAssembly({});
            testCase.verifyEmpty(kept);
            testCase.verifyEmpty(minted);
            testCase.verifyFalse(report.changed);
            testCase.verifyEqual(report.documents_inspected, 0);
        end

    end
end


% ===================== fixtures + accessors (test-only) ====================

function s = haleyBacteria()
% haley/doImport.m: OP50 (Species child, inline 'wild type') and OP50-GFP
% (same Species, a GeneticStrainType child document, backgroundStrain = OP50).
s = { ...
    strainDoc('op50_doc', 'Escherichia coli OP50', 'species_doc', ...
        'wild type', 'NCBITaxon:637912', {}), ...
    strainDoc('op50gfp_doc', 'OP50-GFP', 'species_doc', ...
        'ndi://gst_doc', 'WBStrain:00041972', {'ndi://op50_doc'}), ...
    speciesDoc('species_doc'), ...
    gstDoc('gst_doc', 'transgenic', 'openminds:transgenic')};
end

function s = haleyBacteriaIn(sfx, sess)
% haleyBacteria with every id suffixed by SFX and stored in session SESS -- the
% per-session copy haley/doImport.m writes.
s = { ...
    strainDoc(['op50_doc' sfx], 'Escherichia coli OP50', ['species_doc' sfx], ...
        'wild type', 'NCBITaxon:637912', {}), ...
    strainDoc(['op50gfp_doc' sfx], 'OP50-GFP', ['species_doc' sfx], ...
        ['ndi://gst_doc' sfx], 'WBStrain:00041972', {['ndi://op50_doc' sfx]}), ...
    speciesDoc(['species_doc' sfx]), ...
    gstDoc(['gst_doc' sfx], 'transgenic', 'openminds:transgenic')};
for k = 1:numel(s)
    s{k}.base.session_id = sess;
end
end

function d = datasetEntity(id)
%DATASETENTITY A did-schema #88 `entity` of type dataset (its id is the
%   dataset's session id).
d = struct('document_class', dc('entity', {'base'}), ...
    'depends_on', struct('name', {}, 'value', {}), ...
    'base', struct('id', id, 'session_id', id, 'name', 'n', ...
        'datestamp', '2024-01-01T00:00:00.000Z'), ...
    'entity', struct('type', struct('node', '', 'name', 'dataset'), 'name', 'ds'));
end

function s = twoParentCross()
s = { ...
    strainDoc('parent_a_doc', 'ArcCreERT2', 'species_doc', 'transgenic', ...
        'EMPTY:00000284', {}), ...
    strainDoc('parent_b_doc', 'eYFP', 'species_doc', 'transgenic', ...
        'EMPTY:00000287', {}), ...
    strainDoc('cross_doc', 'ArcCreERT2 x eYFP', 'species_doc', 'transgenic', ...
        'EMPTY:00000288', {'ndi://parent_a_doc', 'ndi://parent_b_doc'}), ...
    speciesDoc('species_doc')};
end

function b = strainDoc(id, name, speciesRefId, gst, ontologyId, backgroundRefs)
% GST is either an inline char ('wild type') or an 'ndi://<id>' reference.
f = struct();
if ~isempty(name);        f.name = name;                     end
if ~isempty(speciesRefId); f.species = {['ndi://' speciesRefId]}; end
if ~isempty(gst);         f.geneticStrainType = gst;         end
if ~isempty(ontologyId);  f.ontologyIdentifier = ontologyId; end
if ~isempty(backgroundRefs); f.backgroundStrain = backgroundRefs; end
f.description = 'as the source gives it';
refs = {};
if ~isempty(speciesRefId); refs{end+1} = speciesRefId; end
if ischar(gst) && startsWith(gst, 'ndi://'); refs{end+1} = gst(7:end); end
for k = 1:numel(backgroundRefs); refs{end+1} = backgroundRefs{k}(7:end); end %#ok<AGROW>
b = openmindsDoc(id, 'openminds.core.research.Strain', ...
    'https://openminds.om-i.org/types/Strain', f, refs);
end

function b = speciesDoc(id)
f = struct('name', 'Escherichia coli', ...
    'preferredOntologyIdentifier', 'NCBITaxon:562', ...
    'definition', 'Escherichia coli is a species of bacteria.', ...
    'synonym', 'E. coli');
b = openmindsDoc(id, 'openminds.controlledterms.Species', ...
    'https://openminds.om-i.org/types/Species', f, {});
end

function b = gstDoc(id, name, node)
f = struct('name', name, 'preferredOntologyIdentifier', node);
b = openmindsDoc(id, 'openminds.controlledterms.GeneticStrainType', ...
    'https://openminds.om-i.org/types/GeneticStrainType', f, {});
end

function b = openmindsDoc(id, matlabType, omType, fields, childRefs)
b = struct();
b.document_class = dc('openminds', {'base'});
% openMINDSobj2ndi_document appends `openminds_1..n` for each ndi:// child, or a
% single EMPTY `openminds` dep for a leaf with no children.
if isempty(childRefs)
    b.depends_on = dep('openminds', '');
else
    deps = struct('name', {}, 'value', {});
    for k = 1:numel(childRefs)
        deps(end+1) = dep(sprintf('openminds_%d', k), childRefs{k}); %#ok<AGROW>
    end
    b.depends_on = deps;
end
b.base = base(id);
b.openminds = struct('openminds_type', omType, 'matlab_type', matlabType, ...
    'openminds_id', ['https://openminds.om-i.org/instances/' id], ...
    'fields', fields);
end

function s = snakeifyFields(s)
% Rewrite the camelCase keys inside `openminds.fields` to snake_case, to
% exercise the fallback reads.
map = {'geneticStrainType', 'genetic_strain_type'; ...
       'backgroundStrain',  'background_strain'; ...
       'ontologyIdentifier', 'ontology_identifier'; ...
       'preferredOntologyIdentifier', 'preferred_ontology_identifier'};
if ~isfield(s, 'openminds') || ~isstruct(s.openminds) ...
        || ~isfield(s.openminds, 'fields'); return; end
f = s.openminds.fields;
for k = 1:size(map, 1)
    if isfield(f, map{k,1})
        f.(map{k,2}) = f.(map{k,1});
        f = rmfield(f, map{k,1});
    end
end
s.openminds.fields = f;
end

function x = dc(name, supers)
sc = struct('class_name', {}, 'class_version', {});
for i = 1:numel(supers)
    sc(i) = struct('class_name', supers{i}, 'class_version', '1.0.0');
end
x = struct('class_name', name, 'class_version', '1.0.0', ...
    'superclasses', sc, 'schema_version', 'V_eta');
end

function x = dep(name, value)
x = struct('name', name, 'value', value);
end

function x = base(id)
x = struct('id', id, 'session_id', 'sess_1', 'name', 'n', ...
    'datestamp', '2024-01-01T00:00:00.000Z');
end

function b = strainWithId(bodies, id)
b = [];
for k = 1:numel(bodies)
    if strcmp(bodies{k}.document_class.class_name, 'entity') ...
            && ndi.v2.vocabIs('entity_type', bodies{k}.entity.type, 'strain') ...
            && strcmp(bodies{k}.base.id, id)
        b = bodies{k}; return;
    end
end
end

function out = assertionAbout(bodies, entityId, variableName)
out = {};
for k = 1:numel(bodies)
    b = bodies{k};
    if strcmp(b.document_class.class_name, 'assertion') ...
            && strcmp(depValue(b, 'entity_id'), entityId) ...
            && strcmp(b.statement.variable.name, variableName)
        out{end+1} = b; %#ok<AGROW>
    end
end
end

function out = relationsFrom(bodies, childId)
out = {};
for k = 1:numel(bodies)
    b = bodies{k};
    if strcmp(b.document_class.class_name, 'directed_relation') ...
            && strcmp(depValue(b, 'child_id'), childId)
        out{end+1} = b; %#ok<AGROW>
    end
end
end

function tf = anyClass(bodies, className)
tf = false;
for k = 1:numel(bodies)
    if strcmp(bodies{k}.document_class.class_name, className)
        tf = true; return;
    end
end
end

function tf = anyId(bodies, id)
tf = false;
for k = 1:numel(bodies)
    if strcmp(bodies{k}.base.id, id); tf = true; return; end
end
end

function bodies = dropId(bodies, id)
out = {};
for k = 1:numel(bodies)
    if strcmp(bodies{k}.base.id, id); continue; end
    out{end+1} = bodies{k}; %#ok<AGROW>
end
bodies = out;
end

function v = depValue(s, name)
v = '';
if ~isfield(s, 'depends_on') || isempty(s.depends_on); return; end
for k = 1:numel(s.depends_on)
    if strcmp(s.depends_on(k).name, name)
        v = s.depends_on(k).value; return;
    end
end
end
