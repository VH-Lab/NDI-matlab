% NDI_DAQSYSTEMSTRING - a class for describing the device and channels that correspond to an NDI_EPOCHPROBEMAP_DAQSYSTEM
%
%  ndi.daq.daqsystemstring
%
%  A 'devicestring' is a part of an ndi.epoch.epochprobemap_daqsystem that indicates the channel types and
%  channel numbers that correspond to a particular record.
%
%  For example, one may specify that a 4-channel extracellular recording with name
%  'ctx' and reference 1 was recorded on a device called 'mydevice' via analog input
%  on channels 27-28 and 45 and 88 with the following ndi.epoch.epochprobemap_daqsystem entry:
%           name: 'ctx'
%      reference: 1
%           type: 'extracellular_electrode-4'
%   devicestring: 'mydevice:ai27-28,45,88
%
%  The form of a device string is DEVICENAME:CT####, where DEVICENAME is the name of
%  ndi.daq.system object, CT is the channel type identifier, and #### is a list of channels.
%  The #### list of channels should be numbered from 1, and can use the symbols '-' to
%  indicate a sequential run of channels, and ',' to separate channels.
%  Use a semicolon to separate channel types (e.g., 'ai27-28;di1')
%
%  For example:
%     '1-5,10,17'      corresponds to [1 2 3 4 5 10 17]
%     '2,5,11-12,8     corresponds to [2 5 11 12 8]
%     ''               corresponds to []  % if the device doesn't have channels
%
%
%  See also: ndi.daq.daqsystemstring/NDI_DEVICESTRING, NDI_DEVICESTRING/DEVICESTRING
%

classdef daqsystemstring
    properties (GetAccess=public, SetAccess=protected)
        devicename    % The name of the device
        channeltype   % The type of channels that are used by the device
        channellist   % An array of the channels that are referred to by the devicestring
    end

    methods
        function obj = daqsystemstring(devicename, channeltype, channellist)
            % ndi.daq.daqsystemstring - Create an NDI_DEVICESTRING object from a string or from a device name, channel type, and channel list
            %
            % DEVSTR = ndi.daq.daqsystemstring(DEVICENAME, CHANNELTYPE, CHANNELLIST)
            %    or DEVSTR = ndi.daq.daqsystemstring(DEVSTRING)
            %
            % Creates a device string suitable for a ndi.epoch.epochprobemap_daqsystem from a DEVICENAME,
            % a cell array of strings CHANNELTYPE (such as 'ai', 'di', 'ao'), and a CHANNELLIST.
            %
            % Inputs:
            %    In the first form:
            %      DEVICENAME should be the name of an ndi.daq.system
            %      CHANNEL_PREFIX should be the prefix for a particular type of channel. These channel type will vary from
            %          device to device. For example, a NDI_DAQSYSTEM_MULTICHANNELDAQ might use:
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
            %      myndi_daqsystemstring1 = ndi_devicestring('mydevice','ai',[1:5 7 23])
            %      myndi_daqsystemstring2 = ndi_devicestring('mydevice:ai1-5,7,23');
            %
            % See also: ndi.daq.daqsystemstring
            %
            if nargin==1
                % it is a string
                [obj.devicename, obj.channeltype, obj.channellist] = ndi_daqsystemstring2channel(obj,devicename);
            else
                obj.devicename = devicename;
                obj.channeltype = channeltype;
                obj.channellist = channellist;
            end
        end % ndi.daq.daqsystemstring

        function [devicename, channeltype, channel] = ndi_daqsystemstring2channel(self, devstr)
            % NDI_DAQSYSTEMSTRING2CHANNEL - Convert an ndi.daq.daqsystemstring to device, channel type, channel list
            %
            % [DEVICENAME, CHANNELTYPE, CHANNELLIST] = NDI_DAQSYSTEMSTRING2CHANNEL(SELF, DEVSTR)
            %
            % Returns the device name (DEVICENAME), channel type (CHANNELTYPE), and channel list
            % (CHANNEL) of a device string.
            %
            % Inputs:
            %    DEVSTR should be an NDI devicestring in the form: devicename:ct#,#-#,#,#
            % Outputs:
            %    DEVICENAME is the string corresponding to the device name
            %    CHANNELTYPE is a cell array of strings with channel types
            %    CHANNELLIST is an array of the channel numbers
            %
            % Example:
            %    devstr = ndi.daq.daqsystemstring('mydevice:ai1-5,13,18');
            %    [devicename, channeltype, channel] = ndi_daqsystemstring2channel(devstr);
            %    % devicename == 'mydevice', channelype = 'ai', channel == [1 2 3 4 5 13 18]
            %
            % See also: ndi.daq.daqsystemstring, NDI_DEVICESTRING/DEVICESTRING
            %
            if nargin<2
                devstr = self.devicestring();
            end
            channeltype = {};
            channel = [];
            devstr(find(isspace(devstr))) = []; % remove whitespace
            colon = find(strtrim(devstr)==':');
            devicename = devstr(1:colon-1);
            % now read semi-colon-delimited segments
            if devstr(end)~=';'
                devstr(end+1)=';';
            end % add a superfluous ending semi-colon to make code easier
            separators= [colon find(devstr==';')];
            for i=1:numel(separators)-1
                mysubstr = devstr(separators(i)+1:separators(i+1)-1);
                firstnumber = find(  ~isletter(mysubstr), 1);
                if isempty(firstnumber)
                    error(['No number in ndi.daq.system substring: ' mysubstr '.']);
                end
                channelshere = vlt.string.str2intseq(mysubstr(firstnumber:end));
                channeltype = cat(2,channeltype,repmat({mysubstr(1:firstnumber-1)},1,numel(channelshere)));
                channel = cat(2,channel,channelshere(:)');
            end
        end % ndi_daqsystemstring2channel

        function devstr = devicestring(self)
            % DEVICESTRING - Produce an ndi.daq.daqsystemstring character string
            %
            % DEVSTR = DEVICESTRING(SELF)
            %
            % Creates a device string suitable for a ndi.epoch.epochprobemap_daqsystem from an ndi.daq.daqsystemstring object.
            %
            % Inputs:
            %    SELF - an ndi.daq.daqsystemstring object
            % Outputs:
            %    DEVSTR - the device string; e.g., 'mydevice:ai1-5,10,11-23'
            %
            %
            % See also: ndi.daq.daqsystemstring
            devstr = [self.devicename ':'];
            prevchanneltype = '';
            newchannellist = [];
            for i=1:numel(self.channellist)
                currentchanneltype = self.channeltype{i};
                if strcmp(currentchanneltype,prevchanneltype)
                    newchannellist(end+1) = self.channellist(i);
                elseif ~strcmp(currentchanneltype,prevchanneltype)
                    % we need to write the previous channels
                    if ~isempty(newchannellist) % do the writing
                        devstr = cat(2,devstr, [prevchanneltype vlt.string.intseq2str(newchannellist) ]);
                        devstr(end+1) = ';';
                    end
                    % start off the new list
                    newchannellist = [self.channellist(i)];
                end
                if i==numel(self.channellist) % need to write any channels accumulated
                    devstr = cat(2,devstr, [currentchanneltype vlt.string.intseq2str(newchannellist) ]);
                end
                prevchanneltype = currentchanneltype;
            end
        end % devicestring
    end
end
