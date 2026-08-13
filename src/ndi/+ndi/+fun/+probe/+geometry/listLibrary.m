function names = listLibrary(group)
% NDI.FUN.PROBE.GEOMETRY.LISTLIBRARY - list the electrode layouts shipped with NDI
%
% NAMES = NDI.FUN.PROBE.GEOMETRY.LISTLIBRARY()
% NAMES = NDI.FUN.PROBE.GEOMETRY.LISTLIBRARY(GROUP)
%
% Returns a cell array of the electrode-layout names available in the NDI library
% at [ndi_common]/probe/geometry/. Layouts are organized into groups (subfolders,
% typically by manufacturer, e.g. 'neuropixels', 'cambridgeneurotech', 'generic').
%
% With no argument, NAMES contains every layout as 'group/model'. With a GROUP
% argument, NAMES contains just the model names within that group.
%
% See also: NDI.FUN.PROBE.GEOMETRY.READLIBRARY, NDI.FUN.PROBE.GEOMETRY.FROMLIBRARY

    root = fullfile(ndi.common.PathConstants.CommonFolder, 'probe', 'geometry');

    if nargin>=1 && ~isempty(group),
        d = fullfile(root, group);
        if ~isfolder(d),
            error('No electrode-layout group ''%s'' found in %s.', group, root);
        end;
        L = dir(fullfile(d,'*.json'));
        [~, names] = fileparts({L.name});
        if ~iscell(names), names = {names}; end;
        return;
    end;

    names = {};
    if ~isfolder(root),
        return;
    end;
    groups = dir(root);
    for i=1:numel(groups),
        if ~groups(i).isdir || startsWith(groups(i).name,'.'),
            continue;
        end;
        L = dir(fullfile(root, groups(i).name, '*.json'));
        for j=1:numel(L),
            [~, model] = fileparts(L(j).name);
            names{end+1} = [groups(i).name '/' model]; %#ok<AGROW>
        end;
    end;

end
