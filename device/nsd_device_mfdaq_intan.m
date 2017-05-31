% NSD_DEVICE_MFDAQ_INTAN - Device driver for Intan Technologies RHD file format
%
% This class reads data from Intan Technologies .RHD file format.
%
% Intan Technologies: http://intantech.com/
%
%

classdef nsd_device_mfdaq_intan < handle & nsd_device_mfdaq
	properties
		

	end % properties

	methods
		function obj = nsd_device_mfdaq_intan(name,thedatatree)
		% NSD_DEVICE_MFDAQ_INTAN - Create a new NSD_DEVICE_MFDAQ_INTAN object
		%
		%  D = NSD_DEVICE_MFDAQ_INTAN(NAME,THEDATATREE)
		%
		%  Creates a new NSD_DEVICE_MFDAQ_INTAN object with name NAME and associated
		%  datatree THEDATATREE.
		%
			if nargin==1
				error(['Not enough input arguments.']);
			elseif nargin==2,
				obj.name = name;
				obj.datatree = thedatatree;
			else,
				error(['Too many input arguments.']);
			end;
		end

		function channels = getchannels(self)
		% GETCHANNELS - List the channels that are available on this Intan device
		%
		%  CHANNELS = GETCHANNELS(THEDEV)
		%
		%  Returns the channel list of acquired channels in this experiment
		%
		% CHANNELS is a structure list of all channels with fields:
		% -------------------------------------------------------
		% 'name'             | The name of the channel (e.g., 'ai1')
		% 'type'             | The type of data stored in the channel
		%                    |    (e.g., 'analogin', 'digitalin', 'image', 'timestamp')
		%

			N = numepochs(self.datatree);

			channels = struct('name',[],'type',[]);
			channels = channels([]);

			intan_channel_types = {
				'amplifier_channels'
				'aux_input_channels'
				'board_dig_in_channels'
				'board_dig_out_channels'};

			multifunctiondaq_channel_types = self.mfdaq_channeltypes(self);

			for n=1:N,
				% then, open RHD files, and examine the headers for all channels present
				%   for any new channel that hasn't been identified before,
				%   add it to the list
				filelist = getepochfiles(self.datatree, n);

				filename = filelist{1}; % assume only 1 file

				header = read_Intan_RHD2000_header(filename);

				for k=1:length(intan_channel_types),
					if isfield(header,intan_channel_types{k},
						channel_type_entry = mfdaqchanneltype2intanheadertype(intan_channel_types{k});
						channel = getfield(header, intan_channel_types{k});
						num = numel(channel);             %% number of channels with specific type
						for p = 1:numel(channel),
							newchannel.type = channel_type_entry;
							error(['need to convert to standard naming scheme']);
							newchannel.name = channel(p).native_channel_name;  % needs modifying
						end
					end
				end
			end
		end % getchannels()

		function b = verifyepochrecord(self, epochrecord, number)
		% VERIFYEPOCHRECORD - Verifies that an EPOCHRECORD is compatible with a given device and the data on disk
		%
		%   B = VERIFYEPOCHRECORD(MYSAMPLEAPI_DEVICE, EPOCHRECORD, NUMBER)
		%
		% Examines the SAPI_EPOCHRECORD EPOCHRECORD and determines if it is valid for the given device
		% epoch NUMBER.
		%
		% For the abstract class SAMPLEAPI_DEVICE, EPOCHRECORD is always valid as long as
		% EPOCHRECORD is an SAPI_EPOCHRECORD object.
		%
		% See also: SAMPLEAPI_DEVICE, SAPI_EPOCHRECORD
			b = 1;
			% UPDATE NEEDED
			% b = isa(epochrecord, 'sAPI_epochrecord') && strcmp(epochrecord.type,'rhd') && strcmp(epochrecord.devicestring,self.name);
		end

		function data = readchannels_epochsamples(self, channeltype, channel, epoch, s0, s1)
		%  FUNCTION READ_CHANNELS - read the data based on specified channels
		%
		%  DATA = READ_CHANNELS(MYDEV, CHANNELTYPE, CHANNEL, EPOCH ,S0, S1)
		%
		%  CHANNELTYPE is the type of channel to read
		%
		%  CHANNEL is a vector of the channel numbers to read, beginning from 1
		%
		%  EPOCH is 
		%
		%  DATA is the channel data (each column contains data from an indvidual channel) 
		%

			filename = self.datatree.getepochfiles(self,epoch);
			filename = filename{1}; % don't know how to handle multiple filenames coming back
			intanchanneltype = multifuncdaqchanneltype2intan(channeltype);

			sr = getsamplerate(self, channeltype, channel, epoch);
			sr_unique = unique(sr); % get all sample rates
			if numel(sr_unique)~=1, error(['Do not know how to handle different sampling rates across channels.']); end;

			sr = sr_unique;

			t0 = (s0-1)/sr;
			t1 = (s1-1)/sr;
			[data] = read_Intan_RHD2000_datafile(file_name,'',intanchanneltype,channel,t0,t1);

		end % readchannels_epochsamples

		function sr = samplerate(sAPI_dev, epoch, channeltype, channel)
		%
		% FUNCTION GETSAMERATE - GET THE SAMPLE RATE FOR SPECIFIC CHANNEL
		%
		% SR = GETSAMERATE(DEV, EPOCH, CHANNELTYPE, CHANNEL)
		%
		% SR is the list of sample rate from specified channels

			filename = self.datatree.getepochfiles(self,epoch);
			filename = filename{1}; % don't know how to handle multiple filenames coming back

			head = read_Intan_RHD2000_header(filename);
			freq = head.frequency_parameters;
			freq_name = fieldnames(freq);               %get all the names for each freq
			all_freqs = cell2mat(struct2cell(freq));             %get all the freqs for each name
			for j = 1:size(freq_name,1),
				temp = freq_name{i};
				if (strncmpi(temp,channeltype,length(channeltype))),      %compare the beginning of two strings
					sr = all_freqs(j); return;
				end
			end
		end % samplerate()
	end % methods

	methods (Static)  % helper functions

		function intanchanheadertype = mfdaqchanneltype2intanheadertype(channeltype)
		% MFDAQCHANNELTYPE2INTANHEADERTYPE - Convert between the NSD_DEVICE_MFDAQ channel types and Intan headers
		%
		% INTANCHANHEADERTYPE = MFDAQCHANNELTYPE2INTANHEADERTYPE(CHANNELTYPE)
		% 
		% Given a standard NSD_DEVICE_MFDAQ channel type, returns the name of the type as
		% indicated in Intan header files.

			switch (channeltype),
				case {'analog_in','ai'},
					intanchanheadertype = 'amplifier_channels';
				case {'digital_in','di'}
					intanchanheadertype = 'board_dig_in_channels';
				case {'digital_out','do'},
					intanchanheadertype = 'board_dig_out_channels';
				case {'auxiliary','aux','ax'},
					intanchanheadertype = 'aux_input_channels';
			end;
		end % mfdaqchanneltype2intanheadertype()
	
		function intanchanneltype = multifuncdaqchanneltype2intan(channeltype)
		% INTANCHANNELTYPE - convert the channel type from generic format of multifuncdaqchannel 
		%					 to the specific intan channel type
		%
		%    INTANCHANNELTYPE = MULTIFUNCDAQCHANNELTYPE2INTAN(CHANNELTYPE)
		%
		%	 the intanchanneltype is a string of the specific channel type for intan
		%

			switch channeltype, 
				case 'analog',
					intanchanneltype = 'adc';
				case 'digitalin',
					intanchanneltype = 'din';
				case 'digitalout',
					intanchanneltype = 'dout';
				case 'image',
					intanchanneltype = [];
				case 'timestamp',
					intanchanneltype = 'timestamp';
				case 'amplifier' 
					intanchanneltype = 'amplifier';
			end;

		end; % multifuncdaqchanneltype2intan()

		function [ standard_name ] = name_convert_to_standard(type, name )
		%   STANDARD_NAME = NAME_CONVERT_TO_STANDARD(TYPE,NAME)
		%       name_convert_to_standard() takes two inputs the standard type of 
		%       the channel and the local channel name and convert the local 
		%       channel name to the standard name 

			typeList = strsplit(type,'_');

			temp1 = typeList{1};        %%get the instrumental name
			temp1 = temp1(1);

			if ~strcmp('diagnostic', typeList{1}),
				temp2 = typeList{2};        %%get the instrumental name
				temp2 = temp2(1);
			else,
				temp2 = '';
			end;

			nameList = strsplit(name,'-');   

			if ~isnan(sscanf(nameList{end},'%f'))
				standard_name = strcat(temp1,temp2,num2str(sscanf(nameList{end},'%f')));
			else 
				standard_name = strcat(temp1,temp2);
				nl = nameList{end};
				for i = 1:length(nl)
					s = nl(i);
					num=str2double(s);
				
					if ~isnan(num)
						standard_name = strcat(standard_name,s);
					end
				end
			end

		end % name_convert_to_standard()

	end % methods (Static)
end

