classdef nsd_probe_stimulator < nsd_probe
% NSD_PROBE_STIMULATOR - Create a new NSD_PROBE_STIMULATOR class object that handles probes that are associated with NSD_IODEVICE_STIMULUS objects
%
	properties (GetAccess=public, SetAccess=protected)
	end

	methods
		function obj = nsd_probe_stimulator(experiment, name, reference, type)
			% NSD_PROBE_STIMULATOR - create a new NSD_PROBE_STIMULATOR object
			%
			% OBJ = NSD_PROBE(EXPERIMENT, NAME, REFERENCE, TYPE)
			%
			% Creates an NSD_PROBE_STIMULATOR associated with an NSD_EXPERIMENT object EXPERIMENT and
			% with name NAME (a string that must start with a letter and contain no white space),
			% reference number equal to REFERENCE (a non-negative integer), the TYPE of the
			% probe (a string that must start with a letter and contain no white space).
			%
				obj = obj@nsd_probe(experiment, name, reference, type);
		end % nsd_probe_stimulator()

		function [stimon, stimoff, stimid, parameters, stimopenclose] = read(self, timeref_or_epoch, t0, t1)
			% READ - read stimulus data from an NSD_PROBE_STIMULATOR object
			%
			% [STIMON, STIMOFF, STIMID, PARAMETERS, STIMOPENCLOSE] = ...
			%   READ(NSD_PROBE_STIMULATOR_OBJ, TIMEREF_OR_EPOCH, T0, T1)
			%
			% Reads stimulus delivery information from an NSD_PROBE_STIMULATOR object.
			%
			% TIMEREF_OR_EPOCH is either an NSD_TIMEREFERENCE object indicating the clock for T0, T1, or
			% it can be a single number, which will indicate the data are to be read from that epoch.
			%
			% Outputs:
			%
			% STIMON is an Nx1 vector with the ON times of each stimulus delivery in the time units of
			%    the epoch or the clock.
			% STIMOFF is an Nx1 vector with the OFF times of each stimulus delivery in the time units of
			%    the epoch or the clock. If STIMOFF data is not provided, these values will be NaN.
			% STIMID is an Nx1 vector with the STIMID values. If STIMID values are not provided, these values
			%    will be NaN.
			% PARAMETERS is an Nx1 cell array of stimulus parameters. If the device provides no parameters,
			%    then this will be an empty cell array of size Nx1.
			% STIMOPENCLOSE is an Nx2 vector of stimulus 'setup' and 'shutdown' times, if applicable. For example,
			%    a visual stimulus might begin or end with the presentation of a 'background' image. These times will
			%    be encoded here. If there is no information about stimulus setup or shutdown, then 
			%    STIMOPENCLOSE == [STIMON STIMOFF].
			%  
				% Step 1, get the epoch

				if ~isa(timeref_or_epoch,'nsd_timereference'),
					epoch = timeref_or_epoch; % for clarity
					[stimon, stimoff, stimid, parameters, stimopenclose] = read_stimulusepoch(self, epoch, t0, t1);
					return;
				end;

				timeref_in = timeref_or_epoch;

				% now we know we need to find a match

				[N, pec, devepochs, devs] = numepochs(self);
				devs = equnique(devs),

				for i=1:numel(devs),
					clock2 = devs{i}.clock;
					[tref,message] = timeconvert(self.experiment.synctable, timeref_in, clock2);
					if ~isempty(tref),
						break; % break the for loop, we're done
					end
				end

				if isempty(tref),
					error(['No way to convert between clocks.']);
				end;

				% how are we guarenteed that tref has an epoch? we aren't right now; punt this issue
				[stimon, stimoff, stimid, parameters, stimopenclose] = read_stimulusepoch(self, tref.epoch, t0-tref.t, t1-tref.t);
		end; % read 

		function [stimon, stimoff, stimid, parameters, stimopenclose] = read_stimulusepoch(self, epoch, t0, t1)
			% READ_STIMULUSEPOCH - Read stimulus data from an NSD_PROBE_STIMULATOR object
			%
			% [STIMON, STIMOFF, STIMID, PARAMETERS, STIMOPENCLOSE] = ...
			%    READSTIMULUSEPOCH(NSD_PROBE_STIMULTOR_OBJ, EPOCH, T0, T1)
			%
			% Reads stimulus delivery information from an NSD_PROBE_STIMULATOR object for a given EPOCH.
			% T0 and T1 are in epoch time.
			%
			% STIMON is an Nx1 vector with the ON times of each stimulus delivery in the time units of
			%    the epoch or the clock.
			% STIMOFF is an Nx1 vector with the OFF times of each stimulus delivery in the time units of
			%    the epoch or the clock. If STIMOFF data is not provided, these values will be NaN.
			% STIMID is an Nx1 vector with the STIMID values. If STIMID values are not provided, these values
			%    will be NaN.
			% PARAMETERS is an Nx1 cell array of stimulus parameters. If the device provides no parameters,
			%    then this will be an empty cell array of size Nx1.
			% STIMOPENCLOSE is an Nx2 vector of stimulus 'setup' and 'shutdown' times, if applicable. For example,
			%    a visual stimulus might begin or end with the presentation of a 'background' image. These times will
			%    be encoded here. If there is no information about stimulus setup or shutdown, then 
			%    STIMOPENCLOSE == [STIMON STIMOFF].
			% 
				[dev,devname,devepoch,channeltype,channel]=self.getchanneldevinfo(epoch);

				if numel(unique(devname))>1, error(['Right now, all channels must be on the same device.']); end;

				channel_labels = getchannels(dev{1});

				[data] = readevents(dev{1},channeltype,channel,devepoch(epoch),t0,t1);

				for i=1:numel(channeltype),
					switch channel_labels(i).name,
						case 'mk1', % stimonoff
							data{i},
							stimon = data{i}(find(data{i}(:,2)==1),1);
							stimoff = data{i}(find(data{i}(:,2)==-1),1);
						case 'mk2',
							stimid = data{i}(:,2);
						case 'mk3',
							stimopenclose(1,:) = data{i}( find(data{i}(:,2)==1) , 1)'; 
							stimopenclose(2,:) = data{i}( find(data{i}(:,2)==1) , 1)'; 
						case {'e1','e2','e3'}, % not saved
						otherwise,
							error(['Unknown channel.']);
					end
				end

				parameters = get_stimulus_parameters(dev{1},devepoch(epoch));

		end %read_stimulusepoch()

	end; % methods
end


