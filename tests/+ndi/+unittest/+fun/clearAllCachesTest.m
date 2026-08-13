classdef clearAllCachesTest < matlab.unittest.TestCase
% clearAllCachesTest - Offline tests for ndi.fun.clearAllCaches.
%
%   Verifies that ndi.fun.clearAllCaches runs without error and actually
%   empties the caches it is responsible for. Runs fully offline: it exercises
%   the global ndi.cache singleton and a locally-constructed ndi.cache, with no
%   NDI Cloud or database network access.
%
%   See also: ndi.fun.clearAllCaches, ndi.database.fun.clearcaches, ndi.cache

    methods (Test)
        function testRunsWithNoArguments(testCase)
            % Should complete without error when called with no arguments.
            try
                ndi.fun.clearAllCaches();
            catch ME
                testCase.verifyFail(sprintf(...
                    'ndi.fun.clearAllCaches() errored: %s', ME.message));
            end
        end

        function testEmptiesGlobalCacheSingleton(testCase)
            % Populate the global ndi.cache singleton, then confirm
            % clearAllCaches empties it.
            c = ndi.common.getCache();
            c.add('clearAllCachesTestKey', 'clearAllCachesTestType', 1234);
            testCase.assertNotEmpty(c.table, ...
                'Sanity check: the entry we just added should be present.');

            ndi.fun.clearAllCaches();

            testCase.verifyEmpty(c.table, ...
                'clearAllCaches should empty the global ndi.cache singleton.');
        end

        function testClearsPassedCache(testCase)
            % A cache passed as an argument (forwarded to clearcaches) is
            % cleared along with the global caches.
            passed = ndi.cache();
            passed.add('passedKey', 'passedType', 5678);
            testCase.assertNotEmpty(passed.table, ...
                'Sanity check: the passed cache should hold the added entry.');

            ndi.fun.clearAllCaches(passed);

            testCase.verifyEmpty(passed.table, ...
                'clearAllCaches should clear a cache passed as an argument.');
        end

        function testRepeatedCallsAreSafe(testCase)
            % Clearing already-empty caches should be a no-op, not an error.
            try
                ndi.fun.clearAllCaches();
                ndi.fun.clearAllCaches();
            catch ME
                testCase.verifyFail(sprintf(...
                    'Calling clearAllCaches twice errored: %s', ME.message));
            end
        end
    end
end
