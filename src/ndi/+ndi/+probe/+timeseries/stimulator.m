classdef stimulator < ndi.probe.timeseries
    % ndi.probe.timeseries.stimulator - Create a new NDI_PROBE_TIMESERIES_STIMULATOR class object that handles probes that are associated with NDI_DAQSYSTEM_STIMULUS objects
    %
    properties (GetAccess=public, SetAccess=protected)
    end

    methods
        function obj = stimulator(varargin)
            % ndi.probe.timeseries.stimulator - create a new ndi.probe.timeseries.stimulator object
            %
            % OBJ = ndi.probe.timeseries.stimulator(SESSION, NAME, REFERENCE, TYPE)
            %
            % Creates an ndi.probe.timeseries.stimulator associated with an ndi.session object SESSION and
            % with name NAME (a string that must start with a letter and contain no white space),
            % reference number equal to REFERENCE (a non-negative integer), the TYPE of the
            % probe (a string that must start with a letter and contain no white space).
            %
            obj = obj@ndi.probe.timeseries(varargin{:});
        end % ndi.probe.timeseries.stimulator()

        function [data, t, timeref] = readtimeseriesepoch(ndi_probe_timeseries_stimulator_obj, epoch, t0, t1)
            % READTIMESERIESEPOCH - Read stimulus data from an ndi.probe.timeseries.stimulator object
            %
            % [DATA, T, TIMEREF] = READTIMESERIESEPOCH(NDI_PROBE_TIMESERIES_STIMULATOR_OBJ, EPOCH, T0, T1)
            %  STIMON, STIMOFF, STIMID, PARAMETERS, STIMOPENCLOSE] = ...
            %    READSTIMULUSEPOCH(NDI_PROBE_STIMULTOR_OBJ, EPOCH, T0, T1)
            %
            % Reads stimulus delivery information from an ndi.probe.timeseries.stimulator object for a given EPOCH.
            % T0 and T1 are in epoch time.
            %
            % T.STIMON is an Nx1 vector with the ON times of each stimulus delivery in the time units of
            %    the epoch or the clock. If marker channels 'mk' are present, then STIMON is taken to be occurrences
            %    where the first marker channel registers a value greater than 0. Alternatively, if 'dim*' channels are present,
            %    then STIMON is taken to be times whenever ANY of the dim channels registers an event onset.
            % T.STIMOFF is an Nx1 vector with the OFF times of each stimulus delivery in the time units of
            %    the epoch or the clock. If STIMOFF data is not provided, these values will be NaN. If marker channels 'mk'
            %    are present, then STIMOFF is taken to be occurrences where the first marker channels registers a value less than 0.
            %    Alternatively, if 'dim*' channels are present, then STIMOFF is taken to be the times when *any* of the 'dim*'
            %    channels go off.
            % DATA.STIMID is an Nx1 vector with the STIMID values. If STIMID values are not provided, these values
            %    will be NaN. If there are marker channels, the STIMID is taken to be the marker code of the second marker channel
            %    in the group. If 'dim*' channels are present, then the stimid will be 1..number of dim channels, depending upon
            %    which 'dim*' channel turned on. For example, if the second one turned on, then the stimid is 2.
            % DATA.PARAMETERS is an Nx1 cell array of stimulus parameters. If the device provides no parameters,
            %    then this will be an empty cell array of size Nx1. This is read from the first metadata channel.
            % DATA.ANALOG is an Nx1 vector with any analog data produced by the stimulator
            % T.STIMOPENCLOSE is an Nx2 vector of stimulus 'setup' and 'shutdown' times, if applicable. For example,
            %    a visual stimulus might begin or end with the presentation of a 'background' image. These times will
            %    be encoded here. If there is no information about stimulus setup or shutdown, then
            %    T.STIMOPENCLOSE == [T.STIMON T.STIMOFF]. If there is a third marker channel present, then STIMOPENCLOSE
            %    will be defined by +1 and -1 marks on the third marker channel.
            % T.STIMEVENTS is a cell array of stimulus event triggers that occur while the stimuli are running.
            %    These channels are optional and may not be present. If the NDI_PROBE_TIMESERIES_STIMULATOR_OBJ has
            %    no events, this will be an empty cell array.
            %    There will be one entry per event channel. In a visual stimulus system, the first event channel
            %    should be data frame events (when the video monitor updates). The second event channel can be the
            %    monitor's refresh rate, if it has one.
            % T.ANALOG is the time of each analog sample
            %
            % TIMEREF is an ndi.time.timereference object that refers to this EPOCH.
            %
            % See also: ndi.probe.timeseries/READTIMESERIES
            %

            data = struct;
            t = struct;

            [dev,devname,devepoch,channeltype,channel]=ndi_probe_timeseries_stimulator_obj.getchanneldevinfo(epoch);
            eid = ndi_probe_timeseries_stimulator_obj.epochid(epoch);

            if numel(unique(devname))>1, error(['Right now, all channels must be on the same device.']); end
            % developer note: it would be pretty easy to extend this, just loop over the devices

            md_index = find(strcmp('md',channeltype));
            hasmetadata = ~isempty(md_index);
            non_md = setdiff(1:numel(channel),md_index);
            channeltype_metadata = channeltype(md_index);
            channel_metadata = channel(md_index);
            channeltype = channeltype(non_md);
            channel=channel(non_md);
            analogIndex = find(strcmp('ai',channeltype));
            hasAnalogData = ~isempty(analogIndex);
            if hasAnalogData
                sr = samplerate(dev{1}, devepoch{1}, channeltype, channel);
                if numel(unique(sr))~=1
                    error(['Do not know how to handle multiple sampling rates across channels.']);
                end
                sr = unique(sr);
                s0 = 1+round(sr*t0);
                s1 = 1+round(sr*t1);
                data.analog = dev{1}.readchannels_epochsamples(channeltype(analogIndex),channel(analogIndex),devepoch{1},s0,s1);
                timechannel = ndi.daq.reader.mfdaq.channelsepoch2timechannelinfo(dev{1}.getchannelsepoch(devepoch{1}),channeltype,channel);
                if isnan(timechannel(1))
                    t.analog = NaN;
                else
                    [t.analog] = readchannels_epochsamples(dev{1}, {'time'}, timechannel(1), devepoch{1}, s0, s1);
                    t.analog = t.analog(:);
                end                
            end
            [timestamps,edata] = readevents(dev{1},channeltype,channel,devepoch{1},t0,t1);
            if ~iscell(edata)
                timestamps = {timestamps};
                edata = {edata};
            end
            channel_labels = getchannels(dev{1});

            markermode = any(ismember(channeltype, {'mk','marker','text','e','event','dep','den'}));
            dimmode = ~isempty(intersect(channeltype,{'dimp','dimn'}));
            mk_ = 0;
            e_ = 0;
            md_ = 0;
            event_data = {};

            channeltype = cat(1,channeltype(:),channeltype_metadata(:));
            channel = cat(1,channel(:),channel_metadata(:));

            if markermode
                for i=1:numel(channeltype)
                    switch(channeltype{i})
                        case {'mk','marker','text'}
                            mk_ = mk_ + 1;
                            switch mk_
                                case 1 % stimonoff
                                    [t.stimon, t.stimoff] = ...
                                        ndi.probe.timeseries.stimulator.pairOnOff(...
                                            timestamps{i}(:,1), edata{i}(:,1));
                                case 2 % stimid
                                    for dd=1:size(edata{i},1)
                                        if strcmp(channeltype{i},'text')
                                            data.stimid(dd,1) = eval([edata{i}{dd}]);
                                        else
                                            data.stimid(dd,:) = edata{i}(dd,:);
                                        end
                                    end
                                case 3 % stimopenclose
                                    [open_, close_] = ...
                                        ndi.probe.timeseries.stimulator.pairOnOff(...
                                            timestamps{i}(:,1), edata{i}(:,1));
                                    t.stimopenclose = [open_ close_];
                                    if isempty(t.stimoff)
                                        t.stimoff = close_;
                                    end
                                otherwise
                                    error(['Got more mark channels than expected.']);
                            end
                        case {'e','event','dep','den'}
                            e_ = e_ + 1;
                            event_data{e_} = timestamps{i};
                        case {'md'}
                            data.parameters = getmetadata(dev{1},devepoch{1},channel(i));
                        otherwise
                            error(['Unknown channel.']);
                    end
                end
                t.stimevents = event_data;
            elseif dimmode
                t.stimon = [];
                t.stimoff = [];
                data.stimid = [];
                counter = 0;
                for i=1:numel(edata)
                    if ~isempty(intersect(channeltype(i),{'dimp','dimn'}))
                        counter = counter + 1;
                        [on_i, off_i] = ndi.probe.timeseries.stimulator.pairOnOff(...
                            timestamps{i}(:,1), edata{i}(:,1));
                        t.stimon  = [t.stimon(:);  on_i];
                        t.stimoff = [t.stimoff(:); off_i];
                        data.stimid = [data.stimid(:); counter*ones(numel(on_i),1)];
                    end
                    if strcmp(channeltype(i),'md')
                        data.parameters = getmetadata(dev{1},devepoch{1},channel(i));
                    end
                    if strcmp(channeltype(i),'e')
                        event_data{end+1} = timestamps{i};
                    end
                end
                % NaN-on entries represent stims that began before the window;
                % sort them by their off-time so they stay in temporal order.
                sort_key = t.stimon;
                nan_on = isnan(sort_key);
                sort_key(nan_on) = t.stimoff(nan_on);
                [~,order] = sort(sort_key);
                t.stimon = t.stimon(order(:));
                t.stimoff = t.stimoff(order(:));
                data.stimid = data.stimid(order(:));
                t.stimopenclose(:,1) = t.stimon;
                t.stimopenclose(:,2) = t.stimoff;
            end

            timeref = ndi.time.timereference(ndi_probe_timeseries_stimulator_obj, ndi.time.clocktype('dev_local_time'), eid, 0);
        end %readtimeseriesepoch()

    end % methods

    methods (Static, Access=public)
        function [on, off] = pairOnOff(times, signs)
            % PAIRONOFF - Pair stimulus on/off events, NaN-filling orphans.
            %
            % [ON, OFF] = pairOnOff(TIMES, SIGNS) takes a column of event
            % times TIMES and a column of marker values SIGNS (>0 means
            % stim-on, <0 means stim-off) and returns equal-length column
            % vectors ON and OFF of paired times.
            %
            % Events are walked in time order. A stim-on is paired with the
            % next stim-off; a stim-on with no following off (clipped by the
            % read window) gets OFF=NaN, and a stim-off with no preceding on
            % gets ON=NaN. This lets callers read partial intervals without
            % erroring on mismatched event counts (issue #248).
            times = times(:);
            signs = sign(signs(:));
            [times, ord] = sort(times);
            signs = signs(ord);

            n = numel(signs);
            on  = nan(n,1);
            off = nan(n,1);
            p = 0;
            k = 1;
            while k <= n
                if signs(k) > 0
                    p = p + 1;
                    on(p) = times(k);
                    if k+1 <= n && signs(k+1) < 0
                        off(p) = times(k+1);
                        k = k + 2;
                    else
                        k = k + 1;
                    end
                else
                    p = p + 1;
                    off(p) = times(k);
                    k = k + 1;
                end
            end
            on  = on(1:p);
            off = off(1:p);
        end
    end % static methods
end
