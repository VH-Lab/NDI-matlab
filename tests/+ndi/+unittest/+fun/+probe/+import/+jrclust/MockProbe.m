classdef MockProbe < handle
    % MOCKPROBE - a minimal stand-in for an ndi.probe in the JRCLUST tests.
    %
    % Two epochs of 100 samples each at 1000 Hz, with a 'dev_local_time' clock.

    properties
        name = 'mockctx'
        reference = 1
        idString = 'mock_probe_id'
        epochIds = {'epoch1','epoch2'}
        sampleRate = 1000
        epochDuration = 0.099  % 100 samples at 1000 Hz, 1-based
        clockType = 'dev_local_time'  % the clock the epochs are kept in
    end

    methods
        function str = elementstring(obj)
            str = [obj.name ' | ' int2str(obj.reference)];
        end

        function i = id(obj)
            i = obj.idString;
        end

        function et = epochtable(obj)
            et = struct('epoch_id',{},'epoch_clock',{},'t0_t1',{});
            for i=1:numel(obj.epochIds)
                et(i).epoch_id = obj.epochIds{i};
                et(i).epoch_clock = {ndi.time.clocktype(obj.clockType)};
                et(i).t0_t1 = {[0 obj.epochDuration]};
            end
        end

        function samples = times2samples(obj, ~, t)
            samples = round(t * obj.sampleRate) + 1; % 1-based
        end

        function t = samples2times(obj, ~, samples)
            t = (double(samples)-1) / obj.sampleRate;
        end

        function sr = samplerate(obj, ~)
            sr = obj.sampleRate;
        end
    end
end
