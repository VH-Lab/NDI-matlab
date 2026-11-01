classdef TestV1FileReader < matlab.unittest.TestCase
    % TESTV1FILEREADER ndi.migrate.internal.v1FileReader, the reader
    % ndi.migrate.local passes to did2.convert.v1_to_v2 as 'V1FileReader'.
    %
    %   A migrator that must read a file a v1 document attaches (first:
    %   gene_list_mapping's mapping.tsv; Jess Haley, 2026-11-01, did-schema
    %   did_v2_go_forward_class_audit.md [key covariate index], [mapping rows
    %   counted, indices 0-based]) reads it through this handle. v1 ingested
    %   the bytes to <.ndi>/files/<uid>, so that is where it looks first; a
    %   local `file` location second. A file found nowhere is an error, which
    %   DID-matlab's did2.convert.v1Files turns into a carry of the whole
    %   document (carry-167), never an empty file.
    %
    %   Self-contained: the store is a temp folder. The conversion test runs
    %   on a copy of the loaded schema set that declares the covariate `index`
    %   (did-schema [key covariate index]) when the loaded set does not yet.

    properties
        Root
        NdiDir
    end

    methods (TestMethodSetup)
        function makeDirs(testCase)
            testCase.Root = tempname();
            testCase.NdiDir = fullfile(testCase.Root, '.ndi');
            mkdir(fullfile(testCase.NdiDir, 'files'));
            mkdir(fullfile(testCase.Root, 'elsewhere'));
            testCase.addTeardown(@() rmdir(testCase.Root, 's'));
        end
    end

    methods (Test)

        function testReadsTheBytesV1IngestedToTheStore(testCase)
            writeText(fullfile(testCase.NdiDir, 'files', 'uid_store'), sprintf('a\tb\n1\t2\n'));
            body = mappingBody('/gone/tmp/mapping.tsv', 'uid_store');
            reader = ndi.migrate.internal.v1FileReader(testCase.NdiDir);
            testCase.verifyEqual(reader(body, 'mapping.tsv'), sprintf('a\tb\n1\t2\n'));
        end

        function testReadsALocalFileLocationWhenTheStoreHasNone(testCase)
            src = fullfile(testCase.Root, 'elsewhere', 'mapping.tsv');
            writeText(src, sprintf('x\n'));
            body = mappingBody(src, 'uid_absent');
            reader = ndi.migrate.internal.v1FileReader(testCase.NdiDir);
            testCase.verifyEqual(reader(body, 'mapping.tsv'), sprintf('x\n'));
        end

        function testAFileFoundNowhereIsAnErrorNotAnEmptyFile(testCase)
            reader = ndi.migrate.internal.v1FileReader(testCase.NdiDir);
            body = mappingBody('/gone/tmp/mapping.tsv', 'uid_absent');
            testCase.verifyError(@() reader(body, 'mapping.tsv'), 'NDI:migrate:v1FileNotFound');
            testCase.verifyError(@() reader(body, 'other.tsv'), 'NDI:migrate:v1FileNotFound');
        end

        function testAnUnsafeUidIsNotLookedUp(testCase)
            writeText(fullfile(testCase.Root, 'escaped.tsv'), 'no');
            body = mappingBody('/gone/tmp/mapping.tsv', '../escaped.tsv');
            reader = ndi.migrate.internal.v1FileReader(testCase.NdiDir);
            testCase.verifyError(@() reader(body, 'mapping.tsv'), 'NDI:migrate:v1FileNotFound');
        end

        function testDid2ReadsThroughIt(testCase)
            % the contract with DID-matlab's did2.convert.v1Files: a found file
            % is OK with its text; a missing one is not OK, and says why
            writeText(fullfile(testCase.NdiDir, 'files', 'uid_store'), 'hello');
            did2.convert.v1Files('set', ndi.migrate.internal.v1FileReader(testCase.NdiDir));
            testCase.addTeardown(@() did2.convert.v1Files('reset'));
            [text, ok] = did2.convert.v1Files('read', mappingBody('/gone/m.tsv', 'uid_store'), 'mapping.tsv');
            testCase.verifyTrue(ok);
            testCase.verifyEqual(text, 'hello');
            [text, ok, why] = did2.convert.v1Files('read', mappingBody('/gone/m.tsv', 'uid_absent'), 'mapping.tsv');
            testCase.verifyFalse(ok);
            testCase.verifyEmpty(text);
            testCase.verifyTrue(contains(why, 'mapping.tsv'), why);
        end

        function testAGeneListMappingConvertsFromItsStoredFile(testCase)
            % the end of the chain: a v1 geneListMapping whose mapping.tsv is
            % in the session's store converts (a relation, its value and the
            % body), its gene indices read from the file
            useSchemaWithIndex(testCase);
            writeText(fullfile(testCase.NdiDir, 'files', 'uid_map'), ...
                sprintf('gene_index_a\tgene_index_b\n0\t5\n1\t7\n1\t9\n'));
            body = mappingBody('/gone/tmp/mapping.tsv', 'uid_map');
            out = did2.convert.v1_to_v2({body}, 'Validate', true, ...
                'V1FileReader', ndi.migrate.internal.v1FileReader(testCase.NdiDir));
            testCase.verifyEmpty(out.quarantine);
            docs = cellfun(@(d) d.toStruct(), out.migrated, 'UniformOutput', false);
            names = cellfun(@(d) char(d.document_class.class_name), docs, 'UniformOutput', false);
            testCase.verifyEqual(sort(names), sort({'directed_relation', 'logical', 'opaque_body'}));
            val = docs{strcmp(names, 'logical')};
            testCase.verifyEqual(double(val.data.dimensions.n), 3);
            covs = val.data.covariates;
            testCase.verifyEqual(double(covs(1).index(:)'), [0 1 1]);
            testCase.verifyEqual(double(covs(2).index(:)'), [5 7 9]);
        end

        function testWithoutTheFileTheMappingIsCarriedWhole(testCase)
            useSchemaWithIndex(testCase);
            body = mappingBody('/gone/tmp/mapping.tsv', 'uid_absent');
            out = did2.convert.v1_to_v2({body}, 'Validate', false, ...
                'V1FileReader', ndi.migrate.internal.v1FileReader(testCase.NdiDir));
            testCase.verifyNumElements(out.migrated, 1);
            testCase.verifyEqual(char(out.migrated{1}.get('document_class.class_name')), 'geneListMapping');
            notes = strjoin(out.summary.migration_notes.carried_as_v1.distinct_details, ' || ');
            testCase.verifyTrue(contains(notes, 'files mapping.tsv'), notes);
        end
    end
end

function body = mappingBody(location, uid)
% a v1 geneListMapping in the shape NDI's template gives it (no NDI writer
% makes the class), attaching mapping.tsv ingested under UID
tpl = jsondecode(fileread(fullfile(ndi.common.PathConstants.DocumentFolder, ...
    'data', 'geneListMapping.json')));
body = struct();
body.document_class = tpl.document_class;
body.depends_on = struct('name', {'geneList_id_a', 'geneList_id_b'}, ...
    'value', {'41268b6f5c6a3d4e_6e0000000000000a', '41268b6f5c6a3d4e_6e00000000000011'});
body.base = struct('id', '41268b6f5c6a3d4e_6e00000000000010', ...
    'session_id', '41268b6f5c6a3d4e_00000000000000a1', 'name', '', ...
    'datestamp', '2025-05-27T15:47:23.738Z');
body.files = struct('file_list', {{'mapping.tsv'}}, 'file_info', struct('name', 'mapping.tsv', ...
    'locations', struct('delete_original', 1, 'uid', uid, 'location', location, ...
    'parameters', '', 'location_type', 'file', 'ingest', 1)));
body.geneListMapping = struct('label', 'mouse aliases', 'mapping_type', 'alias', ...
    'method', 'GEF pairing', 'symmetric', 0, 'n_pairs', 3, 'n_genes_mapped_a', 2, ...
    'n_genes_mapped_b', 3, 'has_score', 0);
body = jsondecode(jsonencode(body));
end

function writeText(p, txt)
fid = fopen(p, 'w');
fwrite(fid, txt);
fclose(fid);
end

function useSchemaWithIndex(testCase)
% did-schema [key covariate index] declares the covariate `index`; until the
% loaded set does, a copy that declares it (what gene_list_mapping needs to
% convert rather than pass through)
src = did2.schema.cache.shared().schemaPath;
tmp = tempname;
mkdir(tmp);
testCase.addTeardown(@() rmdir(tmp, 's'));
did2.schema.cache.copySchemaSet(src, tmp);
f = fullfile(tmp, 'data.json');
txt = fileread(f);
if isempty(strfind(txt, '"name": "index"'))
    k = strfind(txt, '"name": "key"');
    testCase.assertNumElements(k, 1, 'data.json declares one covariate `key`');
    c = strfind(txt(k:end), '"constraints"');
    pos = k + c(1) - 1;
    brace = find(txt(pos:end) == '}', 2);
    at = pos + brace(2) - 1;
    def = ['{"name": "index", "type": "integer", "blank_value": [], "default_value": [], ' ...
        '"mustBeNonEmpty": false, "mustBeScalar": false, "mustNotHaveNaN": false, ' ...
        '"queryable": true, "ontology": null, ' ...
        '"documentation": "test copy: [key covariate index].", "constraints": {}}'];
    writeText(f, [txt(1:at) ', ' def txt(at+1:end)]);
end
did2.schema.cache.setSchemaPath(tmp);
testCase.addTeardown(@() did2.schema.cache.setSchemaPath(src));
end
