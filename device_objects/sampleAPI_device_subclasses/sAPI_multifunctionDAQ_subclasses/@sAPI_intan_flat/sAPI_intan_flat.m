% SAPI_INTAN_FLAT - Create a new SAPI_INTAN_FLAT object
%
%  D = SAPI_INTAN_FLAT(NAME,THEDATATREE, EXP)
%
%  Creates a new SAPI_INTAN_FLAT object with NAME, THEDATATREE and
%  associated EXP
%

classdef sAPI_intan_flat < handle & sAPI_multifunctionDAQ
   properties
   end
   methods
      function obj = sAPI_intan_flat_cons(obj,exp,name,thedatatree,reference)
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

        filelist = findfiletype(getpath(exp),'rhd');


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
        end
      end

      function [intervals] = getintervals(sAPI_dev)
        %   FUNCTION GETINTERVALS - list the relative time order for all the
        %   intervals
        %
        %   INTERVALS = GETINTERVALS(SAPI_DEV)
        %
        %   Returns the orders for all the intervals related to the experiment
        %
        %   INTERVALS = {f1,order1
        %                f2,order2
        %                f3,order3....}

        intervals = struct('file',[],'local_epoch_order',[]);
        intervals = ([]);

        filelist = findfiletype(getpath(getexperiment(sAPI_dev)),'rhd');
            for i=1:length(filelist),
                temp = read_Intan_RHD2000_header(filelist{i});
                intervals(end+1).file = temp.fileinfo.filename;
                intervals(end).local_epoch_order = i;            % desired implementation: need to use multiple filenames to make comparsion and get the order list
            end
      end


      function report = read_channel(sAPI_dev,channeltype,channel,sAPI_clock, t0,t1)

        %  FUNCTION READ_CHANNELS - read the data based on specified channels
        %
        %  REPORT = READ_CHANNELS(SAPI_DEV, CHANNELTYPE,CHANNEL,SAPI_CLOCK,T0,T1)
        %
        %  CHANNELTYPE is the type of channel to read
        %  ('analog','digitalin','digitalout', etc)
        %  
        %
        %  REPORT is the data collection for specific channels

        file_names = findfiletype(getpath(exp),'rhd');  %%use the files as object fields later

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
      end
    end
end
