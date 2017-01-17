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

file_names = findfiletype(getpath(getexperiment(sAPI_dev)),'rhd');  %%use the files as object fields later

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
