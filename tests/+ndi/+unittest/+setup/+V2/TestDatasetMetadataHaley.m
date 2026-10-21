classdef TestDatasetMetadataHaley < matlab.unittest.TestCase
%TESTDATASETMETADATAHALEY Stage 2 of the Haley V2 import, over its real spec.
%
%   Builds every dataset-level document from
%   +ndi/+setup/+conv/+haley/import_V2_spec.json with
%   ndi.setup.V2.datasetMetadata (which validates each one through
%   did2.build) and checks what came out: the counts, the links, and that
%   spec content with no V2 home is REPORTED rather than dropped.
%
%   Needs DID-matlab's did2.build and a V2 schema that has `study`,
%   `instance_of`, `awarded_to` and `directed_relation.roles`
%   (Waltham-Data-Science/did-schema PR #78). Without them every test is
%   FILTERED with a message, never passed; test-import-v2.yml runs this with
%   them and fails if anything was filtered.
%
%   UNVERIFIED: written without MATLAB; test-import-v2.yml is the first run.

    properties
        Spec
        Result
    end

    methods (TestClassSetup)
        function build(testCase)
            testCase.assumeTrue(~isempty(which('did2.build.document')), ...
                'did2.build (DID-matlab V2) is not on the path');
            schemaPath = getenv('DID_SCHEMA_PATH');
            testCase.assumeTrue(~isempty(schemaPath) && ...
                ndi.setup.V2.schemaHasClass('study', schemaPath), ...
                'DID_SCHEMA_PATH does not hold a V2 schema with `study` (did-schema PR #78)');
            specFile = fullfile(fileparts(which('ndi.setup.conv.haley.import_V2')), ...
                'import_V2_spec.json');
            testCase.Spec = jsondecode(fileread(specFile));
            testCase.Result = ndi.setup.V2.datasetMetadata(testCase.Spec, did.ido.unique_id());
        end
    end

    methods (Test)
        function testCountsFollowTheSpec(testCase)
            s = testCase.Spec;
            c = testCase.Result.census;
            n = @(cls) sum(c.count(strcmp(c.class, cls)));
            testCase.verifyEqual(n('organization'), numel(s.organizations));
            testCase.verifyEqual(n('person'), numel(s.people));
            testCase.verifyEqual(n('funding'), numel(s.funding));
            testCase.verifyEqual(n('study'), numel(s.studies));
            testCase.verifyEqual(n('strain'), numel(s.strains));
            testCase.verifyEqual(n('subject'), numel(s.instruments));
            testCase.verifyEqual(n('chemical'), numel(s.chemicals));
            testCase.verifyEqual(n('formulation'), numel(s.formulations));
            testCase.verifyEqual(n('dataset'), 1);
            % every strain has a source, so each adds one stock product
            testCase.verifyEqual(n('product'), numel(s.products) + numel(s.strains));
            % 47 before decision #56; + the media kitchen's suborganization_of
            % Salk + 6 recipes documented_by WormBook (5 since decision #86)
            if ndi.setup.V2.mergedEntities()
                % one entity class (2026-10-08): the entity fields become
                % assertions and relations, so these totals are a different
                % count, not a moved one. What must hold on either schema:
                % every document is an entity of a known type, a statement or
                % a relation.
                kinds = {'organization', 'person', 'funding', 'study', 'strain', ...
                    'subject', 'chemical', 'formulation', 'dataset', 'product', ...
                    'software', 'publication', 'protocol', 'directed_relation'};
                other = c(~ismember(c.class, kinds), :);
                testCase.verifyTrue(all(endsWith(other.class, ...
                    {'_assertion', '_observation', '_manipulation', '_calculation'})), ...
                    strjoin(other.class, ', '));
                testCase.verifyFalse(any(strcmp(c.class, 'web_resource')), ...
                    'web_resource retired: its URL is an identifier of what it names');
                return;
            end
            % 53 before decision #89; + suborganization_of for Sigma-Aldrich
            % (of EMD Millipore) and PixeLink (of Navitar); decision #90, + Alfa
            % Aesar's (of Thermo Fisher)
            testCase.verifyEqual(n('directed_relation'), 56, ...
                'relation count moved: re-derive it from the spec, do not bump it');
            % 133 before decision #56; + 3 organizations, 1 web resource,
            % 4 products, 20 chemicals, 9 formulations, 7 relations; + the
            % temperature probe (decision #59: an instrument with no product,
            % so no instance_of relation); + the lab's analysis package and
            % macOS, stage 10's run environment (decision #60); decision #86,
            % the potassium phosphate buffer from 231109_KPO4_stock: + Sigma-
            % Aldrich, 2 products, 2 chemicals, the 2 1 M stocks, - the
            % buffer's documented_by WormBook; decision #89, + 2 relations;
            % decision #90, the cholesterol stock as a recipe: + Alfa Aesar and
            % Decon Labs, their relation, 2 products, the stock formulation, and
            % cholesterol + ethanol as chemicals in place of the stock (+1);
            % decision #91, the MgSO4 and CaCl2 stocks as recipes: + 2 products
            % and 2 formulations, the weighed solids replacing the 1 M chemicals
            testCase.verifyEqual(numel(testCase.Result.documents), 199);
        end

        function testStudiesCanBeMintedApartFromTheRest(testCase)
            % import_V2 builds the studies in stage 3, beside the sessions
            % (decision #50): "exclude" + "only" together are "include".
            sid = did.ido.unique_id();
            datasetId = did.ido.unique_id();
            if ndi.v2.sessionIdIsEdge()
                % the dataset entity's id IS the dataset's session id
                % (V_eta_relation_inheritance_plan.md, 2026-10-20)
                datasetId = sid;
            end
            rest = ndi.setup.V2.datasetMetadata(testCase.Spec, sid, ...
                'DatasetId', datasetId, 'Studies', "exclude");
            studies = ndi.setup.V2.datasetMetadata(testCase.Spec, sid, ...
                'DatasetId', datasetId, 'Studies', "only");
            classOf = @(r) cellfun(@ndi.v2.leafName, r.documents, 'UniformOutput', false);
            testCase.verifyEqual(sum(strcmp(classOf(rest), 'study')), 0);
            testCase.verifyEqual(sum(strcmp(classOf(studies), 'study')), numel(testCase.Spec.studies));
            testCase.verifyEqual(numel(rest.documents) + numel(studies.documents), ...
                numel(testCase.Result.documents));
            % each study is filed under the dataset the other call built
            rel = studies.documents(strcmp(classOf(studies), 'directed_relation'));
            testCase.verifyEqual(numel(rel), numel(testCase.Spec.studies));
            for k = 1:numel(rel)
                dep = rel{k}.depends_on;
                testCase.verifyTrue(any(strcmp({dep.document_id}, datasetId)));
            end
            ds = rest.documents(strcmp(classOf(rest), 'dataset'));
            testCase.verifyEqual(ds{1}.base.id, datasetId);
            if ndi.v2.sessionIdIsEdge()
                % the dataset's id is known from the session id, so "only"
                % needs no 'DatasetId', and another id is refused
                alone = ndi.setup.V2.datasetMetadata(testCase.Spec, sid, 'Studies', "only");
                rel = alone.documents(strcmp(classOf(alone), 'directed_relation'));
                testCase.verifyTrue(all(cellfun(@(r) any(strcmp({r.depends_on.document_id}, sid)), rel)));
                testCase.verifyError(@() ndi.setup.V2.datasetMetadata(testCase.Spec, sid, ...
                    'DatasetId', did.ido.unique_id(), 'Studies', "only"), 'ndi:setup:V2:datasetId');
            else
                testCase.verifyError(@() ndi.setup.V2.datasetMetadata(testCase.Spec, sid, ...
                    'Studies', "only"), 'ndi:setup:V2:noDatasetId');
            end
        end

        function testEveryEdgeNamesABuiltDocument(testCase)
            docs = testCase.Result.documents;
            ids = cellfun(@(d) d.base.id, docs, 'UniformOutput', false);
            nEdges = 0;
            for k = 1:numel(docs)
                for e = 1:numel(docs{k}.depends_on)
                    nEdges = nEdges + 1;
                    testCase.verifyTrue(any(strcmp(docs{k}.depends_on(e).document_id, ids)), ...
                        sprintf('%s edge %s names no document built here', ...
                        docs{k}.document_class.class_name, docs{k}.depends_on(e).name));
                end
            end
            testCase.verifyGreaterThan(nEdges, 0, 'no edges were inspected');
        end

        function testAuthorsAreOrderedWithRoles(testCase)
            rels = relationsNamed(testCase.Result.documents, 'has_author');
            testCase.verifyEqual(numel(rels), 4);
            seq = cellfun(@(r) r.directed_relation.sequence, rels);
            testCase.verifyEqual(sort(seq), 1:4);
            first = rels{seq == 1};
            testCase.verifyEqual(parentOf(first), testCase.Result.ids('haley'));
            testCase.verifyEqual(numel(first.directed_relation.roles), 14);
            corr = rels(cellfun(@(r) any(strcmp({r.directed_relation.roles.name}, ...
                'corresponding author')), rels));
            testCase.verifyEqual(sort(cellfun(@parentOf, corr, 'UniformOutput', false)), ...
                sort({testCase.Result.ids('aoi'), testCase.Result.ids('chalasani')}));
        end

        function testRelationTermsAreCompletedFromTheirValueSet(testCase)
            % a study is filed under the dataset by included_in where the
            % schema binds it (schema:isPartOf; V_eta_relation_inheritance_plan.md,
            % 2026-10-20), by part_of (BFO:0000050) before
            name = ndi.v2.recordRelation();
            member = relationsNamed(testCase.Result.documents, name);
            testCase.verifyEqual(numel(member), numel(testCase.Spec.studies));
            % the prefix is BFO from 2026-10-19 (V_eta_prefix_spelling_plan.md) and
            % lowercase on a schema built between 2026-10-08 and then
            node = 'bfo:0000050';
            if strcmp(name, 'included_in')
                node = 'schema:ispartof';
                testCase.verifyEmpty(relationsNamed(testCase.Result.documents, 'part_of'), ...
                    'part_of is physical: no record is part_of another');
            end
            testCase.verifyEqual(lower(member{1}.directed_relation.relation.node), node);
        end

        function testStrainLineageAndStock(testCase)
            docs = testCase.Result.documents;
            gfp = docs{strcmp(cellfun(@(d) d.base.id, docs, 'UniformOutput', false), ...
                testCase.Result.ids('OP50-GFP'))};
            if ndi.setup.V2.mergedEntities()
                % one entity class: the background and the stock are relations
                from = relationsNamed(docs, 'derived_from');
                from = from(cellfun(@(r) any(strcmp({r.depends_on.document_id}, ...
                    testCase.Result.ids('OP50-GFP'))), from));
                testCase.verifyTrue(any(cellfun(@(r) strcmp(parentOf(r), ...
                    testCase.Result.ids('OP50')), from)), 'OP50-GFP derived_from OP50');
                if ndi.setup.V2.schemaHasRelation('distributed_as')
                    % decision #17: the stock is `distributed_as`, the background
                    % alone is `derived_from`
                    testCase.verifyEqual(numel(from), 1, 'its background only');
                    stock = relationsNamed(docs, 'distributed_as');
                    stock = stock(cellfun(@(r) any(strcmp({r.depends_on.document_id}, ...
                        testCase.Result.ids('OP50-GFP'))), stock));
                    testCase.verifyNumElements(stock, 1, 'OP50-GFP distributed_as its stock');
                else
                    testCase.verifyEqual(numel(from), 2, 'its background and its stock');
                end
                return;
            end
            bg = gfp.depends_on(strcmp({gfp.depends_on.name}, 'background_strain_id'));
            testCase.verifyEqual({bg.document_id}, {testCase.Result.ids('OP50')});
            testCase.verifyTrue(any(strcmp({gfp.depends_on.name}, 'product_id')));
        end

        function testAStrainsGenotypeIsAnAssertion(testCase)
            % decision #117: on one entity class a strain's genotype is a text
            % assertion about the strain, variable NCIT:C16631 Genotype, and its
            % description keeps the spec's prose only; a `strain` class (no
            % genotype field) keeps it in the description
            docs = testCase.Result.documents;
            pr = testCase.Result.ids('PR811');
            ent = docs{cellfun(@(d) strcmp(d.base.id, pr), docs)};
            desc = char(ndi.v2.blockOf(ent, 'strain', 'description', ''));
            if ~ndi.setup.V2.mergedEntities()
                testCase.verifySubstring(desc, 'osm-6(p811) V');
                return;
            end
            testCase.verifyFalse(contains(desc, 'osm-6'), 'not in the description');
            about = @(d) isfield(d, 'depends_on') && any(strcmp({d.depends_on.document_id}, pr));
            g = docs(cellfun(@(d) about(d) && isstruct(ndi.v2.blockOf(d, 'statement', 'variable')) ...
                && strcmp(ndi.v2.blockOf(d, 'statement', 'variable').node, 'NCIT:C16631'), docs));
            testCase.verifyNumElements(g, 1, 'one genotype assertion');
            testCase.verifyEqual(ndi.v2.blockOf(g{1}, 'statement', 'variable').name, 'Genotype');
            testCase.verifyEqual(ndi.v2.leafName(g{1}), 'text_assertion');
            v = ndi.v2.blockOf(g{1}, 'text', 'value');
            if iscell(v), v = v{1}; end
            testCase.verifyEqual(v(1).text, 'osm-6(p811) V');
        end

        function testRecipesAreBuiltFromTheirIngredients(testCase)
            % decision #56: NGM and the WormBook media, dataset-level
            docs = testCase.Result.documents;
            ids = testCase.Result.ids;
            byId = containers.Map(cellfun(@(d) d.base.id, docs, 'UniformOutput', false), docs);
            sc = byId(ids('s_complete'));
            ing = sc.depends_on(strcmp({sc.depends_on.name}, 'ingredient_id'));
            testCase.verifyEqual({ing.document_id}, {ids('s_basal'), ids('k_citrate_1m_ph6'), ...
                ids('trace_metals'), ids('cacl2_1m'), ids('mgso4_1m')}, 'in the recipe''s order');
            testCase.verifyEqual(numel(sc.formulation.value.ingredients), 5, ...
                'one amount per ingredient edge');
            testCase.verifyEqual(sc.depends_on(strcmp({sc.depends_on.name}, 'product_id')).document_id, ...
                ids('s_complete_kitchen'), 'made by the Salk media kitchen');
            ngm = byId(ids('ngm_no_peptone'));
            ing = ngm.depends_on(strcmp({ngm.depends_on.name}, 'ingredient_id'));
            testCase.verifyFalse(any(strcmp({ing.document_id}, ids('peptone_bd'))));
            testCase.verifyEqual(numel(ing), 7);
            cited = relationsNamed(docs, 'documented_by');
            cited = cited(cellfun(@(r) strcmp(parentOf(r), ids('wormbook_maintenance')), cited));
            testCase.verifyEqual(numel(cited), 5, ...
                ['S Basal, S-Complete, trace metals, potassium citrate, LB (the potassium ' ...
                'phosphate buffer is Jess''s 231109_KPO4_stock, decision #86)']);
            kp = byId(ids('kpo4_1m_ph6'));
            ing = kp.depends_on(strcmp({kp.depends_on.name}, 'ingredient_id'));
            testCase.verifyEqual(sort({ing.document_id}), sort({ids('kh2po4_1m'), ids('k2hpo4_1m')}), ...
                'the buffer is the 1 M dibasic titrated into the 1 M monobasic');
            if ndi.setup.V2.schemaHasField('formulation', 'value.type')
                testCase.verifyEqual(sc.formulation.value.type.node, 'EMPTY:0000266');
                testCase.verifyEqual(sc.formulation.value.type.name, 'S medium');
            end
        end

        function testChemicalsAndFormulationTypesCarryTheirNodes(testCase)
            % every chemical's substance and every formulation's type is its
            % decided ontology term (2026-10-19), not a name alone
            docs = testCase.Result.documents;
            classes = cellfun(@ndi.v2.leafName, docs, 'UniformOutput', false);
            chem = docs(strcmp(classes, 'chemical'));
            testCase.verifyNumElements(chem, numel(testCase.Spec.chemicals));
            for k = 1:numel(chem)
                t = chem{k}.chemical.value.substance;
                testCase.verifyNotEmpty(t.node, sprintf('chemical %s has no node', t.name));
            end
            byId = containers.Map(cellfun(@(d) d.base.id, docs, 'UniformOutput', false), docs);
            carb = byId(testCase.Result.ids('carbenicillin_50'));
            testCase.verifyEqual(carb.chemical.value.substance.node, 'CHEBI:3393');
            if ndi.setup.V2.schemaHasField('formulation', 'value.type')
                form = docs(strcmp(classes, 'formulation'));
                testCase.verifyNumElements(form, numel(testCase.Spec.formulations));
                for k = 1:numel(form)
                    t = form{k}.formulation.value.type;
                    testCase.verifyNotEmpty(t.node, sprintf('formulation type %s has no node', t.name));
                end
                lb = byId(testCase.Result.ids('lb'));
                testCase.verifyEqual(lb.formulation.value.type.node, 'MCO:0000030');
            end
        end

        function testEveryAuthorRoleHasItsCreditNode(testCase)
            % the CRediT role names are completed from the field's value set
            rels = relationsNamed(testCase.Result.documents, 'has_author');
            n = 0;
            for k = 1:numel(rels)
                roles = rels{k}.directed_relation.roles;
                if iscell(roles) && all(cellfun(@isstruct, roles)), roles = [roles{:}]; end
                for j = 1:numel(roles)
                    n = n + 1;
                    if isstruct(roles) && isfield(roles, 'node')
                        testCase.verifyNotEmpty(roles(j).node, sprintf('role "%s" has no node', roles(j).name));
                    elseif isstruct(roles)
                        % a schema before the role nodes keeps a role as a name only
                        testCase.verifyNotEmpty(roles(j).name);
                    else
                        testCase.verifyNotEmpty(roles{j});
                    end
                end
            end
            testCase.verifyEqual(n, 29, 'every role of the four authors was inspected');
        end

        function testStudyFactorsAccessibilityAndNoEthicsAssertion(testCase)
            % study factors are decided terms (patch configuration dropped);
            % accessibility is unrestricted access; an ethics assessment that
            % was not required is not asserted
            st = testCase.Spec.studies;
            if isstruct(st), st = num2cell(st); end
            nFactors = 0;
            for k = 1:numel(st)
                f = st{k}.factors;
                if iscell(f), f = [f{:}]; end
                nFactors = nFactors + numel(f);
                testCase.verifyFalse(any(strcmp({f.name}, 'patch configuration')));
                testCase.verifyTrue(all(~cellfun(@isempty, {f.node})), st{k}.key);
            end
            testCase.verifyGreaterThan(nFactors, 0);
            testCase.verifyEqual(testCase.Spec.dataset.accessibility.node, 'NCIT:C183346');
            testCase.verifyFalse(isfield(testCase.Spec.dataset, 'ethics_assessment'));
            docs = testCase.Result.documents;
            if ndi.setup.V2.mergedEntities()
                st = docs(cellfun(@(d) isfield(d, 'statement'), docs));
                vars = cellfun(@(d) d.statement.variable.name, st, 'UniformOutput', false);
                testCase.verifyFalse(any(strcmp(vars, 'ethics assessment')));
                acc = st(strcmp(vars, 'Open or Controlled Data Access Indicator') | strcmp(vars, 'accessibility'));
                testCase.verifyNumElements(acc, 1);
                testCase.verifyEqual(acc{1}.statement.variable.node, 'NCIT:C175887');
            else
                ds = docs{strcmp(cellfun(@ndi.v2.leafName, docs, 'UniformOutput', false), 'dataset')};
                testCase.verifyFalse(isfield(ds.dataset, 'ethics_assessment') && ...
                    ~isempty(ds.dataset.ethics_assessment.name));
                testCase.verifyEqual(ds.dataset.accessibility.node, 'NCIT:C183346');
            end
        end

        function testKeywordsAreTextAndTheLicenceIsItsSpdxTerm(testCase)
            % Jess Haley, 2026-10-21: the dataset's keywords are its own text
            % (a text assertion), not terms with no node; its licence is the
            % term whose node is its SPDX IRI (no ontology has licence terms)
            docs = testCase.Result.documents;
            if ~ndi.setup.V2.mergedEntities()
                % the dataset is its own class here (did-schema main): keyword
                % and license are its own fields, written as the spec gives them
                ds = docs{strcmp(cellfun(@ndi.v2.leafName, docs, 'UniformOutput', false), 'dataset')};
                testCase.verifyEqual(char(ds.dataset.license), 'CC-BY-4.0');
                return;
            end
            st = docs(cellfun(@(d) isfield(d, 'statement'), docs));
            nodes = cellfun(@(d) d.statement.variable.node, st, 'UniformOutput', false);
            kw = st(strcmp(nodes, 'EDAM:data_0968'));
            testCase.verifyNumElements(kw, 1, 'one keyword statement');
            testCase.verifyTrue(isfield(kw{1}, 'text') && ~isfield(kw{1}, 'term'), ...
                'the keywords are a text assertion');
            tv = kw{1}.text.value;
            if iscell(tv), tv = [tv{:}]; end
            words = arrayfun(@(c) char(c.text), tv, 'UniformOutput', false);
            testCase.verifyEqual(sort(words(:)'), sort(cellstr(string(testCase.Spec.dataset.keyword))'));
            lic = st(strcmp(nodes, 'NCIT:C43611'));
            testCase.verifyNumElements(lic, 1, 'one licence statement');
            testCase.verifyEqual(lic{1}.term.value.node, 'https://spdx.org/licenses/CC-BY-4.0');
            testCase.verifyEqual(lic{1}.term.value.name, 'CC-BY-4.0');
        end

        function testUnrepresentedContentIsReportedNotDropped(testCase)
            u = testCase.Result.unrepresented;
            % software.vendor has no V2 home. An instrument's `name` has one only
            % once the schema declares subject.name (did-schema PR #80); before
            % that it is reported here, one row per instrument. Nothing else in
            % the spec should be.
            hasName = ndi.setup.V2.schemaHasField('subject', 'name');
            isName = strcmp({u.field}, 'name');
            if hasName
                testCase.verifyFalse(any(isName), 'subject.name exists, so names are built');
            else
                testCase.verifyEqual(nnz(isName), numel(testCase.Spec.instruments));
            end
            u = u(~isName);
            % formulation.value.type likewise, once the schema declares it
            % (did-schema PR #84); before that, one row per formulation
            isType = strcmp({u.field}, 'type');
            if ndi.setup.V2.schemaHasField('formulation', 'value.type')
                testCase.verifyFalse(any(isType), 'formulation.value.type exists, so types are built');
            else
                testCase.verifyEqual(nnz(isType), numel(testCase.Spec.formulations));
            end
            u = u(~isType);
            % with one entity class a web resource's host has no relation
            % (hosted_by retired, 2026-10-08): one row per resource naming one --
            % EXCEPT a stored copy's host, which is the dataset's `hosted_by` on a
            % schema that has it again (did-schema 9bedceb, 2026-10-15)
            isHost = strcmp({u.field}, 'host');
            wr = testCase.Spec.web_resources;
            if isstruct(wr), wr = num2cell(wr); end
            stored = cellstr(string(testCase.Spec.dataset.stored_at));
            hasHosted = ndi.setup.V2.schemaHasRelation('hosted_by');
            if ndi.setup.V2.mergedEntities()
                expect = sum(cellfun(@(x) isfield(x, 'host') && ...
                    ~(hasHosted && any(strcmp(x.key, stored))), wr));
                testCase.verifyEqual(nnz(isHost), expect);
            else
                testCase.verifyFalse(any(isHost));
            end
            u = u(~isHost);
            % software.vendor: a `developed_by` relation on a schema that has it
            % (did-schema 9bedceb), else one row per software naming a vendor
            % (the analysis package and macOS name none)
            sw = testCase.Spec.software;
            if isstruct(sw), sw = num2cell(sw); end
            nVendor = sum(cellfun(@(x) isfield(x, 'vendor') && ~isempty(x.vendor), sw));
            if ndi.setup.V2.schemaHasRelation('developed_by')
                testCase.verifyEmpty(u);
                testCase.verifyNumElements(relationsNamed(testCase.Result.documents, ...
                    'developed_by'), nVendor);
            else
                testCase.verifyEqual(unique({u.field}), {'vendor'});
                testCase.verifyEqual(numel(u), nVendor);
            end
            if hasHosted && ndi.setup.V2.mergedEntities()
                testCase.verifyNumElements(relationsNamed(testCase.Result.documents, ...
                    'hosted_by'), 1, 'the NDI Cloud copy names its host');
            end
        end
    end
end

function rels = relationsNamed(docs, name)
arguments
    docs cell
    name {mustBeText}
end
isRel = cellfun(@(d) strcmp(d.document_class.class_name, 'directed_relation'), docs);
rels = docs(isRel);
rels = rels(cellfun(@(r) strcmp(r.directed_relation.relation.name, name), rels));
end

function id = parentOf(r)
arguments
    r (1,1) struct
end
id = r.depends_on(strcmp({r.depends_on.name}, 'parent_id')).document_id;
end
