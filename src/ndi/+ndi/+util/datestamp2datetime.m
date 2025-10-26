function datetimeValue = datestamp2datetime(datestampStr)
% NDI_DATESTAMP2DATETIME - Convert a datestamp string to a datetime object
%
% DATETIMEVALUE = NDI.UTIL.DATESTAMP2DATETIME(DATESTAMPSTR)
%
% Converts a datestamp string in the format provided by NDI.DOCUMENT
% objects (in base.datestamp) and returns a MATLAB DATETIME object.
%
% The input format is assumed to be 'yyyy-MM-dd''T''HH:mm:ss.SSSXXX'
% and the timezone is assumed to be UTC.
%
% Example:
%   ds = '2023-01-01T12:00:00.000+00:00';
%   dt = ndi.util.datestamp2datetime(ds);
%   disp(dt);
%

arguments
    datestampStr (1,:) char {mustBeVector}
end

datetimeValue = datetime(datestampStr, 'InputFormat', 'yyyy-MM-dd''T''HH:mm:ss.SSSXXX','TimeZone','UTC');

end