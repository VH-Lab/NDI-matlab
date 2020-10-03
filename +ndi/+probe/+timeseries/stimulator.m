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
			% READ_STIMULUSEPOCH - Read stimulus data from an ndi.probe.timeseries.stimulator object
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
			%    where the first marker channel registers a 1. Alternatively, if 'dim*' channels are present,
			%    then STIMON is taken to be times whenever ANY of the dim channels registers an event onset.
			% T.STIMOFF is an Nx1 vector with the OFF times of each stimulus delivery in the time units of
			%    the epoch or the clock. If STIMOFF data is not provided, these values will be NaN. If marker channels 'mk'
			%    are present, then STIMOFF is taken to be occurrences where the first marker channels registers a -1.
			%    Alternatively, if 'dim*' channels are present, then STIMOFF is taken to be the times when *any* of the 'dim*'
			%    channels go off. 
			% DATA.STIMID is an Nx1 vector with the STIMID values. If STIMID values are not provided, these values
			%    will be NaN. If there are marker channels, the STIMID is taken to be the marker code of the second marker channel
			%    in the group. If 'dim*' channels are present, then the stimid will be 1..number of dim channels, depending upon
			%    which 'dim*' channel turned on. For example, if the second one turned on, then the stimid is 2.
			% DATA.PARAMETERS is an Nx1 cell array of stimulus parameters. If the device provides no parameters,
			%    then this will be an empty cell array of size Nx1. This is read from the first metadata channel.
			% T.STIMOPENCLOSE is an Nx2 vector of stimulus 'setup' and 'shutdown' times, if applicable. For example,
			%    a visual stimulus might begin or end with the presentation of a 'background' image. These times will
			%    be encoded here. If there is no information about stimulus setup or shutdown, then 
			%    T.STIMOPENCLOSE == [T.STIMON T.STIMOFF]. If there is a third marker channel present, then STIMOPENCLOSE
			%    will be defined by +1 and -1 marks on the third marker channel.
			%
			% 
			% TIMEREF is an ndi.time.timereference object that refers to this EPOCH.
			%
			% See also: ndi.probe.timeseries/READTIMESERIES
			%
				[dev,devname,devepoch,channeltype,channel]=ndi_probe_timeseries_stimulator_obj.getchanneldevinfo(epoch);
				eid = ndi_probe_timeseries_stimulator_obj.epochid(epoch);

				if numel(unique(devname))>1, error(['Right now, all channels must be on the same device.']); end;
					% developer note: it would be pretty easy to extend this, just loop over the devices
				[edata] = readevents(dev{1},channeltype,channel,devepoch{1},t0,t1);
				if ~iscell(edata),
					edata = {edata};
				end;
				channel_labels = getchannels(dev{1});

				markermode = any(strcmp('mk',channeltype));
				dimmode = ~isempty(intersect(channeltype,{'dimp','dimn'}));
				mk_ = 0;
				e_ = 0;
				md_ = 0;
				if markermode,
					for i=1:numel(channeltype),
						switch(channeltype{i}),
							case 'mk',
								mk_ = mk_ + 1;
								switch mk_,
									case 1, % stimonoff
										%edata{i},
										t.stimon = edata{i}(find(edata{i}(:,2)==1),1);
										t.stimoff = edata{i}(find(edata{i}(:,2)==-1),1);
									case 2, % stimid
										data.stimid = edata{i}(:,2);
									case 3, % stimopenclose
										t.stimopenclose(:,1) = edata{i}( find(edata{i}(:,2)==1) , 1); 
										t.stimopenclose(:,2) = edata{i}( find(edata{i}(:,2)==-1) , 1); 
									otherwise,
										error(['Got more mark channels than expected.']);
								end;
							case 'e',
								e_ = e_ + 1;
								% do nothing
							case {'md'},
								data.parameters = getmetadata(dev{1},devepoch{1},channel(i));
							otherwise,
								error(['Unknown channel.']);
						end
					end
				elseif dimmode,
					t.stimon = [];
					t.stimoff = [];
					data.stimid = [];
					counter = 0;
					for i=1:numel(edata),
						if ~isempty(intersect(channeltype(i),{'dimp','dimn'})),
							counter = counter + 1;
							t.stimon = [t.stimon(:); vlt.data.colvec(edata{i}(find(edata{i}(:,2)==1),1))];
							t.stimoff = [t.stimoff(:); vlt.data.colvec(edata{i}(find(edata{i}(:,2)==-1),1))];
							data.stimid = [data.stimid(:); counter*ones(numel(find(edata{i}(:,2)==1)),1)];
						end;
						if strcmp(channeltype(i),'md'),
							data.parameters = getmetadata(dev{1},devepoch{1},channel(i));
						end;
					end;
					[dummy,order] = sort(t.stimon);
					t.stimon = t.stimon(order(:));
					t.stimoff = t.stimoff(order(:));
					data.stimid = data.stimid(order(:));
					t.stimopenclose(:,1) = t.stimon;
					t.stimopenclose(:,2) = t.stimoff;
				end;

				timeref = ndi.time.timereference(ndi_probe_timeseries_stimulator_obj, ndi.time.clocktype('dev_local_time'), eid, 0);
		end %readtimeseriesepoch()

	end; % methods
end


