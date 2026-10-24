classdef TestDaqsystemLoadPrefetch < ndi.unittest.session.buildSession
    % TESTDAQSYSTEMLOADPREFETCH - daqsystem_load fetches dependencies in one search
    %
    % ndi.session/daqsystem_load collects every daqsystem's daqreader,
    % filenavigator and daqmetadatareader documents in a single search and
    % passes them to the ndi.daq.system constructor. These tests check that
    % the batched path builds the same objects as the one-search-per-
    % dependency path.

    methods (Test)
        function testPrefetchHoldsEveryDependency(testCase)
            S = testCase.Session;
            docs = S.database_search(ndi.query('','isa','daqsystem',''));
            prefetched = ndi.session.daqsystem_prefetch(S, docs);
            for i = 1:numel(docs)
                testCase.verifyTrue(isKey(prefetched, docs{i}.dependency_value('daqreader_id')));
                testCase.verifyTrue(isKey(prefetched, docs{i}.dependency_value('filenavigator_id')));
            end
        end

        function testPrefetchOfNoDocsIsEmpty(testCase)
            prefetched = ndi.session.daqsystem_prefetch(testCase.Session, {});
            testCase.verifyEqual(prefetched.Count, uint64(0));
        end

        function testLoadMatchesUnbatchedConstruction(testCase)
            S = testCase.Session;
            % a second daqsystem, so the batched search spans several systems
            dt = ndi.file.navigator(S, {'#.rhd', '#.epochprobemap.ndi'}, ...
                'ndi.epoch.epochprobemap_daqsystem', {'(.*)epochprobemap.ndi'});
            S.daqsystem_add(ndi.daq.system.mfdaq('intan2', dt, ndi.daq.reader.mfdaq.intan()));
            S.cache.clear();

            dev = S.daqsystem_load('name', '(.*)');
            testCase.verifyNumElements(dev, 2);
            docs = S.database_search(ndi.query('','isa','daqsystem',''));
            for i = 1:numel(dev)
                match = docs(cellfun(@(d) strcmp(d.document_properties.base.id, dev{i}.id()), docs));
                testCase.verifyNumElements(match, 1);
                plain = ndi.database.fun.ndi_document2ndi_object(match{1}, S);
                testCase.verifyClass(dev{i}, class(plain));
                testCase.verifyEqual(dev{i}.name, plain.name);
                testCase.verifyEqual(dev{i}.daqreader.id(), plain.daqreader.id());
                testCase.verifyEqual(dev{i}.filenavigator.id(), plain.filenavigator.id());
                testCase.verifyEqual(dev{i}.filenavigator.fileparameters, plain.filenavigator.fileparameters);
            end
        end
    end
end
