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
