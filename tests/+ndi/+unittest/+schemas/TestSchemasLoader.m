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
            testCase.verifyEqual(info.path, 'schemas/V_delta/stable');
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
            testCase.verifySubstring(p, 'V_delta');
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
            testCase.verifySubstring(p, fullfile('V_delta', 'unpinned'));
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

    end
end
