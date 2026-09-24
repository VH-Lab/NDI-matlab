classdef TestStrainAssembly < matlab.unittest.TestCase
%TESTSTRAINASSEMBLY Unit tests for the V_eta openMINDS strain second pass
%   (pure struct logic; no database, schema, or MATLAB toolbox needed).
%
%   ndi.migrate.internal.strainAssembly turns each UNATTACHED `openminds`
%   document carrying an openMINDS Strain into a `strain` ENTITY with its id
%   PRESERVED, consuming the Species / GeneticStrainType FRAGMENT documents it
%   references into the strain's `species` and `genetic_strain_type` fields and
%   wiring `backgroundStrain` into the recursive `background_strain_#` edge. No
%   `term_assertion` is emitted -- these documents have no subject.
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
%   only one level (universalRenames.m:351-367, `snakeCaseBlockFields` walks
%   `fieldnames(block)` and stops), and `fields` is nested inside the
%   `openminds` block. testSnakeCaseFieldKeysAlsoResolve pins the fallback
%   anyway, per the standing migrator lesson.
%
%   Run with:  runtests('ndi.unittest.migrate.TestStrainAssembly')
%
%   Fixtures/accessors are LOCAL FUNCTIONS below the classdef, as in
%   TestPathSPromotion.

    methods (Test)

        function testStrainMintedWithIdPreserved(testCase)
            structs = haleyBacteria();
            [~, minted, report] = ndi.migrate.internal.strainAssembly(structs);

            testCase.verifyTrue(report.changed);
            testCase.verifyEqual(report.strains_seen, 2);
            testCase.verifyEqual(report.strains_assembled, 2);

            op50 = strainWithId(minted, 'op50_doc');
            testCase.verifyNotEmpty(op50);
            % ID PRESERVATION IS LOAD-BEARING: ontologyTableRow's
            % `bacteriaStrain` cell holds this id as a plain string, so nothing
            % would flag a re-mint.
            testCase.verifyEqual(op50.base.id, 'op50_doc');
            testCase.verifyEqual(op50.document_class.class_name, 'strain');
            testCase.verifyEqual(op50.document_class.schema_version, 'V_eta');
            supers = {op50.document_class.superclasses.class_name};
            testCase.verifyTrue(any(strcmp(supers, 'entity')));
            testCase.verifyEqual(op50.strain.name, 'Escherichia coli OP50');
        end

        function testSpeciesFragmentBecomesAField(testCase)
            structs = haleyBacteria();
            [~, minted, ~] = ndi.migrate.internal.strainAssembly(structs);
            op50 = strainWithId(minted, 'op50_doc');
            testCase.verifyEqual(op50.strain.species.node, 'NCBITaxon:562');
            testCase.verifyEqual(op50.strain.species.name, 'Escherichia coli');
        end

        function testInlineGeneticStrainTypeIsAccepted(testCase)
            % The writer ASSIGNS A CHAR ('wild type'). Whether openMINDS
            % coerces it into its own document was never read, so both shapes
            % must work; here it is inline, so there is no CURIE and the node
            % stays empty (normalising 'wild type' vs 'wildtype' is the T8
            % binding job, not this pass's).
            structs = haleyBacteria();
            [~, minted, ~] = ndi.migrate.internal.strainAssembly(structs);
            op50 = strainWithId(minted, 'op50_doc');
            testCase.verifyEqual(op50.strain.genetic_strain_type.name, 'wild type');
            testCase.verifyEqual(op50.strain.genetic_strain_type.node, '');
        end

        function testReferencedGeneticStrainTypeFragmentIsAccepted(testCase)
            structs = haleyBacteria();
            [~, minted, ~] = ndi.migrate.internal.strainAssembly(structs);
            gfp = strainWithId(minted, 'op50gfp_doc');
            testCase.verifyEqual(gfp.strain.genetic_strain_type.name, 'transgenic');
            testCase.verifyEqual(gfp.strain.genetic_strain_type.node, ...
                'openminds:transgenic');
        end

        function testPedigreeBecomesBackgroundStrainEdge(testCase)
            structs = haleyBacteria();
            [~, minted, report] = ndi.migrate.internal.strainAssembly(structs);
            gfp = strainWithId(minted, 'op50gfp_doc');
            testCase.verifyEqual(depValue(gfp, 'background_strain_1'), 'op50_doc');
            testCase.verifyEqual(report.background_edges, 1);
            testCase.verifyEqual(report.background_unresolved, 0);
            % the root strain has no pedigree edge at all (not an empty one)
            op50 = strainWithId(minted, 'op50_doc');
            testCase.verifyEmpty(depValue(op50, 'background_strain_1'));
            testCase.verifyEmpty(op50.depends_on);
        end

        function testTwoParentCrossGetsTwoEdges(testCase)
            % ArcCreERT2 x eYFP is production data (hunsberger
            % SubjectInformationCreator.m:70-107): backgroundStrain is an ARRAY.
            structs = twoParentCross();
            [~, minted, report] = ndi.migrate.internal.strainAssembly(structs);
            cross = strainWithId(minted, 'cross_doc');
            testCase.verifyEqual(depValue(cross, 'background_strain_1'), 'parent_a_doc');
            testCase.verifyEqual(depValue(cross, 'background_strain_2'), 'parent_b_doc');
            testCase.verifyEqual(report.background_edges, 2);
            testCase.verifyEqual(report.background_over_max, 0);
        end

        function testUnresolvableParentProducesNoEmptyEdge(testCase)
            structs = haleyBacteria();
            structs = dropId(structs, 'op50_doc');     % the pedigree target
            [~, minted, report] = ndi.migrate.internal.strainAssembly(structs);
            gfp = strainWithId(minted, 'op50gfp_doc');
            testCase.verifyEmpty(gfp.depends_on);
            testCase.verifyEqual(report.background_edges, 0);
            testCase.verifyEqual(report.background_unresolved, 1);
        end

        function testGlobalIdentifierIsSplitOnScheme(testCase)
            structs = haleyBacteria();
            [~, minted, ~] = ndi.migrate.internal.strainAssembly(structs);
            op50 = strainWithId(minted, 'op50_doc');
            testCase.verifyEqual(numel(op50.entity.global_identifier), 1);
            testCase.verifyEqual(op50.entity.global_identifier(1).scheme, 'NCBITaxon');
            testCase.verifyEqual(op50.entity.global_identifier(1).value, '637912');
            gfp = strainWithId(minted, 'op50gfp_doc');
            testCase.verifyEqual(gfp.entity.global_identifier(1).scheme, 'WBStrain');
            testCase.verifyEqual(gfp.entity.global_identifier(1).value, '00041972');
        end

        function testIdentifierlessStrainStillAssembles(testCase)
            % 115 strains carry no identifier at all (dabrowska sets only
            % `name`); the global_identifier array is simply empty.
            structs = {strainDoc('bare_doc', 'OTR-IRES-Cre', 'species_doc', ...
                'transgenic', '', {}), speciesDoc('species_doc')};
            [~, minted, report] = ndi.migrate.internal.strainAssembly(structs);
            testCase.verifyEqual(report.strains_assembled, 1);
            testCase.verifyEmpty(minted{1}.entity.global_identifier);
        end

        function testFragmentsAreConsumedAndSourcesReplaced(testCase)
            structs = haleyBacteria();
            [kept, ~, report] = ndi.migrate.internal.strainAssembly(structs);
            % the two Strain documents and the two fragments all leave `kept`;
            % the Strains come back as `strain` documents with the same ids.
            testCase.verifyEqual(report.fragments_seen, 2);
            testCase.verifyEqual(report.fragments_consumed, 2);
            testCase.verifyEqual(report.fragments_retained, 0);
            testCase.verifyFalse(anyClass(kept, 'openminds'));
        end

        function testFragmentSharedWithAnUnassembledStrainIsRetained(testCase)
            % A fragment may only go when EVERY document that references it is
            % a strain this pass assembled -- otherwise the surviving
            % passthrough's `openminds_#` edge would dangle.
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

        function testIncompleteStrainPassesThroughUntouched(testCase)
            % `name`, `species` and `genetic_strain_type` are all
            % mustBeNonEmpty on strain.json. A Strain missing one is left as a
            % passthrough rather than emitted with a vacuous required field.
            structs = {strainDoc('no_species_doc', 'X', '', 'wildtype', '', {})};
            [kept, minted, report] = ndi.migrate.internal.strainAssembly(structs);
            testCase.verifyFalse(report.changed);
            testCase.verifyEmpty(minted);
            testCase.verifyEqual(report.strains_incomplete, 1);
            testCase.verifyEqual(numel(report.incomplete_reasons), 1);
            testCase.verifyTrue(anyId(kept, 'no_species_doc'));
        end

        function testNoTermAssertionIsEmitted(testCase)
            % These documents carry no subject_id -- they are not assertions
            % about anybody. That is the whole reason `strain` is an entity.
            structs = haleyBacteria();
            [~, minted, ~] = ndi.migrate.internal.strainAssembly(structs);
            for k = 1:numel(minted)
                testCase.verifyEqual(minted{k}.document_class.class_name, 'strain');
                names = fieldnames(minted{k});
                testCase.verifyFalse(any(strcmp(names, 'term_assertion')));
                testCase.verifyEmpty(depValue(minted{k}, 'subject_id'));
            end
        end

        function testSnakeCaseFieldKeysAlsoResolve(testCase)
            % Standing migrator lesson: any nested sub-field a migrator reads
            % needs a snake+camelCase fallback.
            structs = haleyBacteria();
            for k = 1:numel(structs)
                structs{k} = snakeifyFields(structs{k});
            end
            [~, minted, report] = ndi.migrate.internal.strainAssembly(structs);
            testCase.verifyEqual(report.strains_assembled, 2);
            gfp = strainWithId(minted, 'op50gfp_doc');
            testCase.verifyEqual(depValue(gfp, 'background_strain_1'), 'op50_doc');
        end

        function testNonStrainOpenmindsIsLeftAlone(testCase)
            % Group B of Part 7 (Dataset / Person / Organization ...) is not
            % handled here; those documents are counted and left untouched.
            structs = {openmindsDoc('ds_doc', 'openminds.core.products.Dataset', ...
                'https://openminds.om-i.org/types/Dataset', struct('fullName', 'D'), {})};
            [kept, minted, report] = ndi.migrate.internal.strainAssembly(structs);
            testCase.verifyFalse(report.changed);
            testCase.verifyEmpty(minted);
            testCase.verifyEqual(report.openminds_other, 1);
            testCase.verifyEqual(numel(kept), 1);
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
    if strcmp(bodies{k}.document_class.class_name, 'strain') ...
            && strcmp(bodies{k}.base.id, id)
        b = bodies{k}; return;
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
