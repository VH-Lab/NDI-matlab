function [pathname, dirtype] = chooseDatasetOrSession(options)
%NDI.UTIL.CHOOSEDATASETORSESSION Pick a folder that is an NDI session or dataset.
%
%   [PATHNAME, DIRTYPE] = ndi.util.chooseDatasetOrSession()
%
%   Opens a folder-selection dialog and returns the chosen PATHNAME only
%   once it is an NDI session or dataset directory. DIRTYPE is the kind that
%   was chosen ('session', 'dataset', or 'unknown' -- see
%   ndi.session.dir.directorytype). If the user cancels, PATHNAME and
%   DIRTYPE are both '' (empty char).
%
%   MATLAB's uigetdir has no content filter (it cannot gray out folders that
%   are not NDI directories), so selections are validated after the fact:
%   if the chosen folder is not acceptable, the dialog explains why and
%   re-opens until an acceptable folder is chosen or the user cancels.
%
%   Name-value options:
%       StartPath - folder the dialog opens in (default: current folder).
%       Title     - dialog title (default derived from the accepted types).
%       Accept    - cellstr of directorytype values to accept. Defaults to
%                   {'session','dataset','unknown'} -- an NDI directory of
%                   unknown type is still a session or dataset, so it is
%                   accepted here. ndi.util.chooseSession and
%                   ndi.util.chooseDataset narrow this to a single type.
%
%   See also: ndi.util.chooseSession, ndi.util.chooseDataset,
%     ndi.session.dir.directorytype, uigetdir

    arguments
        options.StartPath (1,:) char = ''
        options.Title     (1,:) char = ''
        options.Accept    (1,:) cell = {'session', 'dataset', 'unknown'}
    end

    accept = options.Accept;
    title  = options.Title;
    if isempty(title)
        title = defaultTitle(accept);
    end

    pathname = '';
    dirtype  = '';
    start    = options.StartPath;

    while true
        sel = uigetdir(start, title);
        if isequal(sel, 0)
            return;   % user cancelled
        end

        t = ndi.session.dir.directorytype(sel);
        if any(strcmp(t, accept))
            pathname = sel;
            dirtype  = t;
            return;
        end

        % Not acceptable: explain and re-open near the chosen folder.
        msg = mismatchMessage(t, accept);
        uiwait(errordlg(msg, title, 'modal'));
        start = sel;
    end
end

% ------------------------------------------------------------------------
function title = defaultTitle(accept)
%DEFAULTTITLE Dialog title describing the accepted directory kinds.
    wantsSession = any(strcmp('session', accept));
    wantsDataset = any(strcmp('dataset', accept));
    if wantsSession && ~wantsDataset
        title = 'Select an NDI session directory';
    elseif wantsDataset && ~wantsSession
        title = 'Select an NDI dataset directory';
    else
        title = 'Select an NDI session or dataset directory';
    end
end

% ------------------------------------------------------------------------
function msg = mismatchMessage(t, accept)
%MISMATCHMESSAGE Explain why a chosen folder was not accepted.
    wanted = acceptedKindsPhrase(accept);
    switch t
        case 'none'
            msg = ['That folder is not an NDI session or dataset ' ...
                   'directory. Please choose ' wanted '.'];
        case 'unknown'
            msg = ['That NDI folder predates object-type markers, so its ' ...
                   'type cannot be confirmed. Open it once with ' ...
                   'ndi.session.dir or ndi.dataset.dir to record whether ' ...
                   'it is a session or a dataset, then choose it again. ' ...
                   '(Expected ' wanted '.)'];
        otherwise
            % t is a valid NDI type, just not one that was requested.
            msg = ['That folder is an NDI ' t ', but ' wanted ...
                   ' is required. Please choose ' wanted '.'];
    end
end

% ------------------------------------------------------------------------
function phrase = acceptedKindsPhrase(accept)
%ACCEPTEDKINDSPHRASE Human phrase for the accepted directory kinds.
    wantsSession = any(strcmp('session', accept));
    wantsDataset = any(strcmp('dataset', accept));
    if wantsSession && ~wantsDataset
        phrase = 'an NDI session';
    elseif wantsDataset && ~wantsSession
        phrase = 'an NDI dataset';
    else
        phrase = 'an NDI session or dataset';
    end
end
