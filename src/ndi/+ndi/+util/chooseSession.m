function [pathname, dirtype] = chooseSession(options)
%NDI.UTIL.CHOOSESESSION Pick a folder that is an NDI session directory.
%
%   [PATHNAME, DIRTYPE] = ndi.util.chooseSession()
%
%   Opens a folder-selection dialog and returns the chosen PATHNAME only
%   once it is an NDI session directory (ndi.session.dir.directorytype
%   returns 'session'). DIRTYPE is 'session'. If the user cancels, PATHNAME
%   and DIRTYPE are both '' (empty char).
%
%   A directory whose type cannot be confirmed ('unknown' -- an NDI folder
%   created before object-type markers existed) is NOT accepted here,
%   because it could be a dataset; the dialog explains that it must be
%   opened once to record its type. Use ndi.util.chooseDatasetOrSession to
%   accept either kind.
%
%   Name-value options (passed through to ndi.util.chooseDatasetOrSession):
%       StartPath - folder the dialog opens in (default: current folder).
%       Title     - dialog title (default: 'Select an NDI session directory').
%
%   See also: ndi.util.chooseDataset, ndi.util.chooseDatasetOrSession,
%     ndi.session.dir.directorytype

    arguments
        options.StartPath (1,:) char = ''
        options.Title     (1,:) char = ''
    end

    [pathname, dirtype] = ndi.util.chooseDatasetOrSession( ...
        'Accept', {'session'}, ...
        'StartPath', options.StartPath, ...
        'Title', options.Title);
end
