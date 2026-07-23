classdef pyraview < ndi.gui.app.sessionApp
% NDI.GUI.APP.PYRAVIEW - Signal viewer for NDI-matlab
%
%   OBJ = ndi.gui.app.pyraview(SESSION)
%
%   Opens a signal viewer for the ndi.session SESSION. The window shows the
%   continuous data for a chosen probe, epoch and filter band, with
%   pan/zoom scrollbars and an optional spiking-units panel that overlays
%   spike ticks on the traces and shows unit waveforms on the side.
%
%   This is a session GUI app (see ndi.gui.app.sessionApp): its constructor
%   takes the ndi.session as its first argument, so it can be launched from
%   the ndi.gui.navigator "Apps" menu.
%
%   See also: ndi.gui.app.sessionApp, ndi.gui.navigator, ndi.session

    properties (Constant)
        Name = "pyraview"   % ndi.gui.app.sessionApp menu label
    end

    properties (Access = private)
        session                    % the ndi.session being viewed
        fig                        % the figure
        mainAxes                   % main trace axes
        spikingAxes                % spiking waveform axes
        probes = {}                % cell array of ndi.probe.timeseries.mfdaq probes

        current_doc = []           % pyraview document for the current view
        epoch_t0 = 0               % epoch start time (s)
        epoch_t1 = 0               % epoch end time (s)
        current_data_t0 = -Inf     % start of the loaded data buffer
        current_data_t1 = -Inf     % end of the loaded data buffer
        current_data = []          % loaded data
        current_time = []          % loaded time vector
        current_level = []         % loaded decimation level
        loaded_pixel_span = 0      % pixel span used for the last load
        loaded_view_duration = Inf % duration used for the last load
        view_t0 = 0                % start of the current view (s)
        view_duration = 1          % duration of the current view (s)
        channel_y_spacing = 100    % vertical spacing between channels
        first_plot = true          % true until the first plot of a dataset
        split_position = 0.8       % main/spiking split fraction
        dragging = false           % true while the split bar is dragged
        last_mode = ''             % pan/zoom mode saved during a drag
        spiking_epochid = ''       % epoch id for lazy spike-time reads

        % Spiking unit information (struct array). Kept as a property; on a
        % handle object this is accessed by reference, so it is not copied on
        % the pan/zoom hot path (the reason the function version stashed it in
        % appdata instead of the figure UserData).
        spiking_info
    end

    methods
        function obj = pyraview(session)
            arguments
                session (1,1) ndi.session
            end
            obj.session      = session;
            obj.spiking_info = obj.emptySpikingInfo();
            obj.build();
        end
    end

    methods (Access = private)
        function build(obj)
            % Build the figure, controls, axes and callbacks.
            session = obj.session;

            obj.fig = figure('Name', ['pyraview: ' session.reference], ...
                'NumberTitle', 'off', ...
                'MenuBar', 'none', ...
                'Tag', 'ndi.gui.app.pyraview', ...
                'Visible', 'on');
            fig = obj.fig;

            % Controls dispatch by their Tag through controlCallback.
            callback = @(src, ~) obj.controlCallback(src);

            % Store the app on the figure for external access / debugging.
            set(fig, 'UserData', obj);

            % Dropdown: Probe
            uicontrol(fig, 'Style', 'text', 'String', 'Probe:', ...
                'Units', 'pixels', 'Position', [10 10 50 20], ...
                'HorizontalAlignment', 'left', 'Tag', 'ProbeText', ...
                'FontWeight', 'bold', 'FontSize', 14);

            % Show every multifunction-DAQ timeseries probe (n-trode, patch,
            % sharp, ecg, eeg, ppg, accelerometer, etc.), i.e. anything that
            % is an ndi.probe.timeseries.mfdaq. Stimulator and image probes are
            % siblings of mfdaq under ndi.probe.timeseries and are excluded by
            % the isa() test.
            allprobes = session.getprobes();
            probes = allprobes(cellfun(@(p) isa(p, 'ndi.probe.timeseries.mfdaq'), allprobes));
            probe_strings = {};
            for i = 1:numel(probes)
                probe_strings{end+1} = probes{i}.elementstring(); %#ok<AGROW>
            end
            if isempty(probe_strings)
                probe_strings = {'No probes found'};
            end

            obj.probes = probes;

            uicontrol(fig, 'Style', 'popupmenu', 'String', probe_strings, ...
                'Units', 'pixels', 'Position', [10 10 200 20], ...
                'Tag', 'ProbeMenu', 'Callback', callback, 'Value', 1, ...
                'FontSize', 14);

            % Dropdown: Epoch
            uicontrol(fig, 'Style', 'text', 'String', 'epoch_id:', ...
                'Units', 'pixels', 'Position', [10 10 60 20], ...
                'HorizontalAlignment', 'left', 'Tag', 'EpochText', ...
                'FontWeight', 'bold', 'FontSize', 14);

            uicontrol(fig, 'Style', 'popupmenu', 'String', {' '}, ...
                'Units', 'pixels', 'Position', [10 10 200 20], ...
                'Tag', 'EpochMenu', 'Callback', callback, 'Value', 1, ...
                'FontSize', 14);

            % Dropdown: Band
            uicontrol(fig, 'Style', 'text', 'String', 'band:', ...
                'Units', 'pixels', 'Position', [10 10 40 20], ...
                'HorizontalAlignment', 'left', 'Tag', 'BandText', ...
                'FontWeight', 'bold', 'FontSize', 14);

            uicontrol(fig, 'Style', 'popupmenu', 'String', {'low', 'high', 'all'}, ...
                'Units', 'pixels', 'Position', [10 10 80 20], ...
                'Tag', 'BandMenu', 'Callback', callback, 'Value', 2, ...
                'FontSize', 14); % Default high ('all' passes unfiltered data)

            % Edit: Channel Spacing
            uicontrol(fig, 'Style', 'text', 'String', 'Spacing:', ...
                'Units', 'pixels', 'Position', [10 10 60 20], ...
                'HorizontalAlignment', 'left', 'Tag', 'SpacingText', ...
                'FontWeight', 'bold', 'FontSize', 14);

            uicontrol(fig, 'Style', 'edit', 'String', '100', ...
                'Units', 'pixels', 'Position', [10 10 50 20], ...
                'Tag', 'SpacingEdit', 'Callback', callback, ...
                'FontSize', 14);

            % Mapping
            uicontrol(fig, 'Style', 'text', 'String', 'Mapping:', ...
                'Units', 'pixels', 'Position', [10 10 60 20], ...
                'HorizontalAlignment', 'left', 'Tag', 'MappingText', ...
                'FontWeight', 'bold', 'FontSize', 14);

            uicontrol(fig, 'Style', 'popupmenu', 'String', {'raw', 'PlexonSV'}, ...
                'Units', 'pixels', 'Position', [10 10 100 20], ...
                'Tag', 'MappingMenu', 'Callback', callback, 'Value', 1, ...
                'FontSize', 14);

            % Checkbox: Show spiking units
            uicontrol(fig, 'Style', 'checkbox', 'String', 'Show spiking units', ...
                'Units', 'pixels', 'Position', [10 10 200 20], ...
                'Tag', 'SpikingCheckbox', 'Callback', callback, ...
                'FontWeight', 'bold', 'FontSize', 14, 'Value', 0);

            % Separator Line (using uipanel as line)
            uipanel(fig, 'Units', 'pixels', 'Position', [0 0 100 1], 'Tag', 'SeparatorLine', ...
                'BorderType', 'line', 'HighlightColor', [0 0 0]);

            % Main Frame (uipanel)
            frame_panel = uipanel(fig, 'Title', '', 'Units', 'pixels', ...
                'Position', [10 10 100 100], 'Tag', 'MainFrame');

            % Axes
            ax = axes('Parent', frame_panel, 'Units', 'normalized', ...
                'Position', [0 0 1 1], 'Tag', 'MainAxes');
            xlabel(ax, 'Time (s)');
            obj.mainAxes = ax;

            % Spiking Units Frame
            sf = uipanel(fig, 'Title', '', 'Units', 'pixels', ...
                'Position', [10 10 100 100], 'Tag', 'SpikingFrame', 'Visible', 'off');

            % Split Dragger (visible only when Spiking is on)
            uicontrol(fig, 'Style', 'text', 'String', '', ...
                'Units', 'pixels', 'Position', [0 0 5 100], ...
                'Tag', 'SplitDragger', 'BackgroundColor', [0.8 0.8 0.8], ...
                'Enable', 'inactive', 'ButtonDownFcn', @(src, ev) obj.startDrag(src), ...
                'Visible', 'off');

            % Spiking Axes
            sax = axes('Parent', sf, 'Units', 'normalized', ...
                'Position', [0 0 0.6 1], 'Tag', 'SpikingAxes');
            obj.spikingAxes = sax;

            % Waveform X-axis buttons (positions set in onResize)
            uicontrol(sf, 'Style', 'pushbutton', 'String', 'Reset X', ...
                'Units', 'normalized', 'Position', [0.12 0.01 0.22 0.05], ...
                'Tag', 'SpikingWaveResetX', 'Callback', callback);
            uicontrol(sf, 'Style', 'pushbutton', 'String', 'Zoom', ...
                'Units', 'normalized', 'Position', [0.37 0.01 0.22 0.05], ...
                'Tag', 'SpikingWaveZoom', 'Callback', callback);

            % Spiking Title
            uicontrol(sf, 'Style', 'text', 'String', 'Spiking neurons', ...
                'Units', 'normalized', 'Position', [0.6 0.9 0.4 0.1], ...
                'Tag', 'SpikingTitle', 'FontWeight', 'bold');

            % Sort checkbox: by max channel location (else by name). On by default.
            uicontrol(sf, 'Style', 'checkbox', 'String', 'Sort by max channel', ...
                'Units', 'normalized', 'Position', [0.62 0.86 0.38 0.05], ...
                'Tag', 'SpikingSortCheckbox', 'Callback', callback, 'Value', 1);

            % Show-box checkbox: draw a channel-extent box around each spike
            uicontrol(sf, 'Style', 'checkbox', 'String', 'Show box', ...
                'Units', 'normalized', 'Position', [0.62 0.80 0.38 0.05], ...
                'Tag', 'SpikingBoxCheckbox', 'Callback', callback, 'Value', 0);

            % Spiking Listbox
            uicontrol(sf, 'Style', 'listbox', 'String', {}, ...
                'Units', 'normalized', 'Position', [0.6 0 0.4 0.79], ...
                'Tag', 'SpikingList', 'Callback', callback);

            % Link Y Axes
            linkaxes([ax, sax], 'y');

            % Setup zoom/pan callbacks on axes
            z = zoom(fig);
            z.ActionPostCallback = @(src, event) obj.onZoomPan();
            p = pan(fig);
            p.ActionPostCallback = @(src, event) obj.onZoomPan();

            % Scrollbar 1 (Top) - Pan
            s1 = uicontrol(frame_panel, 'Style', 'slider', 'Units', 'normalized', ...
                'Position', [0 0 1 1], ...
                'Tag', 'Scroll1', 'Callback', callback, ...
                'Min', 0, 'Max', 1, 'Value', 0, 'SliderStep', [0.01, 0.1]);
            addlistener(s1, 'ContinuousValueChange', @(src, ev) obj.controlCallback(src));

            % Scrollbar 2 (Bottom) - Zoom
            s2 = uicontrol(frame_panel, 'Style', 'slider', 'Units', 'normalized', ...
                'Position', [0 0 1 1], ...
                'Tag', 'Scroll2', 'Callback', callback, ...
                'Min', 0, 'Max', 1, 'Value', 0.5, 'SliderStep', [1/200, 10/200]);
            addlistener(s2, 'ContinuousValueChange', @(src, ev) obj.controlCallback(src));

            % Buttons: Reset X / Reset Y
            uicontrol(frame_panel, 'Style', 'pushbutton', 'String', 'Reset X', ...
                'Units', 'normalized', 'Position', [0.6 0.05 0.1 0.05], ...
                'Tag', 'ResetXButton', 'Callback', callback);

            uicontrol(frame_panel, 'Style', 'pushbutton', 'String', 'Reset Y', ...
                'Units', 'normalized', 'Position', [0.7 0.05 0.1 0.05], ...
                'Tag', 'ResetYButton', 'Callback', callback);

            % Toggle Buttons: Pan / Zoom
            uicontrol(frame_panel, 'Style', 'togglebutton', 'String', 'Pan', ...
                'Units', 'normalized', 'Position', [0.8 0.05 0.1 0.05], ...
                'Tag', 'PanButton', 'Callback', callback, 'Value', 1); % Default Pan

            uicontrol(frame_panel, 'Style', 'togglebutton', 'String', 'Zoom', ...
                'Units', 'normalized', 'Position', [0.9 0.05 0.1 0.05], ...
                'Tag', 'ZoomButton', 'Callback', callback, 'Value', 0);

            set(fig, 'SizeChangedFcn', @(src, event) obj.onResize());

            % Activate Pan mode initially
            pan(fig, 'on'); zoom(fig, 'off');

            % Trigger initial layout and update
            obj.update_epoch_list();
            obj.onResize();
        end

        function controlCallback(obj, src)
            % Dispatch a control by its Tag, then refresh (rate-limited).
            obj.dispatch(get(src, 'Tag'));
            drawnow limitrate;
        end

        function dispatch(obj, command)
            fig = obj.fig;
            switch command
                case 'ProbeMenu'
                    obj.update_epoch_list();
                    obj.check_and_load();
                case 'EpochMenu'
                    obj.check_and_load();
                case 'BandMenu'
                    obj.check_and_load();
                case 'SpacingEdit'
                    obj.update_spacing();
                case 'MappingMenu'
                    obj.plot_data();
                case 'SpikingCheckbox'
                    obj.onResize();
                    val = get(findobj(fig, 'Tag', 'SpikingCheckbox'), 'Value');
                    if val
                        pm = findobj(fig, 'Tag', 'ProbeMenu');
                        probe_idx = get(pm, 'Value');

                        em = findobj(fig, 'Tag', 'EpochMenu');
                        epoch_strs = get(em, 'String');
                        epoch_val = get(em, 'Value');
                        epoch_str = '';
                        if ~isempty(epoch_strs) && epoch_val <= numel(epoch_strs)
                            epoch_str = epoch_strs{epoch_val};
                        end

                        if ~isempty(obj.probes) && probe_idx <= numel(obj.probes) && ~strcmp(epoch_str, ' ')
                            probe = obj.probes{probe_idx};

                            % Colors are assigned in sort_spiking_info (via
                            % update_spiking_list_ui) so every load path is covered.
                            spiking_info = ndi.gui.app.pyraview.load_spiking_neurons(obj.session, probe, epoch_str);

                            obj.spiking_epochid = epoch_str; % needed for lazy spike-time reads
                            obj.spiking_info = spiking_info;
                            obj.update_spiking_list_ui();
                        end
                    else
                        % Hiding the spiking panel: remove the tick layer too.
                        delete(findobj(obj.mainAxes, 'Tag', 'SpikeTick'));
                    end
                case 'SpikingList'
                    obj.ensure_spike_times_loaded(); % load times for newly selected units
                    obj.update_spiking_plot();       % waveform side panel
                    obj.update_spike_overlay();      % spike tick layer in main axes
                case 'SpikingSortCheckbox'
                    obj.apply_spiking_sort();
                case 'SpikingBoxCheckbox'
                    obj.update_spike_overlay(); % redraw ticks with/without boxes
                case 'SpikingWaveResetX'
                    obj.waveform_reset_x();
                case 'SpikingWaveZoom'
                    obj.waveform_zoom_x();
                case 'Scroll1' % Pan
                    obj.update_from_scrollbars('Scroll1');
                case 'Scroll2' % Zoom
                    obj.update_from_scrollbars('Scroll2');
                case 'ResetXButton'
                    obj.view_t0 = obj.epoch_t0;
                    obj.view_duration = obj.epoch_t1 - obj.epoch_t0;
                    obj.update_scrollbars();
                    obj.update_view();
                case 'ResetYButton'
                    axis(obj.mainAxes, 'auto y');
                    obj.first_plot = true;
                case 'PanButton'
                    set(findobj(fig, 'Tag', 'PanButton'), 'Value', 1);
                    set(findobj(fig, 'Tag', 'ZoomButton'), 'Value', 0);
                    pan(fig, 'on'); zoom(fig, 'off');
                case 'ZoomButton'
                    set(findobj(fig, 'Tag', 'PanButton'), 'Value', 0);
                    set(findobj(fig, 'Tag', 'ZoomButton'), 'Value', 1);
                    zoom(fig, 'on'); pan(fig, 'off');
            end
        end

        function startDrag(obj, ~)
            fig = obj.fig;
            obj.dragging = true;

            % Disable Pan/Zoom temporarily to allow drag
            p = pan(fig);
            z = zoom(fig);

            obj.last_mode = '';
            if strcmp(p.Enable, 'on')
                obj.last_mode = 'pan';
                pan(fig, 'off');
            elseif strcmp(z.Enable, 'on')
                obj.last_mode = 'zoom';
                zoom(fig, 'off');
            end

            set(fig, 'WindowButtonMotionFcn', @(s, e) obj.dragSplit());
            set(fig, 'WindowButtonUpFcn', @(s, e) obj.stopDrag());
        end

        function dragSplit(obj)
            fig = obj.fig;
            if ~obj.dragging, return; end

            pos = get(fig, 'CurrentPoint');
            fig_pos = get(fig, 'Position');
            width = fig_pos(3);

            % Calculate ratio (CurrentPoint is relative to bottom-left)
            ratio = pos(1) / width;

            % Clamp
            ratio = max(0.2, min(0.9, ratio));

            obj.split_position = ratio;
            obj.onResize();
        end

        function stopDrag(obj)
            fig = obj.fig;
            obj.dragging = false;

            % Clear callbacks FIRST
            set(fig, 'WindowButtonMotionFcn', '');
            set(fig, 'WindowButtonUpFcn', '');

            % Restore mode SECOND
            if strcmp(obj.last_mode, 'pan')
                pan(fig, 'on');
            elseif strcmp(obj.last_mode, 'zoom')
                zoom(fig, 'on');
            end
        end

        function update_epoch_list(obj)
            fig = obj.fig;
            % Get selected probe
            pm = findobj(fig, 'Tag', 'ProbeMenu');
            val = get(pm, 'Value');
            probes = obj.probes;

            if isempty(probes)
                return;
            end

            if val > numel(probes)
                val = 1;
                set(pm, 'Value', 1);
            end

            selected_probe = probes{val};
            et = selected_probe.epochtable();
            epoch_ids = {et.epoch_id};

            epoch_list = [{' '}, epoch_ids];

            em = findobj(fig, 'Tag', 'EpochMenu');
            set(em, 'String', epoch_list, 'Value', 1);
        end

        function check_and_load(obj)
            fig = obj.fig;

            pm = findobj(fig, 'Tag', 'ProbeMenu');
            probe_idx = get(pm, 'Value');
            if isempty(obj.probes) || probe_idx > numel(obj.probes)
                return;
            end
            probe = obj.probes{probe_idx};

            em = findobj(fig, 'Tag', 'EpochMenu');
            epoch_strs = get(em, 'String');
            epoch_val = get(em, 'Value');
            if epoch_val < 1 || epoch_val > numel(epoch_strs)
                return;
            end
            epoch_str = epoch_strs{epoch_val};

            if strcmp(epoch_str, ' ')
                return;
            end

            bm = findobj(fig, 'Tag', 'BandMenu');
            band_strs = get(bm, 'String');
            band_val = get(bm, 'Value');
            band_str = band_strs{band_val};

            doc = [];
            if ~isempty(obj.current_doc)
                try
                    doc_props = obj.current_doc.document_properties;
                    match_epoch = strcmp(doc_props.epochid.epochid, epoch_str);
                    % Match on the filter label, which carries the user-facing
                    % band ('low', 'high', 'all') for every band; filter.type is
                    % the schema vocabulary ('low', 'high', 'none') and is 'none'
                    % for the unfiltered 'all' band.
                    if isfield(doc_props, 'filter') && isfield(doc_props.filter, 'label')
                        match_band = strcmp(doc_props.filter.label, band_str);
                    else
                        match_band = false;
                    end
                    match_element = strcmp(obj.current_doc.dependency_value('element_id'), probe.id());

                    if match_epoch && match_band && match_element
                        doc = obj.current_doc;
                        disp('Using cached document from memory.');
                    end
                catch
                end
            end

            if isempty(doc)
                session = obj.session;
                q1 = ndi.query('', 'isa', 'pyraview');
                q2 = ndi.query('', 'depends_on', 'element_id', probe.id());
                q3 = ndi.query('epochid.epochid', 'exact_string', epoch_str);
                q4 = ndi.query('filter.label', 'exact_string', band_str);
                q = q1 & q2 & q3 & q4;
                docs = session.database_search(q);

                if isempty(docs)
                    disp('Document not found, creating...');
                    try
                        doc = ndi.gui.app.pyraview.makePyraviewDoc(probe, epoch_str, band_str);
                        disp(['Created document with id: ' doc.id()]);
                    catch e
                        disp(['Error creating document: ' e.message]);
                        return;
                    end
                else
                    disp('Document found.');
                    doc = docs{1};
                end
            end

            obj.current_doc = doc;

            try
                t0_t1 = doc.document_properties.epochclocktimes.t0_t1;
                obj.epoch_t0 = t0_t1(1);
                obj.epoch_t1 = t0_t1(2);
            catch
                obj.epoch_t0 = 0; obj.epoch_t1 = 100;
            end

            full_dur = obj.epoch_t1 - obj.epoch_t0;
            obj.view_duration = min(10, full_dur);
            obj.view_t0 = obj.epoch_t0;

            obj.current_data_t0 = -Inf;
            obj.current_data_t1 = -Inf;
            obj.loaded_pixel_span = 0;
            obj.loaded_view_duration = Inf;
            obj.first_plot = true; % Reset Y-axis scale on new data

            obj.update_scrollbars();
            obj.update_view();

            % Check for spiking
            cb = findobj(fig, 'Tag', 'SpikingCheckbox');
            if get(cb, 'Value')
                si = ndi.gui.app.pyraview.load_spiking_neurons(obj.session, probe, epoch_str);
                obj.spiking_epochid = epoch_str; % needed for lazy spike-time reads
                obj.spiking_info = si;
                obj.update_spiking_list_ui();
            end
        end

        function update_spiking_list_ui(obj)
            fig = obj.fig;
            % Sort the units according to the sort checkbox before displaying them.
            cb = findobj(fig, 'Tag', 'SpikingSortCheckbox');
            by_channel = ~isempty(cb) && get(cb, 'Value') == 1;
            spiking_info = obj.sort_spiking_info(obj.spiking_info, by_channel);
            obj.spiking_info = spiking_info;

            strs = {spiking_info.label};

            lb = findobj(fig, 'Tag', 'SpikingList');
            set(lb, 'String', strs);
            set(lb, 'Max', max(2, numel(strs))); % Allow multiple selection

            % Default the units to off when there are many of them. Loading and
            % plotting spike times happens lazily on selection, so leaving a large
            % population unselected keeps opening the panel fast.
            if isempty(strs) || numel(strs) > 20
                set(lb, 'Value', []);
            else
                set(lb, 'Value', 1:numel(strs));
            end

            obj.ensure_spike_times_loaded(); % read times for any default-selected units
            obj.update_spiking_plot();       % waveform side panel
            obj.update_spike_overlay();      % spike tick layer in main axes
        end

        function apply_spiking_sort(obj)
            fig = obj.fig;
            % Re-sort the unit list when the sort checkbox is toggled, preserving the
            % current selection (matched by element id since indices change on sort).
            si = obj.spiking_info;
            if isempty(si)
                return;
            end

            lb = findobj(fig, 'Tag', 'SpikingList');
            sel = get(lb, 'Value');
            sel_ids = {};
            for k = 1:numel(sel)
                if sel(k) <= numel(si)
                    sel_ids{end+1} = si(sel(k)).element_doc.id(); %#ok<AGROW>
                end
            end

            cb = findobj(fig, 'Tag', 'SpikingSortCheckbox');
            by_channel = ~isempty(cb) && get(cb, 'Value') == 1;
            si = obj.sort_spiking_info(si, by_channel);
            obj.spiking_info = si;

            % Restore selection by element id.
            new_sel = [];
            for k = 1:numel(si)
                if any(strcmp(si(k).element_doc.id(), sel_ids))
                    new_sel(end+1) = k; %#ok<AGROW>
                end
            end
            set(lb, 'String', {si.label});
            set(lb, 'Max', max(2, numel(si)));
            set(lb, 'Value', new_sel);

            obj.ensure_spike_times_loaded();
            obj.update_spiking_plot();
            obj.update_spike_overlay();
        end

        function ensure_spike_times_loaded(obj)
            fig = obj.fig;
            % Lazily construct the element object and read spike times for the
            % currently selected units, caching both so each unit is built/read at
            % most once.
            si = obj.spiking_info;
            if isempty(si)
                return;
            end

            if isempty(obj.spiking_epochid)
                return;
            end
            epochid = obj.spiking_epochid;

            lb = findobj(fig, 'Tag', 'SpikingList');
            sel = get(lb, 'Value');

            % Determine which selected units still need their object built and spike
            % times read, so the progress bar is shown only when there is real work.
            needIdx = [];
            for k = 1:numel(sel)
                idx = sel(k);
                if idx > numel(si), continue; end
                if isfield(si, 'times_loaded') && si(idx).times_loaded
                    continue;
                end
                needIdx(end+1) = idx; %#ok<AGROW>
            end

            if isempty(needIdx)
                return;
            end

            % Progress bar: units are read one at a time (object construction +
            % readtimeseries) and this can be slow for many newly selected units.
            pb_fig = figure('Name', 'Loading Spiking Neurons', 'NumberTitle', 'off', ...
                'MenuBar', 'none', 'ToolBar', 'none', 'Resize', 'off', ...
                'Position', [500 500 520 80]);
            pb = ndi.gui.component.NDIProgressBar('Parent', pb_fig, ...
                'Message', 'Loading...', 'Text', 'Loading spike times...');
            cleanupObj = onCleanup(@() delete(pb_fig)); %#ok<NASGU>

            nNeed = numel(needIdx);
            for k = 1:nNeed
                idx = needIdx(k);

                pb.Value = k / nNeed;
                pb.Message = sprintf('Loading unit %d of %d...', k, nNeed);
                drawnow;

                % Build the element object on first use (deferred from load time).
                if isempty(si(idx).element_obj)
                    try
                        si(idx).element_obj = ndi.database.fun.ndi_document2ndi_object(...
                            si(idx).element_doc, obj.session);
                    catch
                        si(idx).element_obj = [];
                    end
                end

                try
                    [~, t] = si(idx).element_obj.readtimeseries(epochid, -Inf, Inf);
                    si(idx).spike_times = t;
                catch
                    si(idx).spike_times = [];
                end
                si(idx).times_loaded = true;
            end

            obj.spiking_info = si;
        end

        function update_spiking_plot(obj)
            fig = obj.fig;
            lb = findobj(fig, 'Tag', 'SpikingList');

            selectedIdx = get(lb, 'Value');
            spiking_info = obj.spiking_info;

            sax = obj.spikingAxes;
            cla(sax);

            if isempty(selectedIdx) || isempty(spiking_info)
                return;
            end

            spacing = obj.channel_y_spacing;

            % Accumulate every waveform's line segments grouped by color, then draw
            % one plot() per color. NaN rows separate channels and neurons so a
            % whole color group is a single line object.
            color_keys = {};  % unique color key strings
            color_vals = {};  % actual color value per key
            X_by_color = {};  % accumulated X column per key
            Y_by_color = {};  % accumulated Y column per key
            text_labels = struct('x', {}, 'y_top', {}, 'y_bot', {}, 'str', {});

            % Loop through selected
            for k = 1:numel(selectedIdx)
                idx = selectedIdx(k);
                if idx > numel(spiking_info), continue; end

                info = spiking_info(idx);
                doc = info.neuron_doc;

                if isempty(doc) || ~isfield(doc.document_properties, 'neuron_extracellular') || ...
                        ~isfield(doc.document_properties.neuron_extracellular, 'mean_waveform')
                    continue;
                end

                waveform = doc.document_properties.neuron_extracellular.mean_waveform; % N x C
                [numSamples, numChannels] = size(waveform);

                % Normalize X to 0..1 for this neuron slot k
                % k corresponds to x-range [k-1+0.25, k-1+0.75]
                t = linspace(-0.25, 0.25, numSamples)';
                t_shifted = idx + t;

                color = 'k';
                if isfield(info, 'color') && ~isempty(info.color)
                    color = info.color;
                end

                % Resolve the color group for this neuron
                if ischar(color)
                    key = color;
                else
                    key = mat2str(color);
                end
                ci = find(strcmp(color_keys, key), 1);
                if isempty(ci)
                    color_keys{end+1} = key; %#ok<AGROW>
                    color_vals{end+1} = color; %#ok<AGROW>
                    X_by_color{end+1} = []; %#ok<AGROW>
                    Y_by_color{end+1} = []; %#ok<AGROW>
                    ci = numel(color_keys);
                end

                % Build all channels at once: each column is a channel, with a
                % trailing NaN row so channels/neurons are not connected.
                offsets = (0:numChannels-1) * spacing;           % 1 x C
                Xblock = [repmat(t_shifted, 1, numChannels); nan(1, numChannels)];
                Yblock = [waveform + offsets;                 nan(1, numChannels)];
                X_by_color{ci} = [X_by_color{ci}; Xblock(:)];
                Y_by_color{ci} = [Y_by_color{ci}; Yblock(:)];

                % Labels
                label_idx = num2str(idx);
                text_labels(end+1).x = idx; %#ok<AGROW>
                text_labels(end).y_top = (numChannels+0.5)*spacing;
                text_labels(end).y_bot = -0.5*spacing;
                text_labels(end).str = label_idx;
            end

            hold(sax, 'on');
            for ci = 1:numel(color_keys)
                if ~isempty(X_by_color{ci})
                    plot(sax, X_by_color{ci}, Y_by_color{ci}, 'Color', color_vals{ci});
                end
            end

            for t = 1:numel(text_labels)
                text(sax, text_labels(t).x, text_labels(t).y_top, text_labels(t).str, 'HorizontalAlignment', 'center');
                text(sax, text_labels(t).x, text_labels(t).y_bot, text_labels(t).str, 'HorizontalAlignment', 'center');
            end
            hold(sax, 'off');

            xlim(sax, [0, max(numel(spiking_info), 1) + 1]);
        end

        function update_spike_overlay(obj)
            fig = obj.fig;
            % Draw spike ticks for the *entire recording* into the main trace axes,
            % one solid line per color group, on top of the data.
            ax = obj.mainAxes;

            % Remove any previous tick layer.
            delete(findobj(ax, 'Tag', 'SpikeTick'));

            si = obj.spiking_info;
            lb = findobj(fig, 'Tag', 'SpikingList');
            if isempty(lb) || isempty(si)
                return;
            end
            selectedIdx = get(lb, 'Value');
            if isempty(selectedIdx)
                return;
            end

            spacing = obj.channel_y_spacing;

            % Group selected units by color so each color is a single line object.
            groups = containers.Map();
            for idx = selectedIdx
                if idx > numel(si), continue; end
                info = si(idx);
                col = 'k';
                if isfield(info, 'color') && ~isempty(info.color)
                    col = info.color;
                end
                if ischar(col)
                    key = col;
                else
                    key = mat2str(col);
                end
                if ~isKey(groups, key)
                    groups(key) = idx;
                else
                    groups(key) = [groups(key), idx];
                end
            end

            % Whether to also draw the channel-extent box around each spike.
            bc = findobj(fig, 'Tag', 'SpikingBoxCheckbox');
            show_box = ~isempty(bc) && get(bc, 'Value') == 1;

            % Preserve the current view limits; drawing whole-recording ticks must not
            % rescale the axes (which would jump the view).
            xl = get(ax, 'XLim');
            yl = get(ax, 'YLim');

            hold(ax, 'on');
            keys = groups.keys;
            for i = 1:numel(keys)
                key = keys{i};
                idxs = groups(key);
                if key(1) == '['
                    col = eval(key);
                else
                    col = key;
                end
                % Unbounded window -> ticks (and optional boxes) for the entire
                % recording, drawn once per color in a single plot call.
                [sX, sY] = ndi.gui.app.pyraview.transformSpikeData(si, idxs, -Inf, Inf, spacing, show_box);
                if ~isempty(sX)
                    plot(ax, sX, sY, 'Color', col, 'LineWidth', 2, 'Tag', 'SpikeTick');
                end
            end

            set(ax, 'XLim', xl, 'YLim', yl);
            obj.bring_ticks_to_front(ax);
        end

        function waveform_reset_x(obj)
            % Reset the waveform panel X axis to show all units.
            si = obj.spiking_info;
            n = numel(si);
            xlim(obj.spikingAxes, [0, max(n, 1) + 1]);
        end

        function waveform_zoom_x(obj)
            % Zoom the waveform panel X axis to the selected units whose maximum
            % channel is currently visible in the main data Y view.
            fig = obj.fig;
            si = obj.spiking_info;
            if isempty(si)
                return;
            end

            lb = findobj(fig, 'Tag', 'SpikingList');
            sel = get(lb, 'Value');
            if isempty(sel)
                return;
            end

            spacing = obj.channel_y_spacing;
            yl = get(obj.mainAxes, 'YLim'); % visible channel range in the main data view

            visible = [];
            for k = 1:numel(sel)
                idx = sel(k);
                if idx > numel(si), continue; end
                y_best = (si(idx).best_channel - 1) * spacing;
                if y_best >= yl(1) && y_best <= yl(2)
                    visible(end+1) = idx; %#ok<AGROW>
                end
            end

            if isempty(visible)
                return; % nothing visible to zoom to; leave the view unchanged
            end

            xlim(obj.spikingAxes, [min(visible) - 0.6, max(visible) + 0.6]);
        end

        function update_spacing(obj)
            fig = obj.fig;
            se = findobj(fig, 'Tag', 'SpacingEdit');
            str = get(se, 'String');
            val = str2double(str);
            if isnan(val)
                val = 100;
                set(se, 'String', '100');
            end
            obj.channel_y_spacing = val;
            obj.plot_data(); % Re-plot without reloading data

            % Update spiking plot if visible (spacing changes the tick Y positions too)
            if strcmp(get(findobj(fig, 'Tag', 'SpikingFrame'), 'Visible'), 'on')
                obj.update_spiking_plot();
                obj.update_spike_overlay();
            end
        end

        function update_from_scrollbars(obj, source)
            fig = obj.fig;
            % Read scrollbar values and update view_t0 / view_duration.
            % SOURCE is the tag of the slider that triggered this update
            % ('Scroll1' for pan, 'Scroll2' for zoom).
            s1 = findobj(fig, 'Tag', 'Scroll1'); % Pan
            s2 = findobj(fig, 'Tag', 'Scroll2'); % Zoom

            full_dur = obj.epoch_t1 - obj.epoch_t0;
            if full_dur <= 0, full_dur = 1; end

            if strcmp(source, 'Scroll1')
                % PAN: slider value is in milliseconds relative to epoch_t0
                val_ms = round(get(s1, 'Value'));
                obj.view_t0 = obj.epoch_t0 + val_ms / 1000;

                % Clamp to valid pan range
                max_start = obj.epoch_t1 - obj.view_duration;
                if max_start < obj.epoch_t0, max_start = obj.epoch_t0; end
                if obj.view_t0 > max_start, obj.view_t0 = max_start; end
                if obj.view_t0 < obj.epoch_t0, obj.view_t0 = obj.epoch_t0; end
            else
                % ZOOM: recompute view_duration, maintain center time
                val_zoom = get(s2, 'Value');

                center_t = obj.view_t0 + obj.view_duration / 2;

                W_max = 2592000;
                W_min = 0.001;
                N = 200;

                s = round(val_zoom * N);
                exponent = (N - s) / N;
                new_duration = W_min * (W_max / W_min)^exponent;
                obj.view_duration = new_duration;

                new_t0 = center_t - new_duration / 2;

                % Clamp T0 to epoch bounds
                if new_t0 < obj.epoch_t0
                    new_t0 = obj.epoch_t0;
                end
                if new_t0 + new_duration > obj.epoch_t1
                    new_t0 = obj.epoch_t1 - new_duration;
                end
                if new_t0 < obj.epoch_t0
                    new_t0 = obj.epoch_t0;
                end

                obj.view_t0 = new_t0;

                % Pan slider range/step depends on view_duration, so refresh it
                obj.update_pan_slider(s1);
            end

            obj.update_view();
        end

        function update_scrollbars(obj)
            fig = obj.fig;
            s1 = findobj(fig, 'Tag', 'Scroll1');
            s2 = findobj(fig, 'Tag', 'Scroll2');

            full_dur = obj.epoch_t1 - obj.epoch_t0;
            if full_dur <= 0, full_dur = 1; end

            % Calculate val_zoom (Scroll2)
            W_max = 2592000;
            W_min = 0.001;
            N = 200;

            exponent_ideal = log(obj.view_duration / W_min) / log(W_max / W_min);
            s_ideal = N * (1 - exponent_ideal);
            s = round(s_ideal);
            val_zoom = s / N;

            val_zoom = max(0, min(1, val_zoom));

            set(s2, 'Value', val_zoom);

            % Pan scrollbar (Scroll1): 1 step per ms; arrow/trough = 10% of view
            obj.update_pan_slider(s1);
        end

        function update_pan_slider(obj, s1)
            % Configure the pan scrollbar so that there is one slider unit per
            % millisecond of pannable range, and arrow/trough clicks move the
            % view by 10% of the current view duration. The slider value is the
            % view start time in milliseconds since epoch_t0.
            if isempty(s1) || ~isgraphics(s1)
                return;
            end

            max_start = obj.epoch_t1 - obj.view_duration;
            if max_start < obj.epoch_t0, max_start = obj.epoch_t0; end

            range_ms = round((max_start - obj.epoch_t0) * 1000);

            if range_ms < 1
                % Nothing to pan (view covers the whole epoch). Park the slider.
                set(s1, 'Min', 0, 'Max', 1, 'Value', 0, ...
                    'SliderStep', [1 1], 'Enable', 'off');
                return;
            end

            val_ms = round((obj.view_t0 - obj.epoch_t0) * 1000);
            val_ms = max(0, min(range_ms, val_ms));

            step_ms = max(1, round(0.1 * obj.view_duration * 1000));
            step_frac = min(1, step_ms / range_ms);

            % Set Min/Max before Value to avoid out-of-range errors.
            set(s1, 'Min', 0, 'Max', range_ms, 'Value', val_ms, ...
                'SliderStep', [step_frac, step_frac], 'Enable', 'on');
        end

        function onZoomPan(obj)
            ax = obj.mainAxes;
            xl = xlim(ax);

            obj.view_t0 = xl(1);
            obj.view_duration = xl(2) - xl(1);

            obj.update_scrollbars();
            obj.update_view();
        end

        function update_view(obj)
            fig = obj.fig;
            if isempty(obj.current_doc)
                return;
            end

            req_t0 = obj.view_t0;
            req_t1 = req_t0 + obj.view_duration;

            needs_load = false;

            % Edge check
            if req_t0 < obj.current_data_t0 || req_t1 > obj.current_data_t1
                needs_load = true;
            end

            % Resolution check
            ax_pos = getpixelposition(obj.mainAxes);
            current_pixel_span = ax_pos(3);

            if abs(current_pixel_span - obj.loaded_pixel_span) / obj.loaded_pixel_span > 0.1
                needs_load = true;
            end

            if obj.view_duration < obj.loaded_view_duration * 0.8
                needs_load = true;
            end

            if needs_load
                probe_idx = get(findobj(fig, 'Tag', 'ProbeMenu'), 'Value');
                probe = obj.probes{probe_idx};

                [tVec, data, level] = ndi.gui.app.pyraview.getData(probe, obj.current_doc, req_t0, req_t1, current_pixel_span);

                if ~isempty(tVec)
                    obj.current_data_t0 = tVec(1);
                    obj.current_data_t1 = tVec(end);
                    obj.current_data = data;
                    obj.current_time = tVec;
                    obj.current_level = level;
                    obj.loaded_pixel_span = current_pixel_span;
                    obj.loaded_view_duration = obj.view_duration;

                    obj.plot_data();
                else
                    cla(obj.mainAxes);
                end
            else
                xlim(obj.mainAxes, [req_t0, req_t1]);
            end

            obj.update_scrollbars();
        end

        function plot_data(obj)
            fig = obj.fig;

            data = obj.current_data;
            tVec = obj.current_time;
            level = obj.current_level;
            spacing = obj.channel_y_spacing;

            if isempty(data)
                cla(obj.mainAxes);
                return;
            end

            % Get Mapping
            mm = findobj(fig, 'Tag', 'MappingMenu');
            maps = get(mm, 'String');
            map_val = get(mm, 'Value');
            mapping_name = maps{map_val};

            numChannels = size(data, 2);
            try
                mapping = ndi.gui.app.pyraview.mappings(1:numChannels, mapping_name);
            catch e
                warning('Mapping error: %s', e.message);
                mapping = [];
            end

            % Store previous YLim if not first plot
            if ~obj.first_plot
                yl_old = ylim(obj.mainAxes);
            else
                yl_old = [];
            end

            % Pass mapping to transform function
            [X, Y] = ndi.gui.app.pyraview.transformPlotData(data, tVec, level, spacing, mapping);

            % Replace only the previous main traces, leaving any spike tick objects
            % (Tag 'SpikeTick') in place.
            delete(findobj(obj.mainAxes, 'Tag', 'MainTrace'));
            hold(obj.mainAxes, 'on');
            h_main = plot(obj.mainAxes, X, Y, 'Color', [0 0.4470 0.7410]);
            set(h_main, 'Tag', 'MainTrace');

            % Keep the tick layer drawn on top of the freshly added traces.
            obj.bring_ticks_to_front(obj.mainAxes);

            hold(obj.mainAxes, 'off');

            % Restore X limits
            xlim(obj.mainAxes, [obj.view_t0, obj.view_t0 + obj.view_duration]);

            % Restore Y limits if preserved
            if ~isempty(yl_old)
                ylim(obj.mainAxes, yl_old);
            else
                % First plot of this dataset: auto-fit Y to the data.
                ylim(obj.mainAxes, 'auto');
                obj.first_plot = false;
            end
        end

        function onResize(obj)
            fig = obj.fig;
            pos = get(fig, 'Position');
            width = pos(3);
            height = pos(4);

            margin = 10;
            control_height = 25;

            top_y = height - margin - control_height;

            % Controls Layout
            pt = findobj(fig, 'Tag', 'ProbeText');
            pm = findobj(fig, 'Tag', 'ProbeMenu');
            set(pt, 'Position', [margin, top_y, 50, control_height]);
            set(pm, 'Position', [margin + 50, top_y, 200, control_height]);

            current_x = margin + 50 + 200 + margin;
            et = findobj(fig, 'Tag', 'EpochText');
            em = findobj(fig, 'Tag', 'EpochMenu');
            set(et, 'Position', [current_x, top_y, 80, control_height]);
            set(em, 'Position', [current_x + 80, top_y, 200, control_height]);

            % Row 1 continued: Band | Spacing
            current_x = current_x + 80 + 200 + margin;
            bt = findobj(fig, 'Tag', 'BandText');
            bm = findobj(fig, 'Tag', 'BandMenu');
            set(bt, 'Position', [current_x, top_y, 40, control_height]);
            set(bm, 'Position', [current_x + 40, top_y, 80, control_height]);

            current_x = current_x + 40 + 80 + margin;
            st = findobj(fig, 'Tag', 'SpacingText');
            se = findobj(fig, 'Tag', 'SpacingEdit');
            set(st, 'Position', [current_x, top_y, 75, control_height]);
            set(se, 'Position', [current_x + 75, top_y, 50, control_height]);

            current_x = current_x + 75 + 50 + margin;
            mt = findobj(fig, 'Tag', 'MappingText');
            mm = findobj(fig, 'Tag', 'MappingMenu');
            set(mt, 'Position', [current_x, top_y, 75, control_height]);
            set(mm, 'Position', [current_x + 75, top_y, 100, control_height]);

            current_x = current_x + 75 + 100 + margin;
            sc = findobj(fig, 'Tag', 'SpikingCheckbox');
            set(sc, 'Position', [current_x, top_y, 200, control_height]);

            % Separator
            sep_y = top_y - margin;
            sep = findobj(fig, 'Tag', 'SeparatorLine');
            set(sep, 'Position', [0, sep_y, width, 1]);

            % Frames
            % Main Frame hugs bottom (0) and separator (sep_y)
            frame_y = 0;
            frame_h = sep_y;

            % Check Spiking Checkbox
            show_spiking = get(sc, 'Value');
            split = obj.split_position;

            mf = findobj(fig, 'Tag', 'MainFrame');
            sf = findobj(fig, 'Tag', 'SpikingFrame');
            sd = findobj(fig, 'Tag', 'SplitDragger');

            if show_spiking
                main_w = width * split;
                spiking_w = width * (1 - split);
                dragger_w = 5;

                set(mf, 'Position', [0, frame_y, main_w, frame_h]);
                set(sf, 'Position', [main_w, frame_y, spiking_w, frame_h], 'Visible', 'on');
                set(sd, 'Position', [main_w - dragger_w/2, frame_y, dragger_w, frame_h], 'Visible', 'on');
            else
                main_w = width;
                set(mf, 'Position', [0, frame_y, main_w, frame_h]);
                set(sf, 'Visible', 'off');
                set(sd, 'Visible', 'off');
            end

            % Scrollbars inside MainFrame (Normalized)
            scrollbar_h_px = 20;
            if frame_h > 0
                sb_h_norm = scrollbar_h_px / frame_h;
            else
                sb_h_norm = 0.05;
            end

            % Button Height (px) converted to norm
            btn_h_px = 25;
            if frame_h > 0
                btn_h_norm = btn_h_px / frame_h;
            else
                btn_h_norm = 0.05;
            end

            s1 = findobj(mf, 'Tag', 'Scroll1'); % Pan (Top)
            s2 = findobj(mf, 'Tag', 'Scroll2'); % Zoom (Bottom)
            ax = findobj(mf, 'Tag', 'MainAxes');

            rxb = findobj(mf, 'Tag', 'ResetXButton');
            ryb = findobj(mf, 'Tag', 'ResetYButton');
            pb = findobj(mf, 'Tag', 'PanButton');
            zb = findobj(mf, 'Tag', 'ZoomButton');

            % Scroll 2 (Bottom)
            set(s2, 'Position', [0.05, 0, 0.9, sb_h_norm]);

            % Scroll 1 (Above Scroll 2)
            set(s1, 'Position', [0.05, sb_h_norm, 0.9, sb_h_norm]);

            % Buttons (Right aligned above scrollbars)
            btn_w_norm = 0.1;
            right_margin = 0.05;

            set(rxb, 'Position', [1 - right_margin - 4*btn_w_norm, 2*sb_h_norm, btn_w_norm, btn_h_norm]);
            set(ryb, 'Position', [1 - right_margin - 3*btn_w_norm, 2*sb_h_norm, btn_w_norm, btn_h_norm]);
            set(pb, 'Position', [1 - right_margin - 2*btn_w_norm, 2*sb_h_norm, btn_w_norm, btn_h_norm]);
            set(zb, 'Position', [1 - right_margin - btn_w_norm, 2*sb_h_norm, btn_w_norm, btn_h_norm]);

            % Axes
            axes_bottom = 2*sb_h_norm + btn_h_norm;

            main_ax_pos = [0.05, axes_bottom + 0.05, 0.9, 1 - (axes_bottom + 0.05) - 0.02];
            set(ax, 'Position', main_ax_pos);

            % Align Spiking Axes to Main Axes
            if show_spiking
                sax = findobj(sf, 'Tag', 'SpikingAxes');
                slb = findobj(sf, 'Tag', 'SpikingList');
                stt = findobj(sf, 'Tag', 'SpikingTitle');
                ssc = findobj(sf, 'Tag', 'SpikingSortCheckbox');
                sbc = findobj(sf, 'Tag', 'SpikingBoxCheckbox');
                brx = findobj(sf, 'Tag', 'SpikingWaveResetX');
                bzm = findobj(sf, 'Tag', 'SpikingWaveZoom');

                spiking_ax_pos = [0.1, main_ax_pos(2), 0.5, main_ax_pos(4)];
                set(sax, 'Position', spiking_ax_pos);

                % Waveform X-axis buttons in the gap just below the waveform axes.
                wave_btn_h = 0.025;
                wave_btn_y = max(0.01, main_ax_pos(2) - 0.06);
                set(brx, 'Position', [0.12, wave_btn_y, 0.22, wave_btn_h]);
                set(bzm, 'Position', [0.37, wave_btn_y, 0.22, wave_btn_h]);

                % Title
                set(stt, 'Position', [0.65, 0.92, 0.35, 0.07]);

                % Sort and show-box checkboxes under the title
                set(ssc, 'Position', [0.65, 0.86, 0.35, 0.05]);
                set(sbc, 'Position', [0.65, 0.80, 0.35, 0.05]);

                % Listbox on Right, below the checkboxes
                set(slb, 'Position', [0.65, 0, 0.35, 0.79]);
            end

            obj.update_view();
        end
    end

    methods (Static, Access = private)
        function si = emptySpikingInfo()
            % Empty spiking_info template (same fields as load_spiking_neurons).
            si = struct('element_obj', {}, 'element_doc', {}, 'neuron_doc', {}, ...
                'label', {}, 'name', {}, 'quality', {}, ...
                'spike_times', {}, 'times_loaded', {}, 'best_channel', {}, ...
                'low_channel', {}, 'high_channel', {}, 'color', {});
        end

        function si = sort_spiking_info(si, by_channel)
            % Reorder the spiking_info struct array. When BY_CHANNEL is true, sort
            % by best (maximum-energy) channel location; otherwise sort by unit
            % name. Labels are renumbered and colors reassigned to match the order.
            if isempty(si)
                return;
            end

            if by_channel
                % Descending so that, matching the viewer's channel layout, the
                % smallest channel ends up last in the list.
                keys = [si.best_channel];
                [~, order] = sort(keys, 'descend');
            else
                names = cell(1, numel(si));
                for k = 1:numel(si)
                    if isfield(si, 'name') && ~isempty(si(k).name)
                        names{k} = si(k).name;
                    else
                        names{k} = si(k).label;
                    end
                end
                [~, order] = sort(lower(names));
            end

            si = si(order);

            color_cycle = {'k', 'm', 'b', 'g', [1 0.5 0], 'r'};
            for k = 1:numel(si)
                q = 0;
                if isfield(si, 'quality') && ~isempty(si(k).quality)
                    q = si(k).quality;
                end
                nm = '';
                if isfield(si, 'name') && ~isempty(si(k).name)
                    nm = si(k).name;
                end
                si(k).label = sprintf('%d %s Q%d', k, nm, q);
                si(k).color = color_cycle{mod(k-1, numel(color_cycle)) + 1};
            end
        end

        function bring_ticks_to_front(ax)
            % Move the spike tick line objects to the front of the axes' child
            % stack (drawn on top of the data traces). Child index 1 is topmost.
            ch = get(ax, 'Children');
            if numel(ch) < 2
                return;
            end
            tags = get(ch, 'Tag');
            if ~iscell(tags)
                tags = {tags};
            end
            isTick = strcmp(tags, 'SpikeTick');
            if any(isTick) && ~all(isTick)
                set(ax, 'Children', [ch(isTick); ch(~isTick)]);
            end
        end
    end
end
