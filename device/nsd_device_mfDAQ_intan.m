% NSD_DEVICE_MFDAQ_INTAN - Device driver for Intan Technologies RHD file format
%
% This class reads data from Intan Technologies .RHD file format.
%
% Intan Technologies: http://intantech.com/
%
%

classdef nsd_device_mfdaq_intan < handle & nsd_device_mfdaq
	properties
		

	end; % properties

	methods
		function obj = nsd_intan_flat(obj,exp,name,thedatatree,reference)
		% NSD_DEVICE_MFDAQ_INTAN - Create a new NSD_DEVICE_MFDAQ_INTAN object
		%
		%  D = NSD_DEVICE_MFDAQ_INTAN(NAME,THEDATATREE)
		%
		%  Creates a new NSD_DEVICE_MFDAQ_INTAN object with name NAME and associated
		%  datatree THEDATATREE.
		%
			if nargin==1 || nargin ==2 || nargin ==3,
				error(['Not enough input arguments.']);
			elseif nargin==4,
				obj.exp = exp;
				obj.name = name;
				obj.datatree = thedatatree;
				obj.reference = 'time';
			elseif nargin==5,
				obj.exp = exp;
				obj.name = name;
				obj.datatree = thedatatree;
				obj.reference = reference;
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
		% 'name'             | The name of the channel (e.g., 'ai0')
		% 'type'             | The type of data stored in the channel
		%                    |    (e.g., 'analogin', 'digitalin', 'image', 'timestamp')
		%

			N = numepochs(self.datatree);

			filelist = self.thedatatree.getallfiles('rhd');  % does this really exist??

			channels = struct('name',[],'type',[]);
			channels = channels([]);

			intan_channel_types = {
				'amplifier_channels'
				'aux_input_channels'
				'supply_voltage_channels'
				'board_adc_channels'
				'board_dig_in_channels'
				'board_dig_out_channels'};

			multifunctiondaq_channel_types = channel_types(self);

			for n=1:N,
				% then, open RHD files, and examine the headers for all channels present
				%   for any new channel that hasn't been identified before,
				%   add it to the list
				filelist = getepochfiles(self.datatree, n);

				filename = filelist{1}; % assume only 1 file

				obj = read_Intan_RHD2000_header(filename);

				list_field = fieldnames(obj);
				structSize = size(list_field,1);

				for k = 1:structSize,
					occur = strcmp(list_field{k},intan_channel_types);  %%if the field is channel
					if any(occur),
						channel = getfield(obj, list_field{k});
						num = numel(channel);             %% number of channels with specific type
						lc = {channels(:).name};
						channel_type_entry = find(strcmp(list_field{k},intan_channel_types));
						channel_type_name = multifunctiondaq_channel_types{channel_type_entry};
						for p = 1:num,
							error(['need to convert to standard naming scheme']);
							channels(end+1).name = channel(p).native_channel_name;  % needs modifying
							channels(end).type = channel_type_name;
						end
					end
				end
			end
		end % getchannels()

		function epochrecord = getepochrecord(self, number)
		% GETEPOCHRECORD - retreive the epoch record associated with a recording epoch
		%
		%   EPOCHRECORD = GETEPOCHRECORD(MYSAMPLEAPI_DEVICE, NUMBER)
		%
		% Returns the EPOCHRECORD associated the the data epoch NUMBER for the
		% SAMPLEAPI_DEVICE.
		%
		% In the abstract base class SAMPLEAPI_DEVICE, this returns empty always.
		% In specific device classes, this will return an EPOCHRECORD object.
		%
		% See also: SAMPLEAPI_DEVICE, SAPI_EPOCHRECORD
			if (verifyepochrecord(self.thedatatree.getepoch(number),~)
				epochrecord = self.thedatatree.getepoch(number);
			else,
				error(['the numbered epoch is not a valid epoch for the given device']);
			end
		end

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
			b = isa(epochrecord, 'sAPI_epochrecord') && strcmp(epochrecord.type,'rhd') && strcmp(epochrecord.devicestring,self.name);
		end

		function report = read_channel(self,sAPI_dev,channeltype,channel,clock_or_interval, t0,t1)
		%  FUNCTION READ_CHANNELS - read the data based on specified channels
		%
		%  REPORT = READ_CHANNELS(SAPI_DEV, CHANNELTYPE,CHANNEL,SAPI_CLOCK,T0,T1)
		%
		%  CHANNELTYPE is the type of channel to read
		%  ('analog','digitalin','digitalout', etc)
		%
		%
		%  REPORT is the data collection for specific channels

			%create the query for epoches either use reference number or time
			if nargin==5,
				query = clock_or_interval;
			else,
				query = constructQuery(sAPI_clock, t0,t1);
			end

			file_names = self.thedatatree.getepoch(query,'rhd');  %%use the files as object fields later

			%file_names,
			% here we want to convert t0, and t1, which are in units of sAPI_clock
			%    into i0_, t0_ and i1_, t1_ (i being local recorded interval, and t being time within that interval)

			[i0_,t0_] = convert(sAPI_dev,sAPI_clock,t0);
			[i1_,t1_] = convert(sAPI_dev,sAPI_clock,t1);    %may need to incorporate the getintervals func into convert func

			intanchanneltype = multifuncdaqchanneltype2intan(channeltype);

			report = emptystruct('data','epoch','t_start','t_end');     %%initial structure

			for i = i0_:i1_,
				if i==i0_,
					time_start = t0_;
				else,
					time_start = 0; % start at beginning of interval
				end;

				if i==i1_,
					t_end = t1_;
				else,
					t_end = Inf; % go to end of interval
				end;
				[data,~,~] = read_Intan_RHD2000_datafile(file_names{i},'',intanchanneltype,channel,time_start,t1_);
				report(end+1).data = data;
				report(end).epoch = i;
				report(end).t_start = t0_;
				report(end).t_end = t1_;
			end

		end %read_channel()

		function sr = getsamplerate(sAPI_dev, interval, channeltype, channel)
		%
		% FUNCTION GETSAMERATE - GET THE SAMPLE RATE FOR SPECIFIC CHANNEL
		%
		% SR = GETSAMERATE(DEV, INTERVAL, CHANNELTYPE, CHANNEL)
		%
		% SR is the list of sample rate from specified channels

			file_names = findfiletype(getpath(getexperiment(sAPI_dev)),'rhd');

			for i = interval,
				head = read_Intan_RHD2000_header(file_names{i});
				freq = head.frequency_parameters;
				freq_name = fieldnames(freq);               %get all the names for each freq
				all_freqs = cell2mat(struct2cell(freq));             %get all the freqs for each name
				for j = 1:size(freq_name,1),
					temp = freq_name{i};
					if (strncmpi(temp,channeltype,length(channeltype))),      %compare the beginning of two strings
						sr = all_freqs(j); return;
					end
				end

				% step 1: read header file of that interval
				% step 2: look in header.frequency_parameters to pull out the rate
			end

		end

		function intanchanneltype = multifuncdaqchanneltype2intan(self, channeltype)
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

		function [ standard_name ] = name_convert_to_standard(self, type, name )
		%   STANDARD_NAME = NAME_CONVERT_TO_STANDARD(SELF,TYPE,NAME)
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

	end; % methods
end;

