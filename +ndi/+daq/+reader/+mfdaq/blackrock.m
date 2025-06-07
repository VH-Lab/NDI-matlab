% NDI_DAQREADER_MFDAQ_BLACKROCK - Device driver for Blackrock Microsystems NSx/NEV file format
%
% This class reads data from Blackrock Microsystems NSx/NEV file format.
%
% Blackrock Microsystems: https://www.blackrockmicro.com/
%
%

classdef blackrock < ndi.daq.reader.mfdaq
    properties

    end % properties

    methods
        function obj = blackrock(varargin)
            % ndi.daq.reader.mfdaq.blackrock - Create a new NDI_DEVICE_MFDAQ_BLACKROCK object
            %
            %  D = ndi.daq.reader.mfdaq.blackrock()
            %
            %  Creates a new ndi.daq.reader.mfdaq.blackrock object
            %
            obj = obj@ndi.daq.reader.mfdaq(varargin{:})
        end

        function channels = getchannelsepoch(ndi_daqreader_mfdaq_blackrock_obj, epochfiles)
            % GETCHANNELSEPOCH - List the channels that are available on this Blackrock device for a given set of files
            %
            %  CHANNELS = GETCHANNELSEPOCH(NDI_DAQREADER_MFDAQ_BLACKROCK_OBJ, EPOCHFILES)
            %
            %  Returns the channel list of acquired channels in this session
            %
            % CHANNELS is a structure list of all channels with fields:
            % -------------------------------------------------------
            % 'name'             | The name of the channel (e.g., 'ai1')
            % 'type'             | The type of data stored in the channel
            %                    |    (e.g., 'analogin', 'digitalin', 'image', 'timestamp')
            %

            [ns_h,nev_h,headers] = read_blackrock_headers(ndi_daqreader_mfdaq_blackrock_obj, epochfiles);
            % to do: need to search nev file
            channels = vlt.data.emptystruct('name','type');
            for i=1:numel(ns_h.MetaTags.ChannelID)
                newchannel.type = 'analog_in';
                newchannel.name = ['ai' int2str(ns_h.MetaTags.ChannelID(i))];
                channels(end+1) = newchannel;
            end;

        end % getchannels()

        function [b,msg] = verifyepochprobemap(ndi_daqreader_mfdaq_blackrock_obj, epochprobemap, epochfiles)
            % VERIFYEPOCHPROBEMAP - Verifies that an EPOCHPROBEMAP is compatible with a given device and the data on disk
            %
            %   B = VERIFYEPOCHPROBEMAP(NDI_DAQREADER_MFDAQ_BLACKROCK_OBJ, EPOCHPROBEMAP, EPOCHFILES)
            %
            % Examines the NDI_EPOCHPROBEMAP_DAQREADER EPOCHPROBEMAP and determines if it is valid for the given device
            % with epoch files EPOCHFILES.
            %
            % See also: ndi.daq.reader, NDI_EPOCHPROBEMAP_DAQREADER
            b = 1;
            msg = '';
            % UPDATE NEEDED
        end

        function data = readchannels_epochsamples(ndi_daqreader_mfdaq_blackrock_obj, channeltype, channel, epochfiles, s0, s1)
            %  READCHANNELS_EPOCHSAMPLES - read the data based on specified channels
            %
            %  DATA = READCHANNELS_EPOCHSAMPLES(MYDEV, CHANNELTYPE, CHANNEL, EPOCHFILES ,S0, S1)
            %
            %  CHANNELTYPE is the type of channel to read (cell array of strings, one per channel)
            %
            %  CHANNEL is a vector of the channel numbers to read, beginning from 1
            %
            %  EPOCH is set of epoch files
            %
            %  DATA is the channel data (each column contains data from an individual channel)
            %
            [nev_files, nsv_files] = ndi.daq.reader.mfdaq.blackrock.filenamefromepochfiles(epochfiles);

            [ns_h,nev_h,headers] = ndi_daqreader_mfdaq_blackrock_obj.read_blackrock_headers(epochfiles);

            uniquechannel = unique(channeltype);
            if numel(uniquechannel)~=1
                error(['Only one type of channel may be read per function call at present.']);
            end

            data = [];

            if s0 < 1
                s0 = 1; % in Blackrock, the first sample is always 1
            elseif s0 > ns_h.MetaTags.DataPoints
                s0 = ns_h.MetaTags.DataPoints;
            end;

            if s1 > ns_h.MetaTags.DataPoints
                s1 = ns_h.MetaTags.DataPoints;
            end;

            if s1 < s0
                data = zeros(0, numel(channel));
                return;
            end;

            if strcmp(vlt.data.celloritem(channeltype,1),'ai')
                for i=1:numel(channel)
                    ns_out = openNSx(nsv_files{1},'read','precision','double','uV','sample',...
                        ['t:' int2str(s0) ':' int2str(s1)], ['c:' int2str(channel(i))]);
                    if ~isstruct(ns_out)
                        error(['No data read from channel ' int2str(i) ' of blackrock record.']);
                    end;
                    data = cat(2,data,ns_out.Data');
                end;

            elseif strcmp(vlt.data.celloritem(channeltype,1),'time')
                data = cat(1,data,ns_h.MetaTags.Timestamp+((s0:s1)'-1)*1./ns_h.MetaTags.SamplingFreq);
            end;

        end % readchannels_epochsamples

        function sr = samplerate(ndi_daqreader_mfdaq_blackrock_obj, epochfiles, channeltype, channel)
            % SAMPLERATE - GET THE SAMPLE RATE FOR SPECIFIC EPOCH AND CHANNEL
            %
            % SR = SAMPLERATE(DEV, EPOCHFILES, CHANNELTYPE, CHANNEL)
            % CHANNELTYPE can be either a string or a cell array of
            % strings the same length as the vector CHANNEL.
            % If CHANNELTYPE is a single string, then it is assumed that
            % that CHANNELTYPE applies to every entry of CHANNEL.
            %
            % SR is the list of sample rate from specified channels
            %
            sr = [];

            [ns_h,nev_h,headers] = read_blackrock_headers(ndi_daqreader_mfdaq_blackrock_obj, epochfiles, channeltype, channel);

            for i=1:numel(channel)
                ct = vlt.data.celloritem(channeltype,i);
                if strcmpi(ct,'ai') | strcmpi(ct,'time')
                    sr(i) = ns_h.MetaTags.SamplingFreq;
                else
                    error(['At present, do not know how to handle Blackrock Micro channels of type ' ct '.']);
                end;
            end;
        end % samplerate()

        function [ns_h,nev_h,headers] = read_blackrock_headers(ndi_daqreader_mfdaq_blackrock_obj, epochfiles, channeltype, channels)
            % READ_BLACKROCK_HEADERS - read information from Blackrock Micro header files
            %
            % [NS_H, NEV_H, HEADERS] = READ_BLACKROCK_HEADERS(NDI_DAQREADER_MFDAQ_BLACKROCK_OBJ, EPOCHFILES, [CHANNELTYPE, CHANNELS])
            %
            [nev_files, nsv_files] = ndi.daq.reader.mfdaq.blackrock.filenamefromepochfiles(epochfiles);
            if ~isempty(nsv_files{1})
                ns_h = openNSx(nsv_files{1},'noread');
            else
                ns_h = [];
            end;
            if ~isempty(nev_files{1})
                nev_h = openNEV(nev_files{1},'noread');
                nev_h = [];
            end;

            headers.ns_rate = [];
            if ~isempty(ns_h)
                headers.ns_rate = ns_h.MetaTags.SamplingFreq;
            end;
            headers.requestedchanneltype = [];
            headers.requestedchannelindexes= [];

            if nargin>=3
                for i=1:numel(channels)
                    ct = vlt.data.celloritem(channeltype,i);
                    if strcmpi(ct,'ai')
                        if isempty(ns_h)
                            error(['ai channels in Blackrock must be stored in .ns# files, but there is none.']);
                        end;
                        index = find(ns_h.MetaTags.ChannelID==channels(i));
                        if isempty(index)
                            error(['Channel ' int2str(channels(i)) ' not recorded.']);
                        else
                            headers.requestedchannelindexes(i) = index;
                            headers.requestedchanneltype(i) = 1; % ns==1, nev==2
                        end;
                    else
                        error(['At present, do not know how to handle Blackrock Micro channels of type ' ct '.']);
                    end;
                end;
            end;
        end; % read_blackrock_headers()

        function t0t1 = t0_t1(ndi_daqreader_mfdaq_blackrock_obj, epochfiles)
            % T0_T1 - return the t0_t1 (beginning and end) epoch times for an epoch
            %
            % T0T1 = T0_T1(NDI_EPOCHSET_OBJ, EPOCHFILES)
            %
            % Return the beginning (t0) and end (t1) times of the epoch EPOCH_NUMBER
            % in the same units as the ndi.time.clocktype objects returned by EPOCHCLOCK.
            %
            % The abstract class always returns {[NaN NaN]}.
            %
            % See also: ndi.time.clocktype, EPOCHCLOCK
            %
            [ns_h,nev_h,headers] = read_blackrock_headers(ndi_daqreader_mfdaq_blackrock_obj, epochfiles);
            % need to convert from duration of whole recording to time labels of the first and last sample
            % time of last sample = duration - 1/samplingfreq
            t0t1 = {[ns_h.MetaTags.Timestamp + [0 ns_h.MetaTags.DataDurationSec-1/ns_h.MetaTags.SamplingFreq]]};
            % developer note: in the Blackrock acquisition software, one can define a time offset; right now we aren't considering that
        end % t0t1

    end % methods

    methods (Static)  % helper functions

        function [nevfiles, nsvfiles] = filenamefromepochfiles(filename_array)
            % FILENAMEFROMEPOCHFILES - return the file name that corresponds to the NEV/NSV files
            %
            % [NEVFILES, NSVFILES] = FILENAMEFROMEPOCHFILES(FILENAME_ARRAY)
            %
            % Examines the list of filenames in FILENAME_ARRAY (cell array of full path file strings) and determines which
            % ones have the extension '.nev' (neuro event file) and which have the extension '.ns#', where # is a number, or the source
            % data files.
            %
            sv = ['.*\.ns\d\>'];
            tf_sv = vlt.string.strcmp_substitution(sv,filename_array,'UseSubstituteString',0);
            nsvfiles = filename_array(find(tf_sv));

            ne_search = ['.*\.nev\>'];
            tf_ne = vlt.string.strcmp_substitution(ne_search,filename_array,'UseSubstituteString',0);
            nevfiles = filename_array(find(tf_ne));

            if numel(nsvfiles)+numel(nevfiles) == 0
                error(['No .ns# or .nev files found.']);
            end;

            if numel(nsvfiles)>1
                error(['More than 1 NS# file in this file list; do not know what to do.']);
            end;
        end % filenamefromepoch

    end % methods (Static)
end
