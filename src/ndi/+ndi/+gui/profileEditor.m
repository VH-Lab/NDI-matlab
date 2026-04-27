function fig = profileEditor(options)
%NDI.GUI.PROFILEEDITOR uifigure editor for ndi.cloud.profile.
%
%   NDI.GUI.PROFILEEDITOR opens a window for managing the NDI Cloud
%   login profiles held by ndi.cloud.profile. The editor exposes the
%   common operations (Add, Set Current, Change Password, Remove) and
%   refreshes from the singleton after every change. Stage is
%   intentionally not shown — it is a developer-only field, set from
%   the command line via ndi.cloud.profile.setStage.
%
%   Syntax:
%       ndi.gui.profileEditor()
%       ndi.gui.profileEditor(Position=[x y w h])
%       fig = ndi.gui.profileEditor(...)
%
%   Name-value arguments:
%       Position - 1x4 double, the figure Position in pixels.
%                  Default [120 120 720 420].
%
%   Outputs:
%       fig      - handle of the created uifigure (suppressed when
%                  called with no output argument).
%
%   Layout:
%       * A uitable lists every profile with columns Current /
%         Nickname / Email / UID. The current profile is marked with
%         an asterisk in the Current column.
%       * The bottom row holds Add..., Set Current, Change
%         Password..., Remove, and Close buttons.
%
%   Buttons:
%       Add               - prompt for Nickname / Email / Password
%                           and call ndi.cloud.profile.add.
%       Set Current       - call ndi.cloud.profile.setCurrent for the
%                           selected row.
%       Change Password   - prompt for a new password and call
%                           ndi.cloud.profile.setPassword. The user
%                           never sees the underlying secrets key.
%       Remove            - confirm, then call
%                           ndi.cloud.profile.remove (which also
%                           deletes the secret from the active
%                           backend).
%       Close             - dispose the window. Pending edits go
%                           through the API as they happen, so no
%                           explicit Save step is needed here.
%
%   Implementation notes:
%       Plain uifigure built imperatively from local functions, like
%       ndi.gui.preferencesEditor. The uitable's CellSelectionCallback
%       maintains the currently-selected row in fig.UserData.
%       Password input uses inputdlg, which does not mask characters;
%       this is a known v1 limitation.
%
%   Example:
%       ndi.gui.profileEditor();
%
%   See also: ndi.cloud.profile, ndi.gui.preferencesEditor

    arguments
        options.Position (1,4) double = [120 120 720 420]
    end

    fig = uifigure('Name', 'NDI Cloud Profiles', ...
        'Position', options.Position, ...
        'Tag',      'ndiProfileEditor');
    fig.UserData = struct('SelectedRow', []);

    rootGrid = uigridlayout(fig, [2 1]);
    rootGrid.RowHeight   = {'1x', 38};
    rootGrid.ColumnWidth = {'1x'};
    rootGrid.Padding     = [8 8 8 8];
    rootGrid.RowSpacing  = 6;

    tablePanel = uipanel(rootGrid, 'BorderType', 'none');
    tablePanelGrid = uigridlayout(tablePanel, [1 1]);
    tablePanelGrid.Padding = [0 0 0 0];

    profileTable = uitable(tablePanelGrid, ...
        'Tag',                   'ndiProfileTable', ...
        'ColumnName',            {'Current', 'Nickname', 'Email', 'UID'}, ...
        'ColumnEditable',        [false false false false], ...
        'ColumnWidth',           {60, 160, 220, 'auto'}, ...
        'CellSelectionCallback', @onSelectionChanged);
    fig.UserData.Table = profileTable;
    refreshTable(fig);

    buttonRow = uigridlayout(rootGrid, [1 6]);
    buttonRow.ColumnWidth   = {'1x', 90, 110, 150, 90, 90};
    buttonRow.RowHeight     = {'1x'};
    buttonRow.Padding       = [0 0 0 0];
    buttonRow.ColumnSpacing = 6;

    uilabel(buttonRow, 'Text', '');   % left spacer
    uibutton(buttonRow, 'Text', 'Add...',             'ButtonPushedFcn', @onAdd);
    uibutton(buttonRow, 'Text', 'Set Current',        'ButtonPushedFcn', @onSetCurrent);
    uibutton(buttonRow, 'Text', 'Change Password...', 'ButtonPushedFcn', @onChangePassword);
    uibutton(buttonRow, 'Text', 'Remove',             'ButtonPushedFcn', @onRemove);
    uibutton(buttonRow, 'Text', 'Close',              'ButtonPushedFcn', @onClose);

    if nargout == 0
        clear fig
    end
end


