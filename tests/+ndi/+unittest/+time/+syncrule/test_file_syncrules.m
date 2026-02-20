classdef test_file_syncrules < matlab.unittest.TestCase

    methods (Test)

        function testFileMatch(testCase)
            import ndi.time.syncrule.filematch;
            import ndi.unittest.time.syncrule.MockSession;
            import ndi.unittest.time.syncrule.MockMFDAQ;

            % Setup Mocks
            session = MockSession();
            daq1 = MockMFDAQ('daq1', session);
            daq2 = MockMFDAQ('daq2', session);

            % Setup overlapping epochs
            daq1 = daq1.addEpoch('e1', {'common1.dat', 'common2.dat'});
            daq2 = daq2.addEpoch('e1', {'common1.dat', 'common2.dat'});

            session.addDAQ(daq1);
            session.addDAQ(daq2);

            % Create Rule
            rule = filematch(struct('number_fullpath_matches', 2));

            node1 = struct('objectname', 'daq1', 'epoch_id', 'e1', ...
                'objectclass', 'ndi.unittest.time.syncrule.MockMFDAQ', ...
                'underlying_epochs', struct('underlying', {{'common1.dat', 'common2.dat'}}));
            node2 = struct('objectname', 'daq2', 'epoch_id', 'e1', ...
                'objectclass', 'ndi.unittest.time.syncrule.MockMFDAQ', ...
                'underlying_epochs', struct('underlying', {{'common1.dat', 'common2.dat'}}));

            [cost, mapping] = rule.apply(node1, node2, daq1);

            testCase.verifyEqual(cost, 1);
            testCase.verifyEqual(mapping.map(10), 10); % Identity mapping

            % Test failure case (insufficient overlap)
            rule_strict = filematch(struct('number_fullpath_matches', 3));
            [cost_fail, mapping_fail] = rule_strict.apply(node1, node2, daq1);
            testCase.verifyEmpty(cost_fail);
        end

        function testFileFind(testCase)
            import ndi.time.syncrule.filefind;
            import ndi.unittest.time.syncrule.MockSession;
            import ndi.unittest.time.syncrule.MockMFDAQ;

            % Create dummy sync file
            syncfile = [tempname '.txt'];
            fid = fopen(syncfile, 'w');
            fprintf(fid, '10 2'); % shift=10, scale=2 -> T2 = 2*T1 + 10
            fclose(fid);

            % Setup Mocks
            session = MockSession();
            daq1 = MockMFDAQ('daq1', session);
            daq2 = MockMFDAQ('daq2', session);

            % Daq2 has the sync file
            daq1 = daq1.addEpoch('e1', {'common.dat'});
            daq2 = daq2.addEpoch('e1', {'common.dat', syncfile});

            % Fix: Update node1 to contain the syncfile if testing forward direction where code checks node_a
            % Code logic for forward: checks epochnode_a.
            % Code logic for backward: checks epochnode_b.

            % Let's put file in daq1 (node1) to match forward logic of filefind
            daq1 = daq1.addEpoch('e1', {'common.dat', syncfile});

            session.addDAQ(daq1);
            session.addDAQ(daq2);

            [~, syncfname, ext] = fileparts(syncfile);
            rule = filefind(struct('number_fullpath_matches', 1, ...
                'syncfilename', [syncfname ext], ...
                'daqsystem1', 'daq1', ...
                'daqsystem2', 'daq2'));

            node1 = struct('objectname', 'daq1', 'epoch_id', 'e1', ...
                'objectclass', 'ndi.unittest.time.syncrule.MockMFDAQ', ...
                'underlying_epochs', struct('underlying', {{'common.dat', syncfile}}));
            node2 = struct('objectname', 'daq2', 'epoch_id', 'e1', ...
                'objectclass', 'ndi.unittest.time.syncrule.MockMFDAQ', ...
                'underlying_epochs', struct('underlying', {{'common.dat', syncfile}}));

            [cost, mapping] = rule.apply(node1, node2, daq1);

            testCase.verifyEqual(cost, 1);
            % T2 = 2*T1 + 10.
            testCase.verifyEqual(mapping.map(1), 12);

            delete(syncfile);
        end
    end
end
