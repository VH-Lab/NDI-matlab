classdef ListDialog < handle
%NDI.UTIL.LISTDIALOG Modal list picker with a readable, configurable font.
%
%   A drop-in style replacement for the built-in LISTDLG whose font size is
%   configurable (and defaults to a readable 14 pt, where LISTDLG's is tiny
%   and fixed). It is built on uifigure/uilistbox and styled in the NDI
%   Cloud colour scheme (ndi.gui.cloudColors).
%
%   Convenience (blocking) use -- the LISTDLG replacement:
%       [indices, ok] = ndi.util.ListDialog.choose(items, Name, Value, ...)
%   returns the selected 1-based INDICES into ITEMS and OK = true, or []
%   and OK = false if the user cancels or closes the window.
%
%   Object use (non-blocking; construction does not wait):
%       d = ndi.util.ListDialog(items, 'Visible', 'off', ...);
%       % inspect d.ListBox / fire d.OKButton.ButtonPushedFcn, etc.
%       [indices, ok] = d.getSelection();   % blocks until OK / Cancel
%
%   Name-value options:
%       Title       - window title (default "Select").
%       Prompt      - header prompt text (default "Select an item:").
%       FontSize    - list font size in points (default 14).
%       Multiselect - allow multiple selection (default false).
%       Parent      - a figure to centre the dialog over (default [];
%                     otherwise a fixed default position is used).
%       Visible     - 'on' (default) or 'off'.
%
%   Example:
%       [idx, ok] = ndi.util.ListDialog.choose({'alpha','beta','gamma'}, ...
%           'Title', 'Pick one', 'FontSize', 16);
%
%   See also: listdlg, uilistbox, ndi.gui.cloudColors

    properties (SetAccess = private)
        Figure                              % the uifigure handle
        ListBox                             % the uilistbox handle
        OKButton                            % the OK/confirm uibutton
        CancelButton                        % the Cancel uibutton
        Items (1,:) cell = {}               % the choices, as a row cell array
        SelectedIndex double = []           % chosen 1-based index/indices
        Confirmed (1,1) logical = false     % true if OK was pressed
    end

    methods
        function obj = ListDialog(items, options)
            arguments
                items cell
                options.Title (1,1) string = "Select"
                options.Prompt (1,1) string = "Select an item:"
                options.FontSize (1,1) double {mustBePositive} = 14
                options.Multiselect (1,1) logical = false
                options.Parent = []
                options.Visible (1,1) matlab.lang.OnOffSwitchState = "on"
            end

            obj.Items = items(:)';   % normalise to a row cell array
            c = ndi.gui.cloudColors();

            w = 480; h = 420;
            pos = ndi.util.ListDialog.centeredPosition(options.Parent, w, h);

            obj.Figure = uifigure('Name', char(options.Title), ...
                'Position',    pos, ...
                'Color',       c.offWhite, ...
                'Visible',     options.Visible, ...
                'WindowStyle', 'modal', ...
                'Tag',         'ndiUtilListDialog');

            g = uigridlayout(obj.Figure, [3 1]);
            g.RowHeight       = {28, '1x', 38};
            g.ColumnWidth     = {'1x'};
            g.Padding         = [8 8 8 8];
            g.RowSpacing      = 6;
            g.BackgroundColor = c.offWhite;

            % Navy NDI Cloud header bar with white prompt text.
            hb = uigridlayout(g, [1 1]);
            hb.Padding         = [8 0 8 0];
            hb.BackgroundColor = c.darkBlue;
            uilabel(hb, 'Text', char(options.Prompt), ...
                'FontColor',         c.white, ...
                'FontWeight',        'bold', ...
                'FontSize',          14, ...
                'VerticalAlignment', 'center');

            if options.Multiselect
                ms = 'on';
            else
                ms = 'off';
            end
            obj.ListBox = uilistbox(g, 'Items', obj.Items, ...
                'Multiselect', ms, 'FontSize', options.FontSize);
            % Default to the first item so a bare OK returns a valid choice.
            if ~isempty(obj.Items)
                if options.Multiselect
                    obj.ListBox.Value = obj.Items(1);
                else
                    obj.ListBox.Value = obj.Items{1};
                end
            end

            br = uigridlayout(g, [1 3]);
            br.ColumnWidth     = {'1x', 90, 90};
            br.RowHeight       = {'1x'};
            br.Padding         = [0 0 0 0];
            br.ColumnSpacing   = 6;
            br.BackgroundColor = c.offWhite;
            uilabel(br, 'Text', '');   % left spacer
            obj.OKButton = uibutton(br, 'Text', 'OK', ...
                'ButtonPushedFcn', @(~,~) obj.onOK());
            obj.CancelButton = uibutton(br, 'Text', 'Cancel', ...
                'ButtonPushedFcn', @(~,~) obj.onCancel());
            ndi.util.ListDialog.accent(obj.OKButton, c);
            ndi.util.ListDialog.accent(obj.CancelButton, c);

            obj.Figure.CloseRequestFcn = @(~,~) obj.onCancel();
        end % constructor

        function [indices, ok] = getSelection(obj)
            %GETSELECTION Block until OK/Cancel, then return the result.
            %   [INDICES, OK] = GETSELECTION(OBJ) waits for the user to
            %   press OK or Cancel (or close the window), then returns the
            %   selected 1-based INDICES (OK = true) or [] (OK = false), and
            %   deletes the dialog window.
            if isvalid(obj.Figure)
                uiwait(obj.Figure);
            end
            indices = obj.SelectedIndex;
            ok      = obj.Confirmed;
            if ~isempty(obj.Figure) && isvalid(obj.Figure)
                delete(obj.Figure);
            end
        end % getSelection
    end % methods

    methods (Access = private)
        function onOK(obj)
            %ONOK Confirm the current selection and stop waiting.
            obj.SelectedIndex = obj.currentIndices();
            obj.Confirmed     = ~isempty(obj.SelectedIndex);
            obj.resume();
        end

        function onCancel(obj)
            %ONCANCEL Discard the selection and stop waiting.
            obj.SelectedIndex = [];
            obj.Confirmed     = false;
            obj.resume();
        end

        function resume(obj)
            %RESUME Release a pending uiwait (a no-op if none is active).
            if ~isempty(obj.Figure) && isvalid(obj.Figure)
                uiresume(obj.Figure);
            end
        end

        function idx = currentIndices(obj)
            %CURRENTINDICES Map the listbox Value back to Items indices.
            %   Labels are matched by string; callers should keep Items
            %   unique (the navigator's cloud labels embed the dataset id).
            v = obj.ListBox.Value;
            if isempty(v)
                idx = [];
                return;
            end
            if ~iscell(v)
                v = {v};
            end
            idx = [];
            for i = 1:numel(v)
                j = find(strcmp(obj.Items, v{i}), 1);
                if ~isempty(j)
                    idx(end+1) = j; %#ok<AGROW>
                end
            end
            idx = sort(idx);
        end
    end % private methods

    methods (Static)
        function [indices, ok] = choose(items, varargin)
            %CHOOSE Build the dialog, block for a choice, return the result.
            %   [INDICES, OK] = ndi.util.ListDialog.choose(ITEMS, ...) is the
            %   blocking, listdlg-style convenience entry point; it accepts
            %   the same name-value options as the constructor.
            d = ndi.util.ListDialog(items, varargin{:});
            [indices, ok] = d.getSelection();
        end
    end % static methods

    methods (Static, Access = private)
        function accent(btn, c)
            %ACCENT Style a button in the NDI Cloud accent (light-blue/navy).
            if isempty(btn) || ~isvalid(btn)
                return;
            end
            btn.BackgroundColor = c.lightBlue;
            btn.FontColor       = c.darkBlue;
            btn.FontWeight      = 'bold';
        end

        function pos = centeredPosition(parent, w, h)
            %CENTEREDPOSITION [x y w h] centred over PARENT, or a default.
            if ~isempty(parent) && isscalar(parent) && isvalid(parent)
                ppos = parent.Position;
                x = ppos(1) + (ppos(3) - w) / 2;
                y = ppos(2) + (ppos(4) - h) / 2;
            else
                x = 300;
                y = 300;
            end
            pos = [x y w h];
        end
    end % static private methods
end % classdef
