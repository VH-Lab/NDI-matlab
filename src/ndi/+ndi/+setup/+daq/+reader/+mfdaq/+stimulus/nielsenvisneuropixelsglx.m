% NDI_DAQREADER_MFDAQ_STIMULUS_NIELSENVISNEUROPIXELSGLX - Device object for vhlab visual stimulus computer with Neuropixels GLX
%
% This device reads the '.analyzer' files and analog input channels from a Neuropixels GLX recording
% that are present in directories where a VHLAB stimulus computer (running NewStim/RunExperiment)
% has produced triggers that have been acquired on a Neuropixels GLX system.
%
% Analog channel 1 is the stimulus setup / clear times signal.
% Analog channel 2 is the stimulus on / off times signal.
% A threshold of 2.5V is applied to detect signal transitions.
%
% This device produces the following event channels in each epoch:
%
% Channel name:   | Signal description:
% ----------------|------------------------------------------
% mk1             | stimulus on/off
% mk2             | stimid
% mk3             | stimulus open/close (begin background/end background)
%

classdef nielsenvisneuropixelsglx < ndi.daq.reader.mfdaq.ndr
    properties (GetAccess=public,SetAccess=protected)
    end
    properties (Access=private) % potential private variables
    end

    methods
        function obj = nielsenvisneuropixelsglx(varargin)
            % ndi.setup.daq.reader.mfdaq.stimulus.nielsenvisneuropixelsglx - Create a new multifunction DAQ object
            %
            %  D = ndi.setup.daq.reader.mfdaq.stimulus.nielsenvisneuropixelsglx()
            %
            %  Creates a new ndi.setup.daq.reader.mfdaq.stimulus.nielsenvisneuropixelsglx object
            %  that reads from Neuropixels GLX files.
            obj = obj@ndi.daq.reader.mfdaq.ndr('neuropixelsGLX');
        end % nielsenvisneuropixelsglx()

        function ec = epochclock(ndi_daqreader_mfdaq_stimulus_nielsenvisneuropixelsglx_obj, epochfiles)
            % EPOCHCLOCK - return the ndi.time.clocktype objects for an epoch
            %
            % EC = EPOCHCLOCK(NDI_DAQREADER_MFDAQ_STIMULUS_NIELSENVISNEUROPIXELSGLX_OBJ, EPOCHFILES)
            %
            % Return the clock types available for this epoch as a cell array
            % of ndi.time.clocktype objects (or sub-class members).
            %
            % This returns a single clock type 'dev_local_time';
            %
            % See also: ndi.time.clocktype
            %
            ec = {ndi.time.clocktype('dev_local_time')};
        end % epochclock

        function channels = getchannelsepoch(thedev, epochfiles)
            % GETCHANNELSEPOCH - List the channels that are available on this device
            %
            %  CHANNELS = GETCHANNELSEPOCH(THEDEV, EPOCHFILES)
            %
            % This device produces the following channels in each epoch:
            % Channel name:   | Signal description:
            % ----------------|------------------------------------------
            % mk1             | stimulus on/off
            % mk2             | stimid
            % mk3             | stimulus open/close
            %
            channels        = struct('name','mk1','type','marker','time_channel',NaN);
            channels(end+1) = struct('name','mk2','type','marker','time_channel',NaN);
            channels(end+1) = struct('name','mk3','type','marker','time_channel',NaN);
        end % getchannelsepoch()

        function [timestamps,data] = readevents_epochsamples_native(ndi_daqreader_mfdaq_stimulus_nielsenvisneuropixelsglx_obj, channeltype, channel, epochfiles, t0, t1)
            %  READEVENTS_EPOCHSAMPLES_NATIVE - read events or markers of specified channels for a specified epoch
            %
            %  [TIMESTAMPS, DATA] = READEVENTS_EPOCHSAMPLES_NATIVE(SELF, CHANNELTYPE, CHANNEL, EPOCHFILES, T0, T1)
            %
            %  SELF is the NDI_DAQREADER_MFDAQ_STIMULUS_NIELSENVISNEUROPIXELSGLX object.
            %
            %  CHANNELTYPE is a cell array of strings describing the the type(s) of channel(s) to read
            %  ('event','marker', etc). If CHANNELTYPE is a string, it is
            %  assumed to apply to all channels.
            %
            %  CHANNEL is a vector with the identity of the channel(s) to be read.
            %
            %  EPOCH is the cell array of file names associated with an epoch
            %
            %  DATA is a two-column vector; the first column has the time of the event. The second
            %  column indicates the marker code. In the case of 'events', this is just 1. If more than one channel
            %  is requested, DATA is returned as a cell array, one entry per channel.
            %
            timestamps = {};
            data = {};

            if ~iscell(channeltype)
                channeltype = repmat({channeltype},numel(channel),1);
            end

            pathname = {};
            fname = {};
            ext = {};
            analyzerFile = '';
            for i=1:numel(epochfiles)
                [pathname{i},fname{i},ext{i}] = fileparts(epochfiles{i});
                if strcmp(ext{i},'.analyzer')
                    analyzerFile = epochfiles{i};
                end
            end
            if isempty(analyzerFile)
                error(['No .analyzer file among epochfiles.']);
            end

            z = load(analyzerFile,'-mat');

            % do the decoding
            [stimParams,displayOrder] = ndi.setup.stimulus.kjnielsenlab.extractStimulusParameters(z.Analyzer);
            stimid = displayOrder;

            % read analog data and time

            srt = ndi_daqreader_mfdaq_stimulus_nielsenvisneuropixelsglx_obj.samplerate(epochfiles,'time', 1);
            s0d = round(1+round(srt*t0));
            s1d = round(1+round(srt*t1));

            [analogData] = ndi_daqreader_mfdaq_stimulus_nielsenvisneuropixelsglx_obj.readchannels_epochsamples(...
                'analog_in', [1;2], epochfiles, s0d, s1d);

            [timeData] = ndi_daqreader_mfdaq_stimulus_nielsenvisneuropixelsglx_obj.readchannels_epochsamples(...
                'time', 1, epochfiles, s0d, s1d);

            % apply threshold to convert analog signals to logical
            threshold = 2.5;
            refractory_samples = round(0.05 * srt); % 0.05 second refractory period

            % channel 2 is stimulus on/off
            stim_on_off_signal = analogData(:,2);
            pos_crossings_2 = find(stim_on_off_signal(1:end-1) < threshold & stim_on_off_signal(2:end) >= threshold) + 1;
            neg_crossings_2 = find(stim_on_off_signal(1:end-1) >= threshold & stim_on_off_signal(2:end) < threshold) + 1;
            pos_crossings_2 = vlt.signal.refractory(pos_crossings_2, refractory_samples);
            neg_crossings_2 = vlt.signal.refractory(neg_crossings_2, refractory_samples);
            stimontimes = timeData(pos_crossings_2);
            stimofftimes = timeData(neg_crossings_2);

            % channel 1 is stimulus setup/clear
            setup_clear_signal = analogData(:,1);
            pos_crossings_1 = find(setup_clear_signal(1:end-1) < threshold & setup_clear_signal(2:end) >= threshold) + 1;
            neg_crossings_1 = find(setup_clear_signal(1:end-1) >= threshold & setup_clear_signal(2:end) < threshold) + 1;
            pos_crossings_1 = vlt.signal.refractory(pos_crossings_1, refractory_samples);
            neg_crossings_1 = vlt.signal.refractory(neg_crossings_1, refractory_samples);
            stimsetuptimes = timeData(pos_crossings_1);
            stimcleartimes = timeData(neg_crossings_1);

            for i=1:numel(channel)
                switch (ndi.daq.system.mfdaq.mfdaq_prefix(channeltype{i}))
                    case 'mk'
                        % put them together, alternating stimtimes and stimofftimes in the final product
                        time1 = [stimontimes(:)' ; stimofftimes(:)'];
                        data1 = [ones(size(stimontimes(:)')) ; -1*ones(size(stimofftimes(:)'))];
                        time1 = reshape(time1,numel(time1),1);
                        data1 = reshape(data1,numel(data1),1);
                        ch{1} = [time1 data1];

                        time2 = [stimontimes(:)];
                        data2 = [stimid(:)];
                        ch{2} = [time2 data2(1:size(time2,1),:)]; % fix for aborted trials

                        time3 = [stimsetuptimes(:)' ; stimcleartimes(:)'];
                        data3 = [ones(size(stimsetuptimes(:)')) ; -1*ones(size(stimcleartimes(:)'))];
                        time3 = reshape(time3,numel(time3),1);
                        data3 = reshape(data3,numel(data3),1);
                        ch{3} = [time3 data3];

                        timestamps{i} = ch{channel(i)}(:,1);
                        data{i} = ch{channel(i)}(:,2:end);
                    case 'md'

                    otherwise
                        error(['Unknown channel.']);
                end
            end

            for i=1:numel(timestamps)
                inds_here = find(timestamps{i}>=t0 & timestamps{i}<=t1);
                timestamps{i} = timestamps{i}(inds_here);
                data{i} = data{i}(inds_here);
            end

            if numel(data)==1 % if only 1 channel entry to return, make it non-cell
                timestamps = timestamps{1};
                data = data{1};
            end

        end % readevents_epochsamples_native()

        function data = readchannels_epochsamples(obj, channeltype, channel, epochfiles, s0, s1)
            % READCHANNELS_EPOCHSAMPLES - read channel data, filtering epochfiles for the ndr reader
            epochfiles = ndi.setup.daq.reader.mfdaq.stimulus.nielsenvisneuropixelsglx.filter_epochfiles(epochfiles);
            data = readchannels_epochsamples@ndi.daq.reader.mfdaq.ndr(obj, channeltype, channel, epochfiles, s0, s1);
        end

        function sr = samplerate(obj, epochfiles, channeltype, channel)
            % SAMPLERATE - GET THE SAMPLE RATE FOR SPECIFIC CHANNEL
            epochfiles = ndi.setup.daq.reader.mfdaq.stimulus.nielsenvisneuropixelsglx.filter_epochfiles(epochfiles);
            sr = samplerate@ndi.daq.reader.mfdaq.ndr(obj, epochfiles, channeltype, channel);
        end

        function t0t1 = t0_t1(obj, epochfiles)
            % T0_T1 - return the t0_t1 (beginning and end) epoch times for an epoch
            epochfiles = ndi.setup.daq.reader.mfdaq.stimulus.nielsenvisneuropixelsglx.filter_epochfiles(epochfiles);
            t0t1 = t0_t1@ndi.daq.reader.mfdaq.ndr(obj, epochfiles);
        end

    end % methods

    methods (Static)
        function epochfiles = filter_epochfiles(epochfiles)
            % FILTER_EPOCHFILES - remove .meta files that do not have a matching .bin file
            %
            %  EPOCHFILES = FILTER_EPOCHFILES(EPOCHFILES)
            %
            %  For each .bin file in EPOCHFILES, the matching .meta file has the same
            %  name with .meta instead of .bin. Any .meta file without a corresponding
            %  .bin file is removed so that the neuropixelsGLX reader sees exactly one.
            %
            bin_bases = {};
            for i = 1:numel(epochfiles)
                if endsWith(epochfiles{i}, '.bin')
                    bin_bases{end+1} = epochfiles{i}(1:end-4); %#ok<AGROW>
                end
            end
            keep = true(size(epochfiles));
            for i = 1:numel(epochfiles)
                if endsWith(epochfiles{i}, '.meta')
                    meta_base = epochfiles{i}(1:end-5);
                    if ~any(strcmp(meta_base, bin_bases))
                        keep(i) = false;
                    end
                end
            end
            epochfiles = epochfiles(keep);
        end
    end % static methods
end
