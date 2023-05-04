function timestamp_string = timestamp()
% TIMESTAMP - return a current time stamp string
%
% TIMESTAMP_STRING = ndi.fun.timestamp()
%
% Returns a current time stamp string using the expression:
%   TIMESTAMP_STRING = char(datetime('now','TimeZone','UTCLeapSeconds'))
%
% The string is checked to make sure that the seconds are not
% "60.000", which can occur due to rounding and which can cause a 
% validation error when the data is included in a database.
% In that case, the seconds are set to "59.999".
%
% Example:
%   ts_st = ndi.fun.timestamp()
%

timestamp_string = char(datetime('now','TimeZone','UTCLeapSeconds'));

if strcmp(timestamp_string(end-6:end-1),'60.000'),
	timestamp_string(end-6:end-1) = '59.999';
end;
 

