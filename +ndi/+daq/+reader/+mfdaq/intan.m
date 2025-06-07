% NDI_DAQREADER_MFDAQ_INTAN - Device driver for Intan Technologies RHD file forma
%
% This class reads data from Intan Technologies .RHD file format.
%
% Intan Technologies: http://intantech.com/
%
%

classdef intan < ndi.daq.reader.mfdaq
    properties

    end % properties

    methods
        function obj = intan(varargin)
            % ndi.daq.reader.mfdaq.intan - Create a new NDI_DEVICE_MFDAQ_INTAN object
            %
            %  D = ndi.daq.reader.mfdaq.intan(NAME,THEFILENAVIGATOR)
            %
            %  Creates a new ndi.daq.reader.mfdaq.intan object with name NAME and associated
            %  filenavigator THEFILENAVIGATOR.
            %
            obj = obj@ndi.daq.reader.mfdaq(varargin{:})
        end

        function channels = getchannelsepoch(ndi_daqreader_mfdaq_intan_obj, epochfiles)
            % GETCHANNELSEPOCH - List the channels that are available on this Intan device for a given set of files
            %
            %  CHANNELS = GETCHANNELSEPOCH(NDI_DAQREADER_MFDAQ_INTAN_OBJ, EPOCHFILES)
            %
            %  Returns the channel list of acquired channels in this session
            %
            % CHANNELS is a structure list of all channels with fields:
            % -------------------------------------------------------
            % 'name'             | The name of the channel (e.g., 'ai1')
            % 'type'             | The type of data stored in the channel
            %                    |    (e.g., 'analogin', 'digitalin', 'image', 'timestamp')
            % 'time_channel'     | The channel number that contains the time information for
            %                    |    each channel.
            %
            channels.name = 't1';
            channels.type = 'time';
            channels.time_channel = 1;

            intan_channel_types = {
                'amplifier_channels'
                'aux_input_channels'
                'board_dig_in_channels'
                'board_dig_out_channels'};

            multifunctiondaq_channel_types = ndi.daq.system.mfdaq.mfdaq_channeltypes;

            % open RHD files, and examine the headers for all channels present
            %   for any new channel that hasn't been identified before,
            %   add it to the list

            filename = ndi_daqreader_mfdaq_intan_obj.filenamefromepochfiles(epochfiles);
            header = read_Intan_RHD2000_header(filename);

            for k=1:length(intan_channel_types)
                if isfield(header,intan_channel_types{k})
                    channel_type_entry = ndi_daqreader_mfdaq_intan_obj.intanheadertype2mfdaqchanneltype(...
                        intan_channel_types{k});
                    channel = getfield(header, intan_channel_types{k});
                    num = numel(channel);             %% number of channels with specific type
                    for p = 1:numel(channel)
                        newchannel.type = channel_type_entry;
                        newchannel.name = ndi_daqreader_mfdaq_intan_obj.intanname2mfdaqname(...
                            ndi_daqreader_mfdaq_intan_obj,...
                            channel_type_entry,...
                            channel(p).native_channel_name);
                        newchannel.time_channel = 1;
                        if strcmp(newchannel.type,'auxiliary_in')
                            newchannel.time_channel = 2;
                        end;
                        channels(end+1) = newchannel;
                    end
                end
            end
        end % getchannels()

        function [b,msg] = verifyepochprobemap(ndi_daqreader_mfdaq_intan_obj, epochprobemap, epochfiles)
            % VERIFYEPOCHPROBEMAP - Verifies that an EPOCHPROBEMAP is compatible with a given device and the data on disk
            %
            %   B = VERIFYEPOCHPROBEMAP(NDI_DAQREADER_MFDAQ_INTAN_OBJ, EPOCHPROBEMAP, EPOCHFILES)
            %
            % Examines the NDI_EPOCHPROBEMAP_DAQREADER EPOCHPROBEMAP and determines if it is valid for the given device
            % with epoch files EPOCHFILES.
            %
            % See also: ndi.daq.reader, NDI_EPOCHPROBEMAP_DAQREADER
            b = 1;
            msg = '';
            % UPDATE NEEDED
        end

        function [filename, parentdir, isdirectory] = filenamefromepochfiles(ndi_daqreader_mfdaq_intan_obj, filename_array)
            % FILENAMEFROMEPOCHFILES - return the file name that corresponds to the RHD file, or directory in case of directory
            %
            % [FILENAME, PARENTDIR, ISDIRECTORY] = FILENAMEFROMEPOCHFILES(NDI_DAQREADER_MFDAQ_INTAN_OBJ, FILENAME_ARRAY)
            %
            % Examines the list of filenames in FILENAME_ARRAY (cell array of full path file strings) and determines which
            % one is an RHD data file. If the 1-file-per-channel mode is used, then PARENTDIR is the name of the directory
            % that holds the data files and ISDIRECTORY is 1.

            s1 = ['.*\.rhd\>']; % equivalent of *.ext on the command line
            [tf, matchstring, substring] = vlt.string.strcmp_substitution(s1,filename_array,'UseSubstituteString',0);
            parentdir = '';
            isdirectory = 0;

            index = find(tf);
            if numel(index)> 1
                error(['Need only 1 .rhd file per epoch.']);
            elseif numel(index)==0
                error(['Need 1 .rhd file per epoch.']);
            else
                filename = filename_array{index};
                [parentdir, fname, ext] = fileparts(filename);
                if contains(fname,'info')
                    s2 = ['time\.dat\>']; % equivalent of *.ext on the command line
                    tf2 = vlt.string.strcmp_substitution(s2,filename_array,'UseSubstituteString',0);
                    if any(tf)
                        % we will call it a directory
                        isdirectory = 1;
                    end;
                end;
            end
        end % filenamefromepoch

        % 01234567890123456789012345678901234567890123456789012345678901234567890123456789
        function data = readchannels_epochsamples(ndi_daqreader_mfdaq_intan_obj, channeltype, channel, epochfiles, s0, s1)
            %  READCHANNELS_EPOCHSAMPLES - read the data based on specified channels
            %
            %  DATA = READCHANNELS_EPOCHSAMPLES(MYDEV, CHANNELTYPE, CHANNEL, EPOCHFILES ,S0, S1)
            %
            %  CHANNELTYPE is the type of channel to read (cell array of strings, one per
            %     channel, or single string for all channels)
            %
            %  CHANNEL is a vector of the channel numbers to read, beginning from 1
            %
            %  EPOCH is set of epoch files
            %
            %  DATA is the channel data (each column contains data from an individual channel)
            %
            [filename,parentdir,isdirectory] = ndi_daqreader_mfdaq_intan_obj.filenamefromepochfiles(epochfiles);

            if ~iscell(channeltype)
                channeltype = repmat({channeltype},numel(channel),1);
            end;
            uniquechannel = unique(channeltype);
            if numel(uniquechannel)~=1
                error(['Only one type of channel may be read per function call at present.']);
            end
            intanchanneltype = ndi_daqreader_mfdaq_intan_obj.mfdaqchanneltype2intanchanneltype(uniquechannel{1});

            sr = ndi_daqreader_mfdaq_intan_obj.samplerate(epochfiles, channeltype, channel);
            sr_unique = unique(sr); % get all sample rates
            if numel(sr_unique)~=1
                error(['Do not know how to handle different sampling rates across channels.']);
            end;

            sr = sr_unique;

            t0 = (s0-1)/sr;
            t1 = (s1-1)/sr;

            if strcmp(intanchanneltype,'time')
                channel = 1; % time only has 1 channel in Intan RHD
            end;

            is_digital = 0;
            if strcmp(intanchanneltype,'din')
                is_digital = 1;
                alt_channel = channel;
                channel = 1;
            end;

            if strcmp(intanchanneltype,'dout')
                is_digital = 1;
                alt_channel = channel;
                channel = 1;
            end;

            if ~isdirectory
                data = read_Intan_RHD2000_datafile(filename,'',intanchanneltype,channel,t0,t1);
            else
                data = read_Intan_RHD2000_directory(parentdir,'',intanchanneltype,channel,t0,t1);
            end;

            if is_digital
                digital_data = int2bit(data', 8, 0)';
                if size(digital_data,2)<16 % make sure our output is 16 bits wide
                    digital_data = [digital_data zeros(size(digital_data,1),8) ];
                end;
                data = digital_data(:,alt_channel);
            end;

        end % readchannels_epochsamples

        function [datatype,p,datasize] = underlying_datatype(ndi_daqreader_mfdaq_obj, epochfiles, channeltype, channel)
            % UNDERLYING_DATATYPE - get the underlying data type for a channel in an epoch
            %
            % [DATATYPE,P,DATASIZE] = UNDERLYING_DATATYPE(DEV, EPOCHFILES, CHANNELTYPE, CHANNEL)
            %
            % Return the underlying datatype for the requested channel.
            %
            % DATATYPE is a type that is suitable for passing to FREAD or FWRITE
            %  (e.g., 'float64', 'uint16', etc. See help fread.)
            %
            % P is a polynomial that converts between the double data that is returned by
            % READCHANNEL. RETURNED_DATA = (RAW_DATA+P(1))*P(2)+(RAW_DATA+P(1))*P(3) ...
            %
            % DATASIZE is the sample size in bits.
            %
            % CHANNELTYPE must be a string. It is assumed that
            % that CHANNELTYPE applies to every entry of CHANNEL.
            %
            switch(channeltype)
                case {'analog_in','analog_out'}
                    % For the abstract class, keep the data in doubles. This will always work but may not
                    % allow for optimal compression if not overridden
                    datatype = 'uint16';
                    datasize = 16;
                    p = [32768 0.195];
                case {'auxiliary_in'}
                    datatype = 'uint16';
                    datasize = 16;
                    p = [0 3.7400e-05];
                case {'time'}
                    datatype = 'float64';
                    datasize = 64;
                    p = [0 1];
                case {'digital_in','digital_out'}
                    datatype = 'char';
                    datasize = 8;
                    p = [0 1];
                case {'eventmarktext','event','marker','text'}
                    datatype = 'float64';
                    datasize = 64;
                    p = [0 1];
                otherwise
                    error(['Unknown channel type ' channeltype '.']);
            end; %
        end;

        function sr = samplerate(ndi_daqreader_mfdaq_intan_obj, epochfiles, channeltype, channel)
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
            filename = ndi_daqreader_mfdaq_intan_obj.filenamefromepochfiles(epochfiles);

            if iscell(channeltype) & numel(channeltype)==1 & numel(channel) ~=1
                channeltype = repmat(channeltype,1,numel(channel));
            end;

            head = read_Intan_RHD2000_header(filename);
            for i=1:numel(channel)
                channeltype_here = vlt.data.celloritem(channeltype,i);
                freq_fieldname = ndi_daqreader_mfdaq_intan_obj.mfdaqchanneltype2intanfreqheader(channeltype_here);
                sr(i) = getfield(head.frequency_parameters,freq_fieldname);
            end
        end % samplerate()

        function t0t1 = t0_t1(ndi_daqreader_mfdaq_intan_obj, epochfiles)
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
            [filename,parentdir,isdirectory] = ndi_daqreader_mfdaq_intan_obj.filenamefromepochfiles(epochfiles);
            header = read_Intan_RHD2000_header(filename);
            if ~isdirectory
                [blockinfo, bytes_per_block, bytes_present, num_data_blocks] = Intan_RHD2000_blockinfo(filename, header);

                total_samples = 60 * num_data_blocks;
            else
                finfo = dir([parentdir filesep '*time.dat']);
                if isempty(finfo)
                    error(['File time.dat necessary in directory ' parentdir ' but it was not found.']);
                end;
                total_samples = finfo.bytes / 4;
            end;

            total_time = total_samples / header.frequency_parameters.amplifier_sample_rate; % in seconds

            t0 = 0;
            t1 = total_time-1/header.frequency_parameters.amplifier_sample_rate;

            t0t1 = {[t0 t1]};
            % developer note: in the Intan acquisition software, one can define a time offset; right now we aren't considering that
        end % t0t1

    end % methods

    methods (Static)  % helper functions

        function intanchanheadertype = mfdaqchanneltype2intanheadertype(channeltype)
            % MFDAQCHANNELTYPE2INTANHEADERTYPE - Convert between the ndi.daq.reader.mfdaq channel types and Intan headers
            %
            % INTANCHANHEADERTYPE = MFDAQCHANNELTYPE2INTANHEADERTYPE(CHANNELTYPE)
            %
            % Given a standard ndi.daq.reader.mfdaq channel type, returns the name of the type as
            % indicated in Intan header files.

            switch (channeltype)
                case {'analog_in','ai'}
                    intanchanheadertype = 'amplifier_channels';
                case {'digital_in','di'}
                    intanchanheadertype = 'board_dig_in_channels';
                case {'digital_out','do'}
                    intanchanheadertype = 'board_dig_out_channels';
                case {'auxiliary','aux','ax','auxiliary_in','auxiliary_input'}
                    intanchanheadertype = 'aux_input_channels';
                otherwise
                    error(['Could not convert channeltype ' channeltype '.']);
            end;

        end % mfdaqchanneltype2intanheadertype()

        function channeltype = intanheadertype2mfdaqchanneltype(intanchanneltype)
            % INTANHEADERTYPE2MFDAQCHANNELTYPE- Convert between Intan headers and the ndi.daq.reader.mfdaq channel types
            %
            % CHANNELTYPE = INTANHEADERTYPE2MFDAQCHANNELTYPE(INTANCHANNELTYPE)
            %
            % Given an Intan header file type, returns the standard ndi.daq.reader.mfdaq channel type

            switch (intanchanneltype)
                case {'amplifier_channels'}
                    channeltype = 'analog_in';
                case {'board_dig_in_channels'}
                    channeltype = 'digital_in';
                case {'board_dig_out_channels'}
                    channeltype = 'digital_out';
                case {'aux_input_channels'}
                    channeltype = 'auxiliary_in';
                otherwise
                    error(['Could not convert channeltype ' intanchanneltype '.']);
            end;

        end % mfdaqchanneltype2intanheadertype()

        function intanchanneltype = mfdaqchanneltype2intanchanneltype(channeltype)
            % MFDAQCHANNELTYPE2INTANCHANNELTYPE- convert the channel type from generic format of multifuncdaqchannel
            %                     to the specific intan channel type
            %
            %    INTANCHANNELTYPE = MFDAQCHANNELTYPE2INTANCHANNELTYPE(CHANNELTYPE)
            %
            %     the intanchanneltype is a string of the specific channel type for intan
            %
            switch channeltype
                case {'analog_in','ai'}
                    intanchanneltype = 'amp';
                case {'digital_in','di'}
                    intanchanneltype = 'din';
                case {'digital_out','do'}
                    intanchanneltype = 'dout';
                case {'time','timestamp'}
                    intanchanneltype = 'time';
                case {'auxiliary','aux','auxiliary_input','auxiliary_in'}
                    intanchanneltype = 'aux';
                otherwise
                    error(['Do not know how to convert channel type ' channeltype '.']);
            end
        end % mfdaqchanneltype2intanchanneltype()

        function [ channame ] = intanname2mfdaqname(ndi_daqreader_mfdaq_intan_obj, type, name )
            % INTANNAME2MFDAQNAME - Converts a channel name from Intan native format to ndi.daq.reader.mfdaq format.
            %
            % MFDAQNAME = INTANNAME2MFDAQNAME(ndi.daq.reader.mfdaq.intan, MFDAQTYPE, NAME)
            %
            % Given an Intan native channel name (e.g., 'A-000') in NAME and a
            % ndi.daq.reader.mfdaq channel type string (see NDI_DEVICE_MFDAQ), this function
            % produces an ndi.daq.reader.mfdaq channel name (e.g., 'ai1').
            %
            sep = find(name=='-');
            isaux = 0;
            if numel(name)>=sep+4
                if strcmpi(name(sep+1:sep+3),'aux') % aux channels
                    sep = sep+3;
                    isaux = 1;
                end;
            end;
            chan_intan = str2num(name(sep+1:end));
            if ~isaux
                chan = chan_intan + 1; % intan numbers from 0
            else
                chan = chan_intan;
            end;
            channame = [ndi.daq.system.mfdaq.mfdaq_prefix(type) int2str(chan)];

        end % intanname2mfdaqname()

        function headername = mfdaqchanneltype2intanfreqheader(channeltype)
            % MFDAQCHANNELTYPE2INTANFREQHEADER - Return header name with frequency information for channel type
            %
            %  HEADERNAME = MFDAQCHANNELTYPE2INTANFREQHEADER(CHANNELTYPE)
            %
            %  Given an NDI_DEV_MFDAQ channel type string, this function returns the associated fieldname
            %
            switch channeltype
                case {'analog_in','ai'}
                    headername = 'amplifier_sample_rate';
                case {'digital_in','di'}
                    headername = 'board_dig_in_sample_rate';
                case {'digital_out','do'}
                    headername = 'board_dig_out_sample_rate';
                case {'time','timestamp'}
                    headername = 'amplifier_sample_rate';
                case {'auxiliary','aux','auxiliary_in'}
                    headername = 'aux_input_sample_rate';
                otherwise
                    error(['Do not know frequency header name for channel type ' channeltype '.']);
            end;
        end % mfdaqchanneltype2intanfreqheader()

    end % methods (Static)
end
