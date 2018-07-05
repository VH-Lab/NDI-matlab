classdef nsd_probe_stimulator < nsd_probe
% NSD_PROBE_STIMULATOR - Create a new NSD_PROBE_MFAQ class object that handles probes that are associated with NSD_DEVICE_MFDAQ objects
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

		function [stimon, stimoff, stimid, parameters, stimopenclose] = read_stimulusepoch(self, clock_or_epoch, t0, t1)
			% READ_STIMULUSEPOCH - Read stimulus data from an NSD_PROBE_STIMULATOR object
			%
			% [STIMON, STIMOFF, STIMID, PARAMETERS, STIMOPENCLOSE] = ...
			%    READSTIMULUSEPOCH(NSD_PROBE_STIMULTOR_OBJ, CLOCK_OR_EPOCH, T0, T1)
			%
			% Reads stimulus delivery information from an NSD_PROBE_STIMULATOR object.
			%
			% CLOCK_OR_EPOCH is either an NSD_CLOCK object indicating the clock for T0, T1, or
			% it can be a single number, which will indicate the data are to be read from that epoch.
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
			
				if isa(clock_or_epoch, 'nsd_clock'),
					error(['Do not know how to deal with clocks yet.']);
				end

				epoch = clock_or_epoch;

				[dev,devname,devepoch,channeltype,channel]=self.getchanneldevinfo(epoch),

		end %read_stimulusepoch()

	end; % methods
end


