classdef MockProbe < ndi.epoch.epochset
    properties
        session
    end
    methods
        function obj = MockProbe(session)
            obj.session = session;
        end
        function [data, t, timeref] = readtimeseries(obj, timeref, t0, t1)
             data.stimid = [1 2 3];
             t.stimon = [0 10 20];
             t.stimoff = [5 15 25];
             % Return the input timeref as the output timeref
             timeref = timeref;
        end

        function name = epochsetname(obj)
            name = 'mock_probe';
        end

        function eid = epochid(obj, epoch_number)
            eid = 'epoch_1';
        end

        function et = epochtable(obj)
             et = struct('epoch_id', 'epoch_1', 'epoch_clock', {ndi.time.clocktype('dev_local_time')}, ...
                 't0_t1', {[0 30]}, 'epoch_session_id', obj.session.id());
        end
    end
end
