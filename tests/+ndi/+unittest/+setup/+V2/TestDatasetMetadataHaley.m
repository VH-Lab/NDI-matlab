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
                isfile(fullfile(schemaPath, 'study.json')), ...
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
            % Salk + 6 recipes documented_by WormBook
            testCase.verifyEqual(n('directed_relation'), 54, ...
                'relation count moved: re-derive it from the spec, do not bump it');
            % 133 before decision #56; + 3 organizations, 1 web resource,
            % 4 products, 20 chemicals, 9 formulations, 7 relations; + the
            % temperature probe (decision #59: an instrument with no product,
            % so no instance_of relation)
            testCase.verifyEqual(numel(testCase.Result.documents), 178);
        end

        function testStudiesCanBeMintedApartFromTheRest(testCase)
            % import_V2 builds the studies in stage 3, beside the sessions
            % (decision #50): "exclude" + "only" together are "include".
            sid = did.ido.unique_id();
            datasetId = did.ido.unique_id();
            rest = ndi.setup.V2.datasetMetadata(testCase.Spec, sid, ...
                'DatasetId', datasetId, 'Studies', "exclude");
            studies = ndi.setup.V2.datasetMetadata(testCase.Spec, sid, ...
                'DatasetId', datasetId, 'Studies', "only");
            classOf = @(r) cellfun(@(d) d.document_class.class_name, r.documents, 'UniformOutput', false);
            testCase.verifyEqual(sum(strcmp(classOf(rest), 'study')), 0);
            testCase.verifyEqual(sum(strcmp(classOf(studies), 'study')), numel(testCase.Spec.studies));
            testCase.verifyEqual(numel(rest.documents) + numel(studies.documents), ...
                numel(testCase.Result.documents));
            % each study is part_of the dataset the other call built
            rel = studies.documents(strcmp(classOf(studies), 'directed_relation'));
            testCase.verifyEqual(numel(rel), numel(testCase.Spec.studies));
            for k = 1:numel(rel)
                dep = rel{k}.depends_on;
                testCase.verifyTrue(any(strcmp({dep.document_id}, datasetId)));
            end
            ds = rest.documents(strcmp(classOf(rest), 'dataset'));
            testCase.verifyEqual(ds{1}.base.id, datasetId);
            testCase.verifyError(@() ndi.setup.V2.datasetMetadata(testCase.Spec, sid, ...
                'Studies', "only"), 'ndi:setup:V2:noDatasetId');
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
            partOf = relationsNamed(testCase.Result.documents, 'part_of');
            testCase.verifyEqual(numel(partOf), numel(testCase.Spec.studies));
            testCase.verifyEqual(partOf{1}.directed_relation.relation.node, 'BFO:0000050');
        end

        function testStrainLineageAndStock(testCase)
            docs = testCase.Result.documents;
            gfp = docs{strcmp(cellfun(@(d) d.base.id, docs, 'UniformOutput', false), ...
                testCase.Result.ids('OP50-GFP'))};
            bg = gfp.depends_on(strcmp({gfp.depends_on.name}, 'background_strain_id'));
            testCase.verifyEqual({bg.document_id}, {testCase.Result.ids('OP50')});
            testCase.verifyTrue(any(strcmp({gfp.depends_on.name}, 'product_id')));
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
            testCase.verifyEqual(numel(cited), 6, ...
                'S Basal, S-Complete, trace metals, potassium citrate, potassium phosphate, LB');
            if ndi.setup.V2.schemaHasField('formulation', 'value.type')
                testCase.verifyEqual(sc.formulation.value.type.name, 'S-Complete');
            end
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
            testCase.verifyEqual(unique({u.field}), {'vendor'});
            testCase.verifyEqual(numel(u), numel(testCase.Spec.software));
        end
    end
end

function rels = relationsNamed(docs, name)
isRel = cellfun(@(d) strcmp(d.document_class.class_name, 'directed_relation'), docs);
rels = docs(isRel);
rels = rels(cellfun(@(r) strcmp(r.directed_relation.relation.name, name), rels));
end

function id = parentOf(r)
id = r.depends_on(strcmp({r.depends_on.name}, 'parent_id')).document_id;
end
