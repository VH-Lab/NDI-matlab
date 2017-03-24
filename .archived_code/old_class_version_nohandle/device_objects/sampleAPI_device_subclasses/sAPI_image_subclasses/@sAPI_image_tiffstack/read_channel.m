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
