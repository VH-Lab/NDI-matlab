classdef MockAnalogDAQReader < ndi.daq.reader.mfdaq
    % MockAnalogDAQReader - Mock reader that produces a known analog waveform for testing
    %
    % Generates a ramp from 0 to 5 over 10 seconds at 1000 Hz.
    % This crosses threshold 2.5 at exactly t=5.0.

    methods
        function obj = MockAnalogDAQReader(varargin)
            obj = obj@ndi.daq.reader.mfdaq(varargin{:});
        end

        function ec = epochclock(obj, epochfiles)
            ec = {ndi.time.clocktype('dev_local_time')};
        end

        function t0t1 = t0_t1(obj, epochfiles)
            t0t1 = {[0 10]};
        end

        function channels = getchannelsepoch(obj, epochfiles)
            channels = struct('name', 'ai1', 'type', 'analog_in', 'time_channel', 1);
        end

        function sr = samplerate(obj, epochfiles, channeltype, channel)
            sr = 1000 * ones(size(channel));
        end

        function data = readchannels_epochsamples(obj, channeltype, channel, epochfiles, s0, s1)
            total_samples = 1000 * 10 + 1;
            if s0 < 1, s0 = 1; end
            if s1 > total_samples, s1 = total_samples; end

            current_samples = s0:s1;
            t = (current_samples(:) - 1) / 1000;

            if (ischar(channeltype) && strcmp(channeltype, 'time')) || ...
               (iscell(channeltype) && any(strcmp(channeltype, 'time')))
                data = t;
                return;
            end

            % Ramp from 0 to 5 over 10 seconds
            data = t * 0.5;  % data = 0.5 * t, so data(t=5) = 2.5
        end
    end
end
