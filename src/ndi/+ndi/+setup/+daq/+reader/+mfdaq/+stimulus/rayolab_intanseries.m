classdef rayolab_intanseries < ndi.daq.reader.mfdaq.ndr
    %NDI.SETUP.DAQ.READER.MFDAQ.STIMULUS.RAYOLAB_INTANSERIES Stimulus reader for RayoLab Intan series.
    %
    %   This stimulus reader exposes stimulus on/off and stimulus id event
    %   channels derived from a single digital input recorded on an Intan
    %   RHD acquisition system. The acquisition data are read via NDR
    %   (ndi.daq.reader.mfdaq.ndr with the "intan" reader), so the
    %   constructor takes the same arguments as ndi.daq.reader.mfdaq.ndr.
    %
    %   The stimulus protocol is:
    %     - Digital input 1 idles high (logical 1) and pulses low (logical 0)
    %       during a stimulus presentation.
    %     - A high-to-low (positive-to-negative) transition marks stimulus
    %       onset.
    %     - A low-to-high (negative-to-positive) transition marks stimulus
    %       offset.
    %     - There is no separate setup or teardown signal; onset and offset
    %       times are reported as-is.
    %
    %   The reader produces the following channels per epoch (matching the
    %   conventional mk1 / mk2 layout used by vhlab and Nielsen lab readers):
    %
    %     Channel name | Signal description
    %     -------------|-------------------------------------------
    %     mk1          | Stimulus on/off (alternating +1 / -1)
    %     mk2          | Stimulus id (always 1, one entry per onset)
    %
    %   See also NDI.DAQ.READER.MFDAQ.NDR,
    %            NDI.DAQ.METADATAREADER.RAYOLABSTIMS,
    %            NDI.SETUP.DAQ.READER.MFDAQ.STIMULUS.NIELSENVISINTAN

    methods
        function obj = rayolab_intanseries(varargin)
            %RAYOLAB_INTANSERIES Construct a RayoLab Intan-series stimulus reader.
            %
            %   D = RAYOLAB_INTANSERIES(READER_STRING) creates the reader
            %   and forwards READER_STRING to ndi.daq.reader.mfdaq.ndr.
            %   Use "intan" (or "RHD" / "intanRHD") for Intan RHD files.
            obj = obj@ndi.daq.reader.mfdaq.ndr(varargin{:});
        end

        function ec = epochclock(~, ~)
            %EPOCHCLOCK Return the device-local clock for an epoch.
            ec = {ndi.time.clocktype('dev_local_time')};
        end

        function channels = getchannelsepoch(~, ~)
            %GETCHANNELSEPOCH List the marker channels exposed by this reader.
            channels        = struct('name','mk1','type','marker','time_channel',NaN);
            channels(end+1) = struct('name','mk2','type','marker','time_channel',NaN);
        end

        function [timestamps, data] = readevents_epochsamples_native(obj, channeltype, channel, epochfiles, t0, t1)
            %READEVENTS_EPOCHSAMPLES_NATIVE Read marker events for an epoch.
            %
            %   [TIMESTAMPS, DATA] = READEVENTS_EPOCHSAMPLES_NATIVE(OBJ,
            %   CHANNELTYPE, CHANNEL, EPOCHFILES, T0, T1) reads digital
            %   input 1 for the requested epoch, derives stimulus on/off
            %   times from its transitions, and returns the marker stream
            %   for the requested channels (mk1 and/or mk2). T0 and T1
            %   bound the returned timestamps in seconds of the device
            %   local clock.
            timestamps = {};
            data = {};

            if ~iscell(channeltype)
                channeltype = repmat({channeltype}, numel(channel), 1);
            end

            srt = obj.samplerate(epochfiles, 'time', 1);
            s0d = round(1 + round(srt * t0));
            s1d = round(1 + round(srt * t1));

            digData  = obj.readchannels_epochsamples('digital_in', 1, ...
                epochfiles, s0d, s1d);
            timeData = obj.readchannels_epochsamples('time', 1, ...
                epochfiles, s0d, s1d);

            % Stimulus onset = positive-to-negative (1 -> 0) edge.
            % Stimulus offset = negative-to-positive (0 -> 1) edge.
            stimontimes  = timeData(1 + find(digData(1:end-1) == 1 & digData(2:end) == 0));
            stimofftimes = timeData(1 + find(digData(1:end-1) == 0 & digData(2:end) == 1));

            % mk1: alternating on/off markers (+1 / -1)
            time1 = [stimontimes(:)' ; stimofftimes(:)'];
            data1 = [ones(size(stimontimes(:)')) ; -1 * ones(size(stimofftimes(:)'))];
            time1 = reshape(time1, numel(time1), 1);
            data1 = reshape(data1, numel(data1), 1);

            % mk2: stimulus id (always 1) at each onset
            time2 = stimontimes(:);
            data2 = ones(size(time2));

            ch{1} = [time1 data1];
            ch{2} = [time2 data2];

            for i = 1:numel(channel)
                switch ndi.daq.system.mfdaq.mfdaq_prefix(channeltype{i})
                    case 'mk'
                        timestamps{i} = ch{channel(i)}(:,1);
                        data{i}       = ch{channel(i)}(:,2:end);
                    otherwise
                        error('Unknown channel type "%s".', channeltype{i});
                end
            end

            for i = 1:numel(timestamps)
                inds_here = find(timestamps{i} >= t0 & timestamps{i} <= t1);
                timestamps{i} = timestamps{i}(inds_here);
                data{i}       = data{i}(inds_here, :);
            end

            if numel(data) == 1
                timestamps = timestamps{1};
                data = data{1};
            end
        end

        function sr = samplerate(obj, epochfiles, channeltype, channel)
            %SAMPLERATE Sample rate for the requested channel.
            sr = samplerate@ndi.daq.reader.mfdaq.ndr(obj, epochfiles, channeltype, channel);
        end
    end
end
