function [pathname, dirtype] = chooseDataset(options)
%NDI.UTIL.CHOOSEDATASET Pick a folder that is an NDI dataset directory.
%
%   [PATHNAME, DIRTYPE] = ndi.util.chooseDataset()
%
%   Opens a folder-selection dialog and returns the chosen PATHNAME only
%   once it is an NDI dataset directory (ndi.session.dir.directorytype
%   returns 'dataset'). DIRTYPE is 'dataset'. If the user cancels, PATHNAME
%   and DIRTYPE are both '' (empty char).
%
%   A directory whose type cannot be confirmed ('unknown' -- an NDI folder
%   created before object-type markers existed) is NOT accepted here,
%   because it could be a session; the dialog explains that it must be
%   opened once to record its type. Use ndi.util.chooseDatasetOrSession to
%   accept either kind.
%
%   Name-value options (passed through to ndi.util.chooseDatasetOrSession):
%       StartPath - folder the dialog opens in (default: current folder).
%       Title     - dialog title (default: 'Select an NDI dataset directory').
%
%   See also: ndi.util.chooseSession, ndi.util.chooseDatasetOrSession,
%     ndi.session.dir.directorytype

    arguments
        options.StartPath (1,:) char = ''
        options.Title     (1,:) char = ''
    end

    [pathname, dirtype] = ndi.util.chooseDatasetOrSession( ...
        'Accept', {'dataset'}, ...
        'StartPath', options.StartPath, ...
        'Title', options.Title);
end
