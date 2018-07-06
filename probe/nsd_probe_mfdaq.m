classdef nsd_probe_mfdaq < nsd_probe
% NSD_PROBE_MFDAQ - Create a new NSD_PROBE_MFAQ class object that handles probes that are associated with NSD_DEVICE_MFDAQ objects
%
	properties (GetAccess=public, SetAccess=protected)
	end

	methods
		function obj = nsd_probe_mfdaq(experiment, name, reference, type)
			% NSD_PROBE - create a new NSD_PROBE object
			%
			%  OBJ = NSD_PROBE(EXPERIMENT, NAME, REFERENCE, TYPE)
			%
			%  Creates an NSD_PROBE associated with an NSD_EXPERIMENT object EXPERIMENT and
			%  with name NAME (a string that must start with a letter and contain no white space),
			%  reference number equal to REFERENCE (a non-negative integer), the TYPE of the
			%  probe (a string that must start with a letter and contain no white space).
			%
			%  NSD_PROBE is an abstract class, and a specific implementation must be called.
			%
				obj = obj@nsd_probe(experiment, name, reference, type);

		end % nsd_probe_mfdaq

		function [data,t,clock] = read_epochsamples(self, epoch, s0, s1)
		%  READ_EPOCHSAMPLES - read the data from a specified epoch
		%
		%  [DATA, T, CLOCK] = READ_EPOCHSAMPLES(NSD_PROBE_MFDAQ_OBJ, EPOCH ,S0, S1)
		%
		%  EPOCH is the epoch number to read from.
		%
		%  DATA will have one column per channel.
		%
		%  T is the time of each sample, relative to the beginning of the epoch.
		%
		%  CLOCK is the NSD_CLOCK associated with the device.
		%
		%  
			[dev,devname,devepoch,channeltype,channel]=self.getchanneldevinfo(epoch);

			if numel(unique(channeltype))>1, error(['At present, do not know how to mix channel types.']); end;
			if numel(unique(dev))>1, error(['At present, do not know how to mix devices.']); end;

			if nargout>=1,
				[data] = readchannels_epochsamples(dev{1}, channeltype, channel, devepoch(1), s0, s1);
			end
			if nargout>=2,
				[t] = readchannels_epochsamples(dev{1}, {'time'}, 1, devepoch(1), s0, s1);
			end
			if nargout>=3,
				clock = dev{1}.clock;
			end

		end % read_epochsamples()

		function [data,t,clock] = read(self, clock_or_epoch, t0, t1)
			%  READ - read the probe data based on specified time relative to an epoch or clock
			%
			%  [DATA,T] = READ(NSD_PROBE_MFDAQ_OBJ, CLOCK_OR_EPOCH, T0, T1)
			%
			%  CLOCK_OR_EPOCH is either an NSD_CLOCK object indicating the clock for T0, T1, or
			%  it can be a single number, which will indicate the data are to be read from that epoch.
			%
			%  DATA is the data collection for the probe. It will have one column per channel.
			%
			%  T is the time of each sample, relative to the beginning of the epoch.
			%
			%  CLOCK is the device's NSD_CLOCK indicating a reference for T
			%

				if isa(clock_or_epoch,'nsd_clock'),
					clock = clock_or_epoch;
					error(['this function does not handle working with clocks yet.']);
				else,
					epoch = clock_or_epoch;
					[dev,devname,devepoch,channeltype,channel]=self.getchanneldevinfo(epoch);
					sr = samplerate(dev{1}, devepoch(1), channeltype, channel);
					if numel(unique(sr))~=1,
						error(['Do not know how to handle multiple sampling rates across channels.']);
					end;
					sr = unique(sr);
					s0 = 1+round(sr*t0);
					s1 = 1+round(sr*t1);
				end;

				if nargout>=1,
					[data] = readchannels_epochsamples(dev{1}, channeltype, channel, devepoch(1), s0, s1);
				end
				if nargout>=2,
					[t] = readchannels_epochsamples(dev{1}, 'time', 1, devepoch(1), s0, s1);
				end
				if nargout>=3,
					clock=dev{1}.clock;
				end
		end %read()

		function sr = samplerate(self, epoch)
			% SAMPLERATE - GET THE SAMPLE RATE FOR A PROBE IN AN EPOCH
			%
			% SR = SAMPLERATE(NSD_PROBE_MFDAQ_OBJ, EPOCH)
			%
			% SR is an array of sample rates for the probe NSD_PROBE_MFDAQ_OBJ
			% from epoch number EPOCH.
			%
				[dev, devname, devepoch, channeltype, channellist] = self.getchanneldevinfo(epoch);
				if numel(unique(channeltype))>1, error(['At present, do not know how to mix channel types.']); end;
				sr = dev.samplerate(devepoch, channeltype, channellist);
		end

	end; % methods
end


