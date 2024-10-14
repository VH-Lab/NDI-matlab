function [probename, proberef, subjectname, probetype] = channelname2probename(chName, subjects, options)
% CHANNELNAME2PROBE - convert a Marder channel name to a probe name
%
% [PROBENAME, PROBEREF, SUBJECTNAME, PROBETYPE] = CHANNELNAME2PROBENAME(CHNAME, SUBJECTS)
%
% Given a channel name (e.g., 'A5','B4'), returns a probe name
% and subject name. PROBEREF is always 1.
% 
% If there is more than one subject (usually a maximum of 1), then the
% program looks for a '1' or '2' in CHNAME. If none is found, then it is 
% assumed there is only 1 subject and 1 is the end of the string.
% If a 2 is found and there is no second subject, a warning is produced.
%

arguments
	chName
	subjects
	options.nothing = 0;
end

subjectname = subjects{1};

probetype = 'eeg';

if ~isempty(findstr(lower(chName),'ecg')),
	probetype = 'ecg';
end;
if ~isempty(findstr(lower(chName),'counter')),
	probetype = '';
end;
if ~isempty(findstr(lower(chName),'status')),
	probetype = '';
end;
if ~isempty(findstr(chName,'ACC')),
	probetype = '';
end;

probename = matlab.lang.makeValidName(chName);
proberef = 1;

