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
   
   