function channels = getchannels(sAPI_dev)
% FUNCTION GETCHANNELS - List the channels that are available on this device
%
%  CHANNELS = GETCHANNELS(SAPI_DEV)
%
%  Returns the channel list of acquired channels in this experiment
%
% CHANNELS is a structure list of all channels with fields:
% -------------------------------------------------------
% 'name'             | The name of the channel (e.g., 'ai0')
% 'type'             | The type of data stored in the channel
%                    |    (e.g., 'image')
%

% look for RHD files
% mypath = getpath(getexperiment(sAPI_dev));
% 
% filelist = findfiletype(mypath,'.rhd');

filelist = findfiletype(getpath(getexperiment(sAPI_dev)),'tif');


channels = struct('name',[],'type',[]);
channels = channels([]);


intan_channel_types = {   'image'  };

sapi_multifunctiondaq_channel_types = { 'image' };


for i=1:length(filelist),
	% then, open RHD files, and examine the headers for all channels present
	%   for any new channel that hasn't been identified before, 
    %   add it to the list
    obj = imread(filelist{i});
    channels(end+1).name = name;  % needs modifying
    channels(end).type = 'image';
%     obj = read_Intan_RHD2000_header(filelist{i});
%     list_field = fieldnames(obj);
%     structSize = size(list_field,1);
%     for k = 1:structSize,
%          occur = strcmp(list_field{k},intan_channel_types);  %%if the field is channel
%          if any(occur),
%             channel = getfield(obj, list_field{k});
%             num = numel(channel);             %% number of channels with specific type
%             lc = {channels(:).name};
%             channel_type_entry = find(strcmp(list_field{k},intan_channel_types));
%             channel_type_name = sapi_multifunctiondaq_channel_types{channel_type_entry};
%             for p = 1:num,
%                 name = name_convert_to_standard(channel_type_name, channel(p).native_channel_name);
%                 answer = strcmp(name,{channels(:).name});
%                 if ~any(answer),    
%                     channels(end+1).name = name;  % needs modifying
%                     channels(end).type = channel_type_name;
%                 end
%             end
%          end
%     end
end;

    

