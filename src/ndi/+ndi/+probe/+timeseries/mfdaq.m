classdef mfdaq < ndi.probe.timeseries
    % NDI_PROBE_TIMESERIES_MFDAQ - Create a new NDI_PROBE_MFAQ class object that handles probes that are associated with NDI_DAQSYSTEM_MFDAQ objects
    %
    properties (GetAccess=public, SetAccess=protected)
    end

    methods
        function obj = mfdaq(varargin)
            % ndi.probe.timeseries.mfdaq - create a new ndi.probe object
            %
            %  OBJ = ndi.probe.timeseries.mfdaq(SESSION, NAME, REFERENCE, TYPE)
            %
            %  Creates an ndi.probe associated with an ndi.session object SESSION and
            %  with name NAME (a string that must start with a letter and contain no white space),
            %  reference number equal to REFERENCE (a non-negative integer), the TYPE of the
            %  probe (a string that must start with a letter and contain no white space).
            %
            %  ndi.probe is an abstract class, and a specific implementation must be called.
            %
            obj = obj@ndi.probe.timeseries(varargin{:});
        end % ndi.probe.timeseries.mfdaq

        function [data,t,timeref_out] = read_epochsamples(ndi_probe_timeseries_mfdaq_obj, epoch, s0, s1)
            %  READ_EPOCHSAMPLES - read the data from a specified epoch
            %
            %  [DATA, T, TIMEREF_OUT] = READ_EPOCHSAMPLES(NDI_PROBE_TIMESERIES_MFDAQ_OBJ, EPOCH ,S0, S1)
            %
            %  EPOCH is the epoch number to read from.
            %
            %  DATA will have one column per channel.
            %  T is the time of each sample, relative to the beginning of the epoch.
            %  TIMEREF_OUT is an ndi.time.timereference object that describes the epoch.
            %
            %
            [dev,devname,devepoch,channeltype,channel]=ndi_probe_timeseries_mfdaq_obj.getchanneldevinfo(epoch);
            eid = ndi_probe_timeseries_mfdaq_obj.epochid(epoch);

            if numel(unique(channeltype))>1, error(['At present, do not know how to mix channel types.']); end
            if numel(vlt.data.equnique(dev))>1, error(['At present, do not know how to mix devices.']); end

            if nargout>=1
                [data] = readchannels_epochsamples(dev{1}, channeltype, channel, devepoch{1}, s0, s1);
            end
            if nargout>=2
                ch = dev{1}.getchannelsepoch(devepoch{1});
                timechannel = ndi.daq.reader.mfdaq.channelsepoch2timechannelinfo(ch,channeltype,channel);
                if isnan(timechannel(1))
                    t = NaN;
                else
                    [t] = readchannels_epochsamples(dev{1}, {'time'}, timechannel(1), devepoch{1}, s0, s1);
                end
            end
            if nargout>=3
                timeref_out = ndi.time.timereference(ndi_probe_timeseries_mfdaq_obj, ndi.time.clocktype('dev_local_time'), eid, 0);
            end
        end % read_epochsamples()

        function [data,t,timeref_out] = readtimeseriesepoch(ndi_probe_timeseries_mfdaq_obj, epoch, t0, t1)
            %  READTIMESERIESEPOCH - read the data from a specified epoch
            %
            %  [DATA, T, TIMEREF_OUT] = READTIMESERIESEPOCH(NDI_PROBE_TIMESERIES_MFDAQ_OBJ, EPOCH ,T0, T1)
            %
            %  EPOCH is the epoch number to read from.
            %
            %  DATA will have one column per channel.
            %  T is the time of each sample, relative to the beginning of the epoch.
            %  TIMEREF_OUT is an ndi.time.timereference object that describes the epoch.
            %
            [dev,devname,devepoch,channeltype,channel]=ndi_probe_timeseries_mfdaq_obj.getchanneldevinfo(epoch);
            eid = ndi_probe_timeseries_mfdaq_obj.epochid(epoch);

            if numel(unique(channeltype))>1, error(['At present, do not know how to mix channel types.']); end
            if numel(vlt.data.equnique(dev))>1, error(['At present, do not know how to mix devices.']); end

            s = dev{1}.epochtimes2samples(channeltype, channel, devepoch{1}, [t0 t1]);
            s0 = s(1);
            s1 = s(2);

            % save some time
            if nargout==1
                [data] = read_epochsamples(ndi_probe_timeseries_mfdaq_obj, epoch, s0, s1);
            elseif nargout==2
                [data,t] = read_epochsamples(ndi_probe_timeseries_mfdaq_obj, epoch, s0, s1);
            elseif nargout>2
                [data,t,timeref_out] = read_epochsamples(ndi_probe_timeseries_mfdaq_obj, epoch, s0, s1);
            end

        end % readtimeseriesepoch()

        function sr = samplerate(ndi_probe_timeseries_mfdaq_obj, epoch)
            % SAMPLERATE - GET THE SAMPLE RATE FOR A PROBE IN AN EPOCH
            %
            % SR = SAMPLERATE(NDI_PROBE_TIMESERIES_MFDAQ_OBJ, EPOCH)
            %
            % SR is an array of sample rates for the probe NDI_PROBE_TIMESERIES_MFDAQ_OBJ
            % from epoch number EPOCH.
            %
            [dev, devname, devepoch, channeltype, channellist] = ndi_probe_timeseries_mfdaq_obj.getchanneldevinfo(epoch);
            if numel(unique(channeltype))>1, error(['At present, do not know how to mix channel types.']); end
            sr = dev{1}.samplerate(devepoch{1}, channeltype{1}, channellist(1));
        end

    end % methods
end
