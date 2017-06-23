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

		function [data,t] = read_epochsamples(self, epoch, s0, s1)
		%  READ_EPOCHSAMPLES - read the data from a specified epoch
		%
		%  [DATA, T] = READ_EPOCHSAMPLES(NSD_PROBE_MFDAQ_OBJ, EPOCH ,S0, S1)
		%
		%  EPOCH is the epoch number to read from.
		%
		%  DATA will have one column per channel.
		%
		%  T is the time of each sample, relative to the beginning of the epoch.
		%
		%  
			[dev,devname,devepoch,channeltype,channel]=self.getchanneldevinfo(epoch);

			if nargout>=1,
				[data] = readchannels_epochsamples(dev, channeltype, channel, devepoch, s0, s1);
			end
			if nargout>=2,
				[t] = readchannels_epochsamples(dev, 'time', 1, devepoch, s0, s1);
			end

		end % read_epochsamples()

		function [data,t] = read(self, clock_or_epoch, t0, t1)
			%  READ - read the probe data based on specified time relative to an epoch or clock
			%
			%  [DATA,T] = READ(NSD_PROBE_MFDAQ_OBJ, CLOCK_OR_EPOCH, T0, T1)
			%
			%  CHANNELTYPE is the type of channel to read
			%  ('analog','digitalin','digitalout', etc)
			%  
			%  CHANNEL is a vector with the identity of the channels to be read.
			%  
			%  CLOCK_OR_EPOCH is either an NSD_CLOCK object indicating the clock for T0, T1, or
			%  it can be a single number, which will indicate the data are to be read from that epoch.
			%
			%  DATA is the data collection for the probe. It will have one column per channel.
			%
			%  T is the time of each sample, relative to the beginning of the epoch.
			%

				if isa(clock_or_epoch,'nsd_clock'),
					clock = clock_or_epoch;
					error(['this function does not handle working with clocks yet.']);
				else,
					epoch = clock_or_epoch;
					[dev,devname,devepoch,channeltype,channel]=self.getchanneldevinfo(epoch);
					sr = samplerate(dev, devepoch, channeltype, channel);
					if numel(unique(sr))~=1,
						error(['Do not know how to handle multiple sampling rates across channels.']);
					end;
					sr = unique(sr);
					s0 = 1+round(sr*t0);
					s1 = 1+round(sr*t1);
				end;

				if nargout>=1,
					[data] = readchannels_epochsamples(dev, devepoch, channeltype, channel, s0, s1);
				end
				if nargout>=2,
					[t] = readchannels_epochsamples(dev, devepoch, 'time', 1, s0, s1);
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
				sr = dev.samplerate(devepoch, channeltype, channellist);
		end

		function [dev, devname, devepoch, channeltype, channellist] = getchanneldevinfo(self, epoch)
			% GETCHANNELDEVINFO = Get the device, channeltype, and channellist for a given epoch for NSD_PROBE_MFDAQ
			% 
			% [DEV, DEVNAME, DEVEPOCH, CHANNELTYPE, CHANNELLIST] = GETCHANNELDEVINFO(NSD_PROBE_MFDAQ_OBJ, EPOCH)
			%
			% Given an NSD_PROBE_MFDAQ object and an EPOCH number, this functon returns the corresponding
			% NSD_DEVICE object DEV, the name of the device in DEVNAME, the epoch number, DEVEPOCH of the device that
			% corresponds to the probe's epoch, the CHANNELTYPE, and an array of channels that comprise the probe in CHANNELLIST.
			%
				[n, probe_epoch_contents, devepochs] = numepochs(self);
				if ~(epoch >=1 & epoch <= n),
					error(['Requested epoch out of range of 1 .. ' int2str(n) '.']);
				end
				devstr = nsd_devicestring(probe_epoch_contents(epoch).devicestring);
				[devname, channeltype, channellist] = devstr.nsd_devicestring2channel();
				devepoch = devepochs(epoch);
				dev = load(self.experiment.device,'name', devname); % now we have the device handle
			end
	end; % methods
end


