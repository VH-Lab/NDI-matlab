classdef vhNDISpikeSorter < ndi.gui.app.sessionApp
% NDI.GUI.APP.VHNDISPIKESORTER - launch the VH Lab interactive spike sorter from NDI
%
%   OBJ = ndi.gui.app.vhNDISpikeSorter(SESSION)
%
%   Opens a small window that lets the user launch the VH Lab interactive,
%   single-channel/n-trode spike sorting GUI (the vhNDISpikeSorter package in
%   vhlab-library-matlab) on the ndi.session SESSION. This app is grouped under
%   the "Spike Sorters" category in the navigator's per-session Apps menu, so it
%   appears alongside the other NDI spike sorters (e.g. ndi.gui.app.kiasort).
%
%   The VH Lab spike sorter itself (vhNDISpikeSorter.spikesorting) lives in the
%   separate vhlab-library-matlab repository and is not part of NDI. This class
%   is only a thin wrapper: it checks whether that package is on the MATLAB path
%   and, if so, offers a button that opens the existing GUI with:
%
%       vhNDISpikeSorter.spikesorting('ndiSession', SESSION)
%
%   If the package is not installed, the window explains that vhlab-library-matlab
%   must be on the path and leaves the launch button disabled.
%
%   See also: ndi.gui.app.sessionApp, ndi.gui.app.kiasort

    properties (Constant)
        Name     = "VHLab Spike Sorter"   % ndi.gui.app.sessionApp menu label
        Category = "Spike Sorters"        % grouped under this Apps submenu
    end

    % The fully-qualified name of the external package function we wrap. We keep
    % it as a string and always dispatch through feval/exist so MATLAB resolves
    % it as the top-level vhNDISpikeSorter package function rather than as a
    % (non-existent) static method of this class, which shares the leaf name.
    properties (Constant, Access = private)
        LauncherFcn = 'vhNDISpikeSorter.spikesorting'
    end

    properties (Access = private)
        session         % the ndi.session
        fig             % the uifigure
        OpenButton      % launches the existing GUI
        StatusLabel     % availability / help text
    end

    methods
        function obj = vhNDISpikeSorter(session)
            arguments
                session (1,1) ndi.session
            end
            obj.session = session;
            obj.build();
        end
    end

    methods (Access = private)
        function build(obj)
            c = ndi.gui.cloudColors();

            obj.fig = uifigure('Name', ['VHLab Spike Sorter: ' obj.session.reference], ...
                'Position', [100 100 460 200], ...
                'Color', c.darkBlue, ...
                'Tag', 'ndi.gui.app.vhNDISpikeSorter');

            root = uigridlayout(obj.fig, [3 1], ...
                'RowHeight', {30, '1x', 40}, 'ColumnWidth', {'1x'}, ...
                'RowSpacing', 10, 'Padding', [15 15 15 15], ...
                'BackgroundColor', c.darkBlue);

            title = uilabel(root, 'Text', 'VH Lab Interactive Spike Sorter', ...
                'FontSize', 16, 'FontWeight', 'bold', 'FontColor', c.white, ...
                'HorizontalAlignment', 'center');
            title.Layout.Row = 1; title.Layout.Column = 1;

            obj.StatusLabel = uilabel(root, 'Text', '', ...
                'WordWrap', 'on', 'FontColor', c.white, ...
                'HorizontalAlignment', 'center', 'VerticalAlignment', 'center');
            obj.StatusLabel.Layout.Row = 2; obj.StatusLabel.Layout.Column = 1;

            obj.OpenButton = uibutton(root, 'push', 'Text', 'Open Spike Sorter', ...
                'FontWeight', 'bold', 'BackgroundColor', c.lightBlue, 'FontColor', c.darkBlue, ...
                'Tooltip', 'Open the VH Lab spike sorting GUI for this session', ...
                'ButtonPushedFcn', @(~,~) obj.openSorter());
            obj.OpenButton.Layout.Row = 3; obj.OpenButton.Layout.Column = 1;

            obj.refreshAvailability();
        end

        function tf = isAvailable(~)
            % True if the vhNDISpikeSorter package (vhlab-library-matlab) is on
            % the path. The string is resolved globally, so it finds the
            % top-level package function, not this class.
            tf = exist(ndi.gui.app.vhNDISpikeSorter.LauncherFcn, 'file') == 2;
        end

        function refreshAvailability(obj)
            if obj.isAvailable()
                obj.StatusLabel.Text = ['The VH Lab interactive spike sorter is available. ' ...
                    'Click below to open it for this session.'];
                obj.OpenButton.Enable = 'on';
            else
                obj.StatusLabel.Text = ['The VH Lab spike sorter (vhNDISpikeSorter) was not ' ...
                    'found on the MATLAB path. Install / add vhlab-library-matlab to use it.'];
                obj.OpenButton.Enable = 'off';
            end
        end

        function openSorter(obj)
            % Re-check in case the path changed while the window was open.
            if ~obj.isAvailable()
                obj.refreshAvailability();
                uialert(obj.fig, ['The vhNDISpikeSorter package is not on the MATLAB path. ' ...
                    'Add vhlab-library-matlab and try again.'], 'Spike sorter not found');
                return;
            end
            try
                feval(ndi.gui.app.vhNDISpikeSorter.LauncherFcn, 'ndiSession', obj.session);
            catch e
                uialert(obj.fig, e.message, 'Could not open the VH Lab spike sorter');
            end
        end
    end
end
