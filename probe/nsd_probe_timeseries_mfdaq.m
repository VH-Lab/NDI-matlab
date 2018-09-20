classdef nsd_probe_timeseries_mfdaq < nsd_probe_timeseries
% NSD_PROBE_TIMESERIES_MFDAQ - Create a new NSD_PROBE_MFAQ class object that handles probes that are associated with NSD_IODEVICE_MFDAQ objects
%
	properties (GetAccess=public, SetAccess=protected)
	end

	methods
		function obj = nsd_probe_timeseries_mfdaq(experiment, name, reference, type)
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
				obj = obj@nsd_probe_timeseries(experiment, name, reference, type);
		end % nsd_probe_timeseries_mfdaq

		function [data,t,timeref_out] = read_epochsamples(nsd_probe_timeseries_mfdaq_obj, epoch, s0, s1)
			%  READ_EPOCHSAMPLES - read the data from a specified epoch
			%
			%  [DATA, T, TIMEREF_OUT] = READ_EPOCHSAMPLES(NSD_PROBE_TIMESERIES_MFDAQ_OBJ, EPOCH ,S0, S1)
			%
			%  EPOCH is the epoch number to read from.
			%
			%  DATA will have one column per channel.
			%  T is the time of each sample, relative to the beginning of the epoch.
			%  TIMEREF_OUT is an NSD_TIMEREFERENCE object that describes the epoch.
			%
			%  
				[dev,devname,devepoch,channeltype,channel]=nsd_probe_timeseries_mfdaq_obj.getchanneldevinfo(epoch);
				eid = nsd_probe_timeseries_mfdaq_obj.epochid(epoch);

				if numel(unique(channeltype))>1, error(['At present, do not know how to mix channel types.']); end;
				if numel(equnique(dev))>1, error(['At present, do not know how to mix devices.']); end;

				if nargout>=1,
					[data] = readchannels_epochsamples(dev{1}, channeltype, channel, devepoch{1}, s0, s1);
				end
				if nargout>=2,
					[t] = readchannels_epochsamples(dev{1}, {'time'}, 1, devepoch{1}, s0, s1);
				end
				if nargout>=3,
					timeref_out = nsd_timereference(nsd_probe_timeseries_mfdaq_obj, nsd_clocktype('dev_local_time'), eid, 0);
				end
		end % read_epochsamples()

		function [data,t,timeref_out] = readtimeseriesepoch(nsd_probe_timeseries_mfdaq_obj, epoch, t0, t1)
			%  READ_EPOCHSAMPLES - read the data from a specified epoch
			%
			%  [DATA, T, TIMEREF_OUT] = READTIMESERIESEPOCH(NSD_PROBE_TIMESERIES_MFDAQ_OBJ, EPOCH ,T0, T1)
			%
			%  EPOCH is the epoch number to read from.
			%
			%  DATA will have one column per channel.
			%  T is the time of each sample, relative to the beginning of the epoch.
			%  TIMEREF_OUT is an NSD_TIMEREFERENCE object that describes the epoch.
			%
				[dev,devname,devepoch,channeltype,channel]=nsd_probe_timeseries_mfdaq_obj.getchanneldevinfo(epoch);
				eid = nsd_probe_timeseries_mfdaq_obj.epochid(epoch);

				if numel(unique(channeltype))>1, error(['At present, do not know how to mix channel types.']); end;
				if numel(equnique(dev))>1, error(['At present, do not know how to mix devices.']); end;

				sr = samplerate(dev{1}, devepoch{1}, channeltype, channel);
				if numel(unique(sr))~=1,
					error(['Do not know how to handle multiple sampling rates across channels.']);
				end;

				sr = unique(sr);
				s0 = 1+round(sr*t0);
				s1 = 1+round(sr*t1);
	
				% save some time

				if nargout==1,
					[data] = read_epochsamples(nsd_probe_timeseries_mfdaq_obj, epoch, s0, s1);
				elseif nargout==2,
					[data,t] = read_epochsamples(nsd_probe_timeseries_mfdaq_obj, epoch, s0, s1);
				elseif nargout>2,
					[data,t,timeref_out] = read_epochsamples(nsd_probe_timeseries_mfdaq_obj, epoch, s0, s1);
				end

		end % read_epochsamples()

		function sr = samplerate(nsd_probe_timeseries_mfdaq_obj, epoch)
			% SAMPLERATE - GET THE SAMPLE RATE FOR A PROBE IN AN EPOCH
			%
			% SR = SAMPLERATE(NSD_PROBE_TIMESERIES_MFDAQ_OBJ, EPOCH)
			%
			% SR is an array of sample rates for the probe NSD_PROBE_TIMESERIES_MFDAQ_OBJ
			% from epoch number EPOCH.
			%
				[dev, devname, devepoch, channeltype, channellist] = nsd_probe_timeseries_mfdaq_obj.getchanneldevinfo(epoch),
				if numel(unique(channeltype))>1, error(['At present, do not know how to mix channel types.']); end;
				sr = dev{1}.samplerate(devepoch, channeltype, channellist);
		end

	end; % methods
end


