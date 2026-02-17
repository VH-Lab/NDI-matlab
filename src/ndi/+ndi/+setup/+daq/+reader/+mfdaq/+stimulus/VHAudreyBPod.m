classdef VHAudreyBPod < ndi.daq.reader.mfdaq
    % NDI.SETUP.DAQ.READER.MFDAQ.STIMULUS.VHAUDREYBPOD - Reader for VHAudreyBPod stimulus files
    %
    % This class reads VHAudreyBPod .tsv files.
    % It provides 3 channels:
    %   e1: Event, StartTime
    %   e2: Event, EndTime
    %   mk1: Marker, StartTime with stimid value

    methods
        function obj = VHAudreyBPod(varargin)
            % VHAUDREYBPOD - Create a new VHAudreyBPod reader object
            %
            % OBJ = NDI.SETUP.DAQ.READER.MFDAQ.STIMULUS.VHAUDREYBPOD(NAME, THEFILENAVIGATOR, DAQREADER)
            obj = obj@ndi.daq.reader.mfdaq(varargin{:});
        end

        function channels = getchannelsepoch(obj, epochfiles)
            % GETCHANNELSEPOCH - List the channels available in this epoch
            channels = struct('name','e1','type','event','time_channel',NaN);
            channels(end+1) = struct('name','e2','type','event','time_channel',NaN);
            channels(end+1) = struct('name','mk1','type','marker','time_channel',NaN);
        end

        function [timestamps,data] = readevents_epochsamples_native(obj, channeltype, channel, epochfiles, t0, t1)
            % READEVENTS_EPOCHSAMPLES_NATIVE - Read events from the file

            timestamps = {};
            data = {};

            if ~iscell(channeltype)
                channeltype = repmat({channeltype},numel(channel),1);
            end

            % Find the TSV file
            tsvFile = '';
            for i=1:numel(epochfiles)
                [~,~,ext] = fileparts(epochfiles{i});
                if strcmpi(ext, '.tsv')
                    tsvFile = epochfiles{i};
                    break;
                end
            end

            if isempty(tsvFile)
                error('No .tsv file found in epochfiles.');
            end

            % Parse data from TSV
            % Format: Solenoid_Valve_Number (1), Open_Times (2), StartTime (3), EndTime (4)
            try
                % Read raw data skipping 1 header line
                M = dlmread(tsvFile, '\t', 1, 0);
            catch
                % Fallback for older MATLAB or if dlmread fails, try simple load
                M = load(tsvFile);
            end

            % Columns: 1=Valve, 2=OpenTime, 3=StartHHMMSS, 4=EndHHMMSS
            raw_valve = M(:,1);
            raw_opentime = M(:,2);
            raw_starttime = M(:,3);
            raw_endtime = M(:,4);

            % Convert Time HHMMSS.frac -> Seconds from Midnight
            % HH = floor(T/10000)
            % MM = floor(mod(T,10000)/100)
            % SS = mod(T,100)

            start_seconds = floor(raw_starttime/10000)*3600 + ...
                            floor(mod(raw_starttime,10000)/100)*60 + ...
                            mod(raw_starttime,100);

            end_seconds = floor(raw_endtime/10000)*3600 + ...
                          floor(mod(raw_endtime,10000)/100)*60 + ...
                          mod(raw_endtime,100);

            % Calculate StimID
            % If Open_Times > 5, stimid = 7, else stimid = Solenoid_Valve_Number
            stimid = raw_valve;
            stimid(raw_opentime > 5) = 7;

            % Process requested channels
            for i=1:numel(channel)
                switch channeltype{i}
                    case {'event','e'}
                        if channel(i) == 1 % e1: StartTime
                            ts = start_seconds;
                            d = ones(size(ts));
                        elseif channel(i) == 2 % e2: EndTime
                            ts = end_seconds;
                            d = ones(size(ts));
                        else
                            error(['Unknown event channel ' num2str(channel(i))]);
                        end
                    case {'marker','mk'}
                        if channel(i) == 1 % mk1: StartTime with StimID
                            ts = start_seconds;
                            d = stimid;
                        else
                            error(['Unknown marker channel ' num2str(channel(i))]);
                        end
                    otherwise
                        error(['Unknown channel type ' channeltype{i}]);
                end

                % Filter by time window t0, t1
                valid_indices = (ts >= t0) & (ts <= t1);
                timestamps{i} = ts(valid_indices);
                data{i} = d(valid_indices);
            end

            if numel(data)==1
                timestamps = timestamps{1};
                data = data{1};
            end
        end
    end
end
