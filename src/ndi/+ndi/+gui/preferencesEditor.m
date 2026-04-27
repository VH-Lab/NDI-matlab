function fig = preferencesEditor(options)
%NDI.GUI.PREFERENCESEDITOR uifigure editor for ndi.preferences.
%
%   NDI.GUI.PREFERENCESEDITOR opens a window for browsing and editing
%   the preferences managed by ndi.preferences. Edits are deferred
%   until the user explicitly applies or saves them, so the on-disk
%   JSON file is only rewritten on demand.
%
%   Syntax:
%       ndi.gui.preferencesEditor()
%       ndi.gui.preferencesEditor(Position=[x y w h])
%       fig = ndi.gui.preferencesEditor(...)
%
%   Name-value arguments:
%       Position - 1x4 double, the figure Position in pixels.
%                  Default [100 100 820 540].
%
%   Outputs:
%       fig      - handle of the created uifigure (also returned via
%                  nargout). When called without an output argument
%                  the handle is suppressed.
%
%   Layout:
%       * Left pane  (~30 percent): a uitree of Categories with
%         Subcategories as children. Selecting a Category shows every
%         item in that category; selecting a Subcategory narrows the
%         right pane to just that subcategory.
%       * Right pane (~70 percent): a scrollable two-column grid with
%         one row per item. The label uses the Description field as
%         a tooltip; the editor widget is chosen from the item Type:
%             'double','single' -> uieditfield (numeric)
%             'logical'         -> uicheckbox
%             everything else   -> uieditfield (text)
%       * Bottom row: Revert | Apply | Save buttons.
%
%   Buttons:
%       Revert - discard pending edits; widgets are repopulated from
%                the current ndi.preferences values.
%       Apply  - push pending edits through ndi.preferences.set
%                (which persists each change to the JSON file). The
%                editor stays open.
%       Save   - same as Apply, then close the window.
%
%   Pending edits live only in the editor (in fig.UserData.pending)
%   until Apply or Save is pressed; nothing reaches the singleton or
%   disk before that. The label of any item with a pending change is
%   marked with a trailing asterisk.
%
%   Implementation notes:
%       This is a plain uifigure built imperatively from local
%       functions, not an App Designer .mlapp. That avoids the
%       App Designer launch penalty while still providing modern
%       widgets (uitree, uigridlayout, scrollable panels). State
%       is stored in fig.UserData and mutated from local-function
%       callbacks; identifiers come from the Tag property so
%       findobj can locate widgets after a rebuild.
%
%   Example:
%       ndi.gui.preferencesEditor();
%
%   See also: ndi.preferences, uifigure, uitree, uigridlayout

    arguments
        options.Position (1,4) double = [100 100 820 540]
    end

    state = makeInitialState();

    fig = uifigure('Name', 'NDI Preferences', ...
        'Position', options.Position, ...
        'Tag',      'ndiPreferencesEditor');
    fig.UserData = state;

    rootGrid = uigridlayout(fig, [2 1]);
    rootGrid.RowHeight    = {'1x', 38};
    rootGrid.ColumnWidth  = {'1x'};
    rootGrid.Padding      = [8 8 8 8];
    rootGrid.RowSpacing   = 6;

    splitter = uigridlayout(rootGrid, [1 2]);
    splitter.ColumnWidth   = {'3x', '7x'};
    splitter.RowHeight     = {'1x'};
    splitter.Padding       = [0 0 0 0];
    splitter.ColumnSpacing = 8;

    tree = uitree(splitter, ...
        'Tag', 'ndiPrefTree', ...
        'SelectionChangedFcn', @onTreeSelect);
    populateTree(tree, state.items);

    rightPanel = uipanel(splitter, ...
        'Tag',         'ndiPrefRightPanel', ...
        'BorderType',  'none', ...
        'Scrollable',  'on');                                       %#ok<NASGU>

    buttonRow = uigridlayout(rootGrid, [1 4]);
    buttonRow.ColumnWidth   = {'1x', 90, 90, 90};
    buttonRow.RowHeight     = {'1x'};
    buttonRow.Padding       = [0 0 0 0];
    buttonRow.ColumnSpacing = 6;

    uilabel(buttonRow, 'Text', '');   % left spacer
    uibutton(buttonRow, 'Text', 'Revert', 'ButtonPushedFcn', @onRevert);
    uibutton(buttonRow, 'Text', 'Apply',  'ButtonPushedFcn', @onApply);
    uibutton(buttonRow, 'Text', 'Save',   'ButtonPushedFcn', @onSave);

    if ~isempty(tree.Children)
        tree.SelectedNodes = tree.Children(1);
        rebuildRightPane(fig, tree.Children(1));
    end

    if nargout == 0
        clear fig
    end
