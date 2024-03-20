classdef mfdaq_epoch_channel

	properties
		channel_information

	end % properties

	methods

		function obj = mfdaq_epoch_channel(varargin)
			% MFDAQ_EPOCH_CHANNEL - create a new MFDAQ_EPOCH_CHANNEL file document
			%
			% OBJ = MFDAQ_EPOCH_CHANNEL(INPUT1, ...)
			%
			% Creates a new MFDAQ_EPOCH_CHANNEL object. If INPUT1 is a character string,
			% then it is assumed that this object should be built from information stored in a
			% file. If INPUT1 is a structure, then it is assumed that this object should be built
			% with a channel_structure (provided in INPUT1) as in
			% ndi.file.type.mfdaq_epoch_channel.create_properties().
			%

				filename = '';
				channel_structure = '';

				if nargin>0,
					if isstruct(varargin{1}),
						channel_structure = varargin{1};
					elseif ischar(varargin{1}),
						filename = varargin{1};
					elseif isstring(varargin{1}),
						filenmae = char(varargin{1});
					end;
				end;

				if ~isempty(channel_structure),
					obj = obj.create_properties(varargin{:});
				end;
				if ~isempty(filename),
					obj = obj.readFromFile(filename);
				end;

		end; % creator

		function obj = create_properties(obj, channel_structure, varargin)
			% CREATE_PROPERTIES - make a structure that describes segmented storage of MFDAQ data
			% 
			% OBJ = CREATE_PROPERTIES(OBJ, CHANNEL_STRUCTURE, ...)
			%
			% CHANNEL_STRUCTURE has fields 'name','type', 'sample_rate', 
            %   'offset', and 'scale'
			%
			% This function also takes name/value pairs that modify the
			% default behavior.
			% -----------------------------------------------------------------
			% | Parameters (default)            | Description                  |
			% |---------------------------------|------------------------------|
			% | analog_in_channels_per_group    | Number of channels per group |
			% |   (400)                         |  for analog input channels   |
			% | analog_out_channels_per_group   | Number of channels per group |
			% |   (400)                         |  for analog output channels  |
			% | auxiliary_in_channels_per_group | Number of channels per group |
			% |   (400)                         |  for auxiliary input channels|
			% | auxiliary_out_channels_per_group| Number of channels per group |
			% |   (400)                         |  for auxiliary output        |
			% | analog_out_channels_per_group   | Number of channels per group |
			% |   (400)                         |  for analog output channels  |
			% | ditial_in_channels_per_group    | Number of channels per group |
			% |   (512)                         |  for digital input channels  |
			% | digital_out_channels_per_group  | Number of channels per group |
			% |   (512)                         |  for digital output channels |
			% 

				% next, need to test with multiple daq systems

				analog_in_channels_per_group = 400;
				analog_out_channels_per_group = 400;
				auxiliary_in_channels_per_group = 400;
				auxiliary_out_channels_per_group = 400;
				digital_in_channels_per_group = 512;
				digital_out_channels_per_group = 512;
				eventmarktext_channels_per_group = 100000;
				time_channels_per_group = 100000;

				analog_in_dataclass = 'ephys';
				analog_out_dataclass = 'ephys';
				auxiliary_in_dataclass = 'ephys';
				auxiliary_out_dataclass = 'ephys';
				digital_in_dataclass = 'digital';
				digital_in_dataclass = 'digital';
				eventmarktext_dataclass = 'eventmarktext';
				time_dataclass = 'time';
                
				
				did.datastructures.assign(varargin{:});

				[dummy,indexes_sorted] = sort({channel_structure.type});
				channel_structure = channel_structure(indexes_sorted);

				channel_information = vlt.data.emptystruct('name','type','time_channel','sample_rate','offset','scale','number','group','dataclass');

				types_available = unique({channel_structure.type});
				index_emt = find( strcmp('event',types_available) | strcmp('marker',types_available) | strcmp('text',types_available) );
                                types_available(index_emt) = [];
                                types_available{end+1} = 'eventmarktext';


				for i=1:numel(types_available),
					if ~strcmp(types_available{i},'eventmarktext'),
						indexes = find(strcmp(types_available{i},{channel_structure.type}));
					else,
						indexes = find(strcmp('event',{channel_structure.type}) | ...
							strcmp('marker',{channel_structure.type}) | strcmp('text',{channel_structure.type}));
					end;
					numbers_here = [];
					for j=1:numel(indexes),
						[prefix,numbers_here(j)] = ndi.fun.channelname2prefixnumber(channel_structure(indexes(j)).name);
					end;
					[dummy,indexes_sorted_type] = sort(numbers_here);
					channels_here = channel_structure(indexes(indexes_sorted_type));

					channels_per_group = eval([types_available{i} '_channels_per_group;']);
					for j=1:numel(channels_here),
						channel_info_here = [];
						channel_info_here.name = channels_here(j).name;
						channel_info_here.type = channels_here(j).type;
						channel_info_here.time_channel = channels_here(j).time_channel;
						channel_info_here.sample_rate = channels_here(j).sample_rate;
                        channel_info_here.offset = channels_here(j).offset;
                        channel_info_here.scale = channels_here(j).scale;
						[dummy,channel_info_here.number] = ndi.fun.channelname2prefixnumber(channels_here(j).name);
						channel_info_here.group = 1+floor( channel_info_here.number / channels_per_group);
						channel_info_here.dataclass = eval([types_available{i} '_dataclass;']);
						channel_information(end+1) = channel_info_here;
					end;
				end;

				obj.channel_information = channel_information;

		end; % create_properties()

		function mfdaq_epoch_channel_obj = readFromFile(mfdaq_epoch_channel_obj, filename)
			% READFROMFILE - read an mfdaq_epoch_channel object from a file
			%
			% MFDAQ_EPOCH_CHANNEL_OBJ = READFROMFILE(MFDAQ_EPOCH_CHANNEL_OBJ, FILENAME)
			%
			% Reads the properties of an MFDAQ_EPOCH_CHANNEL object from FILENAME.
			%
			% Example:
			%   mfdaq_epoch_channel_obj = mfdaq_epoch_channel_obj.readFromFile(filename);
			%
				channel_information = vlt.file.loadStructArray(filename);
				mfdaq_epoch_channel_obj.channel_information = channel_information;

		end; % readFromFile()

		function [b,errmsg] = writeToFile(obj, filename)
			% WRITETOFILE - write the channel_structure to a file
			%
			% [B,ERRMSG] = WRITETOFILE(MFDAQ_EPOCH_CHANNEL_OBJ, FILENAME)
			%
			% Writes the properties of an MFDAQ_EPOCH_CHANNEL object to the binary file
			% FILENAME. If the operation is successful, B is 1. Otherwise, it is 0. ERRMSG
			% contains any error message that describes the error state.
			%
			% Example:
			% [b,errmsg] = mfdaq_epoch_channel_obj.writeToFile(filename);
			% if ~b, disp(['The function failed with an error: ' errmsg '.']); end;
			%

				b = 0;
				errmsg = '';
				try,
					vlt.file.saveStructArray(filename,obj.channel_information);
					b = 1;
				catch,
					errmsg = lasterr;
				end;

		end; % writeToFile()

	end; % methods

	methods(Static),

		function [groups,channel_indexes_in_groups,channel_indexes_in_output] = channelgroupdecoding(channel_info, channel_type, channels)
			% CHANNELGROUPDECODING - decode channel list into the groups where the channels are stored
			%
			% [GROUPS, CHANNEL_INDEXES_IN_GROUPS, CHANNEL_INDEXES_IN_OUTPUT]=...
			%   CHANNELGROUPDECODING(CHANNEL_INFO, CHANNEL_TYPE, CHANNELS)
			%
			%
				channel_num = [];
				groups = [];
				channel_indexes_in_groups = {};
				channel_indexes_in_output = {};

				indexes_type = find(strcmp(channel_type,{channel_info.type}));

				ci = channel_info(indexes_type); % look only at channels with the right type
				for c=1:numel(channels),
					index = find([ci.number]==channels(c));
					if isempty(index),
						error(['Channel number ' int2str(channels(c)) ' not found in record.']);
					end;
					if numel(index)>1,
						error(['Channel number ' int2str(channels(c)) ' found multiple times in record.']);
					end;
					group_loc = ismember(groups,ci(index).group);
					if isempty(group_loc),
						groups(end+1) = ci(index).group;
						group_loc = numel(groups);
						channel_indexes_in_groups{group_loc} = [];
						channel_indexes_in_output{group_loc} = [];
					end;
					subset_group = find([ci.group]==groups(group_loc)); % subset of group and channel type
					chan_index_in_group = find([ci(subset_group).number]==channels(c));
					channel_indexes_in_groups{group_loc}(end+1) = chan_index_in_group;
					channel_indexes_in_output{group_loc}(end+1) = c;
				end;
		end; % channelgroupdecoding()

	end; % methods(static)

end 
