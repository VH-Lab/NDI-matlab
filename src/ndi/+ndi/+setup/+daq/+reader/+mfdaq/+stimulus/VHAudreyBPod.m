classdef VHAudreyBPod < ndi.daq.reader.mfdaq
    % NDI.SETUP.DAQ.READER.MFDAQ.STIMULUS.VHAUDREYBPOD - Reader for VHAudreyBPod stimulus files
    %
    % This class reads stimulus events for the VHAudreyBPod stimulator.
    % Stimulus identities (and wall-clock start / end times) are always
    % parsed from the _stimulus_triggers_log.tsv file in the epoch.
    %
    % The class automatically chooses between two trigger-time sources
    % based on the files present in the epoch:
    %
    %   - If the epoch contains a SpikeGLX NI-DAQ .nidq.bin file (as in
    %     vhajbpod_np / Neuropixels GLX sessions), rising and falling
    %     edges on digital input 1 ('di1') of that file are used as
    %     stimulus start / end times. An internal
    %     ndi.daq.reader.mfdaq.ndr('neuropixelsGLX') reader is lazily
    %     created to read the NI-DAQ channels, and the reader reports
    %     'dev_local_time' as its epoch clock so events align with the
    %     SpikeGLX neuropixelsGLX data.
    %
    %     A single NI-DAQ recording is shared by every Epoch_Set in the
    %     *_g0 run and therefore records the trigger edges of all of the
    %     run's stimulus sets. Each epoch corresponds to one Epoch_Set, so
    %     the reader reads the whole edge train and returns only the
    %     contiguous block belonging to that set (sets are ordered
    %     chronologically and their stimulus counts concatenated). The total
    %     number of NI-DAQ edges must equal the total number of stimuli
    %     across the run's Epoch_Set logs (one trigger per stimulus); if it
    %     does not, an error is raised rather than mis-assigning triggers.
    %
    %   - Otherwise (as in the Intan-based vhtaste_bpod sessions), the
    %     HHMMSS StartTime / EndTime columns of the TSV log are used
    %     directly and the reader falls back to the default mfdaq epoch
    %     clock. Downstream syncgraph rules are responsible for
    %     aligning those seconds-from-midnight times with the other
    %     recording systems.
    %
    % It provides the following channels in both modes:
    %   e1:  Event, stimulus start time
    %   e2:  Event, stimulus end time
    %   mk1: Marker, stimulus start time with value 1
    %   mk2: Marker, stimulus start time with stimid value
    %   mk3: Marker, stimulus end time with value -1
    %

    properties (Access = private)
        % ndrReader - cached ndi.daq.reader.mfdaq.ndr reader used to
        % access the SpikeGLX NI-DAQ digital input when the epoch
        % contains a .nidq.bin file. Created lazily on first use.
        ndrReader = []
    end

    methods
        function obj = VHAudreyBPod(varargin)
            % VHAUDREYBPOD - Create a new VHAudreyBPod reader object
            %
            % OBJ = NDI.SETUP.DAQ.READER.MFDAQ.STIMULUS.VHAUDREYBPOD()
            %
            % Creates a new VHAudreyBPod reader. The reader decides at
            % read time whether to derive trigger timestamps from the
            % TSV HHMMSS columns or from the SpikeGLX NI-DAQ digital
            % input based on which files are present in the epoch.
            obj = obj@ndi.daq.reader.mfdaq(varargin{:});
        end

        function channels = getchannelsepoch(obj, epochfiles)
            % GETCHANNELSEPOCH - List the channels available in this epoch
            channels        = struct('name','e1','type','event','time_channel',NaN);
            channels(end+1) = struct('name','e2','type','event','time_channel',NaN);
            channels(end+1) = struct('name','mk1','type','marker','time_channel',NaN);
            channels(end+1) = struct('name','mk2','type','marker','time_channel',NaN);
            channels(end+1) = struct('name','mk3','type','marker','time_channel',NaN);
        end

        function ec = epochclock(obj, epochfiles)
            % EPOCHCLOCK - return the ndi.time.clocktype objects for an epoch
            %
            % If the epoch contains a SpikeGLX .nidq.bin file the reader
            % returns 'dev_local_time' (because events are extracted
            % directly from the NI-DAQ TTL). Otherwise the default mfdaq
            % epoch clock is returned so existing syncgraph rules still
            % apply to the TSV HHMMSS times.
            %
            if ndi.setup.daq.reader.mfdaq.stimulus.VHAudreyBPod.hasNidqBin(epochfiles)
                ec = {ndi.time.clocktype('dev_local_time')};
            else
                ec = epochclock@ndi.daq.reader.mfdaq(obj, epochfiles);
            end
        end

        function [timestamps, data] = readevents_epochsamples_native(obj, channeltype, channel, epochfiles, t0, t1)
            % READEVENTS_EPOCHSAMPLES_NATIVE - Read events from the epoch

            if ~iscell(channeltype)
                channeltype = repmat({channeltype}, numel(channel), 1);
            end

            % Find and parse this Epoch_Set's TSV stimulus trigger log
            tsvFile = ndi.setup.daq.reader.mfdaq.stimulus.VHAudreyBPod.findTsvFile(epochfiles);
            [stimid, tsv_start_sec, tsv_end_sec] = ...
                ndi.setup.daq.reader.mfdaq.stimulus.VHAudreyBPod.parseAudreyBPodTsv(tsvFile);

            % Decide how to get the stimulus on / off times
            if ndi.setup.daq.reader.mfdaq.stimulus.VHAudreyBPod.hasNidqBin(epochfiles)
                % A single SpikeGLX NI-DAQ recording holds the trigger edges
                % for EVERY Epoch_Set in this *_g0 run, so read the whole edge
                % train (from the start to the end of the recording) and hand
                % this set only the contiguous slice that belongs to it. The
                % number of NI-DAQ trigger edges must equal the total number of
                % stimuli across all of the run's Epoch_Set logs (each stimulus
                % is one trigger); sliceTriggersForSet enforces this with a
                % loud error and does the per-set assignment.
                [allon, alloff] = obj.readNidqTriggers(epochfiles, -Inf, Inf);
                [stimontimes, stimofftimes] = ...
                    ndi.setup.daq.reader.mfdaq.stimulus.VHAudreyBPod.sliceTriggersForSet(...
                        epochfiles, tsvFile, allon, alloff);
            else
                stimontimes  = tsv_start_sec;
                stimofftimes = tsv_end_sec;
            end

            % Assemble event / marker channel outputs
            [timestamps, data] = ...
                ndi.setup.daq.reader.mfdaq.stimulus.VHAudreyBPod.buildAudreyBPodEvents(...
                    channeltype, channel, stimontimes, stimofftimes, stimid, t0, t1);
        end
    end

    methods (Access = private)
        function reader = getNdrReader(obj)
            % GETNDRREADER - lazily create the internal NDR reader used
            % to access the SpikeGLX NI-DAQ in neuropixelsGLX sessions.
            if isempty(obj.ndrReader)
                obj.ndrReader = ndi.daq.reader.mfdaq.ndr('neuropixelsGLX');
            end
            reader = obj.ndrReader;
        end

        function [stimontimes, stimofftimes] = readNidqTriggers(obj, epochfiles, t0, t1)
            % READNIDQTRIGGERS - detect stimulus TTL rising / falling edges
            % on NI-DAQ digital input 1 of the SpikeGLX recording.
            reader = obj.getNdrReader();
            ndrEpochFiles = ndi.setup.daq.reader.mfdaq.stimulus.VHAudreyBPod.filterNidqEpochFiles(epochfiles);

            % Convert the requested time window to NI-DAQ sample indices
            % via the framework helper, which already knows how to map
            % -Inf / +Inf to the first / last sample of the epoch.
            sd = reader.epochtimes2samples('time', 1, ndrEpochFiles, [t0 t1]);
            s0d = sd(1);
            s1d = sd(2);

            srt = reader.samplerate(ndrEpochFiles, 'time', 1);

            digitalData = reader.readchannels_epochsamples('digital_in', 1, ndrEpochFiles, s0d, s1d);
            timeData    = reader.readchannels_epochsamples('time', 1, ndrEpochFiles, s0d, s1d);

            digitalData = double(digitalData(:) > 0);
            timeData    = timeData(:);

            refractory_samples = max(1, round(0.001 * srt));
            pos = find(digitalData(1:end-1) < 0.5 & digitalData(2:end) >= 0.5) + 1;
            neg = find(digitalData(1:end-1) >= 0.5 & digitalData(2:end) < 0.5) + 1;
            pos = vlt.signal.refractory(pos, refractory_samples);
            neg = vlt.signal.refractory(neg, refractory_samples);

            stimontimes  = timeData(pos);
            stimofftimes = timeData(neg);
        end
    end

    methods (Static, Access = private)
        function tf = hasNidqBin(epochfiles)
            % HASNIDQBIN - true if any file in EPOCHFILES is a SpikeGLX
            % .nidq.bin file.
            tf = false;
            for i = 1:numel(epochfiles)
                if endsWith(lower(epochfiles{i}), '.nidq.bin')
                    tf = true;
                    return;
                end
            end
        end

        function tsvFile = findTsvFile(epochfiles)
            % FINDTSVFILE - locate the _stimulus_triggers_log.tsv file in EPOCHFILES.
            tsvFile = '';
            for i = 1:numel(epochfiles)
                [~,~,ext] = fileparts(epochfiles{i});
                if strcmpi(ext, '.tsv')
                    tsvFile = epochfiles{i};
                    return;
                end
            end
            error('No .tsv file found in epochfiles.');
        end

        function [stimontimes, stimofftimes] = sliceTriggersForSet(epochfiles, tsvFile, allon, alloff)
            % SLICETRIGGERSFORSET - return the NI-DAQ trigger edges that belong to one Epoch_Set.
            %
            % [STIMONTIMES, STIMOFFTIMES] = SLICETRIGGERSFORSET(EPOCHFILES, TSVFILE, ALLON, ALLOFF)
            %
            % A single SpikeGLX NI-DAQ recording (shared at the top of the
            % *_g0 run directory) records the trigger edges for every
            % Epoch_Set in the run. ALLON / ALLOFF are the full rising /
            % falling edge times of NI-DAQ digital input 1 for that whole
            % recording. This function finds every Epoch_Set stimulus log
            % under the run directory, orders them chronologically (by the
            % first stimulus start time in each log), and returns the
            % contiguous block of edges that corresponds to the set whose log
            % is TSVFILE.
            %
            % Each stimulus must correspond to exactly one trigger edge, so
            % the total number of rising (and falling) edges must equal the
            % total number of stimuli across all of the run's logs. If it does
            % not, a loud error is raised rather than guessing an assignment.

            import ndi.setup.daq.reader.mfdaq.stimulus.VHAudreyBPod

            g0dir = VHAudreyBPod.runDirOf(epochfiles);
            tsvs  = VHAudreyBPod.findAllTsvsUnder(g0dir);
            if isempty(tsvs)
                error(['VHAudreyBPod: no stimulus-trigger .tsv logs were found under ' g0dir '.']);
            end

            % Count stimuli and earliest start time (for chronological order)
            % for each Epoch_Set log.
            counts = zeros(numel(tsvs),1);
            starts = zeros(numel(tsvs),1);
            for i = 1:numel(tsvs)
                [~, s_start] = VHAudreyBPod.parseAudreyBPodTsv(tsvs{i});
                counts(i) = numel(s_start);
                if isempty(s_start)
                    starts(i) = Inf;
                else
                    starts(i) = min(s_start);
                end
            end
            [~, ord] = sort(starts);
            tsvs   = tsvs(ord);
            counts = counts(ord);

            total = sum(counts);
            non   = numel(allon);
            noff  = numel(alloff);
            if non ~= total || noff ~= total
                error(['VHAudreyBPod: trigger-count mismatch in ' g0dir '. ' ...
                    'NI-DAQ digital input 1 has ' int2str(non) ' rising and ' ...
                    int2str(noff) ' falling edges, but the ' int2str(numel(counts)) ...
                    ' Epoch_Set stimulus log(s) list ' int2str(total) ' stimuli in total. ' ...
                    'Each stimulus must correspond to exactly one NI-DAQ trigger; ' ...
                    'check for missing/extra triggers or an incomplete stimulus log.']);
            end

            idx = VHAudreyBPod.matchTsvIndex(tsvs, tsvFile);
            if isempty(idx)
                error(['VHAudreyBPod: could not locate stimulus log ' tsvFile ...
                    ' among the Epoch_Set logs of ' g0dir '.']);
            end

            offset = sum(counts(1:idx-1));
            n      = counts(idx);
            stimontimes  = allon(offset+1  : offset+n);
            stimofftimes = alloff(offset+1 : offset+n);
        end

        function g0dir = runDirOf(epochfiles)
            % RUNDIROF - the *_g0 SpikeGLX run directory, taken as the folder
            % that holds the shared .nidq.bin file.
            g0dir = '';
            for i = 1:numel(epochfiles)
                if endsWith(lower(epochfiles{i}), '.nidq.bin')
                    g0dir = fileparts(epochfiles{i});
                    return;
                end
            end
            error('VHAudreyBPod: no .nidq.bin file in epoch; cannot locate the SpikeGLX run directory.');
        end

        function tsvs = findAllTsvsUnder(rootdir)
            % FINDALLTSVSUNDER - full paths of every non-hidden
            % *_stimulus_triggers_log.tsv file at or below ROOTDIR (the same
            % files the vhlab_np_epochdir navigator groups into epochs).
            tsvs = {};
            if ~isfolder(rootdir)
                return;
            end
            L = dir(fullfile(rootdir, '**', '*_stimulus_triggers_log.tsv'));
            for i = 1:numel(L)
                if L(i).isdir || L(i).name(1) == '.'
                    continue;
                end
                tsvs{end+1,1} = fullfile(L(i).folder, L(i).name); %#ok<AGROW>
            end
        end

        function idx = matchTsvIndex(tsvs, tsvFile)
            % MATCHTSVINDEX - index of TSVFILE within the cell array TSVS.
            % Matches on the full path first; if that fails (e.g. the paths
            % were formed differently), falls back to a unique basename match.
            idx = find(strcmp(tsvs, tsvFile), 1);
            if ~isempty(idx)
                return;
            end
            [~, nm, ex] = fileparts(tsvFile);
            base = [nm ex];
            hits = [];
            for i = 1:numel(tsvs)
                [~, nmi, exi] = fileparts(tsvs{i});
                if strcmp([nmi exi], base)
                    hits(end+1) = i; %#ok<AGROW>
                end
            end
            if isscalar(hits)
                idx = hits(1);
            else
                idx = [];
            end
        end

        function [stimid, start_seconds, end_seconds] = parseAudreyBPodTsv(tsvFile)
            % PARSEAUDREYBPODTSV - parse a VHAudreyBPod stimulus triggers log.
            %
            % Returns the stim id vector and the HHMMSS start / end
            % times converted to seconds from midnight.
            %
            % Format: Solenoid_Valve_Number (1), Open_Times (2),
            % StartTime HHMMSS (3), EndTime HHMMSS (4)
            try
                M = dlmread(tsvFile, '\t', 1, 0);
            catch
                M = load(tsvFile);
            end

            raw_valve    = M(:,1);
            raw_opentime = M(:,2);
            raw_start    = M(:,3);
            raw_end      = M(:,4);

            start_seconds = floor(raw_start/10000)*3600 + ...
                            floor(mod(raw_start,10000)/100)*60 + ...
                            mod(raw_start,100);
            end_seconds   = floor(raw_end/10000)*3600 + ...
                            floor(mod(raw_end,10000)/100)*60 + ...
                            mod(raw_end,100);

            % StimID: if Open_Times > 5 -> 7 (water / wash), otherwise
            % the solenoid valve number.
            stimid = raw_valve;
            stimid(raw_opentime > 5) = 7;
        end

        function [timestamps, data] = buildAudreyBPodEvents(channeltype, channel, stimontimes, stimofftimes, stimid, t0, t1)
            % BUILDAUDREYBPODEVENTS - assemble the event / marker output
            % arrays for the VHAudreyBPod channel layout.
            %
            %   e1  -> stimontimes,  data = 1
            %   e2  -> stimofftimes, data = 1
            %   mk1 -> stimontimes,  data = 1
            %   mk2 -> stimontimes,  data = stimid
            %   mk3 -> stimofftimes, data = -1
            %
            timestamps = {};
            data = {};

            stimontimes  = stimontimes(:);
            stimofftimes = stimofftimes(:);
            stimid       = stimid(:);

            % Align stimontimes with stimid (guards against aborted trials
            % where the number of triggers differs from the TSV).
            N = min(numel(stimontimes), numel(stimid));

            for i = 1:numel(channel)
                switch channeltype{i}
                    case {'event','e'}
                        if channel(i) == 1
                            ts = stimontimes;
                            d  = ones(size(ts));
                        elseif channel(i) == 2
                            ts = stimofftimes;
                            d  = ones(size(ts));
                        else
                            error(['Unknown event channel ' num2str(channel(i))]);
                        end
                    case {'marker','mk'}
                        if channel(i) == 1
                            ts = stimontimes;
                            d  = ones(size(ts));
                        elseif channel(i) == 2
                            ts = stimontimes(1:N);
                            d  = stimid(1:N);
                        elseif channel(i) == 3
                            ts = stimofftimes;
                            d  = -1 * ones(size(ts));
                        else
                            error(['Unknown marker channel ' num2str(channel(i))]);
                        end
                    otherwise
                        error(['Unknown channel type ' channeltype{i}]);
                end

                valid = (ts >= t0) & (ts <= t1);
                timestamps{i} = ts(valid);
                data{i}       = d(valid);
            end

            if numel(data) == 1
                timestamps = timestamps{1};
                data = data{1};
            end
        end

        function epochfiles = filterNidqEpochFiles(epochfiles)
            % FILTERNIDQEPOCHFILES - reduce EPOCHFILES to the SpikeGLX
            % .nidq.bin / .nidq.meta (and .imec0.ap.meta) files that the
            % underlying ndr neuropixelsGLX reader can process. The
            % VHAudreyBPod stimulus logs (.tsv / .json) and any VHLAB
            % text files are removed, as are any .meta files without a
            % matching .bin file.
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
    end
end
