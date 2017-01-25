function files = getEpoch(dt, query)
% GETEPOCH - get the files for specific query within the data object
%
%  FILES = GETEPOCH(DT, QUERY)
%
%  return the specific data files by time or other information
%

allfiles = findfiletype(getpath(getExperiment(dt)), dt.filetype);

if length(allfiles) <= query,
	files = allfiles(query);
else,
	error(['There is not an epoch numbered ' int2str(query) '; only ' int2str(length(allfiles)) ' epochs found.']);
end;
