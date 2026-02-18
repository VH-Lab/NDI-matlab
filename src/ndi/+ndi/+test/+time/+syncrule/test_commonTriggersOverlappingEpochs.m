classdef test_commonTriggersOverlappingEpochs < matlab.unittest.TestCase

    methods (Test)

        function testParameterValidation(testCase)
            import ndi.time.syncrule.commonTriggersOverlappingEpochs;

            % Test default constructor
            obj = commonTriggersOverlappingEpochs();
            testCase.verifyClass(obj, 'ndi.time.syncrule.commonTriggersOverlappingEpochs');

            % Test invalid params
            params = struct('daqsystem1_name', 123); % Invalid
            testCase.verifyError(@() commonTriggersOverlappingEpochs(params), ...
                'ndi:syncrule:setparameters:invalid');
        end

        function testApplyWithOverlap(testCase)
            import ndi.time.syncrule.commonTriggersOverlappingEpochs;

            % Setup Mocks
            session = MockSession();
            daq1 = MockMFDAQ('daq1', session);
            daq2 = MockMFDAQ('daq2', session);
            session.addDAQ(daq1);
            session.addDAQ(daq2);

            % Setup Epochs with overlap
            % Epoch 1 in DAQ1 overlaps with Epoch 1 in DAQ2
            % Files: daq1_e1 has {'file1.dat', 'common.dat'}
            %        daq2_e1 has {'file2.dat', 'common.dat'}

            daq1.addEpoch('e1', {'common.dat', 'f1.dat'});
            daq2.addEpoch('e1', {'common.dat', 'f2.dat'});

            % Setup Triggers
            % DAQ1: [0 1 2 3 4]
            % DAQ2: [10 12 14 16 18] -> T2 = 2*T1 + 10. Scale=2, Shift=10.

            daq1.addEvents('e1', 'dep', 1, [0 1 2 3 4]');
            daq2.addEvents('e1', 'mk', 1, [10 12 14 16 18]');

            % Create Rule
            params = struct('daqsystem1_name','daq1', 'daqsystem2_name','daq2', ...
                'daqsystem_ch1','dep1', 'daqsystem_ch2','mk1', ...
                'epochclocktype','dev_local_time', ...
                'minFileOverlap', 1, 'errorOnFailure', true);

            rule = commonTriggersOverlappingEpochs(params);

            % Create Epoch Nodes (Inputs to apply)
            node1 = struct('objectname', 'daq1', 'epoch_id', 'e1', ...
                'epoch_clock', struct('type','dev_local_time'), ...
                'underlying_epochs', struct('underlying', {{'common.dat', 'f1.dat'}}));
            node2 = struct('objectname', 'daq2', 'epoch_id', 'e1', ...
                'epoch_clock', struct('type','dev_local_time'), ...
                'underlying_epochs', struct('underlying', {{'common.dat', 'f2.dat'}}));

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

            % Setup Mocks
            session = MockSession();
            daq1 = MockMFDAQ('daq1', session);
            daq2 = MockMFDAQ('daq2', session);
            session.addDAQ(daq1);
            session.addDAQ(daq2);

            % Chain of overlaps:
            % DAQ1_E1 overlaps DAQ2_E1
            % DAQ2_E1 overlaps DAQ1_E2
            % DAQ1_E2 overlaps DAQ2_E2

            daq1.addEpoch('e1', {'c1.dat'});
            daq2.addEpoch('e1', {'c1.dat', 'c2.dat'});
            daq1.addEpoch('e2', {'c2.dat', 'c3.dat'});
            daq2.addEpoch('e2', {'c3.dat'});

            % Triggers (Linear: T2 = T1 + 5)
            daq1.addEvents('e1', 'dep', 1, [0 10]');
            daq2.addEvents('e1', 'mk', 1, [5 15]');

            daq1.addEvents('e2', 'dep', 1, [20 30]');
            daq2.addEvents('e2', 'mk', 1, [25 35]');

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
                elseif strcmp(daq2.Epochs(i).epoch_id, 'e2')
                    daq2.Epochs(i).t0_t1 = {[25 35]};
                end
            end

            % Rule
            params = struct('daqsystem1_name','daq1', 'daqsystem2_name','daq2', ...
                'daqsystem_ch1','dep1', 'daqsystem_ch2','mk1', ...
                'epochclocktype','dev_local_time', ...
                'minFileOverlap', 1, 'errorOnFailure', true);
            rule = commonTriggersOverlappingEpochs(params);

            % Start with E1 nodes
             node1 = struct('objectname', 'daq1', 'epoch_id', 'e1', ...
                'epoch_clock', struct('type','dev_local_time'), ...
                'underlying_epochs', struct('underlying', {{'c1.dat'}}));
             node2 = struct('objectname', 'daq2', 'epoch_id', 'e1', ...
                'epoch_clock', struct('type','dev_local_time'), ...
                'underlying_epochs', struct('underlying', {{'c1.dat', 'c2.dat'}}));

             [cost, mapping] = rule.apply(node1, node2, daq1);

             testCase.verifyEqual(cost, 1);
             % Should include triggers from e2 as well
             % T1 total: [0 10 20 30], T2 total: [5 15 25 35]
             % Map: T2 = T1 + 5.
             testCase.verifyEqual(mapping.map(100), 105, 'AbsTol', 1e-5);

         end

         function testNoOverlap(testCase)
            import ndi.time.syncrule.commonTriggersOverlappingEpochs;

            session = MockSession();
            daq1 = MockMFDAQ('daq1', session);
            daq2 = MockMFDAQ('daq2', session);
            session.addDAQ(daq1);
            session.addDAQ(daq2);

            daq1.addEpoch('e1', {'f1.dat'});
            daq2.addEpoch('e1', {'f2.dat'}); % No common file

             % Rule
            params = struct('daqsystem1_name','daq1', 'daqsystem2_name','daq2', ...
                'daqsystem_ch1','dep1', 'daqsystem_ch2','mk1', ...
                'epochclocktype','dev_local_time', ...
                'minFileOverlap', 1, 'errorOnFailure', true);
            rule = commonTriggersOverlappingEpochs(params);

             node1 = struct('objectname', 'daq1', 'epoch_id', 'e1', ...
                'epoch_clock', struct('type','dev_local_time'), ...
                'underlying_epochs', struct('underlying', {{'f1.dat'}}));
             node2 = struct('objectname', 'daq2', 'epoch_id', 'e1', ...
                'epoch_clock', struct('type','dev_local_time'), ...
                'underlying_epochs', struct('underlying', {{'f2.dat'}}));

            [cost, mapping] = rule.apply(node1, node2, daq1);

            testCase.verifyEmpty(cost);
            testCase.verifyEmpty(mapping);
         end
    end
end

% Mocks

classdef MockSession < handle
    properties
        DAQs
    end
    methods
        function obj = MockSession()
            obj.DAQs = struct();
        end
        function addDAQ(obj, daq)
            obj.DAQs.(daq.name) = daq;
        end
        function d = daqsystem_load(obj, varargin)
            % varargin: 'name', name
            name = varargin{2};
            if isfield(obj.DAQs, name)
                d = {obj.DAQs.(name)};
            else
                d = {};
            end
        end
        function docs = database_search(obj, query)
            docs = {};
        end
    end
end

classdef MockMFDAQ < ndi.daq.system.mfdaq
    properties
        Epochs
        Events
        MySession
    end
    methods
        function obj = MockMFDAQ(name, session)
            % Minimal constructor to bypass ndi.daq.system checks
            % We can't easily bypass base constructor validation if we inherit.
            % But ndi.daq.system allows (name, filenavigator, daqreader).
            % We pass empty/dummies.
            % But wait, ndi.daq.system checks inputs.
            % We can use 0 arg constructor and set properties?
            % No, 0 arg constructor sets properties.
            % Actually, we can just call base with (name, [], []).

            % BUT, ndi.daq.system.mfdaq constructor calls base with varargin.
            % And checks daqreader type.
            % So we should pass nothing and set name manually if protected?
            % name is SetAccess=protected.
            % We can't set it easily.
            %
            % Workaround: Pass a dummy reader if needed, or modify behavior.
            % Actually, if we pass NO args, it returns empty obj.
            % But we need to set name.

            % Alternative: Don't inherit from mfdaq for mock, just replicate interface.
            % But `apply` checks `isa(daq, 'ndi.daq.system')`? No, `apply` takes `daqsystem_a`.
            % `apply` doesn't strictly enforce class, but `daqsystem.epochtable` is called.
            % `eligibleepochsets` says `ndi.daq.system`.
            % But inside `apply`, strict type checking isn't done except by method calls.
            % So a struct or simple class works IF MATLAB doesn't check type in signature.
            % `apply` signature: `(obj, epochnode_a, epochnode_b, daqsystem_a)`.
            % It doesn't enforce type.
            % However, I used `daqsystem1 = session.daqsystem_load(...)`.
            % `daqsystem_load` usually returns objects from DB or memory.
            % My mock session returns MockMFDAQ.
            % So if MockMFDAQ has methods, it works.
            %
            % The only issue is `testCase.verifyClass` or `apply` doing `isa`.
            % My code:
            % `apply` doesn't check `isa`.
            % `filematch.m` checks `isa(..., 'ndi.daq.system')`.
            % My code `commonTriggersOverlappingEpochs.m` does NOT check `isa`.
            % So I can use a simple Mock class!

            obj = obj@ndi.daq.system.mfdaq(); % Use 0-arg constructor
            obj.name = name;
            obj.MySession = session;
            obj.Epochs = struct('epoch_id',{}, 'underlying_epochs',{});
            obj.Events = struct();
        end

        % Override base methods to avoid errors
        function ec = epochclock(obj, epoch)
             ec = {ndi.time.clocktype('dev_local_time')};
        end

        function addEpoch(obj, id, files)
            idx = numel(obj.Epochs) + 1;
            obj.Epochs(idx).epoch_id = id;
            obj.Epochs(idx).underlying_epochs = struct('underlying', {files});
             % Add extra fields if needed by epochtable?
             obj.Epochs(idx).epoch_session_id = 'sess1';
             obj.Epochs(idx).epoch_clock = {ndi.time.clocktype('dev_local_time')};
             obj.Epochs(idx).t0_t1 = {[0 100]};
        end

        function addEvents(obj, epoch_id, type, ch, times)
             key = sprintf('%s_%s_%d', epoch_id, type, ch);
             obj.Events.(key) = times;
        end

        function et = epochtable(obj)
            et = obj.Epochs;
        end

        function sess = session(obj)
            sess = obj.MySession;
        end

        function [ts, data] = readevents(obj, type, ch, epoch, t0, t1)
            key = sprintf('%s_%s_%d', epoch, type, ch);
            if isfield(obj.Events, key)
                ts = obj.Events.(key);
            else
                ts = [];
            end
            data = ones(size(ts));
        end
    end
end
