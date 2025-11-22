classdef ndr < ndi.daq.reader.mfdaq
    % ndi.daq.reader.mfdaq.ndr - Allows NDI to use NDR readers
    %
    % This class reads data using NDR-matlab ndr.reader objects.
    %
    % NDR-MATLAB must be installed: https://github.com/VH-Lab/NDR-matlab/
    %

    properties
        ndr_reader_string (1,:) char {mustBeTextScalar}
    end

    methods
        function obj = ndr(varargin)
            % NDR - create a new ndi.daq.reader.mfdaq.ndr object
            %
            % OBJ = NDR(READER_STRING)
            %
            % Creates a new ndi.daq.reader.mfdaq.ndr object
            % for reading files with ndr.reader objects.
            %
            % READER_STRING should be a string that specifies
            % a file type, such as 'RHD', 'sev', 'som', etc.
            %
            % A list of valid strings may be obtained from
            %   reader_string = ndr.known_readers()
            %

            finished = 0;

            if nargin==0
                reader_string = 'RHD';
            elseif nargin==1
                % should be a reader_string
                reader_string = char(varargin{1});
                if isempty(reader_string)
                    error(['READER_STRING must be not empty.']);
                end
            elseif nargin==2 & isa(varargin{1},'ndi.session') & isa(varargin{2},'ndi.document')
                obj.identifier = varargin{2}.document_properties.base.id;
                obj.ndr_reader_string = varargin{2}.document_properties.daqreader_ndr.ndr_reader_string;
                finished = 1;
            else
                error(['Unknown arguments.']);
            end

            if ~finished
                kr = ndr.known_readers();
                index = find(strcmpi(reader_string,kr));
                if isempty(index)
                    error(['READER_STRING must be a member of the known readers of NDR, as listed in ndr.known_readers()']);
                end
                obj.ndr_reader_string = kr{index};
            end
        end

        function channels = getchannelsepoch(ndi_daq_reader_mfdaq_ndr_obj, epochfiles)
            % GETCHANNELSEPOCH - List the channels that are available for this epoch for the NDR daq reader
            %
            %  CHANNELS = GETCHANNELSEPOCH(NDI_DAQ_READER_MFDAQ_NDR_OBJ, EPOCHFILES)
            %
            %  Returns the channel list of acquired channels in this session
            %
            % CHANNELS is a structure list of all channels with fields:
            % -------------------------------------------------------
            % 'name'             | The name of the channel (e.g., 'ai1')
            % 'type'             | The type of data stored in the channel
            %                    |    (e.g., 'analogin', 'digitalin', 'image', 'timestamp')
            % 'time_channel'     | The channel number that has the time information for that channel
            %
            ndr_reader = ndr.reader(ndi_daq_reader_mfdaq_ndr_obj.ndr_reader_string);
            channels = ndr_reader.getchannelsepoch(epochfiles,1);
        end % getchannelsepoch

        function data = readchannels_epochsamples(ndi_daq_reader_mfdaq_ndr_obj, channeltype, channel, epochfiles, s0, s1)
            %  READCHANNELS_EPOCHSAMPLES - read the data based on specified channels
            %
            %  DATA = READCHANNELS_EPOCHSAMPLES(NDI_DAQREADER_MFDAQ_NDR_OBJ, CHANNELTYPE, CHANNEL, EPOCHFILES, S0, S1)
            %
            %  CHANNELTYPE is the type of channel to read (cell array of strings, one per
            %     channel, or single string for all channels)
            %
            %  CHANNEL is a vector of the channel numbers to read, beginning from 1
            %
            %  EPOCHFILES is the cell array of full path filenames for this epoch
            %
            %  DATA is the channel data (each column contains data from an individual channel)
            %
            ndr_reader = ndr.reader(ndi_daq_reader_mfdaq_ndr_obj.ndr_reader_string);
            data = ndr_reader.readchannels_epochsamples(channeltype,channel,epochfiles,1,s0,s1);
        end % readchannels_epochsamples

        function ec = epochclock(ndi_daq_reader_mfdaq_ndr_obj, epochfiles)
            % EPOCHCLOCK - return the ndi.time.clocktype objects for an epoch
            %
            % EC = EPOCHCLOCK(NDI_DAQREADER_MFDAQ_OBJ, EPOCHFILES)
            %
            % Return the clock types available for this epoch as a cell array
            % of ndi.time.clocktype objects (or sub-class members).
            %
            % See also: ndi.time.clocktype
            %
            ndr_reader = ndr.reader(ndi_daq_reader_mfdaq_ndr_obj.ndr_reader_string);
            ec_ndr = ndr_reader.epochclock(epochfiles,1);
            ec = {};
            for i=1:numel(ec_ndr)
                ec{i} = ndi.time.clocktype(ec_ndr{i}.type);
            end
        end % epochclock

        function t0t1 = t0_t1(ndi_daq_reader_mfdaq_ndr_obj, epochfiles)
            % T0_T1 - return the t0_t1 (beginning and end) epoch times for an epoch
            %
            % T0T1 = T0_T1(NDI_DAQSYSTEM_MFDAQ_NDR_OBJ, EPOCHFILES)
            %
            % Return the beginning (t0) and end (t1) times of the EPOCHFILES that define this
            % epoch in the same units as the ndi.time.clocktype objects returned by EPOCHCLOCK.
            %
            %
            % See also: ndi.time.clocktype, EPOCHCLOCK
            %
            ndr_reader = ndr.reader(ndi_daq_reader_mfdaq_ndr_obj.ndr_reader_string);
            t0t1 = ndr_reader.t0_t1(epochfiles,1);
        end % t0t1

        function [datatype,p,datasize] = underlying_datatype(ndi_daq_reader_mfdaq_ndr_obj, epochfiles, channeltype, channel)
            % UNDERLYING_DATATYPE - get the underlying data type for a channel in an epoch
            %
            % [DATATYPE,P,DATASIZE] = UNDERLYING_DATATYPE(NDI_DAQSYSTEM_MFDAQ_NDR_OBJ, EPOCHFILES, CHANNELTYPE, CHANNEL)
            %
            % Return the underlying datatype for the requested channel.
            %
            % DATATYPE is a type that is suitable for passing to FREAD or FWRITE
            %  (e.g., 'float64', 'uint16', etc. See help fread.)
            %
            % P is a matrix of polynomials that converts between the double data that is returned by
            % READCHANNEL. RETURNED_DATA = (RAW_DATA+P(i,1))*P(i,2)+(RAW_DATA+P(i,1))*P(i,3) ...
            % There is one row of P for each entry of CHANNEL.
            %
            % DATASIZE is the sample size in bits.
            %
            % CHANNELTYPE must be a string. It is assumed that
            % that CHANNELTYPE applies to every entry of CHANNEL.
            %
            ndr_reader_obj = ndr.reader(ndi_daq_reader_mfdaq_ndr_obj.ndr_reader_string);
            [datatype,p,datasize] = ndr_reader_obj.ndr_reader_base.underlying_datatype(epochfiles, 1, channeltype, channel);
        end

        function [timestamps,data] = readevents_epochsamples_native(ndi_daq_reader_mfdaq_ndr_obj, channeltype, channel, epochfiles, t0, t1)
            %  READEVENTS_EPOCHSAMPLES_NATIVE - read events or markers of specified channels for a specified epoch
            %
            %  DATA = READEVENTS_EPOCHSAMPLES_NATIVE(NDR_DAQREADER_MFDAQ_NDR_OBJ, CHANNELTYPE, CHANNEL, EPOCHFILES, T0, T1)
            %
            %  CHANNELTYPE is the type of channel to read
            %  ('event','marker', etc)
            %
            %  CHANNEL is a vector with the identity of the channel(s) to be read.
            %
            %  EPOCH is the set of epoch files
            %
            %  DATA is a two-column vector; the first column has the time of the event. The second
            %  column indicates the marker code. In the case of 'events', this is just 1. If more than one channel
            %  is requested, DATA is returned as a cell array, one entry per channel.
            %
            ndr_reader = ndr.reader(ndi_daq_reader_mfdaq_ndr_obj.ndr_reader_string);
            [timestamps,data] = ndr_reader.readevents_epochsamples_native(channeltype, channel, epochfiles, 1, t0, t1);
        end % readevents_epochsamples_native

        function sr = samplerate(ndi_daq_reader_mfdaq_ndr_obj, epochfiles, channeltype, channel)
            % SAMPLERATE - GET THE SAMPLE RATE FOR SPECIFIC EPOCH AND CHANNEL
            %
            % SR = SAMPLERATE(NDI_DAQREADER_MFDAQ_NDR_OBJ, EPOCHFILES, CHANNELTYPE, CHANNEL)
            %
            % SR is the list of sample rate from specified channels in samples/sec.
            %
            ndr_reader = ndr.reader(ndi_daq_reader_mfdaq_ndr_obj.ndr_reader_string);
            sr = ndr_reader.samplerate(epochfiles,1,channeltype,channel);
        end % samplerate

        function t = epochsamples2times(ndi_daq_reader_mfdaq_ndr_obj, channeltype, channel, epochfiles, s, S)
            % EPOCHSAMPLES2TIMES - convert samples to time
            if nargin < 6, S = []; end
            ndr_reader = ndr.reader(ndi_daq_reader_mfdaq_ndr_obj.ndr_reader_string);
            t = ndr_reader.samples2times(channeltype, channel, epochfiles, 1, s);
        end

        function s = epochtimes2samples(ndi_daq_reader_mfdaq_ndr_obj, channeltype, channel, epochfiles, t, S)
            % EPOCHTIMES2SAMPLES - convert time to samples
            if nargin < 6, S = []; end
            ndr_reader = ndr.reader(ndi_daq_reader_mfdaq_ndr_obj.ndr_reader_string);
            if any(isinf(t))
                t0t1 = ndr_reader.t0_t1(epochfiles, 1);
                t(isinf(t) & t<0) = t0t1{1}(1);
                t(isinf(t) & t>0) = t0t1{1}(2);
            end
            s = ndr_reader.times2samples(channeltype, channel, epochfiles, 1, t);
        end

        function ndi_document_obj = newdocument(ndi_daqreader_obj)
            % NEWDOCUMENT - create a new ndi.document for an ndi.daq.reader object
            %
            % DOC = NEWDOCUMENT(NDI_DAQREADER_OBJ)
            %
            % Creates an ndi.document object DOC that represents the
            %    ndi.daq.reader object.
            ndi_document_obj = ndi.document('daqreader_ndr',...
                'daqreader.ndi_daqreader_class',class(ndi_daqreader_obj),...
                'daqreader_ndr.ndr_reader_string', ndi_daqreader_obj.ndr_reader_string,...
                'daqreader_ndr.ndi_daqreader_ndr_class',class(ndi_daqreader_obj),...
                'base.id', ndi_daqreader_obj.id(),...
                'base.session_id',ndi.session.empty_id());
        end % newdocument()

    end % methods
end % class
