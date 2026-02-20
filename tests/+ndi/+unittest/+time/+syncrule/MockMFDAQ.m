classdef MockMFDAQ < ndi.daq.system.mfdaq
    properties
        Epochs
        Events
        MySession
    end
    methods
        function obj = MockMFDAQ(name, session)
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

        function obj = addEpoch(obj, id, files)
            idx = numel(obj.Epochs) + 1;
            obj.Epochs(idx).epoch_id = id;
            obj.Epochs(idx).underlying_epochs.underlying = files;
             % Add extra fields if needed by epochtable?
             obj.Epochs(idx).epoch_session_id = 'sess1';
             obj.Epochs(idx).epoch_clock = {ndi.time.clocktype('dev_local_time')};
             obj.Epochs(idx).t0_t1 = {[0 100]};
        end

        function obj = addEvents(obj, epoch_id, type, ch, times)
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
             if iscell(type), type = type{1}; end
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
