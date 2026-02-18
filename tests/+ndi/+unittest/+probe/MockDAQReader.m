classdef MockDAQReader < ndi.daq.reader.mfdaq
    methods
        function obj = MockDAQReader(varargin)
            obj = obj@ndi.daq.reader.mfdaq(varargin{:});
        end

        function ec = epochclock(obj, epochfiles)
            ec = {ndi.time.clocktype('dev_local_time')};
        end

        function t0t1 = t0_t1(obj, epochfiles)
            t0t1 = {[0 10]}; % 10 seconds
        end

        function channels = getchannelsepoch(obj, epochfiles)
            channels = struct('name', 'di1', 'type', 'digital_in', 'time_channel', 1);
        end

        function sr = samplerate(obj, epochfiles, channeltype, channel)
            sr = 1000 * ones(size(channel));
        end

        function data = readchannels_epochsamples(obj, channeltype, channel, epochfiles, s0, s1)
            % Generate a square wave on di1
            % transitions at t=1, 2, 3, ...
            % sr=1000. t=1 -> s=1001.

            total_samples = 1000 * 10 + 1;

            % If s0, s1 out of bounds, clip?
            if s0 < 1, s0 = 1; end
            if s1 > total_samples, s1 = total_samples; end

            num_samples = s1 - s0 + 1;
            data = zeros(num_samples, 1);

            % Generate data based on global sample index
            current_samples = s0:s1;

            % Square wave: 1 when mod(t, 2) < 1.
            % t = (s-1)/1000.
            % mod((s-1)/1000, 2) < 1 => high.

            t = (current_samples - 1) / 1000;
            is_high = mod(t, 2) >= 1; % Low 0-1, High 1-2, Low 2-3...
            % Wait, user wants rising events.
            % Let's make it simpler. Pulse at t=1, t=3, t=5.

            % 0 everywhere
            data(:) = 0;

            % Pulse at t=1.0 to t=1.1
            % s from 1001 to 1101.
            mask = (t >= 1.0 & t < 1.1) | (t >= 3.0 & t < 3.1);
            data(mask) = 1;
        end
    end
end
