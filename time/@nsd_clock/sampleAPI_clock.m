function c = NSD_clock(device, interval)
% NSD_CLOCK - specify a clock for an experiment
%
%   C = NSD_CLOCK  returns a clock that is in units that are
%   global to the experiment.
%
%   C = NSD_CLOCK(DEVICE) returns a clock that is in units of
%   time local to the device DEVICE.
%
%   C = NSD_CLOCK(DEVICE, INTERVAL) returns a clock that is relative
%   to the beginning of the INTERVALth recording of device DEVICE.
%
%

if nargin==0,
	type = 'global';
	device = [];
	interval = [];
elseif nargin==1,
	type = 'local';
	interval = [];
elseif nargin==2,
	type = 'epoch';
end;

sampleapi_clock_structure = struct('type',type,'device',device,'interval',interval);

c = class(sampleapi_clock_structure,'NSD_clock');
