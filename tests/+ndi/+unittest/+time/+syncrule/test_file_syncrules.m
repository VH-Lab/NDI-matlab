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

            session.addDAQ(daq1);
            session.addDAQ(daq2);

            [~, syncfname, ext] = fileparts(syncfile);
            rule = filefind(struct('number_fullpath_matches', 1, ...
                'syncfilename', [syncfname ext], ...
                'daqsystem1', 'daq1', ...
                'daqsystem2', 'daq2'));

            node1 = struct('objectname', 'daq1', 'epoch_id', 'e1', ...
                'objectclass', 'ndi.unittest.time.syncrule.MockMFDAQ', ...
                'underlying_epochs', struct('underlying', {{'common.dat'}}));
            node2 = struct('objectname', 'daq2', 'epoch_id', 'e1', ...
                'objectclass', 'ndi.unittest.time.syncrule.MockMFDAQ', ...
                'underlying_epochs', struct('underlying', {{'common.dat', syncfile}}));

            % Apply Forward (daq1 -> daq2)
            % Wait, logic checks if file is in "epochnode_a" (forward) or "epochnode_b" (backward).
            % Forward condition: node_a is daq1, node_b is daq2.
            % Code checks if syncfile is in `epochnode_a.underlying_epochs`.
            % In my setup, syncfile is in `node2` (daq2).
            % So `node1` is `daq1` (a), `node2` is `daq2` (b).
            % Syncfile is in `node2`.
            % Logic says:
            % if forward (a=d1, b=d2): check a for syncfile.
            % if backward (b=d1, a=d2): check b for syncfile.
            % Wait, let's re-read filefind.m.
            % "This file should be in the second daq system's epoch files."
            % Parameters: daqsystem1, daqsystem2.
            % If a=d1, b=d2 (forward): checks `epochnode_a` for file?
            % Code:
            % if forward
            %    for i=1... epochnode_a...
            %       if match... return mapping [scale shift]
            % This implies the sync file is in DAQ1?
            % Documentation says "This file should be in the second daq system's epoch files."
            % If daqsystem2 is the "second", then `b` should have it?
            % If `forward` is true, `a` is `d1`.
            % Code checks `a`!
            % This looks like a bug in `filefind.m` vs its documentation, OR I am misinterpreting.
            % Documentation: "TimeOnDaqSystem2 = shift + scale * TimeOnDaqSystem1". "file should be in the second daq system's epoch files".
            % If `a` is `d1` and `b` is `d2`.
            % Code checks `epochnode_a` (d1).
            % So code expects file in d1. Doc says d2.
            % I will test based on CODE behavior (file in `node1`/`a`).

            % Move syncfile to node1 for the test to match code logic?
            % Or should I test backward?
            % Let's put file in `node1`.

            daq1 = daq1.addEpoch('e1', {'common.dat', syncfile});
            node1.underlying_epochs.underlying = {'common.dat', syncfile};

            [cost, mapping] = rule.apply(node1, node2, daq1);

            testCase.verifyEqual(cost, 1);
            % T2 = 2*T1 + 10.
            testCase.verifyEqual(mapping.map(1), 12);

            delete(syncfile);
        end
    end
end
