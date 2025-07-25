classdef CacheTest <  matlab.unittest.TestCase
    % ProbeTest - Unit test for testing the openMINDS tutorials.

    properties
        Cache
        TestKey = 'mykey'
    end

    properties (TestParameter)
        % pass?
    end

    methods (TestClassSetup)
        function setupClass(testCase) %#ok<*MANU>
            testCase.Cache = ndi.cache(...
                'maxMemory', 1024, ...
                'replacement_rule', 'fifo'); % 1K
            % Pass. No class setup routines needed
        end
    end

    methods (TestClassTeardown)
        function tearDownClass(testCase)
            % Pass. No class teardown routines needed
        end
    end

    methods (TestMethodSetup)
        function setupMethod(testCase)
            % Pass. No method setup routines needed
        end
    end

    methods (Test)
        function testCreateCache(testCase)
            % testCase.Cache = ndi.cache(...
            %     'maxMemory', 1024, ...
            %     'replacement_rule', 'fifo'); % 1K

            testCase.assertClass(testCase.Cache, 'ndi.cache')
        end

        function testAddElementsToCache(testCase)
            key = testCase.TestKey;

            for i = 1:5
                if i == 1
                    priority = 1;
                else
                    priority = 0;
                end
                testCase.Cache.add(key, ['type' int2str(i)], rand(25,1), priority);
            end
        end

        function readElementsFromCache(testCase)
            key = testCase.TestKey;
            for i=1:5
                t = testCase.Cache.lookup(key,['type' int2str(i)]);
            end
        end

        function testCacheEjection(testCase)
            key = testCase.TestKey;
            testCase.log(matlab.unittest.Verbosity.Verbose, ...
                ['About to add an element that will cause the cache to ', ...
                'eject its lowest priority entry, which should be entry ''type 2'' ']);

            testCase.Cache.add(key, 'type6', rand(25,1));

            cachedTypes = {testCase.Cache.table.type};
            testCase.assertFalse( any(strcmp(cachedTypes, 'type2')) )

            testCase.log(matlab.unittest.Verbosity.Verbose, ...
                sprintf('Types left in the cache: %s', strjoin(cachedTypes, ', ')));

        end
    end
end