end


function state = makeInitialState()
%MAKEINITIALSTATE Build the UserData struct that backs the editor.
%
%   STATE = MAKEINITIALSTATE() snapshots the current preferences
%   from ndi.preferences.getSingleton().Items into STATE.items and
%   creates three containers.Map handles keyed on item index:
%
%       STATE.pending - pending edits not yet applied (idx -> value)
%       STATE.labels  - uilabel handles for each item shown
%       STATE.widgets - editor widget handles for each item shown
%
%   The labels and widgets maps are reset every time the right pane
%   is rebuilt; pending survives until Revert, Apply, or Save.
    prefs = ndi.preferences.getSingleton();
    state.items   = prefs.Items;
    state.pending = containers.Map('KeyType', 'int32', 'ValueType', 'any');
    state.labels  = containers.Map('KeyType', 'int32', 'ValueType', 'any');
    state.widgets = containers.Map('KeyType', 'int32', 'ValueType', 'any');
end


function populateTree(tree, items)
%POPULATETREE Build the left-hand uitree from a snapshot of Items.
%
%   POPULATETREE(TREE, ITEMS) creates one top-level uitreenode per
%   distinct Category in ITEMS and one child node per non-empty
%   Subcategory. NodeData on each node carries a struct with
%   fields Category and Subcategory so onTreeSelect can rebuild the
%   right pane without re-parsing labels.
    if isempty(items); return; end
    cats = unique({items.Category}, 'stable');
    for ci = 1:numel(cats)
        catName = cats{ci};
        catNode = uitreenode(tree, ...
            'Text',     catName, ...
            'NodeData', struct('Category', catName, 'Subcategory', ''));
        catMask = strcmp({items.Category}, catName);
        subs = unique({items(catMask).Subcategory}, 'stable');
        subs = subs(~cellfun(@isempty, subs));
        for si = 1:numel(subs)
            subName = subs{si};
            uitreenode(catNode, ...
                'Text',     subName, ...
                'NodeData', struct('Category', catName, ...
                                   'Subcategory', subName));
        end
        expand(catNode);
    end
end


function onTreeSelect(src, evt)
%ONTREESELECT Tree SelectionChangedFcn: rebuild the right pane.
%
%   Triggered when the user clicks a Category or Subcategory in the
%   left tree. Forwards the first selected node to rebuildRightPane.
    if isempty(evt.SelectedNodes); return; end
    rebuildRightPane(ancestor(src, 'figure'), evt.SelectedNodes(1));
end


