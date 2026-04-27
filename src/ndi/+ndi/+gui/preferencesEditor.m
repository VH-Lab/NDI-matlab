function fig = preferencesEditor(options)
% NDI.GUI.PREFERENCESEDITOR - simple uifigure editor for ndi.preferences.
%
%   ndi.gui.preferencesEditor()                          % open the editor
%   fig = ndi.gui.preferencesEditor()                    % return handle
%   ndi.gui.preferencesEditor(Position=[x y w h])        % override geometry
%
% Layout:
%   - Left  (~30%): uitree of Categories with Subcategories as children.
%     Selecting a Category shows every item in it; selecting a
%     Subcategory shows just that subcategory.
%   - Right (~70%): scrollable list of editor widgets, one per item, with
%     each item's Description shown as a tooltip on the label and editor.
%   - Bottom: Revert | Apply | Save buttons.
%
% Buttons:
%   Revert - discard pending edits in the editor; widgets are
%            repopulated from the current ndi.preferences values.
%   Apply  - push pending edits to ndi.preferences (which persists to
%            the JSON file). Editor stays open.
%   Save   - same as Apply, then close the editor window.
%
% Pending edits live only in the editor until Apply or Save is pressed;
% nothing reaches the singleton or disk before that. A trailing '*' is
% added to the label of any item with a pending change.
%
% This is a plain uifigure built imperatively (no App Designer) so it
% launches without the .mlapp wrapper penalty. State is kept in
% fig.UserData and mutated from local-function callbacks.
%
% See also: ndi.preferences

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
        'Scrollable',  'on');

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
    prefs = ndi.preferences.getSingleton();
    state.items   = prefs.Items;
    state.pending = containers.Map('KeyType', 'int32', 'ValueType', 'any');
    state.labels  = containers.Map('KeyType', 'int32', 'ValueType', 'any');
    state.widgets = containers.Map('KeyType', 'int32', 'ValueType', 'any');
end


function populateTree(tree, items)
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
    if isempty(evt.SelectedNodes); return; end
    rebuildRightPane(ancestor(src, 'figure'), evt.SelectedNodes(1));
end


function rebuildRightPane(fig, node)
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
    fig   = ancestor(src, 'figure');
    state = fig.UserData;
    state.pending = containers.Map('KeyType', 'int32', 'ValueType', 'any');
    fig.UserData  = state;
    refreshCurrentSelection(fig);
end


function onApply(src, ~)
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
    fig = ancestor(src, 'figure');
    onApply(src, evt);
    if isvalid(fig)
        delete(fig);
    end
end


function refreshCurrentSelection(fig)
    tree = findobj(fig, 'Tag', 'ndiPrefTree');
    if isempty(tree) || isempty(tree.SelectedNodes)
        return
    end
    rebuildRightPane(fig, tree.SelectedNodes(1));
end


function p = itemPath(item)
    if isempty(item.Subcategory)
        p = sprintf('%s.%s', item.Category, item.Name);
    else
        p = sprintf('%s.%s.%s', ...
            item.Category, item.Subcategory, item.Name);
    end
end
