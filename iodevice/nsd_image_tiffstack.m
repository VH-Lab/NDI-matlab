% function d = sAPI_image_tiffstack(name,thefiletree, exp)
%
% sAPI_image_tiffstack_struct = struct([]);
% S = sAPI_image(name,thefiletree,exp);
%
% d = class(sAPI_image_tiffstack_struct, 'sAPI_image_tiffstack',S);

classdef nsd_image_tiffstack < handle & nsd_iodevice_mfdaq
% SAPI_IMAGE_TIFFSTACK - Create a new SAPI_IMAGE_TIFFSTACK object
%
%  D = SAPI_IMAGE_TIFFSTACK(NAME, THEFILETREE,EXP)
%
%  Creates a new SAPI_IMAGE_TIFFSTACK object with NAME, THEDATAREE and associated EXP.
%
   properties
   end
   methods
      function obj = nsd_image_tiffstack(obj,exp,name,thefiletree,reference)
        if nargin==1 || nargin ==2 || nargin ==3,
            error(['Not enough input arguments.']);
        elseif nargin==4,
            obj.exp = exp;
            obj.name = name;
            obj.filetree = thefiletree;
            obj.reference = 'time';
        elseif nargin==5,
            obj.exp = exp;
            obj.name = name;
            obj.filetree = thefiletree;
            obj.reference = reference;
        else,
            error(['Too many input arguments.']);
        end;
      end

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
                        name = name_convert_to_standard(channel_type_name, channel(p).native_channel_name);
                        answer = strcmp(name,{channels(:).name});
                        if ~any(answer),
                            channels(end+1).name = name;  % needs modifying
                            channels(end).type = channel_type_name;
                        end
                    end
                 end
            end
        end
      end

      function report = read_channel(sAPI_dev,channeltype,channel,sAPI_clock, t0,t1)
        %  FUNCTION READ_CHANNELS - read the data based on specified channels
        %
        %  REPORT = READ_CHANNELS(SAPI_DEV, CHANNELTYPE,CHANNEL,SAPI_CLOCK,T0,T1)
        %
        %  CHANNELTYPE is the type of channel to read
        %  ('image', etc)
        %  
        %
        %  REPORT is the data collection for specific image channels


        file_names = findfiletype(getpath(getexperiment(sAPI_dev)),'tif');  %%use the files as object fields later

        %file_names,
          % here we want to convert t0, and t1, which are in units of sAPI_clock
          %    into i0_, t0_ and i1_, t1_ (i being local recorded interval, and t being time within that interval) 

        [i0_,t0_] = convert(sAPI_dev,sAPI_clock,t0);

        %i0_,
        %t0_,

        [i1_,t1_] = convert(sAPI_dev,sAPI_clock,t1);    %may need to incorporate the getintervals func into convert func

        %i1_,
        %t1_,

        intanchanneltype = multifuncdaqchanneltype2intan(channeltype);


        report = emptystruct('channeltype','channel','epoch','frame','data');     %%initial structure
        for i = 1:size(file_names,1),
            [sz,~] = getsamplesize(file_names{i});
            if t1 - t0 > sz,
                disp('the required frame number is larger than the existing frame of the image');
                return;
            end
            for j = t0:t1,
                image = imread(file_names{i},j);
                report(end+1).channeltype = channeltype;
                report(end).channel = channel;
                report(end).epoch = i;
                report(end).frame = j;
                report(end).data = image;
            end
        end
      function [sz,imagesize]= getsamplesize(sAPI_dev, interval, channeltype, channel)
        %
        % FUNCTION GETSAMERATE - GET THE SAMPLE RATE FOR SPECIFIC CHANNEL
        %
        % SR = GETSAMERATE(DEV, INTERVAL, CHANNELTYPE, CHANNEL)
        %
        % SR is the list of sample rate from specified channels

        file_names = findfiletype(getpath(getexperiment(sAPI_dev)),'tif');

        head = imfinfo(file_names{1});

        imagesize = head.FileSize;

        sz = size(head,1);

        % for i = i:size(head,1),
        %     size = head{i}.FileSize;
        %     freq_name = fieldnames(freq);               %get all the names for each freq
        %     all_freqs = cell2mat(struct2cell(freq));             %get all the freqs for each name
        %     for j = 1:size(freq_name,1),
        %         temp = freq_name{i};
        %         if (strncmpi(temp,channeltype,length(channeltype))),      %compare the beginning of two strings
        %             sr = all_freqs(j); return;
        %         end
        %     end


           % step 1: read header file of that image
           % step 2: look in header.frequency_parameters to pull out the rate


        end

        function [intervals] = getintervals(sAPI_dev)
        %   FUNCTION GETINTERVALS - list the relative time order for all the
        %   intervals
        %
        %   INTERVALS = GETINTERVALS(SAPI_DEV)
        %
        %   Returns the orders for all the intervals related to the experiment
        %
        %   EPOCH = {f1,order1
        %            f2,order2
        %            f3,order3....}

        intervals = struct('file',[],'local_epoch_order',[]);
        intervals = ([]);

        filelist = findfiletype(getpath(getexperiment(sAPI_dev)),'tif');
            for i=1:length(filelist),
                intervals(end+1).file = filelist{i};
                intervals(end).local_epoch_order = i;            % desired implementation: need to use multiple filenames to make comparsion and get the order list
            end
        return;  


        % intervals = [];
        % for (i <= size(device.stim_times,1) )
        % intervals(:,1) = device.stim_times(,2);
        % intervals(:,2) = device.stim_times(,3) - device.stim_times(,2);
        % intervals(:,3) = device.voltageForTime; 

        end

   end