function rebuildRightPane(fig, node)
%REBUILDRIGHTPANE Render the editor rows for the selected tree node.
%
%   REBUILDRIGHTPANE(FIG, NODE) clears the right uipanel and lays
%   out one row per item that matches NODE.NodeData. If the selected
%   node has an empty Subcategory all items in that Category are
%   shown (and the row label is prefixed with the item's
%   Subcategory); otherwise only the items in that specific
%   Subcategory are shown.
%
%   The current value used for each widget is the pending edit if
%   one exists for that item index, otherwise the saved Value.
%   Items with a pending edit get a trailing '*' on their label.
    state      = fig.UserData;
    rightPanel = findobj(fig, 'Tag', 'ndiPrefRightPanel');
    delete(rightPanel.Children);

    state.labels  = containers.Map('KeyType', 'int32', 'ValueType', 'any');
    state.widgets = containers.Map('KeyType', 'int32', 'ValueType', 'any');

    nd    = node.NodeData;
    items = state.items;
    if isempty(nd.Subcategory)
        mask = strcmp({items.Category}, nd.Category);
    else
        mask = strcmp({items.Category}, nd.Category) ...
             & strcmp({items.Subcategory}, nd.Subcategory);
    end
    indices = find(mask);

    nRows = numel(indices) + 1;
    grid = uigridlayout(rightPanel, [nRows, 2]);
    grid.RowHeight     = repmat({30}, 1, nRows);
    grid.ColumnWidth   = {'1x', '1x'};
    grid.Padding       = [8 8 8 8];
    grid.RowSpacing    = 4;
    grid.ColumnSpacing = 8;
    grid.Scrollable    = 'on';

    h1 = uilabel(grid, 'Text', 'Preference', 'FontWeight', 'bold');
    h1.Layout.Row = 1; h1.Layout.Column = 1;
    h2 = uilabel(grid, 'Text', 'Value',      'FontWeight', 'bold');
    h2.Layout.Row = 1; h2.Layout.Column = 2;

    for k = 1:numel(indices)
        idx  = indices(k);
        item = items(idx);
        row  = k + 1;

        labelTxt = item.Name;
        if isKey(state.pending, int32(idx))
            labelTxt = [labelTxt '*']; %#ok<AGROW>
        end
        if ~isempty(item.Subcategory) && isempty(nd.Subcategory)
            labelTxt = sprintf('%s / %s', item.Subcategory, labelTxt);
        end

        lbl = uilabel(grid, 'Text', labelTxt, ...
            'Tooltip', item.Description);
        lbl.Layout.Row = row; lbl.Layout.Column = 1;

        if isKey(state.pending, int32(idx))
            currentVal = state.pending(int32(idx));
        else
            currentVal = item.Value;
        end

        widget = makeEditorWidget(grid, item, currentVal, idx);
        widget.Layout.Row = row; widget.Layout.Column = 2;

        state.labels(int32(idx))  = lbl;
        state.widgets(int32(idx)) = widget;
    end

    fig.UserData = state;
end


function widget = makeEditorWidget(parent, item, currentVal, idx)
%MAKEEDITORWIDGET Create the editor widget for one preference item.
%
%   WIDGET = MAKEEDITORWIDGET(PARENT, ITEM, CURRENTVAL, IDX) returns
%   a widget chosen from ITEM.Type:
%
%       'double' or 'single' -> numeric uieditfield
%       'logical'            -> uicheckbox
%       any other type       -> text uieditfield (the value is first
%                               coerced through char(string(...)) so
%                               strings, chars, and stringifiable
%                               objects all render)
%
%   The widget's ValueChangedFcn forwards to onValueChanged with IDX
%   so the pending-edits map stays keyed by the original Items index.
%   The Description field is wired as the widget's Tooltip.
    cb = @(src, evt) onValueChanged(src, evt, idx);
    switch item.Type
        case {'double', 'single'}
            widget = uieditfield(parent, 'numeric', ...
                'Value',           double(currentVal), ...
                'ValueChangedFcn', cb, ...
                'Tooltip',         item.Description);
        case 'logical'
            widget = uicheckbox(parent, ...
                'Value',           logical(currentVal), ...
                'Text',            '', ...
                'ValueChangedFcn', cb, ...
                'Tooltip',         item.Description);
        otherwise
            if ischar(currentVal) || isstring(currentVal)
                txt = char(currentVal);
            else
                try
                    txt = char(string(currentVal));
                catch
                    txt = '';
                end
            end
            widget = uieditfield(parent, 'text', ...
                'Value',           txt, ...
                'ValueChangedFcn', cb, ...
                'Tooltip',         item.Description);
    end
