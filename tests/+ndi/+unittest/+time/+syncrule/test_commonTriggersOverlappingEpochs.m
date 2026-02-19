classdef test_commonTriggersOverlappingEpochs < matlab.unittest.TestCase

    methods (Test)

        function testParameterValidation(testCase)
            import ndi.time.syncrule.commonTriggersOverlappingEpochs;

            % Test default constructor
            obj = commonTriggersOverlappingEpochs();
            testCase.verifyClass(obj, 'ndi.time.syncrule.commonTriggersOverlappingEpochs');

            % Test invalid params
            params = struct('daqsystem1_name', 123); % Invalid
            % We expect an error, but the ID might be empty or generic
            try
                commonTriggersOverlappingEpochs(params);
                testCase.verifyFail('Expected exception was not thrown');
            catch
                % Expected
            end
        end

        function testApplyWithOverlap(testCase)
            import ndi.time.syncrule.commonTriggersOverlappingEpochs;
            import ndi.unittest.time.syncrule.MockSession;
            import ndi.unittest.time.syncrule.MockMFDAQ;

            % Setup Mocks
            session = MockSession();
            daq1 = MockMFDAQ('daq1', session);
            daq2 = MockMFDAQ('daq2', session);
            session.addDAQ(daq1);
            session.addDAQ(daq2);

            % Setup Epochs with embedded overlap (grandparent of A matches parent of B)
            % A: /data/sess1/e1/f1.dat. GP: /data/sess1
            % B: /data/sess1/f2.dat. P: /data/sess1

            daq1 = daq1.addEpoch('e1', {'/data/sess1/e1/f1.dat'});
            daq2 = daq2.addEpoch('e1', {'/data/sess1/f2.dat'});

            % Setup Triggers
            % DAQ1: [0 1 2 3 4]
            % DAQ2: [10 12 14 16 18] -> T2 = 2*T1 + 10. Scale=2, Shift=10.

            daq1 = daq1.addEvents('e1', 'dep', 1, [0 1 2 3 4]');
            daq2 = daq2.addEvents('e1', 'mk', 1, [10 12 14 16 18]');

            % Add DAQs to session AFTER modification (since they are value classes)
            session.addDAQ(daq1);
            session.addDAQ(daq2);

            % Create Rule
            params = struct('daqsystem1_name','daq1', 'daqsystem2_name','daq2', ...
                'daqsystem_ch1','dep1', 'daqsystem_ch2','mk1', ...
                'epochclocktype','dev_local_time', ...
                'minEmbeddedFileOverlap', 1, 'errorOnFailure', true);

            rule = commonTriggersOverlappingEpochs(params);

            % Create Epoch Nodes (Inputs to apply)
            node1 = struct('objectname', 'daq1', 'epoch_id', 'e1', ...
                'epoch_clock', struct('type','dev_local_time'), ...
                'underlying_epochs', struct('underlying', {{'/data/sess1/e1/f1.dat'}}));
            node2 = struct('objectname', 'daq2', 'epoch_id', 'e1', ...
                'epoch_clock', struct('type','dev_local_time'), ...
                'underlying_epochs', struct('underlying', {{'/data/sess1/f2.dat'}}));

            % Apply
            [cost, mapping] = rule.apply(node1, node2, daq1);

            % Verify
            testCase.verifyEqual(cost, 1);

            % Mapping should be DAQ1 -> DAQ2
            % T2 = 2*T1 + 10.
            % mapping.map(T1) should equal T2.
            t_out = mapping.map(1); % 1 -> 12
            testCase.verifyEqual(t_out, 12, 'AbsTol', 1e-5);

            % Test Reverse Application (apply called with B, A)
            % [cost, mapping] = rule.apply(node2, node1, daq2);
            % Should return mapping DAQ2 -> DAQ1.
            % T1 = 0.5*T2 - 5.
            % map(12) -> 1.

            [cost_r, mapping_r] = rule.apply(node2, node1, daq2);
            testCase.verifyEqual(cost_r, 1);
            t_out_r = mapping_r.map(12);
            testCase.verifyEqual(t_out_r, 1, 'AbsTol', 1e-5);

        end

         function testApplyExpandedOverlap(testCase)
            import ndi.time.syncrule.commonTriggersOverlappingEpochs;
            import ndi.unittest.time.syncrule.MockSession;
            import ndi.unittest.time.syncrule.MockMFDAQ;

            % Setup Mocks
            session = MockSession();
            daq1 = MockMFDAQ('daq1', session);
            daq2 = MockMFDAQ('daq2', session);
            session.addDAQ(daq1);
            session.addDAQ(daq2);

            % Chain of overlaps:
            % E1: A has /data/p1/e1/f1.dat (GP=/data/p1). B has /data/p1/f2.dat (P=/data/p1). Match.
            % E2: A has /data/p2/e2/f3.dat (GP=/data/p2). B has /data/p2/f4.dat (P=/data/p2). Match.
            % B also has /data/p1/fX.dat in E1 so E1 is connected.

            daq1 = daq1.addEpoch('e1', {'/data/p1/e1/f1.dat'});
            daq2 = daq2.addEpoch('e1', {'/data/p1/f2.dat'});

            daq1 = daq1.addEpoch('e2', {'/data/p2/e2/f3.dat'});
            % Make sure daq2 e1 and e2 are connected or daq1 e1 and e2 are connected?
            % The logic finds ALL epochs in A and B that are connected via overlaps.
            % If we start with E1. A-E1 matches B-E1.
            % Does A-E1 match anything else? No.
            % Does B-E1 match anything else?
            % If B-E1 had a file that matched A-E2?
            % Let's make B-E1 have 2 files: /data/p1/f2.dat and /data/p2/fX.dat.
            % Then /data/p2/fX.dat (P=/data/p2) matches A-E2 (/data/p2/e2/f3.dat, GP=/data/p2).

            daq2 = daq2.addEpoch('e1', {'/data/p1/f2.dat', '/data/p2/fX.dat'});

            % Triggers (Linear: T2 = T1 + 5)
            daq1 = daq1.addEvents('e1', 'dep', 1, [0 10]');
            daq2 = daq2.addEvents('e1', 'mk', 1, [5 15]');

            daq1 = daq1.addEvents('e2', 'dep', 1, [20 30]');
            % daq2 triggers for e1 are already added.
            % daq2 needs e2 triggers? No, daq2 has e1.
            % Wait, does daq2 have e2?
            % I didn't add e2 to daq2.
            % But I added file /data/p2/fX.dat to daq2 E1.
            % So daq2 E1 matches daq1 E2.
            % So daq1 E2 is included.

            % Manually set t0 for epochs to ensure order
            % E1 starts at 0, E2 starts at 20
            % Find indices.
            % DAQ1
            for i=1:numel(daq1.Epochs)
                if strcmp(daq1.Epochs(i).epoch_id, 'e1')
                    daq1.Epochs(i).t0_t1 = {[0 10]};
                elseif strcmp(daq1.Epochs(i).epoch_id, 'e2')
                    daq1.Epochs(i).t0_t1 = {[20 30]};
                end
            end
            % DAQ2
             for i=1:numel(daq2.Epochs)
                if strcmp(daq2.Epochs(i).epoch_id, 'e1')
                    daq2.Epochs(i).t0_t1 = {[5 15]};
                end
            end

            % Add DAQs to session AFTER modification
            session.addDAQ(daq1);
            session.addDAQ(daq2);

            % Rule
            params = struct('daqsystem1_name','daq1', 'daqsystem2_name','daq2', ...
                'daqsystem_ch1','dep1', 'daqsystem_ch2','mk1', ...
                'epochclocktype','dev_local_time', ...
                'minEmbeddedFileOverlap', 1, 'errorOnFailure', true);
            rule = commonTriggersOverlappingEpochs(params);

            % Start with E1 nodes
             node1 = struct('objectname', 'daq1', 'epoch_id', 'e1', ...
                'epoch_clock', struct('type','dev_local_time'), ...
                'underlying_epochs', struct('underlying', {{'/data/p1/e1/f1.dat'}}));
             node2 = struct('objectname', 'daq2', 'epoch_id', 'e1', ...
                'epoch_clock', struct('type','dev_local_time'), ...
                'underlying_epochs', struct('underlying', {{'/data/p1/f2.dat', '/data/p2/fX.dat'}}));

             [cost, mapping] = rule.apply(node1, node2, daq1);

             testCase.verifyEqual(cost, 1);
             % Should include triggers from daq1 e1 AND daq1 e2.
             % daq1 e1: [0 10]. daq1 e2: [20 30]. Total T1: [0 10 20 30].
             % daq2 e1: [5 15].
             % Wait, T1 and T2 must be same length for syncTriggers.
             % Here T1 has 4, T2 has 2.
             % This setup will FAIL syncTriggers.
             % I need to add triggers to T2 to match.
             % Let's add triggers to daq2 e1 to match all 4.
             % [5 15 25 35].

             daq2 = daq2.addEvents('e1', 'mk', 1, [5 15 25 35]');
             % Re-add to session? No, daq2 is value class, need to re-add.
             session.addDAQ(daq2);

             % Re-run apply
             [cost, mapping] = rule.apply(node1, node2, daq1);

             % Map: T2 = T1 + 5.
             testCase.verifyEqual(mapping.map(100), 105, 'AbsTol', 1e-5);

         end

         function testNoOverlap(testCase)
            import ndi.time.syncrule.commonTriggersOverlappingEpochs;
            import ndi.unittest.time.syncrule.MockSession;
            import ndi.unittest.time.syncrule.MockMFDAQ;

            session = MockSession();
            daq1 = MockMFDAQ('daq1', session);
            daq2 = MockMFDAQ('daq2', session);

            % Different parents
            daq1 = daq1.addEpoch('e1', {'/data/sess1/e1/f1.dat'});
            daq2 = daq2.addEpoch('e1', {'/data/sess2/f2.dat'});

            session.addDAQ(daq1);
            session.addDAQ(daq2);

             % Rule
            params = struct('daqsystem1_name','daq1', 'daqsystem2_name','daq2', ...
                'daqsystem_ch1','dep1', 'daqsystem_ch2','mk1', ...
                'epochclocktype','dev_local_time', ...
                'minEmbeddedFileOverlap', 1, 'errorOnFailure', true);
            rule = commonTriggersOverlappingEpochs(params);

             node1 = struct('objectname', 'daq1', 'epoch_id', 'e1', ...
                'epoch_clock', struct('type','dev_local_time'), ...
                'underlying_epochs', struct('underlying', {{'/data/sess1/e1/f1.dat'}}));
             node2 = struct('objectname', 'daq2', 'epoch_id', 'e1', ...
                'epoch_clock', struct('type','dev_local_time'), ...
                'underlying_epochs', struct('underlying', {{'/data/sess2/f2.dat'}}));

            [cost, mapping] = rule.apply(node1, node2, daq1);

            testCase.verifyEmpty(cost);
            testCase.verifyEmpty(mapping);
         end
    end
end
