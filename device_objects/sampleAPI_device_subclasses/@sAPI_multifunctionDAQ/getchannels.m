function channels = getchannels(NSD_dev)
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
%                    |    (e.g., 'analog', 'digital', 'image', 'timestamp')
%


channels = struct('name',[],'type',[]);
channels = channels([]);

