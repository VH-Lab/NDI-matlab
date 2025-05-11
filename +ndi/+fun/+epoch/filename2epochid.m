function [epochid] = filename2epochid(session,filename)
%FILENAME2EPOCHID Finds the epochid associated with a given filename.
%
%   EPOCHID = FILENAME2EPOCHID(SESSION, FILENAME) searches through the epoch
%   tables within the provided SESSION object to find an epoch_id
%   associated with the specified FILENAME.
%
%   Input Arguments:
%       session  - An NDI session object.
%
%       filename - A char array or string scalar representing the name of the
%                  file to search for within the epochs.
%
%   Output Arguments:
%       epochid  - The epoch ID(s) associated with the filename.
%                  - If a single unique epoch ID is found, `epochid` is a
%                    char array.
%                  - If multiple unique epoch IDs are found, `epochid` is a
%                    cell array of char arrays (a warning is also issued).
%                  - If no epoch ID is found, an error is thrown.

% Input argument validation
arguments
    session {mustBeA(session,{'ndi.session.dir','ndi.database.dir'})}
    filename (1,:) char
end

% Get cached epoch table
probes = session.getprobes;
cacheTable = session.cache.table;
probeInd = find(contains({cacheTable.type},'epochtable-hash'));

epochid = {};
for p = probeInd
    % Get epoch table for the probe
    et = cacheTable(p).data.epochtable;
    for e = 1:numel(et)

        % Get underlying files (if applicable)
        underlyingFiles = et(e).underlying_epochs.underlying;
        if isa(underlyingFiles,'ndi.daq.system.mfdaq')
            continue
        end

        % Check for matching filename
        fileInd = contains(underlyingFiles,filename);
        if ~any(fileInd)
            continue
        end
        epochid = cat(1,epochid,{et(e).epoch_id});
    end
end

% Retrieve unique epoch ids
epochid = unique(epochid);

% Check output size/type
if iscell(epochid) & isscalar(epochid)
    epochid = epochid{1};
elseif isempty(epochid)
    error('FILENAME2EPOCHID:NoEpochFound','No file was found matching the filename %s',filename);
elseif iscell(epochid) & ~isscalar(epochid)
    warning('FILENAME2EPOCHID:SeveralEpochsFound','More than one file was found matching the filename %s',filename);
end

end