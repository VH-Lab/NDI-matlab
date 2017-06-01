% NSD_DEVICE_MFDAQ_INTAN - Device driver for Intan Technologies RHD file format
%
% This class reads data from Intan Technologies .RHD file format.
%
% Intan Technologies: http://intantech.com/
%
%

classdef nsd_device_mfdaq_intan < nsd_device_mfdaq
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
			obj = obj@nsd_device_mfdaq(name,thedatatree);
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

			channels = emptystruct('name','type');

			N = numepochs(self.datatree);

			intan_channel_types = {
				'amplifier_channels'
				'aux_input_channels'
				'board_dig_in_channels'
				'board_dig_out_channels'};

			multifunctiondaq_channel_types = self.mfdaq_channeltypes;

			for n=1:N,

				% then, open RHD files, and examine the headers for all channels present
				%   for any new channel that hasn't been identified before,
				%   add it to the list
				filelist = getepochfiles(self.datatree, n);

				filename = filelist{1}; % assume only 1 file

				header = read_Intan_RHD2000_header(filename);

				if isempty(channels),
					channels = struct('name','t1','type','time');
				end;

				for k=1:length(intan_channel_types),
					if isfield(header,intan_channel_types{k}),
						channel_type_entry = self.intanheadertype2mfdaqchanneltype(intan_channel_types{k});
						channel = getfield(header, intan_channel_types{k});
						num = numel(channel);             %% number of channels with specific type
						for p = 1:numel(channel),
							newchannel.type = channel_type_entry;
							newchannel.name = self.intanname2mfdaqname(self,...
								channel_type_entry,...
								channel(p).native_channel_name); 
							match = 0;
							for kk=1:length(channels),
								if eqlen(channels(kk),newchannel)
									match = 1;
									break;
								end;
							end;
							if ~match, channels(end+1) = newchannel; end;
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
			filename = self.datatree.getepochfiles(epoch);
			filename = filename{1}; % don't know how to handle multiple filenames coming back
			intanchanneltype = self.mfdaqchanneltype2intanchanneltype(channeltype);

			sr = self.samplerate(epoch, channeltype, channel);
			sr_unique = unique(sr); % get all sample rates
			if numel(sr_unique)~=1,
				error(['Do not know how to handle different sampling rates across channels.']);
			end;

			sr = sr_unique;

			t0 = (s0-1)/sr;
			t1 = (s1-1)/sr;
			[data] = read_Intan_RHD2000_datafile(filename,'',intanchanneltype,channel,t0,t1);

		end % readchannels_epochsamples

		function sr = samplerate(self, epoch, channeltype, channel)
		% SAMPLERATE - GET THE SAMPLE RATE FOR SPECIFIC EPOCH AND CHANNEL
		%
		% SR = SAMPLERATE(DEV, EPOCH, CHANNELTYPE, CHANNEL)
		%
		% SR is the list of sample rate from specified channels

			filename = self.datatree.getepochfiles(epoch);
			filename = filename{1}; % don't know how to handle multiple filenames coming back

			head = read_Intan_RHD2000_header(filename);
			freq_fieldname = self.mfdaqchanneltype2intanfreqheader(channeltype);
			sr = getfield(head.frequency_parameters,freq_fieldname);
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
				otherwise,
					error(['Could not convert channeltype ' channeltype '.']);
			end;

		end % mfdaqchanneltype2intanheadertype()

		function channeltype = intanheadertype2mfdaqchanneltype(intanchanneltype)
		% INTANHEADERTYPE2MFDAQCHANNELTYPE- Convert between Intan headers and the NSD_DEVICE_MFDAQ channel types 
		%
		% CHANNELTYPE = INTANHEADERTYPE2MFDAQCHANNELTYPE(INTANCHANNELTYPE)
		% 
		% Given an Intan header file type, returns the standard NSD_DEVICE_MFDAQ channel type

			switch (intanchanneltype),
				case {'amplifier_channels'},
					channeltype = 'analog_in';
				case {'board_dig_in_channels'},
					channeltype = 'digital_in';
				case {'board_dig_out_channels'},
					channeltype = 'digital_out';
				case {'aux_input_channels'},
					channeltype = 'auxiliary';
				otherwise,
					error(['Could not convert channeltype ' intanchanneltype '.']);
			end;

		end % mfdaqchanneltype2intanheadertype()

		function intanchanneltype = mfdaqchanneltype2intanchanneltype(channeltype)
		% MFDAQCHANNELTYPE2INTANCHANNELTYPE- convert the channel type from generic format of multifuncdaqchannel 
		%					 to the specific intan channel type
		%
		%    INTANCHANNELTYPE = MFDAQCHANNELTYPE2INTANCHANNELTYPE(CHANNELTYPE)
		%
		%	 the intanchanneltype is a string of the specific channel type for intan
		%
			switch channeltype, 
				case {'analog_in','ai'},
					intanchanneltype = 'amp';
				case {'digital_in','di'},
					intanchanneltype = 'din';
				case {'digital_out','do'},
					intanchanneltype = 'dout';
				case {'time','timestamp'},
					intanchanneltype = 'time';
				case {'auxiliary','aux'},
					intanchanneltype = 'aux';
				otherwise,
					error(['Do not know how to convert channel type ' channeltype '.']);
			end
		end % mfdaqchanneltype2intanchanneltype()

		function [ channame ] = intanname2mfdaqname(self, type, name )
		% INTANNAME2MFDAQNAME - Converts a channel name from Intan native format to NSD_DEVICE_MFDAQ format.
		%
		% MFDAQNAME = INTANNAME2MFDAQNAME(SELF, MFDAQTYPE, NAME)
		%   
		% Given an Intan native channel name (e.g., 'A-000') in NAME and a
		% NSD_DEVICE_MFDAQ channel type string (see NSD_DEVICE_MFDAQ), this function
		% produces an NSD_DEVICE_MFDAQ channel name (e.g., 'ai1').
		%  
			sep = find(name=='-');
			chan_intan = str2num(name(sep+1:end));
			chan = chan_intan + 1; % intan numbers from 0
			channame = [self.mfdaq_prefix(type) int2str(chan)];

		end % intanname2mfdaqname()

		function headername = mfdaqchanneltype2intanfreqheader(channeltype)
		% MFDAQCHANNELTYPE2INTANFREQHEADER - Return header name with frequency information for channel type
		%
		%  HEADERNAME = MFDAQCHANNELTYPE2INTANFREQHEADER(CHANNELTYPE)
		%
		%  Given an NSD_DEV_MFDAQ channel type string, this function returns the associated fieldname
		%  
			switch channeltype,
				case {'analog_in','ai'},
					headername = 'amplifier_sample_rate';
				case {'digital_in','di'},
					headername = 'board_dig_in_sample_rate';
				case {'digital_out','do'},
					headername = 'board_dig_out_sample_rate';
				case {'time','timestamp'},
					headername = 'amplifier_sample_rate';
				case {'auxiliary','aux'},
					headername = 'aux_input_sample_rate';
				otherwise,
					error(['Do not know frequency header name for channel type ' channeltype '.']);
			end;
		end % mfdaqchanneltype2intanfreqheader()

	end % methods (Static)
end

