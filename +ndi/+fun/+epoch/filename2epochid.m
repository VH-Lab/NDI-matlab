function [epochid] = filename2epochid(session,filename)
%FILENAME2EPOCHID Finds the epochid associated with a given filename.
%
%   EPOCHID = FILENAME2EPOCHID(SESSION, FILENAME) searches through the epoch
%   tables within the provided SESSION object to find an epoch_id
%   associated with the specified FILENAME.
%
%   Input Arguments:
%       session  - An NDI session object.
%       filename - A char array or string scalar representing the name of the
%                  file to search for within the epochs.
%
%   Output Arguments:
%       epochid  - A cell array of epoch ID(s) associated with the filename.

% Input argument validation
arguments
    session {mustBeA(session,{'ndi.session.dir','ndi.database.dir'})}
    filename (1,:) {mustBeA(filename,{'char','str','cell'})}
end

% Get daq system
dev = session.daqsystem_load;
if ~iscell(dev)
    dev = {dev};
end

% Ensure filename is cell array for processing
if ~iscell(filename)
    filename = {filename};
end

epochid = cell(size(filename));
for d = 1:numel(dev)
    et = dev{d}.epochtable;
    for e = 1:numel(et)
        
        % Get underlying files
        underlyingFiles = et(e).underlying_epochs.underlying;

        % Check if underlying files match any filename(s)
        fileInd = cellfun(@(f) any(contains(underlyingFiles,f)),filename);

        if any(fileInd)
            epochid{fileInd} = et(e).epoch_id;
        end
    end
end

% Check output size/type
missingID = cellfun(@isempty,epochid);
if any(missingID)
    warning('FILENAME2EPOCHID:NoEpochFound','No file was found matching the filename(s): \n %s',...
        strjoin(filename(missingID),'\n'));
end

end