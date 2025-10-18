classdef CacheTest < matlab.unittest.TestCase

    methods (Test)

        function testCacheCreation(testCase)
            % Test creating a cache object
            c = ndi.cache();
            testCase.verifyClass(c, 'ndi.cache');
            testCase.verifyEqual(c.maxMemory, 10e9);
            testCase.verifyEqual(c.replacement_rule, 'fifo');

            c2 = ndi.cache(maxMemory=5e6, replacement_rule='lifo');
            testCase.verifyEqual(c2.maxMemory, 5e6);
            testCase.verifyEqual(c2.replacement_rule, 'lifo');
        end

        function testAddAndLookup(testCase)
            % Test adding and looking up data
            c = ndi.cache(maxMemory=1e6);
            testData = rand(100,100);
            c.add('mykey', 'mytype', testData);
            retrieved = c.lookup('mykey', 'mytype');
            testCase.verifyEqual(retrieved.data, testData);
        end

        function testRemove(testCase)
            % Test removing data
            c = ndi.cache(maxMemory=1e6);
            testData = rand(100,100);
            c.add('mykey', 'mytype', testData);
            c.remove('mykey', 'mytype');
            retrieved = c.lookup('mykey', 'mytype');
            testCase.verifyEmpty(retrieved);
        end

        function testClear(testCase)
            % Test clearing the cache
            c = ndi.cache(maxMemory=1e6);
            c.add('mykey1', 'mytype', rand(10,10));
            c.add('mykey2', 'mytype', rand(10,10));
            c.clear();
            testCase.verifyEqual(c.bytes(), 0);
        end

        function testFifoReplacement(testCase)
            % Test FIFO replacement rule
            c = ndi.cache(maxMemory=900000, replacement_rule='fifo');
            c.add('key1', 'type1', rand(1,100000)); % 800000 bytes
            c.add('key2', 'type2', rand(1,100000)); % 800000 bytes
            % key1 should be gone
            retrieved1 = c.lookup('key1', 'type1');
            retrieved2 = c.lookup('key2', 'type2');
            testCase.verifyEmpty(retrieved1);
            testCase.verifyNotEmpty(retrieved2);
        end

        function testLifoReplacement(testCase)
            % Test LIFO replacement rule
            c = ndi.cache(maxMemory=900000, replacement_rule='lifo');
            c.add('key1', 'type1', rand(1,100000)); % 800000 bytes
            pause(0.01); % ensure unique timestamps
            c.add('key2', 'type2', rand(1,100000)); % 800000 bytes
            % key2 should be gone
            retrieved1 = c.lookup('key1', 'type1');
            retrieved2 = c.lookup('key2', 'type2');
            testCase.verifyNotEmpty(retrieved1);
            testCase.verifyEmpty(retrieved2);
        end

        function testErrorReplacement(testCase)
            % Test error replacement rule
            c = ndi.cache(maxMemory=800000, replacement_rule='error');
            c.add('key1', 'type1', rand(1,100000)); % 800000 bytes
            testCase.verifyError(@() c.add('key2', 'type2', rand(1,1)), '');
        end

        function testPriorityEviction(testCase)
            % Test that high priority items are preserved
            c = ndi.cache(maxMemory=800000, replacement_rule='fifo');
            c.add('low_priority_old', 'type', rand(1,50000), 'priority', 0); % 400KB
            pause(0.01);
            c.add('high_priority', 'type', rand(1,50000), 'priority', 10); % 400KB
            pause(0.01);
            c.add('low_priority_new', 'type', rand(1,50000), 'priority', 0); % 400KB

            % low_priority_old should be gone, high_priority should be preserved
            testCase.verifyEmpty(c.lookup('low_priority_old','type'));
            testCase.verifyNotEmpty(c.lookup('high_priority','type'));
            testCase.verifyNotEmpty(c.lookup('low_priority_new','type'));
        end

        function testAddingLargeItem(testCase)
            % Test adding an item that is larger than the cache
            c = ndi.cache(maxMemory=1e6);
            c.add('small_item', 'type', rand(1,100));

            % This should fail with an error
            testCase.verifyError(@() c.add('large_item', 'type', rand(1,200000)), '');

            % And the cache should be unchanged
            testCase.verifyNotEmpty(c.lookup('small_item','type'));
        end

        function testComplexLifoEviction(testCase)
            % Test LIFO eviction with multiple small items
            c = ndi.cache(maxMemory=1e6, replacement_rule='lifo');
            for i=1:10
                c.add(['small' num2str(i)], 'type', rand(1,10000), 'priority', i); % 80KB each
                pause(0.01);
            end
            % Cache is now at 800KB

            % Add a large item that will be rejected because it has the lowest priority
            c.add('large_item', 'type', rand(1,50000), 'priority', 0); % 400KB

            % The cache should be unchanged because the new item was not safe to add
            for i=1:10
                testCase.verifyNotEmpty(c.lookup(['small' num2str(i)],'type'));
            end
            testCase.verifyEmpty(c.lookup('large_item','type'));
        end

        function testCacheHandles(testCase)
            % Test caching object handles
            c = ndi.cache(maxMemory=1e6);
            fig_handle = figure('Visible','off');
            c.add('myhandle', 'figure', fig_handle);

            retrieved = c.lookup('myhandle','figure');
            testCase.verifyEqual(retrieved.data, fig_handle);

            % Test default remove (deletes handle)
            c.remove('myhandle','figure');
            testCase.verifyFalse(ishandle(fig_handle));

            % Test remove with 'leavehandle'
            fig_handle2 = figure('Visible','off');
            c.add('myhandle2', 'figure', fig_handle2);
            c.remove('myhandle2','figure','leavehandle',true);
            testCase.verifyTrue(ishandle(fig_handle2));
            delete(fig_handle2);
        end

    end
end