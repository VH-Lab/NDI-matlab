classdef TestSchemasLoader < matlab.unittest.TestCase
%TESTSCHEMASLOADER Unit tests for ndi.schemas.* loader scaffolding.
%
%   These tests cover everything the loader can do without network
%   access: pin file read/write, cache directory resolution, fallback
%   directory resolution, and the init no-op when no schemas are
%   available. The actual tarball fetch in ndi.schemas.refresh is
%   exercised by integration tests that require connectivity.

    properties
        OriginalPinJSON  % raw bytes of the on-disk pin.json
        PinFile          % cached absolute path
    end

    methods (TestClassSetup)
        function snapshotPinFile(testCase)
            testCase.PinFile = fullfile( ...
                ndi.common.PathConstants.CommonFolder, ...
                'schemas', 'pin.json');
            if isfile(testCase.PinFile)
                testCase.OriginalPinJSON = fileread(testCase.PinFile);
            else
                testCase.OriginalPinJSON = '';
            end
        end
    end

    methods (TestClassTeardown)
        function restorePinFile(testCase)
            if isempty(testCase.OriginalPinJSON)
                if isfile(testCase.PinFile); delete(testCase.PinFile); end
                return;
            end
            fid = fopen(testCase.PinFile, 'wt');
            if fid < 0; return; end
            fprintf(fid, '%s', testCase.OriginalPinJSON);
            fclose(fid);
        end
    end

    methods (Test)

        function testPinReadDefaults(testCase)
            info = ndi.schemas.pin();
            testCase.verifyClass(info, 'struct');
            testCase.verifyTrue(isfield(info, 'repo'));
            testCase.verifyTrue(isfield(info, 'ref'));
            testCase.verifyTrue(isfield(info, 'path'));
            testCase.verifyEqual(info.path, 'schemas/V_eta/stable');
        end

        function testPinWriteRoundTrip(testCase)
            sha = 'abc1234def5678';
            ndi.schemas.pin(sha);
            after = ndi.schemas.pin();
            testCase.verifyEqual(after.ref, sha);
        end

        function testPinWriteRejectsNonString(testCase)
            testCase.verifyError( ...
                @() ndi.schemas.pin(42), ...
                'NDI:schemas:InvalidPinRef');
        end

        function testCacheDirReflectsPin(testCase)
            ndi.schemas.pin('v1.2.3');
            p = ndi.schemas.cacheDir();
            testCase.verifySubstring(p, 'V_eta');
            testCase.verifySubstring(p, 'v1.2.3');
            testCase.verifyTrue(endsWith(p, fullfile('v1.2.3', 'stable')));
        end

        function testCacheDirSanitizesRef(testCase)
            % Slashes/spaces in a branch name must not escape the cache
            % root or break path construction.
            p = ndi.schemas.cacheDir('feature/x y');
            testCase.verifyFalse(contains(p, 'feature/x y'));
            testCase.verifySubstring(p, 'feature_x_y');
        end

        function testCacheDirUnpinnedSegment(testCase)
            ndi.schemas.pin('');
            p = ndi.schemas.cacheDir();
            testCase.verifySubstring(p, fullfile('V_eta', 'unpinned'));
        end

        function testFallbackDirExists(testCase)
            p = ndi.schemas.fallbackDir();
            testCase.verifyTrue(isfolder(p), ...
                sprintf('Fallback dir should be shipped: %s', p));
        end

        function testActiveSchemaPathNoneByDefault(testCase)
            % The freshly-checked-out repo ships an empty fallback and
            % the test runner doesn't populate the user cache, so the
            % resolver must report 'none' and return ''.
            [p, source] = ndi.schemas.activeSchemaPath();
            testCase.verifyEqual(source, 'none');
            testCase.verifyEqual(p, '');
        end

        function testInitNoOpWhenNoSchemas(testCase)
            % init() must not raise when no schemas are available; it
            % should warn quietly and leave did2 alone.
            [p, source] = ndi.schemas.init('Quiet', true);
            testCase.verifyEqual(source, 'none');
            testCase.verifyEqual(p, '');
        end

        function testRefreshErrorsWhenUnpinned(testCase)
            ndi.schemas.pin('');
            testCase.verifyError( ...
                @() ndi.schemas.refresh(), ...
                'NDI:schemas:UnpinnedRefresh');
        end

        % ---- ndi.schemas.setFiles: tiered and flat did-schema layouts ----
        % [one folder, final classes only] (Jess Haley, 2026-10-29): the
        % loader must read schemas/did_v2/*.json once the tiers are gone,
        % and keep reading schemas/did_v2/stable while they exist.

        function testSetFilesReadsTheTieredLayout(testCase)
            root = testCase.applyFixture( ...
                matlab.unittest.fixtures.TemporaryFolderFixture).Folder;
            writeJson(fullfile(root, 'schemas', 'did_v2', 'stable'), {'entity', 'term_registry_meta'});
            writeJson(fullfile(root, 'schemas', 'did_v2', 'draft'), {'item'});
            writeJson(fullfile(root, 'schemas', 'did_v2'), {'index', 'topics'});
            [files, src, layout] = ndi.schemas.setFiles(root, 'schemas/V_eta/stable');
            testCase.verifyEqual(layout, 'pinned');
            testCase.verifyEqual(src, fullfile(root, 'schemas', 'did_v2', 'stable'));
            testCase.verifyEqual(names(files), {'entity.json', 'term_registry_meta.json'});
        end

        function testSetFilesReadsTheFlatLayout(testCase)
            root = testCase.applyFixture( ...
                matlab.unittest.fixtures.TemporaryFolderFixture).Folder;
            writeJson(fullfile(root, 'schemas', 'did_v2'), ...
                {'entity', 'item', 'term_registry_meta', 'index', 'topics'});
            [files, src, layout] = ndi.schemas.setFiles(root, 'schemas/V_eta/stable');
            testCase.verifyEqual(layout, 'flat');
            testCase.verifyEqual(src, fullfile(root, 'schemas', 'did_v2'));
            % index.json and topics.json are not schemas
            testCase.verifyEqual(names(files), ...
                {'entity.json', 'item.json', 'term_registry_meta.json'});
        end

        function testSetFilesErrorsWhenNothingIsThere(testCase)
            root = testCase.applyFixture( ...
                matlab.unittest.fixtures.TemporaryFolderFixture).Folder;
            testCase.verifyError(@() ndi.schemas.setFiles(root, 'schemas/V_eta/stable'), ...
                'NDI:schemas:FetchFailed');
            % a non-tier pinned path has no flat fallback
            writeJson(fullfile(root, 'schemas', 'did_v2'), {'entity'});
            testCase.verifyError(@() ndi.schemas.setFiles(root, 'schemas/did_v2/other'), ...
                'NDI:schemas:FetchFailed');
        end

        % ---- [schema folders by family] (Jess Haley, 2026-10-30) ----
        % classes in family subfolders of schemas/did_v2/, registries in
        % schemas/registry/ and schemas/generated/. The old and the new layout
        % of the same content give the same files.

        function testSetFilesReadsTheFamilyLayoutAsTheOld(testCase)
            root = testCase.applyFixture( ...
                matlab.unittest.fixtures.TemporaryFolderFixture).Folder;
            old = fullfile(root, 'old'); new = fullfile(root, 'new');
            buildLayout(old, 'old'); buildLayout(new, 'new');
            [fOld, ~, lOld] = ndi.schemas.setFiles(old, 'schemas/V_eta/stable');
            [fNew, srcNew, lNew] = ndi.schemas.setFiles(new, 'schemas/V_eta/stable');
            testCase.verifyEqual(lOld, 'pinned');
            testCase.verifyEqual(lNew, 'flat');
            testCase.verifyEqual(srcNew, fullfile(new, 'schemas', 'did_v2'));
            % the old pinned stable/ tier holds the stable classes and the
            % registries; the new layout holds every class (draft ones too)
            % and the same registries, and no non-class file
            stableClasses = {'base.json', 'entity.json', 'mass.json'};
            regs = {'CURIE_lookups_meta.json', 'binding_registry_meta.json', ...
                'class_disposition_meta.json', 'ndi_reserved_keys.json', ...
                'term_registry_meta.json'};
            testCase.verifyEqual(names(fOld), sort([stableClasses, regs]));
            testCase.verifyEqual(names(fNew), ...
                sort([stableClasses, {'clock_type.json', 'old_thing.json'}, regs]));
        end

        function testSchemaFileFindsTheSameFilesInBothLayouts(testCase)
            root = testCase.applyFixture( ...
                matlab.unittest.fixtures.TemporaryFolderFixture).Folder;
            old = fullfile(root, 'old'); new = fullfile(root, 'new');
            buildLayout(old, 'old'); buildLayout(new, 'new');
            clear ndi.v2.schemaFile
            sets.old = fullfile(old, 'schemas', 'did_v2');
            sets.new = fullfile(new, 'schemas', 'did_v2');
            for layout = {'old', 'new'}
                L = layout{1};
                cls = ndi.v2.schemaClassFiles(sets.(L));
                testCase.verifyEqual(sort(cls.keys()), ...
                    {'base', 'clock_type', 'entity', 'mass', 'old_thing'}, L);
                for r = {'binding_registry_meta.json', 'term_registry_meta.json', ...
                        'CURIE_lookups_meta.json', 'base.json', 'mass.json'}
                    f = ndi.v2.schemaFile(sets.(L), r{1});
                    testCase.verifyTrue(isfile(f), [L ': ' r{1}]);
                    got = jsondecode(fileread(f));
                    testCase.verifyEqual(got.file, r{1}, L);
                end
                % a renamed data file, under either prefix
                f = ndi.v2.schemaFile(sets.(L), 'did_v2_term_registry.json');
                testCase.verifyTrue(isfile(f), [L ': term registry source']);
            end
            % the old stable/ tier, as DID_SCHEMA_PATH, still finds its registries
            f = ndi.v2.schemaFile(fullfile(sets.old, 'stable'), 'binding_registry_meta.json');
            testCase.verifyEqual(f, fullfile(sets.old, 'stable', 'binding_registry_meta.json'));
            % absent: the flat path, as before
            testCase.verifyEqual(ndi.v2.schemaFile(sets.new, 'nothing.json'), ...
                fullfile(sets.new, 'nothing.json'));
        end

        function testDuplicatesAreErrors(testCase)
            root = testCase.applyFixture( ...
                matlab.unittest.fixtures.TemporaryFolderFixture).Folder;
            buildLayout(root, 'new');
            s = fullfile(root, 'schemas');
            putJson(fullfile(s, 'did_v2', 'value', 'entity.json'));
            testCase.verifyError(@() ndi.v2.schemaClassFiles(fullfile(s, 'did_v2')), ...
                'NDI:v2:duplicateSchemaFile');
            delete(fullfile(s, 'did_v2', 'value', 'entity.json'));
            putJson(fullfile(s, 'generated', 'binding_registry_meta.json'));
            clear ndi.v2.schemaFile
            testCase.verifyError(@() ndi.v2.schemaFile(fullfile(s, 'did_v2'), ...
                'binding_registry_meta.json'), 'NDI:v2:duplicateSchemaFile');
        end

    end
end

function writeJson(folder, stems)
if ~isfolder(folder); mkdir(folder); end
for k = 1:numel(stems)
    fid = fopen(fullfile(folder, [stems{k} '.json']), 'wt');
    fprintf(fid, '{}');
    fclose(fid);
end
end

function n = names(files)
n = cell(1, numel(files));
for k = 1:numel(files)
    [~, b, e] = fileparts(files{k});
    n{k} = [b e];
end
end

function buildLayout(root, layout)
% the same classes and registries in did-schema's OLD layout (stable/ and
% draft/ tiers, deprecated/, registries in stable/, V_eta_* data files at the
% top of schemas/) or the NEW one ([schema folders by family]: family
% subfolders, schemas/registry/, schemas/generated/, did_v2_* names). Each
% file's content names it ({"file": "<name>"}).
s = fullfile(root, 'schemas');
if strcmp(layout, 'old')
    place = {'did_v2/stable', {'base', 'entity', 'mass', 'CURIE_lookups_meta', ...
        'binding_registry_meta', 'ndi_reserved_keys', 'term_registry_meta', ...
        'class_disposition_meta'}; 'did_v2/draft', {'clock_type'}; ...
        'did_v2/deprecated', {'old_thing'}; 'did_v2', {'index', 'topics'}; ...
        '', {'V_eta_term_registry', 'V_eta_coverage_ledger'}};
else
    place = {'did_v2', {'base', 'entity'}; 'did_v2/value', {'mass'}; ...
        'did_v2/time_reference', {'clock_type'}; 'did_v2/retiring', {'old_thing'}; ...
        'registry', {'CURIE_lookups_meta', 'binding_registry_meta', ...
        'ndi_reserved_keys', 'did_v2_term_registry'}; ...
        'generated', {'term_registry_meta', 'class_disposition_meta', 'index', ...
        'did_v2_coverage_ledger'}};
end
for k = 1:size(place, 1)
    for j = 1:numel(place{k, 2})
        putJson(fullfile(s, place{k, 1}, [place{k, 2}{j} '.json']));
    end
end
end

function putJson(path)
folder = fileparts(path);
if ~isfolder(folder); mkdir(folder); end
[~, b, e] = fileparts(path);
fid = fopen(path, 'wt');
fprintf(fid, '{"file":"%s"}', [b e]);
fclose(fid);
end
