% NSD_DEVICESTRING - a class for describing the device and channels that correspond to an NSD_EPOCHCONTENTS
%
%  NSD_DEVICESTRING
%
%  A 'devicestring' is a part of an NSD_EPOCHCONTENTS that indicates the channel types and
%  channel numbers that correspond to a particular record.
%
%  For example, one may specify that a 4-channel extracellular recording with name
%  'ctx' and reference 1 was recorded on a device called 'mydevice' via analog input
%  on channels 27-28 and 45 and 88 with the following nsd_epochcontents entry:
%           name: 'ctx'
%      reference: 1
%           type: 'extracellular_electrode-4'
%   devicestring: 'mydevice:ai27-28,45,88
%
%  The form of a device string is DEVICENAME:CT####, where DEVICENAME is the name of 
%  NSD_DEVICE object, CT is the channel type identifier, and #### is a list of channels.
%  The #### list of channels should be numbered from 1, and can use the symbols '-' to
%  indicate a sequential run of channels, and ',' to separate channels.
%  
%  For example:
%     '1-5,10,17'      corresponds to [1 2 3 4 5 10 17]
%     '2,5,11-12,8     corresopnds to [2 5 11 12 8]
%     ''               corresponds to []  % if the device doesn't have channels
%
% 
%  See also: NSD_DEVICESTRING/NSD_DEVICESTRING, NSD_DEVICESTRING/DEVICESTRING
%

classdef nsd_devicestring
	properties (GetAccess=public, SetAccess=protected)
		devicename    % The name of the device
		channeltype   % The type of channels that are used by the device
		channellist   % An array of the channels that are referred to by the devicestring
	end

	methods
		function obj = nsd_devicestring(devicename, channeltype, channellist)
			% NSD_DEVICESTRING - Create an NSD_DEVICESTRING object from a string or from a device name, channel type, and channel list
			%
			% DEVSTR = NSD_DEVICESTRING(DEVICENAME, CHANNELTYPE, CHANNELLIST)
			%    or DEVSTR = NSD_DEVICESTRING(DEVSTRING)
			%
			% Creates a device string suitable for a NSD_EPOCHCONTENTS from a DEVICENAME,
			% CHANNELTYPE (such as 'ai', 'di', 'ao'), and a CHANNELLIST.
			%
			% Inputs:
			%    In the first form:
			%      DEVICENAME should be the name of an NSD_DEVICE
			%      CHANNEL_PREFIX should be the prefix for a particular type of channel. These channel type will vary from
			%          device to device. For example, a NSD_DEVICE_MULTICHANNELDAQ might use:
			%            'ai' - analog input
			%            'ao' - analog output (it is an 'o' like 'oh', not 0)
			%            'di' - digital input
			%            'do' - digital output
			%      CHANNELLIST should be an array of channel numbers, which must start from 1 (that is,
			%            the first channel is 1).
			%    In the second form:
			%      DEVSTRING should be in the form: 'devicename:ct#,#-#,#,#'
			%        where devicename is the name of the device, ct is a string that corresponds to the channel type, and
			%        the numbers and separators specify the channel numbers to be accessed.
			%
			% Examples:
			%
			%      mynsd_devicestring1 = nsd_devicestring('mydevice','ai',[1:5 7 23])
			%      mynsd_devicestring2 = nsd_devicestring('mydevice:ai1-5,7,23');
			%
			% See also: NSD_DEVICESTRING
			%

				if nargin==1,
					% it is a string
					[obj.devicename, obj.channeltype, obj.channellist] = nsd_devicestring2channel(obj,devicename);
				else,
					obj.devicename = devicename;
					obj.channeltype = channeltype;
					obj.channellist = channellist;
				end;
		end % nsd_devicestring

		function [devicename, channeltype, channel] = nsd_devicestring2channel(self)
			% NSD_DEVICESTRING2CHANNELS - Convert an nsd_devicestring to device, channel type, channel list
			%
			% [DEVICENAME, CHANNELTYPE, CHANNELLIST] = NSD_DEVICESTRING2CHANNEL(SELF)
			%
			% Returns the device name (DEVICENAME), channel type (CHANNELTYPE), and channel list
			% (CHANNEL) of a device string.
			%
			% Inputs:
			%    DEVSTR should be an NSD devicestring in the form: devicename:ct#,#-#,#,#
			% Outputs:
			%    DEVICENAME is the string corresponding to the device name
			%    CHANNELTYPE is the channel type
			%    CHANNELLIST is an array of the channels
			%
			% Example:
			%    devstr = nsd_devicestring('mydevice:ai1-5,13,18');
			%    [devicename, channeltype, channel] = nsd_devicestring2channel(devstr);
			%    % devicename == 'mydevice', channelype = 'ai', channel == [1 2 3 4 5 13 18]
			%
			% See also: NSD_DEVICESTRING, NSD_DEVICESTRING/DEVICESTRING
			%
				devstr = self.devicestring();
				devstr(find(isspace(devstr))) = []; % remove whitespace
				colon = find(strtrim(devstr)==':');
				devicename = devstr(1:colon-1);
				firstnumber = find(  ~isletter(devstr(colon+1:end)), 1);
				if isempty(firstnumber), firstnumber = length(devstr(colon+1:end))+1; end;
				channeltype = devstr(colon+1:colon+firstnumber-1);
				channel = str2intseq(devstr(colon+firstnumber:end));
		end % nsd_devicestring2channel

		function devstr = devicestring(self);
			% DEVICESTRING - Produce an NSD_DEVICESTRING character string 
			%
			% DEVSTR = DEVICESTRING(SELF)
			%
			% Creates a device string suitable for a NSD_EPOCHCONTENTS from an NSD_DEVICESTRING object.
			%
			% Inputs:
			%    SELF - an NSD_DEVICESTRING object
			% Outputs:
			%    DEVSTR - the device string; e.g., 'mydevice:ai1-5,10,11-23'
			%
			%
			% See also: NSD_DEVICESTRING

				devstr = [self.devicename ':' self.channeltype intseq2str(self.channellist)];
		end % devicestring
	end

end

     
