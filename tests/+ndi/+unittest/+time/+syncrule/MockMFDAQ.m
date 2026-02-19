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
            obj.Epochs(idx).underlying_epochs = struct('underlying', {{files}});
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
