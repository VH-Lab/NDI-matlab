classdef VHAudreyBPodNP < ndi.daq.reader.mfdaq.ndr
    % NDI.SETUP.DAQ.READER.MFDAQ.STIMULUS.VHAUDREYBPODNP - Reader for VHAudreyBPod triggers acquired on Neuropixels GLX
    %
    % This class reads stimulus trigger events for the VHAudreyBPod system when
    % the triggers are acquired on the NI-DAQ device of a SpikeGLX / Neuropixels GLX
    % recording. The stimulus trigger TTL is expected on NI-DAQ digital input 1
    % ('di1'), and stimulus identities are read from the VHAudreyBPod stimulus
    % triggers TSV log file (typically located in an Epoch_Set_X subdirectory of
    % each epoch directory).
    %
    % It provides 5 channels (mirroring ndi.setup.daq.reader.mfdaq.stimulus.VHAudreyBPod):
    %   e1: Event, stimulus start time (rising edge on di1)
    %   e2: Event, stimulus end time (falling edge on di1)
    %   mk1: Marker, stimulus on/off pairs (stim on = +1, stim off = -1)
    %   mk2: Marker, stimulus start times with stimid value
    %   mk3: Marker, stimulus end times with -1
    %
    % Times are returned in the local device clock of the SpikeGLX NI-DAQ
    % ('dev_local_time'), matching the clock reported by
    % ndi.setup.daq.reader.mfdaq.stimulus.nielsenvisneuropixelsglx so that
    % synchronization with vhneuropixelsGLX works via standard file-match rules.
    %

    methods
        function obj = VHAudreyBPodNP(varargin)
            % VHAUDREYBPODNP - Create a new VHAudreyBPodNP reader object
            %
            % OBJ = NDI.SETUP.DAQ.READER.MFDAQ.STIMULUS.VHAUDREYBPODNP()
            %
            % Creates a new VHAudreyBPodNP reader. The underlying NDR reader is
            % set to 'neuropixelsGLX' so that the NI-DAQ channels can be read
            % from SpikeGLX .nidq.bin files.
            obj = obj@ndi.daq.reader.mfdaq.ndr('neuropixelsGLX');
        end

        function ec = epochclock(obj, epochfiles)
            % EPOCHCLOCK - return the ndi.time.clocktype objects for an epoch
            ec = {ndi.time.clocktype('dev_local_time')};
        end

        function channels = getchannelsepoch(obj, epochfiles)
            % GETCHANNELSEPOCH - List the channels available in this epoch
            channels        = struct('name','e1','type','event','time_channel',NaN);
            channels(end+1) = struct('name','e2','type','event','time_channel',NaN);
            channels(end+1) = struct('name','mk1','type','marker','time_channel',NaN);
            channels(end+1) = struct('name','mk2','type','marker','time_channel',NaN);
            channels(end+1) = struct('name','mk3','type','marker','time_channel',NaN);
        end

        function [timestamps, data] = readevents_epochsamples_native(obj, channeltype, channel, epochfiles, t0, t1)
            % READEVENTS_EPOCHSAMPLES_NATIVE - Read events from the VHAudreyBPodNP epoch
            %
            % Reads the stimulus IDs from the _stimulus_triggers_log.tsv file
            % and pairs them with the TTL rising/falling edges on the NI-DAQ
            % digital input 1 ('di1') to produce stimulus events in the
            % device-local NI-DAQ time.

            timestamps = {};
            data = {};

            if ~iscell(channeltype)
                channeltype = repmat({channeltype}, numel(channel), 1);
            end

            % Find the TSV file among the epoch files
            tsvFile = '';
            for i = 1:numel(epochfiles)
                if endsWith(lower(epochfiles{i}), '_stimulus_triggers_log.tsv')
                    tsvFile = epochfiles{i};
                    break;
                end
            end
            if isempty(tsvFile)
                error('No _stimulus_triggers_log.tsv file found in epochfiles.');
            end

            % Parse TSV data
            % Format: Solenoid_Valve_Number (1), Open_Times (2), StartTime (3), EndTime (4)
            try
                M = dlmread(tsvFile, '\t', 1, 0);
            catch
                M = load(tsvFile);
            end

            raw_valve    = M(:,1);
            raw_opentime = M(:,2);

            % Calculate StimID (matches VHAudreyBPod convention):
            % If Open_Times > 5, stimid = 7, else stimid = Solenoid_Valve_Number
            stimid = raw_valve;
            stimid(raw_opentime > 5) = 7;

            % Read the NI-DAQ digital input 1 TTL from the SpikeGLX nidq.bin
            ndrEpochFiles = ndi.setup.daq.reader.mfdaq.stimulus.VHAudreyBPodNP.filter_epochfiles(epochfiles);

            srt = obj.samplerate(epochfiles, 'time', 1);
            s0d = max(1, round(1 + round(srt * t0)));
            s1d = round(1 + round(srt * t1));

            digitalData = readchannels_epochsamples@ndi.daq.reader.mfdaq.ndr(obj, ...
                'digital_in', 1, ndrEpochFiles, s0d, s1d);
            timeData = readchannels_epochsamples@ndi.daq.reader.mfdaq.ndr(obj, ...
                'time', 1, ndrEpochFiles, s0d, s1d);

            digitalData = double(digitalData(:) > 0);
            timeData    = timeData(:);

            % Detect rising and falling edges on di1 (with a short refractory)
            refractory_samples = max(1, round(0.001 * srt));
            pos_crossings = find(digitalData(1:end-1) < 0.5 & digitalData(2:end) >= 0.5) + 1;
            neg_crossings = find(digitalData(1:end-1) >= 0.5 & digitalData(2:end) < 0.5) + 1;
            pos_crossings = vlt.signal.refractory(pos_crossings, refractory_samples);
            neg_crossings = vlt.signal.refractory(neg_crossings, refractory_samples);

            stimontimes  = timeData(pos_crossings);
            stimofftimes = timeData(neg_crossings);

            % Align the parsed stim IDs with the detected TTL rising edges.
            % If there is a mismatch (e.g. aborted trials), use the first N.
            N = min(numel(stimontimes), numel(stimid));

            for i = 1:numel(channel)
                switch ndi.daq.system.mfdaq.mfdaq_prefix(channeltype{i})
                    case 'e'
                        if channel(i) == 1 % e1: stimulus start times
                            ts = stimontimes(:);
                            d  = ones(size(ts));
                        elseif channel(i) == 2 % e2: stimulus end times
                            ts = stimofftimes(:);
                            d  = ones(size(ts));
                        else
                            error(['Unknown event channel ' num2str(channel(i))]);
                        end
                    case 'mk'
                        if channel(i) == 1 % mk1: alternating stim on/off
                            nPairs = min(numel(stimontimes), numel(stimofftimes));
                            on_t  = stimontimes(1:nPairs);
                            off_t = stimofftimes(1:nPairs);
                            time1 = [on_t(:)' ; off_t(:)'];
                            data1 = [ones(size(on_t(:)')) ; -1*ones(size(off_t(:)'))];
                            ts = reshape(time1, numel(time1), 1);
                            d  = reshape(data1, numel(data1), 1);
                        elseif channel(i) == 2 % mk2: stim start times with stimid
                            ts = stimontimes(1:N);
                            d  = stimid(1:N);
                        elseif channel(i) == 3 % mk3: stim end times with -1
                            ts = stimofftimes(:);
                            d  = -1 * ones(size(ts));
                        else
                            error(['Unknown marker channel ' num2str(channel(i))]);
                        end
                    otherwise
                        error(['Unknown channel type ' channeltype{i}]);
                end

                % Filter by time window t0, t1
                valid = (ts >= t0) & (ts <= t1);
                timestamps{i} = ts(valid);
                data{i}       = d(valid);
            end

            if numel(data) == 1
                timestamps = timestamps{1};
                data = data{1};
            end
        end % readevents_epochsamples_native

        function data = readchannels_epochsamples(obj, channeltype, channel, epochfiles, s0, s1)
            % READCHANNELS_EPOCHSAMPLES - read channel data, filtering epochfiles for the ndr reader
            epochfiles = ndi.setup.daq.reader.mfdaq.stimulus.VHAudreyBPodNP.filter_epochfiles(epochfiles);
            data = readchannels_epochsamples@ndi.daq.reader.mfdaq.ndr(obj, channeltype, channel, epochfiles, s0, s1);
        end

        function sr = samplerate(obj, epochfiles, channeltype, channel)
            % SAMPLERATE - get the sample rate for a specific channel
            epochfiles = ndi.setup.daq.reader.mfdaq.stimulus.VHAudreyBPodNP.filter_epochfiles(epochfiles);
            sr = samplerate@ndi.daq.reader.mfdaq.ndr(obj, epochfiles, channeltype, channel);
        end

        function t0t1 = t0_t1(obj, epochfiles)
            % T0_T1 - return the beginning and end epoch times for an epoch
            epochfiles = ndi.setup.daq.reader.mfdaq.stimulus.VHAudreyBPodNP.filter_epochfiles(epochfiles);
            t0t1 = t0_t1@ndi.daq.reader.mfdaq.ndr(obj, epochfiles);
        end

    end % methods

    methods (Static)
        function epochfiles = filter_epochfiles(epochfiles)
            % FILTER_EPOCHFILES - remove files that the neuropixelsGLX NDR reader should not see
            %
            %  EPOCHFILES = FILTER_EPOCHFILES(EPOCHFILES)
            %
            %  Removes .tsv and .json stimulus log files from the list so the
            %  neuropixelsGLX NDR reader only sees SpikeGLX .bin / .meta files.
            %  Any .meta file without a matching .bin file is also removed so
            %  that the neuropixelsGLX reader sees a consistent set.
            %
            keep = true(size(epochfiles));
            for i = 1:numel(epochfiles)
                lf = lower(epochfiles{i});
                if endsWith(lf, '.tsv') || endsWith(lf, '.json') || endsWith(lf, '.txt')
                    keep(i) = false;
                end
            end
            epochfiles = epochfiles(keep);

            bin_bases = {};
            for i = 1:numel(epochfiles)
                if endsWith(epochfiles{i}, '.bin')
                    bin_bases{end+1} = epochfiles{i}(1:end-4); %#ok<AGROW>
                end
            end
            keep = true(size(epochfiles));
            for i = 1:numel(epochfiles)
                if endsWith(epochfiles{i}, '.meta')
                    meta_base = epochfiles{i}(1:end-5);
                    if ~any(strcmp(meta_base, bin_bases))
                        keep(i) = false;
                    end
                end
            end
            epochfiles = epochfiles(keep);
        end
    end % static methods
end
