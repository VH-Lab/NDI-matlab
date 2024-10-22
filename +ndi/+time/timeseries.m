classdef timeseries < ndi.documentservice
% NDI_TIMESERIES - abstract class for managing time series data
%
        properties (SetAccess=protected,GetAccess=public)
        end % properties
        properties (SetAccess=protected,GetAccess=protected)
        
        end % properties

        methods

        function ndi_timeseries_obj = timeseries(varargin)
            % ndi.time.timeseries - create an ndi.time.timeseries object
            %
            % NDI_TIMESERIES_OBJ = ndi.time.timeseries()
            %
            % This function creates an ndi.time.timeseries object, which is an
            % abstract class that defines methods for other objects that deal with
            % time series.
            %
        end % ndi.time.timeseries()

        function [data, t, timeref] = readtimeseries(ndi_timeseries_obj, timeref_or_epoch, t0, t1)
            %  READTIMESERIES - read a time series from this parent object (ndi.time.timeseries) 
            %
            %  [DATA, T, TIMEREF] = READTIMESERIES(NDI_TIMESERIES_OBJ, TIMEREF_OR_EPOCH, T0, T1)
            %
            %  Reads timeseries data from an ndi.time.timeseries object. The DATA and time information T that are
            %  returned depend on the the specific subclass of ndi.time.timeseries that is called (see READTIMESERIESEPOCH).
            %
            %  TIMEREF_OR_EPOCH is either an ndi.time.timereference object indicating the time reference for
            %  T0, T1, or it can be a single number, which will indicate the data are to be read from that
            %  epoch.
            %
            %  DATA is the data for the probe.  T is a time structure, in units of TIMEREF if it is an
            %  ndi.time.timereference object or in units of the epoch if an epoch is passed.  The TIMEREF is returned.

        end; % readtimeseries()

        function sr = samplerate(ndi_timeseries_obj, epoch)
            % SAMPLE_RATE - return the sample rate of an ndi.time.timeseries object
            %
            % SR = SAMPLE_RATE(NDI_TIMESERIES_OBJ, EPOCH)
            %
            % Returns the sampling rate of a given ndi.time.timeseries object for the epoch
            % EPOCH. EPOCH can be specified as an index or EPOCH_ID.
            %
            % If NDI_TIMESERIES_OBJ is not regularly sampled, then -1 is returned.
                sr = -1; % -1 for abstract class
        end; % sample_rate
    
        function samples = times2samples(ndi_timeseries_obj, epoch, times)
            % SAMPLES2TIMES - convert from the timeseries time to sample numbers
            %
            % SAMPLES = TIMES2SAMPLES(NDI_TIMESERIES_OBJ, EPOCH, TIMES)
            %
            % For a given ndi.time.timeseries object and a recording epoch EPOCH,
            % return the sample index numbers SAMPLE that corresponds to the times TIMES.
            % The first sample in the epoch is 1.
            % The TIMES requested might be out of bounds of the EPOCH; no checking is performed.
            % 
                
                % TODO: convert times to dev_local_clock 
                sr = ndi_timeseries_obj.samplerate(epoch);
                if sr>0,
                    et = ndi_timeseries_obj.epochtableentry(epoch);
                    samples = 1 + round ((times-et.t0_t1{1}(1))*sr);
                    g = (isinf(times) & (times < 0));
                    samples(g) = 1;
                    g = (isinf(times) & (times > 0));
                    samples(g) = 1+sr*diff(et.t0_t1{1}(1:2));
                else,
                    samples = []; % need to be overriden
                end;
        end;    

        function times = samples2times(ndi_timeseries_obj, epoch, samples)
            % TIME2SAMPLES - convert from the timeseries time to sample numbers
            %
            % SAMPLES = TIME2SAMPLES(NDI_TIMESERIES_OBJ, EPOCH, TIMES)
            %
            % For a given ndi.time.timeseries object and a recording epoch EPOCH,
            % return the sample index numbers SAMPLE that corresponds to the times TIMES.
            % The first sample in the epoch is 1.
            % The TIMES requested might be out of bounds of the EPOCH; no checking is performed.
            % 
                % TODO: convert times to dev_local_clock 
                sr = ndi_timeseries_obj.samplerate(epoch);
                if sr>0,
                    et = ndi_timeseries_obj.epochtableentry(epoch);
                    times = et.t0_t1{1}(1) + (samples-1)/sr; 
                else,
                    times = []; % need to be overriden
                end;
        end;    

    end % methods
end % class ndi.time.timereference