end


function onValueChanged(src, evt, idx)
%ONVALUECHANGED Widget ValueChangedFcn: record a pending edit.
%
%   Called when the user changes any editor widget. Stores the new
%   value in fig.UserData.pending under the item index IDX and
%   appends a trailing '*' to the row label so the user can see at
%   a glance which rows have unsaved edits.
    fig   = ancestor(src, 'figure');
    state = fig.UserData;
    state.pending(int32(idx)) = evt.Value;
    fig.UserData = state;

    if isKey(state.labels, int32(idx))
        lbl = state.labels(int32(idx));
        if isvalid(lbl) && ~endsWith(lbl.Text, '*')
            lbl.Text = [lbl.Text '*'];
        end
    end
end


function onRevert(src, ~)
%ONREVERT Revert button callback: drop pending edits.
%
%   Empties fig.UserData.pending and re-renders the current
%   selection so each widget shows the saved Value again. Does not
%   touch ndi.preferences or the JSON file.
    fig   = ancestor(src, 'figure');
    state = fig.UserData;
    state.pending = containers.Map('KeyType', 'int32', 'ValueType', 'any');
    fig.UserData  = state;
    refreshCurrentSelection(fig);
end


function onApply(src, ~)
%ONAPPLY Apply button callback: persist pending edits.
%
%   Iterates over every entry in fig.UserData.pending and calls
%   ndi.preferences.set for each one (which writes the JSON file).
%   On the first failure a uialert is raised and the loop aborts;
%   already-applied edits remain. After a successful run the
%   pending map is cleared, the items snapshot is refreshed from
%   the singleton, and the right pane is rebuilt so the
%   asterisk markers disappear.
    fig   = ancestor(src, 'figure');
    state = fig.UserData;
    keys  = state.pending.keys;
    for k = 1:numel(keys)
        idx  = keys{k};
        item = state.items(idx);
        try
            ndi.preferences.set(itemPath(item), state.pending(int32(idx)));
        catch ME
            uialert(fig, ...
                sprintf('Could not set %s: %s', itemPath(item), ME.message), ...
                'Apply failed');
            return
        end
    end
    state.pending = containers.Map('KeyType', 'int32', 'ValueType', 'any');
    state.items   = ndi.preferences.getSingleton().Items;
    fig.UserData  = state;
    refreshCurrentSelection(fig);
end


function onSave(src, evt)
%ONSAVE Save button callback: apply pending edits and close.
%
%   Calls onApply and, if the figure is still valid afterwards,
%   deletes it. Equivalent to Apply followed by closing the window.
    fig = ancestor(src, 'figure');
    onApply(src, evt);
    if isvalid(fig)
        delete(fig);
    end
end


function refreshCurrentSelection(fig)
%REFRESHCURRENTSELECTION Re-render the right pane for the current node.
%
%   Locates the editor's uitree by Tag and asks rebuildRightPane to
%   re-render the row for whichever node is currently selected.
%   Used after Revert/Apply to discard the previous widget set and
%   pick up the new values without changing what the user is
%   looking at.
    tree = findobj(fig, 'Tag', 'ndiPrefTree');
    if isempty(tree) || isempty(tree.SelectedNodes)
        return
    end
    rebuildRightPane(fig, tree.SelectedNodes(1));
end


function p = itemPath(item)
%ITEMPATH Build the dotted path string for a preference item.
%
%   P = ITEMPATH(ITEM) returns 'Category.Name' when Subcategory is
%   empty and 'Category.Subcategory.Name' otherwise. The result is
%   a valid argument for ndi.preferences.get/set/reset.
    if isempty(item.Subcategory)
        p = sprintf('%s.%s', item.Category, item.Name);
    else
        p = sprintf('%s.%s.%s', ...
            item.Category, item.Subcategory, item.Name);
    end
end
