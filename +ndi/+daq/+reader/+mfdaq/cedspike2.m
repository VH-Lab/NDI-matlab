classdef cedspike2 < ndi.daq.reader.mfdaq
% NDI_DAQSYSTEM_MFDAQ_CEDSPIKE2 - Device driver for CED Spike2
%
% This class reads data from CED Spike2 .SMR or .SON file formats.
%
% It depends on sigTOOL by Malcolm Lidierth (http://sigtool.sourceforge.net).
%
% sigTOOL is also included in the https://github.com/VH-Lab/vhlab-thirdparty-matlab bundle and
% can be installed with instructions at http://code.vhlab.org.
%
	properties
		

	end % properties

	methods
		function obj = cedspike2(varargin)
			% NDI_DAQSYSTEM_MFDAQ_CEDSPIKE2 - Create a new NDI_DEVICE_MFDAQ_CEDSPIKE2 object
			%
			%  D = NDI_DAQSYSTEM_MFDAQ_CEDSPIKE2(NAME,THEFILENAVIGATOR)
			%
			%  Creates a new NDI_DAQSYSTEM_MFDAQ_CEDSPIKE2 object with name NAME and associated
			%  filenavigator THEFILENAVIGATOR.
			%
			obj = obj@ndi.daq.reader.mfdaq(varargin{:})
		end

		function channels = getchannelsepoch(ndi_daqreader_mfdaq_cedspike2_obj, epochfiles)
			% GETCHANNELS - List the channels that are available on this device
			%
			%  CHANNELS = GETCHANNELS(THEDEV, EPOCHFILES)
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

				channels = vlt.data.emptystruct('name','type','time_channel');

				multifunctiondaq_channel_types = ndi.daq.system.mfdaq.mfdaq_channeltypes();

				% open SMR files, and examine the headers for all channels present
				%   for any new channel that hasn't been identified before,
				%   add it to the list
				filename = ndi_daqreader_mfdaq_cedspike2_obj.cedspike2filelist2smrfile(epochfiles);

				header = read_CED_SOMSMR_header(filename);

				if isempty(header.channelinfo),
					channels = vlt.data.emptystruct('name','type','time_channel');
				end;

				for k=1:length(header.channelinfo),
					newchannel.type = ndi_daqreader_mfdaq_cedspike2_obj.cedspike2headertype2mfdaqchanneltype(header.channelinfo(k).kind);
					newchannel.name = [ ndi.daq.system.mfdaq.mfdaq_prefix(newchannel.type) int2str(header.channelinfo(k).number) ];
					newchannel.time_channel = header.channelinfo(k).number;
					channels(end+1) = newchannel;

					if strcmp(newchannel.type,'analog_in'), % add the time channel
						newtimechannel.type = 'time';
						newtimechannel.name = [ ndi.daq.system.mfdaq.mfdaq_prefix(newtimechannel.type) int2str(header.channelinfo(k).number) ];
						newtimechannel.time_channel = header.channelinfo(k).number;
						channels(end+1) = newtimechannel;
					end;
				end
		end % getchannels()

		function [b,msg] = verifyepochprobemap(ndi_daqreader_mfdaq_cedspike2_obj, epochprobemap, epochfiles)
			% VERIFYEPOCHPROBEMAP - Verifies that an EPOCHPROBEMAP is compatible with a given device and the data on disk
			%
			%   B = VERIFYEPOCHPROBEMAP(NDI_DAQSYSTEM_MFDAQ_CEDSPIKE2_OBJ, EPOCHPROBEMAP, EPOCHFILES)
			%
			% Examines the ndi.epoch.epochprobemap_daqsystem EPOCHPROBEMAP and determines if it is valid for the given device
			% epoch NUMBER.
			%
			% For the abstract class ndi.daq.system, EPOCHPROBEMAP is always valid as long as
			% EPOCHPROBEMAP is an ndi.epoch.epochprobemap_daqsystem object.
			%
			% See also: ndi.daq.system, ndi.epoch.epochprobemap_daqsystem
				b = 1;
				msg = '';
				% UPDATE NEEDED
		end

		function data = readchannels_epochsamples(ndi_daqreader_mfdaq_cedspike2_obj, channeltype, channel, epochfiles, s0, s1)
			%  FUNCTION READ_CHANNELS - read the data based on specified channels
			%
			%  DATA = READ_CHANNELS(MYDEV, CHANNELTYPE, CHANNEL, EPOCHFILES, S0, S1)
			%
                        %  CHANNELTYPE is the type of channel to read (cell array of strings, one per
                        %     channel, or single string for all channels)
			%
			%  CHANNEL is a vector of the channel numbers to read, beginning from 1
			%
			%  EPOCHFILES is the cell array of full path filenames for this epoch
			%
			%  DATA is the channel data (each column contains data from an indvidual channel) 
			%

				if ~iscell(channeltype),
					channeltype = repmat({channeltype},numel(channel),1);
				end;
				uniquechannel = unique(channeltype);
				if numel(uniquechannel)~=1,
					error(['Only one type of channel may be read per function call at present.']);
				end

				filename = ndi_daqreader_mfdaq_cedspike2_obj.cedspike2filelist2smrfile(epochfiles);
				sr = ndi_daqreader_mfdaq_cedspike2_obj.samplerate(epochfiles, channeltype, channel);
				sr_unique = unique(sr); % get all sample rates
				if numel(sr_unique)~=1,
					error(['Do not know how to handle different sampling rates across channels.']);
				end;


				sr = sr_unique;

				t0 = (s0-1)/sr;
				t1 = (s1-1)/sr;

				if isinf(t0) | isinf(t1),
					t0_orig = t0;
					t1_orig = t1;
					t0t1_here = ndi_daqreader_mfdaq_cedspike2_obj.t0_t1(epochfiles);
					if isinf(t0_orig),
						if t0_orig<0,
							t0 = t0t1_here{1}(1);
						elseif t0_orig>0,
							t0 = t0t1_here{1}(2);
						end;
					end;
					if isinf(t1_orig),
						if t1_orig<0,
							t1 = t0t1_here{1}(1);
						elseif t1_orig>0
							t2 = t0t1_here{1}(2);
						end;
					end;
				end;

				for i=1:length(channel), % can only read 1 channel at a time
					if strcmpi(channeltype,'time'),
						[dummy,dummy,dummy,dummy,data(:,i)] = read_CED_SOMSMR_datafile(filename,'',channel(i),t0,t1);
					else,
						[data(:,i)] = read_CED_SOMSMR_datafile(filename,'',channel(i),t0,t1);
					end
				end

		end % readchannels_epochsamples

		function t0t1 = t0_t1(ndi_daqreader_mfdaq_cedspike2_obj, epochfiles)
			% EPOCHCLOCK - return the t0_t1 (beginning and end) epoch times for an epoch
			%
			% T0T1 = T0_T1(NDI_DAQSYSTEM_MFDAQ_CEDSPIKE2_OBJ, EPOCHFILES)
			%
			% Return the beginning (t0) and end (t1) times of the EPOCHFILES that define this
			% epoch in the same units as the ndi.time.clocktype objects returned by EPOCHCLOCK.
			%
			%
			% See also: ndi.time.clocktype, EPOCHCLOCK
			%
				filename = ndi_daqreader_mfdaq_cedspike2_obj.cedspike2filelist2smrfile(epochfiles);
				header = read_CED_SOMSMR_header(filename);

				t0 = 0;  % developer note: the time of the first sample in spike2 is not 0 but 0 + 1/4 * sample interval; might be more correct to use this
				t1 = header.fileinfo.dTimeBase * header.fileinfo.maxFTime * header.fileinfo.usPerTime;
				t0t1 = {[t0 t1]};
		end % t0t1

		function [timestamps,data] = readevents_epochsamples_native(ndi_daqreader_mfdaq_cedspike2_obj, channeltype, channel, epochfiles, t0, t1)
			%  FUNCTION READEVENTS_EPOCHSAMPLES_NATIVE - read events or markers of specified channels for a specified epoch
			%
			%  DATA = READEVENTS_EPOCHSAMPLES(MYDEV, CHANNELTYPE, CHANNEL, EPOCHFILES, T0, T1)
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
				%disp('reading here')
                if ~iscell(channeltype),
                    channeltype = repmat({channeltype},numel(channel),1);
                end;
				timestamps = {};
				data = {};
				filename = ndi_daqreader_mfdaq_cedspike2_obj.cedspike2filelist2smrfile(epochfiles);
				for i=1:numel(channel),
					[data{i},dummy,dummy,dummy,timestamps{i}]= ndr.format.ced.read_SOMSMR_datafile(filename, ...
						'',channel(i),t0,t1);
                    if strcmp(channeltype{i},'event'),
                        data{i} = ones(size(data{i}));
                    end;
                    if strcmp(channeltype{i},'marker'),
                        data{i} = sum( double(data{i}) .* repmat([2^0 2^8 2^16 2^24],size(data{i},1),1),2);
                    end;
                    if strcmp(channeltype{i},'text'),
                        data{i} = vlt.data.matrow2cell(data{i})';
                    end;
				end
				if numel(channel)==1,
					timestamps = timestamps{1};
					data = data{1};
				end;
		end % readevents_epochsamples_native()

		function sr = samplerate(ndi_daqreader_mfdaq_cedspike2_obj, epochfiles, channeltype, channel)
			% SAMPLERATE - GET THE SAMPLE RATE FOR SPECIFIC EPOCH AND CHANNEL
			%
			% SR = SAMPLERATE(DEV, EPOCHFILES, CHANNELTYPE, CHANNEL)
			%
			% SR is the list of sample rate from specified channels

				filename = ndi_daqreader_mfdaq_cedspike2_obj.cedspike2filelist2smrfile(epochfiles);

				sr = [];
				for i=1:numel(channel),
					sr(i) = 1/read_CED_SOMSMR_sampleinterval(filename,[],channel(i));
				end

		end % samplerate()

                function [datatype,p,datasize] = underlying_datatype(ndi_daqreader_mfdaq_cedspike2_obj, epochfiles, channeltype, channel)
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


				switch(channeltype),            
					case {'analog_in','analog_out'},
           				filename = ndi_daqreader_mfdaq_cedspike2_obj.cedspike2filelist2smrfile(epochfiles);
                        fid = fopen(filename,'r');
                        p = [];
                        for i=1:numel(channel),
                            Info=SONChannelInfo(fid,channel(i));
    						datatype = 'int16';
	    					datasize = 16;
                            s2 = Info.scale/6553.6;
                            o2 = Info.offset;
				    		p = [p ; [-o2/s2 s2]];
                        end;
                        fclose(fid);
					case {'auxiliary_in'}
						datatype = 'uint16';
						datasize = 16;
                        p = repmat([0 1],numel(channel),1);
					case {'time'},
						datatype = 'float64';
						datasize = 64;
                        p = repmat([0 1],numel(channel),1);
                    case {'digital_in','digital_out'},
						datatype = 'char';
						datasize = 8;
                        p = repmat([0 1],numel(channel),1);
					case {'eventmarktext','event','marker','text'}, 
						datatype = 'float64';
						datasize = 64;
                        p = repmat([0 1],numel(channel),1);
					otherwise,
						error(['Unknown channel type ' channeltype '.']);
				end; %
		end;

	end % methods

	methods (Static)  % helper functions

		function smrfile = cedspike2filelist2smrfile(filelist)
			% CEDSPIKE2SPIKELIST2SMRFILE - Identify the .SMR file out of a file list
			% 
			% FILENAME = CEDSPIKE2FILELIST2SMRFILE(FILELIST)
			%
			% Given a cell array of strings FILELIST with full-path file names,
			% this function identifies the first file with an extension '.smr' (case insensitive)
			% and returns the result in FILENAME (full-path file name).
				for k=1:numel(filelist),
					[pathpart,filenamepart,extpart] = fileparts(filelist{k});
					if strcmpi(extpart,'.smr'),
						smrfile = filelist{k}; % assume only 1 file
						return;
					end; % got the .smr file
				end
				error(['Could not find any .smr file in the file list.']);
		end

		function channeltype = cedspike2headertype2mfdaqchanneltype(cedspike2channeltype)
		% CEDSPIKE2HEADERTYPE2MFDAQCHANNELTYPE- Convert between Intan headers and the ndi.daq.system.mfdaq channel types 
		%
		% CHANNELTYPE = CEDSPIKE2HEADERTYPE2MFDAQCHANNELTYPE(CEDSPIKE2CHANNELTYPE)
		% 
		% Given an Intan header file type, returns the standard ndi.daq.system.mfdaq channel type

			switch (cedspike2channeltype),
				case {1,9},
					% 1 is integer, 9 is single precision floating point
					channeltype = 'analog_in';
				case {2,3,4},
					channeltype = 'event'; % event indicator
						% 2 - positive-to-negative transition
						% 3 - negative-to-positive transition
						% 4 - either transition
				case {5,6},
						% 6 - wavemark, a Spike2-detected event
					channeltype = 'marker';
                case {8},
                    channeltype = 'text';
				case {7,9},
					error(['do not know this event yet--programmer should look it up.']);
				otherwise,
					error(['Could not convert channeltype ' cedspike2channeltype '.']);
			end;

		end % mfdaqchanneltype2cedspike2headertype()

	end % methods (Static)
end