function refreshTable(fig)
%REFRESHTABLE Repopulate the uitable from ndi.cloud.profile.
    tbl      = fig.UserData.Table;
    profiles = ndi.cloud.profile.list();
    cur      = ndi.cloud.profile.getCurrent();
    if isempty(cur)
        currentUID = '';
    else
        currentUID = cur.UID;
    end
    rows = cell(numel(profiles), 4);
    for i = 1:numel(profiles)
        if strcmp(profiles(i).UID, currentUID)
            rows{i, 1} = '*';
        else
            rows{i, 1} = '';
        end
        rows{i, 2} = profiles(i).Nickname;
        rows{i, 3} = profiles(i).Email;
        rows{i, 4} = profiles(i).UID;
    end
    tbl.Data = rows;
end


function onSelectionChanged(src, evt)
%ONSELECTIONCHANGED Track which row of the uitable is selected.
    fig = ancestor(src, 'figure');
    if isempty(evt.Indices)
        fig.UserData.SelectedRow = [];
    else
        fig.UserData.SelectedRow = evt.Indices(1, 1);
    end
end


function uid = selectedUID(fig)
%SELECTEDUID Return the UID of the currently-selected row, or ''.
    tbl = fig.UserData.Table;
    sel = fig.UserData.SelectedRow;
    if isempty(tbl.Data) || isempty(sel) ...
            || sel < 1 || sel > size(tbl.Data, 1)
        uid = '';
        return;
    end
    uid = tbl.Data{sel, 4};
end


function onAdd(src, ~)
%ONADD Add button: prompt and call ndi.cloud.profile.add.
    fig = ancestor(src, 'figure');
    answer = inputdlg( ...
        {'Nickname:', 'Email:', 'Password:'}, ...
        'Add Cloud Profile', ...
        [1 60; 1 60; 1 60]);
    if isempty(answer); return; end
    nickname = strtrim(answer{1});
    email    = strtrim(answer{2});
    password = answer{3};
    if isempty(nickname) || isempty(email) || isempty(password)
        uialert(fig, ...
            'Nickname, email, and password must all be provided.', ...
            'Add failed');
        return;
    end
    try
        ndi.cloud.profile.add(nickname, email, password);
    catch ME
        uialert(fig, ME.message, 'Add failed');
        return;
    end
    refreshTable(fig);
end


function onSetCurrent(src, ~)
%ONSETCURRENT Set Current button: call ndi.cloud.profile.setCurrent.
    fig = ancestor(src, 'figure');
    uid = selectedUID(fig);
    if isempty(uid)
        uialert(fig, 'Select a profile first.', 'No selection');
        return;
    end
    try
        ndi.cloud.profile.setCurrent(uid);
    catch ME
        uialert(fig, ME.message, 'Set Current failed');
        return;
    end
    refreshTable(fig);
end


function onChangePassword(src, ~)
%ONCHANGEPASSWORD Change Password button: prompt and call setPassword.
    fig = ancestor(src, 'figure');
    uid = selectedUID(fig);
    if isempty(uid)
        uialert(fig, 'Select a profile first.', 'No selection');
        return;
    end
    answer = inputdlg('New password:', 'Change Password', [1 60]);
    if isempty(answer); return; end
    pw = answer{1};
    if isempty(pw)
        uialert(fig, 'Password cannot be empty.', 'Change Password failed');
        return;
    end
    try
        ndi.cloud.profile.setPassword(uid, pw);
    catch ME
        uialert(fig, ME.message, 'Change Password failed');
        return;
    end
    uialert(fig, 'Password updated.', 'Done', 'Icon', 'success');
end


function onRemove(src, ~)
%ONREMOVE Remove button: confirm and call ndi.cloud.profile.remove.
    fig = ancestor(src, 'figure');
    uid = selectedUID(fig);
    if isempty(uid)
        uialert(fig, 'Select a profile first.', 'No selection');
        return;
    end
    try
        prof = ndi.cloud.profile.get(uid);
    catch ME
        uialert(fig, ME.message, 'Remove failed');
        return;
    end
    choice = uiconfirm(fig, ...
        sprintf('Delete profile "%s" (%s)?', prof.Nickname, prof.Email), ...
        'Confirm remove', ...
        'Options',       {'Delete', 'Cancel'}, ...
        'DefaultOption', 2, ...
        'CancelOption',  2);
    if ~strcmp(choice, 'Delete'); return; end
    try
        ndi.cloud.profile.remove(uid);
    catch ME
        uialert(fig, ME.message, 'Remove failed');
        return;
    end
    fig.UserData.SelectedRow = [];
    refreshTable(fig);
end


function onClose(src, ~)
%ONCLOSE Close button: dispose the editor figure.
    delete(ancestor(src, 'figure'));
end
