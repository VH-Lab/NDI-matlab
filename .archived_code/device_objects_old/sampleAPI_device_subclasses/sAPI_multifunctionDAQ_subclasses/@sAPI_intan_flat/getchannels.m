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
%                    |    (e.g., 'analogin', 'digitalin', 'image', 'timestamp')
%

% look for RHD files
% mypath = getpath(getexperiment(sAPI_dev));
% 
% filelist = findfiletype(mypath,'.rhd');

filelist = findfiletype(getpath(getexperiment(sAPI_dev)),'rhd'),


channels = struct('name',[],'type',[]);
channels = channels([]);


intan_channel_types = {     'amplifier_channels'
    'aux_input_channels'
    'supply_voltage_channels'
    'board_adc_channels'
    'board_dig_in_channels'
    'board_dig_out_channels'};

sapi_multifunctiondaq_channel_types = { 'analog_in', 'aux_in', 'diagnostic', 'analog_in', 'digital_in', 'digital_out' };


for i=1:length(filelist),
	% then, open RHD files, and examine the headers for all channels present
	%   for any new channel that hasn't been identified before, 
    %   add it to the list
    obj = read_Intan_RHD2000_header(filelist{i});
    list_field = fieldnames(obj);
    structSize = size(list_field,1);
    for k = 1:structSize,
         occur = strcmp(list_field{k},intan_channel_types);  %%if the field is channel
         if any(occur),
            channel = getfield(obj, list_field{k});
            num = numel(channel);             %% number of channels with specific type
            lc = {channels(:).name};
            channel_type_entry = find(strcmp(list_field{k},intan_channel_types));
            channel_type_name = sapi_multifunctiondaq_channel_types{channel_type_entry};
            for p = 1:num,
                %name = name_convert_to_standard(channel_type_name, channel(p).native_channel_name);
                %answer = strcmp(name,{channels(:).name});
                %if ~any(answer),    
                    channels(end+1).name = channel(p).native_channel_name;  % needs modifying
                    channels(end).type = channel_type_name;
                %end
            end
         end
    end
end;

% for j = 1:length(file_names),
%     obj = read_Intan_RHD2000_header(char(file_names(j)));
%     list_field = fieldnames(obj);
%     structSize = size(list_field,1);
%     for k = 1:structSize,
%         occur = strfind(list_field(k),'channel','ForceCellOutput',true);        %%if the field is channel
%         if ~isempty(occur{1}),
%             channel = obj(:).(char(list_field(k)));
%             num = size(channel,2);                                              %% number of channels with specific type
%             lc = {channels(:).name};
%             for p = 1:num,
%                 name = channel(p).native_channel_name;
%                 answer = strfind(lc,name,'ForceCellOutput',true);
%                 if sum(~cellfun(@isempty,answer)) == 0,    
%                     ioc = ioc + 1;
%                     channels(ioc).name = name;
%                     channels(ioc).type = list_field(k);
%                 end
%             end
%         end
%     end
% end
    


    

