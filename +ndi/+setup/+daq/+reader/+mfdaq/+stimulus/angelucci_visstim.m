% NDI_DAQREADER_MFDAQ_STIMULUS_ANGELUCCI_VISSTIM - Device object for Angelucci lab visual stimulus system
%
% This device reads the 'stimData.mat' to obtain stimulus parameters and a *.ns4 file (digital events on ai1).
%
% Channel name:   | Signal description:
% ----------------|------------------------------------------
% m1              | stimulus on/off
% m2              | stimid
%

classdef angelucci_visstim < ndi.daq.reader.mfdaq.blackrock
    properties (GetAcces=public,SetAccess=protected)
    end
    properties (Access=private) % potential private variables
    end

    methods
        function obj = angelucci_visstim(varargin)
            % NDI_DAQREADER_MFDAQ_STIMULUS_ANGELUCCI_VISSTIM2 - Create a new multifunction DAQ object
            %
            %  D = NDI_DAQREADER_MFDAQ_STIMULUS_ANGELUCCI_VISSTIM2(NAME, THEFILENAVIGATOR, DAQREADER)
            %
            %  Creates a new ndi.daq.system.mfdaq object with NAME, and FILENAVIGATOR.
            %  This is an abstract class that is overridden by specific devices.
            obj = obj@ndi.daq.reader.mfdaq.blackrock(varargin{:});
        end; % ndi.daq.reader.mfdaq.stimulus.angelucci_visstim()

        function channels = getchannelsepoch(thedev, epochfiles)
            % FUNCTION GETCHANNELS - List the channels that are available on this device
            %
            %  CHANNELS = GETCHANNELSEPOCH(THEDEV, EPOCHFILES)
            %
            % This device produces the following channels in each epoch:
            % Channel name:   | Signal description:
            % ----------------|------------------------------------------
            % mk1             | stimulus on/off
            % mk2             | stimid
            %
            channels        = struct('name','mk1','type','marker');
            channels(end+1) = struct('name','mk2','type','marker');
        end; % getchannelsepoch()

        function [timestamps,data] = readevents_epochsamples(ndi_daqreader_mfdaq_stimulus_angelucci_visstim_obj, channeltype, channel, epochfiles, t0, t1)
            %  READEVENTS_EPOCHSAMPLES - read events or markers of specified channels for a specified epoch
            %
            %  [TIMESTAMPS,DATA] = READEVENTS_EPOCHSAMPLES(SELF, CHANNELTYPE, CHANNEL, EPOCHFILES, T0, T1)
            %
            %  SELF is the NDI_DAQSYSTEM_MFDAQ_STIMULUS_ANGELUCCI_VISSTIM object.
            %
            %  CHANNELTYPE is a cell array of strings describing the the type(s) of channel(s) to read
            %  ('event','marker', etc)
            %
            %  CHANNEL is a vector with the identity of the channel(s) to be read.
            %
            %  EPOCH is the cell array of file names associated with an epoch
            %
            %  DATA is a two-column vector; the first column has the time of the event. The second
            %  column indicates the marker code. In the case of 'events', this is just 1. If more than one channel
            %  is requested, DATA is returned as a cell array, one entry per channel.
            %

            data = {};
            md_reader = ndi.setup.daq.metadatareader.AngelucciStims();

            tf = endsWith(epochfiles,'stimData.mat','IgnoreCase',true);
            FILENAME = epochfiles{find(tf)};

            [parameters,stimid,stimtimes] = md_reader.readmetadatafromfile(FILENAME);

            stimtimes = (stimtimes(:)-1) / 30000;
            here = stimtimes >= t0 & stimtimes <= t1;
            stimtimes = stimtimes(here);
            stimid = stimid(here);
            stimofftimes = stimtimes + parameters{1}.stimOnDuration / 30000;

            for i=1:numel(channel),
                switch (ndi.daq.system.mfdaq.mfdaq_prefix(channeltype{i})),
                    case 'mk',
                        % put them together, alternating stimtimes and stimofftimes in the final product
                        time1 = [stimtimes(:)' ; stimofftimes(:)'];
                        data1 = [ones(size(stimtimes(:)')) ; -1*ones(size(stimofftimes(:)'))];
                        time1 = reshape(time1,numel(time1),1);
                        data1 = reshape(data1,numel(data1),1);
                        ch{1} = [time1 data1];

                        time2 = [stimtimes(:)];
                        data2 = [stimid(:)];
                        ch{2} = [time2 data2];

                        timestamps{i} = ch{channel(i)}(:,1);
                        data{i} = ch{channel(i)}(:,2:end);
                    case 'md',

                    otherwise,
                        error(['Unknown channel.']);
                end
            end

            if numel(data)==1,% if only 1 channel entry to return, make it non-cell
                timestamps = timestamps{1};
                data = data{1};
            end;

        end % readevents_epochsamples()

    end; % methods

    methods (Static)  % helper functions
    end % static methods
end
