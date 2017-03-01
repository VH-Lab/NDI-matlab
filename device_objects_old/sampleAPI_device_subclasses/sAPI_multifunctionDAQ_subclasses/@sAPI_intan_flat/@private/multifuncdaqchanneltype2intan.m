function intanchanneltype = multifuncdaqchanneltype2intan(channeltype)
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