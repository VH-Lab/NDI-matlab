classdef datasetsPane < ndi.gui.nav.pane
%NDI.GUI.NAV.DATASETSPANE Collapsible, resizable "Datasets" pane.
%
%   The Datasets pane can be collapsed to its header row via the header
%   disclosure triangle. Its header also carries a right-justified "Paths"
%   button for editing the dataset search path (a placeholder in v1).
%
%   The body is a scrollable uitree. Its top-level nodes are datasets:
%       * The first node is always "Unaffiliated"; its children are the
%         ndi.session objects found in the user's base workspace.
%       * The remaining nodes are the ndi.dataset objects found in the
%         base workspace plus any datasets discovered on the dataset
%         search path (path discovery is a v1 stub). Each is labelled by
%         its reference; expanding it lists the sessions returned by the
%         dataset's session_list method.
%
%   Each dataset node carries the uitree's native disclosure triangle, so
%   the user can expand a dataset to reveal its sessions. When engaged the
%   pane is never shorter than MinHeight (100 px) and can be resized by
%   dragging its lower edge (see ndi.gui.navigator).
%
%   See also: ndi.gui.navigator, ndi.gui.nav.pane, ndi.dataset, ndi.session

    properties (SetAccess = protected)
        Resizable (1,1) logical = true   % navigator honours drag-to-resize
        Tree                             % uitree in the body
        Grip                             % thin panel marking the draggable edge
    end

    properties (Constant, Access = private)
        GripHeight = 6                   % pixels of the drag grip at the bottom
    end

    methods
        function obj = datasetsPane(navigator)
            obj@ndi.gui.nav.pane(navigator, ...
                'Title',       'Datasets', ...
                'Collapsible', true, ...
                'Engaged',     true, ...
                'MinHeight',   100, ...
                'Height',      220);
        end

        function tf = HasBody(~)
            tf = true;
        end

        function refresh(obj)
            obj.populateTree();
        end
    end

    methods (Access = protected)
        function buildBody(obj, container)
            % A scrollable tree fills the body; a thin grip at the bottom
            % marks the edge the user drags to resize the pane.
            container.RowHeight  = {'1x', obj.GripHeight};
            container.RowSpacing = 0;

            obj.Tree = uitree(container);
            obj.Tree.Layout.Row    = 1;
            obj.Tree.Layout.Column = 1;

            obj.Grip = uipanel(container, ...
                'BorderType',      'none', ...
                'BackgroundColor', [0.80 0.80 0.80]);
            obj.Grip.Layout.Row    = 2;
            obj.Grip.Layout.Column = 1;

            obj.populateTree();
        end

        function buildHeaderRight(obj, parent)
            btn = uibutton(parent, ...
                'Text',            'Paths', ...
                'ButtonPushedFcn', @(~,~) obj.openPathsEditor());
            btn.Layout.Row    = 1;
            btn.Layout.Column = 3;
        end

        function w = rightWidth(~)
            w = 60;
        end
    end

    methods (Access = private)
        function populateTree(obj)
            %POPULATETREE Rebuild the dataset/session tree from the model.
            if isempty(obj.Tree) || ~isvalid(obj.Tree)
                return;
            end
            delete(obj.Tree.Children);

            % --- Unaffiliated: ndi.session objects in the base workspace ---
            unaffiliated = uitreenode(obj.Tree, ...
                'Text',     'Unaffiliated', ...
                'NodeData', struct('kind', 'dataset', 'name', 'Unaffiliated'));
            sessions = obj.scanWorkspace('ndi.session');
            for i = 1:numel(sessions)
                uitreenode(unaffiliated, ...
                    'Text',     obj.sessionLabel(sessions{i}), ...
                    'NodeData', struct('kind', 'session'));
            end

            % --- Datasets: ndi.dataset objects on the search path + workspace ---
            datasets = [obj.searchPathDatasets(), obj.scanWorkspace('ndi.dataset')];
            for i = 1:numel(datasets)
                ds       = datasets{i};
                node = uitreenode(obj.Tree, ...
                    'Text',     obj.datasetLabel(ds), ...
                    'NodeData', struct('kind', 'dataset'));
                obj.addSessionChildren(node, ds);
            end
        end

        function addSessionChildren(~, node, ds)
            %ADDSESSIONCHILDREN Add one child node per session in a dataset.
            try
                refList = ds.session_list();
            catch
                refList = {};
            end
            for k = 1:numel(refList)
                ref = refList{k};
                if isempty(ref); ref = '(unnamed session)'; end
                uitreenode(node, ...
                    'Text',     char(ref), ...
                    'NodeData', struct('kind', 'session'));
            end
        end

        function openPathsEditor(obj)
            %OPENPATHSEDITOR Placeholder window for editing search paths.
            f = uifigure('Name', 'Dataset Search Paths', ...
                'Position', [150 150 380 160], ...
                'Tag',      'ndiNavigatorDatasetPaths');
            g = uigridlayout(f, [1 1]);
            uilabel(g, ...
                'Text', ['Dataset search-path editor (placeholder).' newline ...
                         'This will let you set where the navigator looks' newline ...
                         'for datasets.'], ...
                'HorizontalAlignment', 'center', ...
                'VerticalAlignment',   'center');
            % Reference obj so future versions can push paths back into the
            % pane; unused today but keeps the callback signature stable.
            f.UserData = obj;
        end
    end

    methods (Access = private, Static)
        function objs = scanWorkspace(className)
            %SCANWORKSPACE Objects in the base workspace that isa CLASSNAME.
            %   Returns a cell array of the matching variable values from
            %   the MATLAB base workspace (the "user's workspace").
            objs = {};
            try
                vars = evalin('base', 'whos');
            catch
                return;
            end
            for i = 1:numel(vars)
                try
                    value = evalin('base', vars(i).name);
                catch
                    continue;
                end
                if isscalar(value) && isa(value, className)
                    objs{end+1} = value; %#ok<AGROW>
                end
            end
        end

        function datasets = searchPathDatasets()
            %SEARCHPATHDATASETS Datasets discovered on the search path.
            %   v1 stub: search-path discovery is configured through the
            %   Paths editor (a placeholder today), so nothing is returned
            %   yet. Kept as a seam for later implementation.
            datasets = {};
        end

        function label = datasetLabel(ds)
            %DATASETLABEL Human-readable reference for a dataset node.
            try
                label = char(ds.reference());
            catch
                label = class(ds);
            end
            if isempty(label)
                label = '(unnamed dataset)';
            end
        end

        function label = sessionLabel(s)
            %SESSIONLABEL Human-readable reference for a session node.
            try
                label = char(s.reference);
            catch
                label = class(s);
            end
            if isempty(label)
                label = '(unnamed session)';
            end
        end
    end
end
