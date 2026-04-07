classdef MockPulseAnalogDAQReader < ndi.daq.reader.mfdaq
    % MockPulseAnalogDAQReader - Mock reader that produces analog pulses for testing
    %
    % Generates a signal at 1000 Hz for 10 seconds:
    %   - Baseline at 0
    %   - Pulse to 5.0 from t=1.0 to t=1.1 (100 samples)
    %   - Pulse to 5.0 from t=3.0 to t=3.1 (100 samples)
    %
    % With threshold 2.5:
    %   - Upward crossings at t=1.0 and t=3.0
    %   - Downward crossings at t=1.1 and t=3.1

    methods
        function obj = MockPulseAnalogDAQReader(varargin)
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

            % Baseline 0, pulses to 5.0
            data = zeros(numel(t), 1);
            mask = (t >= 1.0 & t < 1.1) | (t >= 3.0 & t < 3.1);
            data(mask) = 5.0;
        end
    end
end
