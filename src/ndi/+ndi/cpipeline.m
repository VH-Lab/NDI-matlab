classdef cpipeline
    % A class for managing pipelines of ndi.calculator objects in NDI.
    properties (SetAccess=protected,GetAccess=public)
    end % properties
    methods
    end % methods
    methods (Static)
        function p = defaultPath()
            p = fullfile(ndi.common.PathConstants.LogFolder, '..', 'My Pipelines');
            if ~isfolder(p), mkdir(p); end
            if ~isfolder(fullfile(p, 'Pipelines')), mkdir(fullfile(p, 'Pipelines')); end
            if ~isfolder(fullfile(p, 'Calculator_Parameters')), mkdir(fullfile(p, 'Calculator_Parameters')); end
        end
        
        function edit(options)
            arguments
                options.command (1,:) char = 'new'
                options.pipelinePath (1,:) char = ndi.cpipeline.defaultPath()
                options.session ndi.session = ndi.session.empty()
                options.window_params (1,1) struct = struct('height', 600, 'width', 900)
                options.fig {mustBeA(options.fig,["matlab.ui.Figure","double"])} = []
                options.selectedPipeline (1,:) char = ''
                options.slider_val (1,1) double = 0
                options.order_idx (1,1) double = 0
            end
            
            fig = options.fig;
            if ~strcmpi(options.command,'new') && isempty(fig)
                error('The ''fig'' argument must be provided for all commands except ''new''.');
            end
            
            % GLOBAL FONT SIZE
            fs = 12; 
            
            if strcmpi(options.command,'new')
                if isempty(fig), fig = figure; end
                command = 'NewWindow';
                if ~isempty(options.pipelinePath) && isfolder(options.pipelinePath)
                    ud.pipelinePath = options.pipelinePath;
                    ud.pipelineList = []; ud.pipelineListChar = {}; 
                    ud.linked_object = options.session;
                    ud.gui_rows = []; ud.selected_row_index = []; 
                    set(fig,'userdata',ud);
                else
                    error(['The provided pipeline path does not exist: ' options.pipelinePath '.']);
                end
            else
                ud = get(fig,'userdata');
                command = options.command;
            end
            
            switch (command)
                case 'NewWindow'
                    set(fig,'tag','ndi.cpipeline.edit');
                    uid = vlt.ui.basicuitools_defs;
                    callbackstr = [  'eval([get(gcbf,''Tag'') ''(''''command'''','''''' get(gcbo,''Tag'') '''''' ,''''fig'''',gcbf);'']);'];
                    
                    fig_bg = [0.8 0.8 0.8]; edit_bg = [1 1 1];
                    top = options.window_params.height;
                    margin = 0.04; row_h = 0.05;
                    
                    set(fig,'position',[50 50 options.window_params.width top], 'Color', fig_bg, ...
                        'NumberTitle','off', 'Name',['Editing Pipelines at ' ud.pipelinePath], ...
                        'MenuBar','none', 'ToolBar','none', 'Units','normalized', 'Resize','on');
                    
                    y = 1 - margin - row_h;
                    
                    % Top Controls
                    uicontrol(uid.txt,'Units','normalized','position',[margin y 0.4 row_h],'string','Select Pipeline:',...
                        'BackgroundColor',fig_bg,'FontWeight','bold','HorizontalAlignment','left', 'FontSize', fs);
                    y = y - row_h;
                    uicontrol(uid.popup,'Units','normalized','position',[margin y 0.94 row_h],...
                        'string',{'---'},'tag','PipelinePopup','callback',callbackstr,'BackgroundColor',edit_bg, 'FontSize', fs);
                    
                    y = y - row_h - 0.02; 
                    uicontrol(uid.txt,'Units','normalized','position',[margin y 0.4 row_h],'string','NDI Data:',...
                         'BackgroundColor',fig_bg,'FontWeight','bold','HorizontalAlignment','left', 'FontSize', fs);
                    y = y - row_h;
                    uicontrol(uid.popup,'Units','normalized','position',[margin y 0.94 row_h],...
                        'string',{'None'},'tag','PipelineObjectVariablePopup','callback',callbackstr,'BackgroundColor',edit_bg, 'FontSize', fs);
                    
                    y = y - 0.06; 
                    header_y = y;
                    
                    % ---------------------------------------------------------------------
                    % COLUMN DEFINITIONS 
                    % ---------------------------------------------------------------------
                    panel_width_norm = 1 - (2 * margin);
                    
                    c.name_x = 0.00; c.name_w = 0.32;
                    c.param_x = 0.33; c.param_w = 0.35;
                    c.order_x = 0.70; c.order_w = 0.14; 
                    c.plot_x = 0.86; c.plot_w = 0.14; 
                    
                    ud.col_defs = c;
                    set(fig, 'userdata', ud);
                    % Calculate Header Positions
                    hx_name = margin + (c.name_x * panel_width_norm); hw_name = c.name_w * panel_width_norm;
                    hx_param = margin + (c.param_x * panel_width_norm); hw_param = c.param_w * panel_width_norm;
                    hx_order = margin + (c.order_x * panel_width_norm); hw_order = c.order_w * panel_width_norm;
                    hx_plot = margin + (c.plot_x * panel_width_norm); hw_plot = c.plot_w * panel_width_norm;
                    % Headers
                    uicontrol(uid.txt,'Units','normalized','position',[hx_name header_y hw_name row_h],...
                        'string','Calculator Instance','BackgroundColor',fig_bg,'FontWeight','bold',...
                        'HorizontalAlignment','left', 'FontSize', fs);
                    
                    uicontrol(uid.txt,'Units','normalized','position',[hx_param header_y hw_param row_h],...
                        'string','Parameter Setup Code','BackgroundColor',fig_bg,'FontWeight','bold',...
                        'HorizontalAlignment','left', 'FontSize', fs);
                    
                    uicontrol(uid.txt,'Units','normalized','position',[hx_order header_y hw_order row_h],...
                        'string','Order','BackgroundColor',fig_bg,'FontWeight','bold',...
                        'HorizontalAlignment','center', 'FontSize', fs);
                    
                    uicontrol(uid.txt,'Units','normalized','position',[hx_plot header_y hw_plot row_h],...
                        'string','Figure Output','BackgroundColor',fig_bg,'FontWeight','bold',...
                        'HorizontalAlignment','center', 'FontSize', fs);
                    
                    % Main List Area
                    list_top = header_y; 
                    bottom_area_height = 0.20;
                    list_height = list_top - bottom_area_height;
                    list_bottom = bottom_area_height + 0.01;
                    
                    panel_pos = [margin, list_bottom, 1-(2*margin), list_height];
                    
                    % LIST CONTAINER
                    container = uipanel('Units','normalized', 'Position', panel_pos, 'BackgroundColor', [1 1 1], ...
                        'Tag', 'ListContainerPanel', 'BorderType', 'line', 'HighlightColor', [0.6 0.6 0.6], ...
                        'Visible', 'on', 'FontSize', fs);
                    
                    set(container, 'SizeChangedFcn', @(s,e)ndi.cpipeline.edit('command','UpdateCalculatorInstanceList','fig',fig));
                    
                    slider_w = 0.04;
                    uicontrol('Style','slider','Units','normalized',...
                        'Position',[panel_pos(1)+panel_pos(3), list_bottom, slider_w, list_height],...
                        'Tag','ListSlider', 'Callback', callbackstr, 'Min', 0, 'Max', 1, 'Value', 1);
                    
                    % Buttons
                    btn_h = 0.06; gap = 0.015; 
                    y_row_top = 0.12; y_row_bot = y_row_top - btn_h - gap;
                    btn_w = 0.22; 
                    
                    x = margin;
                    uicontrol(uid.button,'Units','normalized','position',[x y_row_top btn_w btn_h],...
                        'string','New Pipeline','tag','NewPipelineButton','callback',callbackstr, 'FontSize', fs);
                    x = x + btn_w + gap;
                    uicontrol(uid.button,'Units','normalized','position',[x y_row_top btn_w btn_h],...
                        'string','Delete Pipeline','tag','DeletePipelineButton','callback',callbackstr, 'FontSize', fs);
                    
                    x = margin;
                    uicontrol(uid.button,'Units','normalized','position',[x y_row_bot btn_w btn_h],...
                        'string','New Calculator','tag','NewCalculatorInstanceButton','callback',callbackstr, 'FontSize', fs);
                    x = x + btn_w + gap;
                    uicontrol(uid.button,'Units','normalized','position',[x y_row_bot btn_w btn_h],...
                        'string','Delete Calculator','tag','DeleteCalculatorInstanceButton','callback',callbackstr, 'FontSize', fs);
                    x = x + btn_w + gap;
                    uicontrol(uid.button,'Units','normalized','position',[x y_row_bot btn_w btn_h],...
                        'string','Edit Calculator','tag','EditButton','callback',callbackstr, 'FontSize', fs);
                    
                    run_x = x + btn_w + 0.05; run_w = 1 - run_x - margin;
                    run_h = 0.10; run_y = y_row_bot + ((y_row_top+btn_h)-y_row_bot-run_h)/2;
                    
                    uicontrol(uid.button,'Units','normalized','position',[run_x run_y run_w run_h],...
                        'string','RUN PIPELINE','tag','RunButton','callback',callbackstr, ...
                        'FontWeight','bold', 'FontSize', fs+2, 'BackgroundColor',[0.8 1 0.8]);
                    
                    ndi.cpipeline.edit('command','RefreshObjectVariablePopup','fig',fig);
                    ndi.cpipeline.edit('command','LoadPipelines','fig',fig);
                case 'PipelinePopup'
                    ndi.cpipeline.edit('command','UpdateCalculatorInstanceList','fig',fig);
                    
                case 'UpdateCalculatorInstanceList'
                    container = findobj(fig, 'Tag', 'ListContainerPanel');
                    if ~isempty(container.Children), delete(container.Children); end
                    drawnow limitrate; 
                    
                    fs = 12;
                    
                    pipelinePopupObj = findobj(fig,'tag','PipelinePopup');
                    val = get(pipelinePopupObj, 'value');
                    
                    if val <= 1 || isempty(ud.pipelineList)
                        ud.gui_rows = []; set(fig,'userdata',ud); drawnow; return;
                    end
                    
                    try, current_pipeline = ud.pipelineList(val - 1); catch, return; end
                    
                    if isfield(current_pipeline, 'items')
                        calc_items = current_pipeline.items;
                        if iscell(calc_items)
                            temp_items = [];
                            for c_i = 1:numel(calc_items)
                                if isstruct(calc_items{c_i}), temp_items = [temp_items, calc_items{c_i}]; end
                            end
                            calc_items = temp_items;
                        end
                    else, calc_items = []; end
                    
                    if iscolumn(calc_items), calc_items = calc_items'; end
                    if ~isempty(calc_items)
                        [~, sort_idx] = sort([calc_items.order]);
                        calc_items = calc_items(sort_idx);
                    end
                    
                    n_calcs = numel(calc_items);
                    order_options = cellstr(string(1:n_calcs)); 
                    
                    set(container, 'Units', 'pixels');
                    p_pos = get(container, 'Position');
                    panel_w = p_pos(3); panel_h = p_pos(4);
                    
                    row_h_pix = 36; 
                    total_h_pix = n_calcs * row_h_pix;
                    
                    slider = findobj(fig, 'Tag', 'ListSlider');
                    if total_h_pix > panel_h
                        set(slider, 'Enable', 'on', 'Min', 0, 'Max', total_h_pix - panel_h, ...
                            'SliderStep', [row_h_pix/(total_h_pix-panel_h), 5*row_h_pix/(total_h_pix-panel_h)]);
                    else
                        set(slider, 'Enable', 'off', 'Value', 0, 'Max', 0);
                    end
                    
                    slider_val = get(slider, 'Value'); slider_max = get(slider, 'Max');
                    scroll_offset = slider_max - slider_val;
                    
                    ud.gui_rows = struct('bg',{},'order_popup',{},'name',{},'param',{},'plot_check',{});
                    
                    if isfield(ud, 'col_defs'), c = ud.col_defs;
                    else
                        c.name_x = 0.00; c.name_w = 0.32;
                        c.param_x = 0.33; c.param_w = 0.35;
                        c.order_x = 0.70; c.order_w = 0.14; 
                        c.plot_x = 0.86; c.plot_w = 0.14; 
                    end
                    
                    for i = 1:n_calcs
                        item_top_virtual = (i-1) * row_h_pix; 
                        y_pix = panel_h + scroll_offset - item_top_virtual - row_h_pix;
                        if (y_pix + row_h_pix < 0) || (y_pix > panel_h), continue; end
                        bg_color = [1 1 1];
                        if isfield(ud,'selected_row_index') && ~isempty(ud.selected_row_index) && ud.selected_row_index == i
                            bg_color = [0.7 0.85 1];
                        end
                        
                        % 1. NAME
                        x_name = c.name_x * panel_w; w_name = c.name_w * panel_w;
                        
                        % 2. PARAM
                        x_param = c.param_x * panel_w; w_param = c.param_w * panel_w;
                        
                        % 3. ORDER (Nudged Right)
                        w_order_box = 60; 
                        center_order = (c.order_x + (c.order_w/2)) * panel_w;
                        x_order = center_order - (w_order_box / 2) + 15; 
                        
                        % 4. PLOT (Nudged Right to 'O')
                        w_chk = 20; 
                        center_plot = (c.plot_x + (c.plot_w/2)) * panel_w;
                        x_plot = center_plot - (w_chk / 2) + 10; 
                        
                        bg = uicontrol(container, 'Style', 'text', 'Units', 'pixels', ...
                            'Position', [0, y_pix, panel_w, row_h_pix], ...
                            'BackgroundColor', bg_color, 'Enable', 'inactive', 'FontSize', fs, ...
                            'ButtonDownFcn', @(s,e)ndi.cpipeline.edit('command','SelectRow','fig',fig,'slider_val',i));
                        
                        txt = uicontrol(container, 'Style', 'text', 'Units', 'pixels', ...
                            'Position', [x_name+5, y_pix+5, w_name-5, row_h_pix-10], ...
                            'String', calc_items(i).instanceName, ...
                            'BackgroundColor', bg_color, 'HorizontalAlignment', 'left', 'FontSize', fs, ...
                            'Enable', 'inactive', 'ButtonDownFcn', @(s,e)ndi.cpipeline.edit('command','SelectRow','fig',fig,'slider_val',i));
                        
                        % LOAD PARAMETERS
                        try 
                            avail_params = ndi.calculator.get_available_parameters(calc_items(i).calculatorClass, ud.pipelinePath);
                        catch 
                            avail_params = {}; 
                        end
                        
                        % FORMAT DROPDOWN LIST: Default, ---, Example, [others]
                        % Filter out Default/Example from raw list to re-order them manually
                        other_params = avail_params(~ismember(avail_params, {'Default', 'Example'}));
                        display_list = [{'Default', '---', 'Example'}, other_params];
                        
                        % Match current selection
                        curr_sel = calc_items(i).selected_param_name;
                        val_idx = find(strcmp(display_list, curr_sel));
                        if isempty(val_idx)
                            % Fallback: if selected is not in list (e.g. removed), default to Example
                            val_idx = 3; % 'Example'
                            if numel(display_list) < 3, val_idx = 1; end
                        end
                        
                        pop = uicontrol(container, 'Style', 'popupmenu', 'Units', 'pixels', ...
                            'Position', [x_param, y_pix+5, w_param, row_h_pix-8], ...
                            'String', display_list, 'Value', val_idx, 'BackgroundColor', [1 1 1], 'FontSize', fs, ...
                            'Callback', @(s,e)ndi.cpipeline.edit('command','ParamChange','fig',fig,'slider_val',i));
                        
                        order_popup = uicontrol(container, 'Style', 'popupmenu', 'Units', 'pixels', ...
                            'Position', [x_order, y_pix+5, w_order_box, row_h_pix-8], ...
                            'String', order_options, 'Value', calc_items(i).order, 'BackgroundColor', [1 1 1], 'FontSize', fs, ...
                            'Callback', @(s,e)ndi.cpipeline.edit('command','OrderChange','fig',fig,'order_idx',i));
                        
                        plot_val = 0; 
                        if isfield(calc_items(i), 'plot_output'), plot_val = calc_items(i).plot_output; end
                        
                        chk = uicontrol(container, 'Style', 'checkbox', 'Units', 'pixels', ...
                            'Position', [x_plot, y_pix+5, w_chk, row_h_pix-8], ...
                            'String', '', 'Value', plot_val, 'BackgroundColor', bg_color, 'FontSize', fs, ...
                            'Callback', @(s,e)ndi.cpipeline.edit('command','PlotCheckChange','fig',fig,'slider_val',i));
                        
                        ud.gui_rows(i).bg = bg; ud.gui_rows(i).order_popup = order_popup;
                        ud.gui_rows(i).name = txt; ud.gui_rows(i).param = pop;
                        ud.gui_rows(i).plot_check = chk;
                    end
                    set(container, 'Units', 'normalized'); set(fig, 'userdata', ud);
                    set(container, 'Visible', 'off'); set(container, 'Visible', 'on'); drawnow; 
                    
                case 'OrderChange'
                    idx = options.order_idx; 
                    pipelinePopupObj = findobj(fig,'tag','PipelinePopup');
                    val = get(pipelinePopupObj, 'value');
                    if val <= 1, return; end
                    current_pipeline = ud.pipelineList(val - 1);
                    [~, sort_idx] = sort([current_pipeline.items.order]);
                    
                    new_order = get(ud.gui_rows(idx).order_popup, 'Value');
                    current_order = current_pipeline.items(sort_idx(idx)).order;
                    if new_order == current_order, return; end
                    
                    item_A_real_idx = sort_idx(idx); item_B_real_idx = sort_idx(new_order);
                    current_pipeline.items(item_A_real_idx).order = new_order;
                    current_pipeline.items(item_B_real_idx).order = current_order;
                    
                    ud.pipelineList(val - 1) = current_pipeline;
                    set(fig,'userdata',ud);
                    ndi.cpipeline.savePipelineFile(ud.pipelinePath, current_pipeline);
                    ndi.cpipeline.edit('command','UpdateCalculatorInstanceList','fig',fig);
                    
                case 'ParamChange'
                    idx = options.slider_val;
                    pipelinePopupObj = findobj(fig,'tag','PipelinePopup');
                    val = get(pipelinePopupObj, 'value');
                    if val <= 1, return; end
                    current_pipeline = ud.pipelineList(val - 1);
                    [~, sort_idx] = sort([current_pipeline.items.order]);
                    actual_index = sort_idx(idx);
                    
                    items = get(ud.gui_rows(idx).param, 'String'); v = get(ud.gui_rows(idx).param, 'Value');
                    selectedStr = items{v};
                    
                    if strcmp(selectedStr, '---')
                        % If user selects separator, revert to previous or Example
                        set(ud.gui_rows(idx).param, 'Value', 3); % Example
                        current_pipeline.items(actual_index).selected_param_name = 'Example';
                    else
                        current_pipeline.items(actual_index).selected_param_name = selectedStr;
                    end
                    
                    ud.pipelineList(val - 1) = current_pipeline; set(fig, 'userdata', ud);
                    ndi.cpipeline.savePipelineFile(ud.pipelinePath, current_pipeline);
                
                case 'PlotCheckChange'
                    idx = options.slider_val;
                    pipelinePopupObj = findobj(fig,'tag','PipelinePopup');
                    val = get(pipelinePopupObj, 'value');
                    if val <= 1, return; end
                    current_pipeline = ud.pipelineList(val - 1);
                    [~, sort_idx] = sort([current_pipeline.items.order]);
                    actual_index = sort_idx(idx);
                    
                    isChecked = get(ud.gui_rows(idx).plot_check, 'Value');
                    current_pipeline.items(actual_index).plot_output = isChecked;
                    
                    ud.pipelineList(val - 1) = current_pipeline; set(fig, 'userdata', ud);
                    ndi.cpipeline.savePipelineFile(ud.pipelinePath, current_pipeline);
                case 'RunButton'
                    pipelinePopupObj = findobj(fig,'tag','PipelinePopup');
                    val = get(pipelinePopupObj, 'value');
                    if val <= 1, msgbox('Select a pipeline.', 'Error'); return; end
                    
                    current_pipeline = ud.pipelineList(val - 1);
                    items = current_pipeline.items; if isempty(items), return; end
                    [~, s_idx] = sort([items.order]); items = items(s_idx);
                    
                    dataPopupObj = findobj(fig, 'tag', 'PipelineObjectVariablePopup');
                    dv = get(dataPopupObj, 'value'); dlist = get(dataPopupObj, 'userdata');
                    pipeline_session = [];
                    if dv > 1, try, pipeline_session = evalin('base', dlist{dv}); catch, end; end
                    
                    if isempty(pipeline_session), msgbox('Please link NDI Data to Run.', 'Error'); return; end
                    
                    fprintf('\n=======================================================\n');
                    fprintf('Running Pipeline: %s\n', current_pipeline.pipeline_name);
                    fprintf('Linked Session: %s\n', pipeline_session.reference);
                    fprintf('=======================================================\n');
                    h_wait = waitbar(0, 'Executing Pipeline...');
                    
                    try
                        for i = 1:numel(items)
                            calc_name = items(i).instanceName;
                            param_name = items(i).selected_param_name;
                            
                            % Skip separator if somehow selected
                            if strcmp(param_name, '---'), param_name = 'Example'; end
                            
                            fprintf('Step %d/%d: Running ''%s'' (%s)...\n', i, numel(items), calc_name, items(i).calculatorClass);
                            
                            % ESCAPE UNDERSCORES for waitbar
                            safe_calc_name = strrep(calc_name, '_', '\_');
                            waitbar((i-1)/numel(items), h_wait, ['Running ' safe_calc_name]);
                            
                            try
                                fprintf('   > Loading parameters (%s)...\n', param_name);
                                forced_code = '';
                                
                                % Handle special JSON files manually to ensure correct loading
                                if strcmpi(param_name, 'Default') || strcmpi(param_name, 'Example')
                                    json_file = fullfile(ud.pipelinePath, 'Calculator_Parameters', items(i).calculatorClass, [param_name '.json']);
                                    if isfile(json_file)
                                        try
                                            txt = fileread(json_file);
                                            j = jsondecode(txt);
                                            if isfield(j, 'code'), forced_code = j.code; end
                                        catch
                                        end
                                    end
                                end
                                
                                if ~isempty(forced_code)
                                    param_code = forced_code;
                                else
                                    param_code = ndi.calculator.load_parameter_code(items(i).calculatorClass, param_name, ud.pipelinePath);
                                end
                                
                                if iscell(param_code), param_code = strjoin(param_code, newline);
                                elseif isstring(param_code) && numel(param_code) > 1, param_code = join(param_code, newline); end
                                param_code = char(param_code);
                                
                                % Ensure pipeline_session is available in local scope
                                S = pipeline_session;
                                if exist('parameters','var'), clear parameters; end
                                
                                % EXECUTE PARAMETER CODE
                                eval(param_code); 
                                
                                if ~exist('parameters','var')
                                    fprintf('   > Warning: Parameters not created by code. Using default.\n');
                                    thecalc = feval(items(i).calculatorClass, pipeline_session);
                                    parameters = thecalc.default_search_for_input_parameters();
                                end
                                
                                if isempty(parameters)
                                    error('Parameters structure is empty. Cannot run calculator.');
                                end
                                
                                fprintf('   > Calculating...\n');
                                calc_obj = feval(items(i).calculatorClass, pipeline_session);
                                new_docs = calc_obj.run('NoAction', parameters);
                                
                                doc_count = 0;
                                if iscell(new_docs), doc_count = numel(new_docs);
                                elseif isa(new_docs, 'ndi.document'), doc_count = numel(new_docs); 
                                end
                                fprintf('   > Success. Generated/Updated %d documents.\n', doc_count);
                                
                                % ----------------------------------------------------------------
                                % FIGURE OUTPUT LOGIC
                                % ----------------------------------------------------------------
                                if isfield(items(i), 'plot_output') && items(i).plot_output == 1
                                    plot_mode = questdlg(sprintf('Plotting figures for %s?\nSelect Mode:', calc_name), ...
                                        ['Plot Output: ' calc_name], 'Individual', 'Subplots', 'Individual');
                                    
                                    if ~isempty(plot_mode)
                                        plot_docs = calc_obj.search_for_calculator_docs(parameters);
                                        plot_count = numel(plot_docs);
                                        
                                        if plot_count > 0
                                            if strcmp(plot_mode, 'Individual')
                                                fprintf('   > Plotting figures: Generating %d plots for %d documents...\n', plot_count, plot_count);
                                                for p_i = 1:plot_count
                                                    calc_obj.plot(plot_docs{p_i}, 'newfigure', 1);
                                                end
                                            elseif strcmp(plot_mode, 'Subplots')
                                                 num_figs = max(1, min(5, ceil(plot_count/5))); 
                                                 fprintf('   > Plotting figures: Generating %d subplot figures for %d documents...\n', num_figs, plot_count);
                                                 
                                                 for f = 1:num_figs
                                                     figure; 
                                                     set(gcf, 'Name', sprintf('%s: Batch %d of %d', calc_name, f, num_figs), 'NumberTitle', 'on');
                                                     items_per_fig = ceil(plot_count / num_figs);
                                                     start_idx = (f-1)*items_per_fig + 1;
                                                     end_idx = min(f*items_per_fig, plot_count);
                                                     if start_idx > plot_count, break; end
                                                     
                                                     current_chunk = plot_docs(start_idx:end_idx);
                                                     num_in_chunk = numel(current_chunk);
                                                     n_cols = ceil(sqrt(num_in_chunk));
                                                     n_rows = ceil(num_in_chunk / n_cols);
                                                     for k = 1:num_in_chunk
                                                         ax = subplot(n_rows, n_cols, k);
                                                         try
                                                             calc_obj.plot(current_chunk{k}, 'newfigure', 0, 'suppress_title', 0);
                                                         catch plot_err
                                                             text(0.5, 0.5, 'Error', 'HorizontalAlignment', 'center');
                                                             warning(['Error plotting doc: ' plot_err.message]);
                                                         end
                                                     end
                                                 end
                                            end
                                        else
                                            fprintf('   > No documents to plot.\n');
                                        end
                                    end
                                end
                                
                            catch run_err
                                fprintf(2, '   > EXECUTION ERROR: %s\n', run_err.message);
                                err_msg = sprintf('Error executing calculator "%s":\n\n%s\n\nCheck your Input Parameters code.', calc_name, run_err.message);
                                uiwait(msgbox(err_msg, 'Calculator Error', 'error'));
                                delete(h_wait); fprintf('   > Pipeline Stopped due to error.\n'); return; 
                            end
                        end
                        delete(h_wait); msgbox('Success! Pipeline Completed.', 'Info');
                        fprintf('Pipeline Complete.\n');
                    catch e
                        if isvalid(h_wait), delete(h_wait); end
                        errordlg(e.message, 'Execution Error');
                        fprintf(2, 'Pipeline Crashed: %s\n', e.message);
                    end
                    
                case 'LoadPipelines'
                    ud.pipelineList = ndi.cpipeline.getPipelines(ud.pipelinePath);
                    ud.pipelineListChar = {ud.pipelineList.pipeline_name};
                    fullList = [{'Select a Pipeline...'}, ud.pipelineListChar];
                    set(fig,'userdata',ud);
                    set(findobj(fig,'Tag','PipelinePopup'),'String',fullList, 'Value', 1);
                    
                    if isfield(options, 'selectedPipeline') && ~isempty(options.selectedPipeline)
                       idx = find(strcmp(ud.pipelineListChar, options.selectedPipeline));
                       if ~isempty(idx)
                           set(findobj(fig,'Tag','PipelinePopup'),'Value',idx(1)+1); 
                           ndi.cpipeline.edit('command','UpdateCalculatorInstanceList','fig',fig);
                       end
                    end
                    
                case 'RefreshObjectVariablePopup'
                     vars = evalin('base', 'whos'); vn = {};
                     for i=1:length(vars), if ismember(vars(i).class, {'ndi.session','ndi.session.dir','ndi.dataset'}), vn{end+1}=vars(i).name; end; end
                     set(findobj(fig,'Tag','PipelineObjectVariablePopup'),'String',[{'None'}, vn], 'userdata',[{[]}, vn]);
                     
                case 'EditButton'
                    pipelinePopupObj = findobj(fig,'tag','PipelinePopup');
                    val = get(pipelinePopupObj, 'value');
                    if val <= 1, return; end
                    current_pipeline = ud.pipelineList(val - 1);
                    
                    dataPopupObj = findobj(fig, 'tag', 'PipelineObjectVariablePopup');
                    dv = get(dataPopupObj, 'value'); 
                    dlist = get(dataPopupObj, 'userdata'); 
                    session_to_pass = [];
                    if dv > 1
                        try, varName = dlist{dv}; session_to_pass = evalin('base', varName); catch, end
                    end
                    
                    [~, s_idx] = sort([current_pipeline.items.order]);
                    if isfield(ud, 'selected_row_index') && ~isempty(ud.selected_row_index)
                        calc_entry = current_pipeline.items(s_idx(ud.selected_row_index));
                        
                        % REDIRECT DEFAULT TO EXAMPLE (Silent switch)
                        param_to_edit = calc_entry.selected_param_name;
                        if strcmpi(param_to_edit, 'Default')
                            param_to_edit = 'Example';
                        end
                        
                        ndi.calculator.graphical_edit_calculator('command','Edit', 'session', session_to_pass, ...
                            'pipelinePath', ud.pipelinePath, 'calculatorClassname', calc_entry.calculatorClass, ...
                            'name', calc_entry.instanceName, 'paramName', param_to_edit); 
                    else
                        msgbox('Select a Calculator Instance to edit.', 'Info');
                    end
                    
                case 'NewPipelineButton'
                    read_dir = fullfile(ud.pipelinePath, 'Pipelines');
                    [success,filename,~] = ndi.util.choosefileordir(read_dir, {'Pipeline name:'}, {['untitled']}, 'New Pipeline', {['']});
                    if success
                        new_pipe_dir = fullfile(read_dir, filename);
                        if ~isfolder(new_pipe_dir), mkdir(new_pipe_dir); end
                        s.pipeline_name = filename; s.items = [];
                        fid = fopen(fullfile(new_pipe_dir, 'pipeline.json'), 'w'); fprintf(fid, '%s', jsonencode(s, 'PrettyPrint', true)); fclose(fid);
                        ndi.cpipeline.edit('command','LoadPipelines','selectedPipeline',filename,'fig',fig);
                    end
                    
                case 'DeletePipelineButton'
                    pipelinePopupObj = findobj(fig,'tag','PipelinePopup');
                    val = get(pipelinePopupObj, 'value');
                    if val > 1
                        current_pipeline = ud.pipelineList(val - 1);
                        rmdir(fullfile(ud.pipelinePath, 'Pipelines', current_pipeline.pipeline_name), 's');
                        set(pipelinePopupObj, 'Value', 1); ndi.cpipeline.edit('command','LoadPipelines','fig',fig);
                    end
                    
            case 'NewCalculatorInstanceButton'
                    pipelinePopupObj = findobj(fig,'tag','PipelinePopup');
                    val = get(pipelinePopupObj, 'value');
                    if val <= 1, return; end
                    current_pipeline = ud.pipelineList(val - 1);
                    
                    dataPopupObj = findobj(fig, 'tag', 'PipelineObjectVariablePopup');
                    dv = get(dataPopupObj, 'value'); dlist = get(dataPopupObj, 'userdata');
                    temp_session = [];
                    if dv > 1, try, temp_session = evalin('base', dlist{dv}); catch, end; end
                    
                    calcTypeList = ndi.calculator.find_calculator_subclasses();
                    if isstring(calcTypeList), calcTypeList = cellstr(calcTypeList); end
                    
                    if ~isempty(calcTypeList)
                        [idx, isSel] = listdlg('ListString',calcTypeList);
                        if isSel
                            dlg_ans = inputdlg('Name:');
                            if ~isempty(dlg_ans)
                                chosenClass = calcTypeList{idx};
                                param_dir = fullfile(ud.pipelinePath, 'Calculator_Parameters', chosenClass);
                                if ~isfolder(param_dir), mkdir(param_dir); end
                                
                                % -------------------------------------------------------------
                                % 1. GENERATE "Default.json" (Read-Only)
                                % -------------------------------------------------------------
                                default_code = {};
                                default_code{end+1} = sprintf('thecalc = %s(pipeline_session);', chosenClass);
                                default_code{end+1} = 'parameters = thecalc.default_search_for_input_parameters();';
                                
                                default_struct = struct('name', 'Default', 'code', {default_code});
                                fid_d = fopen(fullfile(param_dir, 'Default.json'), 'w');
                                fprintf(fid_d, '%s', jsonencode(default_struct, 'PrettyPrint', true));
                                fclose(fid_d);
                                
                                % -------------------------------------------------------------
                                % 2. GENERATE "Example.json" (Editable, Source Scanned)
                                % -------------------------------------------------------------
                                code_cell = {};
                                code_cell{end+1} = sprintf('thecalc = %s(pipeline_session);', chosenClass);
                                code_cell{end+1} = 'parameters = thecalc.default_search_for_input_parameters();';
                                code_cell{end+1} = ''; 
                                
                                query_lines = {};
                                query_vars = {};
                                
                                try
                                    m_file = which(chosenClass);
                                    if ~isempty(m_file)
                                        txt = fileread(m_file);
                                        lines = splitlines(txt);
                                        
                                        for k=1:numel(lines)
                                            l = strtrim(lines{k});
                                            if startsWith(l, '%'), continue; end 
                                            
                                            pat = '(\w+)\s*=\s*ndi\.query\s*\(\s*''([^'']+)''\s*,\s*[^,]+\s*,\s*([^,\);]+)';
                                            tokens = regexp(l, pat, 'tokens');
                                            
                                            if ~isempty(tokens)
                                                q_var = tokens{1}{1};
                                                q_field = tokens{1}{2};
                                                raw_val = strtrim(tokens{1}{3});
                                                
                                                if startsWith(q_field, 'tuning_curve.')
                                                    q_field = replace(q_field, 'tuning_curve.', 'stimulus_tuningcurve.');
                                                end
                                                if startsWith(raw_val, '''') && ~strcmp(q_var, 'query')
                                                    new_line = sprintf('%s = ndi.query(''%s'', ''contains_string'', %s, '''');', ...
                                                        q_var, q_field, raw_val);
                                                    
                                                    query_lines{end+1} = new_line;
                                                    query_vars{end+1} = q_var;
                                                end
                                            end
                                        end
                                    end
                                catch
                                end
                                
                                if ~isempty(query_lines)
                                    code_cell = [code_cell, query_lines];
                                    if ~isempty(query_vars)
                                        code_cell{end+1} = '';
                                        joined_vars = strjoin(query_vars, ' | ');
                                        code_cell{end+1} = sprintf('q_total = %s;', joined_vars);
                                        
                                        % --- START DYNAMIC NAME UPDATE ---
                                        % Use the calculator instance to find the correct query field name
                                        q_name = 'generated_id'; % Fallback default
                                        try
                                            temp_calc = feval(chosenClass, temp_session);
                                            def_p = temp_calc.default_search_for_input_parameters();
                                            if isfield(def_p, 'query') && ~isempty(def_p.query) && isfield(def_p.query(1), 'name')
                                                q_name = def_p.query(1).name;
                                            end
                                        catch
                                            % If instantiation fails, keep 'generated_id'
                                        end
                                        % Use the dynamic q_name variable here
                                        code_cell{end+1} = sprintf('query_struct = struct(''name'',''%s'',''query'',q_total);', q_name);
                                        % --- END DYNAMIC NAME UPDATE ---
                                        
                                        code_cell{end+1} = '';
                                        code_cell{end+1} = 'parameters.query = query_struct;';
                                    end
                                else
                                    code_cell{end+1} = '% No specific static text queries found in source.';
                                end
                                
                                example_struct = struct('name', 'Example', 'code', {code_cell});
                                fid_e = fopen(fullfile(param_dir, 'Example.json'), 'w');
                                fprintf(fid_e, '%s', jsonencode(example_struct, 'PrettyPrint', true));
                                fclose(fid_e);
                                
                                rehash; pause(0.5); 
                                
                                new_item.calculatorClass = chosenClass; new_item.instanceName = dlg_ans{1};
                                new_item.selected_param_name = 'Example'; 
                                new_item.plot_output = 0; 
                                if isempty(current_pipeline.items)
                                    new_item.order = 1;
                                    current_pipeline.items = new_item;
                                else
                                    new_item.order = numel(current_pipeline.items) + 1;
                                    if iscell(current_pipeline.items), current_pipeline.items{end+1} = new_item;
                                    else, current_pipeline.items(end+1) = new_item; end
                                end
                                
                                ndi.cpipeline.savePipelineFile(ud.pipelinePath, current_pipeline);
                                ndi.cpipeline.edit('command','LoadPipelines','selectedPipeline',current_pipeline.pipeline_name,'fig',fig);
                            end
                        end
                    end
                    
                case 'DeleteCalculatorInstanceButton'
                    pipelinePopupObj = findobj(fig,'tag','PipelinePopup');
                    val = get(pipelinePopupObj, 'value');
                    if val <= 1, return; end
                    current_pipeline = ud.pipelineList(val - 1);
                    if isfield(ud, 'selected_row_index') && ~isempty(ud.selected_row_index)
                        [~, s_idx] = sort([current_pipeline.items.order]);
                        current_pipeline.items(s_idx(ud.selected_row_index)) = [];
                        if ~isempty(current_pipeline.items)
                             [~, s2_idx] = sort([current_pipeline.items.order]);
                             current_pipeline.items = current_pipeline.items(s2_idx);
                             for k=1:numel(current_pipeline.items), current_pipeline.items(k).order = k; end
                        end
                        ndi.cpipeline.savePipelineFile(ud.pipelinePath, current_pipeline);
                        ndi.cpipeline.edit('command','LoadPipelines','selectedPipeline',current_pipeline.pipeline_name,'fig',fig);
                    end
                    
                case 'SelectRow'
                    ud.selected_row_index = options.slider_val; set(fig, 'userdata', ud);
                    for i=1:numel(ud.gui_rows)
                        if ~isempty(ud.gui_rows(i).bg)
                            col = [1 1 1]; if i == ud.selected_row_index, col = [0.7 0.85 1]; end
                            set(ud.gui_rows(i).bg, 'BackgroundColor', col);
                            set(ud.gui_rows(i).name, 'BackgroundColor', col);
                            set(ud.gui_rows(i).plot_check, 'BackgroundColor', col);
                        end
                    end
            end
        end
        
        function savePipelineFile(root_path, pipelineStruct)
            target_file = fullfile(root_path, 'Pipelines', pipelineStruct.pipeline_name, 'pipeline.json');
            fid = fopen(target_file, 'w'); fprintf(fid, '%s', jsonencode(pipelineStruct, 'PrettyPrint', true)); fclose(fid);
        end
        
        function pipelineList = getPipelines(root_dir)
            pipelines_dir = fullfile(root_dir, 'Pipelines');
            if ~isfolder(pipelines_dir), mkdir(pipelines_dir); end
            d = dir(pipelines_dir); nameList = {d([d.isdir]).name}';
            nameList(ismember(nameList,{'.','..'})) = [];
            pipelineList = [];
            for i = 1:numel(nameList)
                json_path = fullfile(pipelines_dir, nameList{i}, 'pipeline.json');
                if isfile(json_path)
                    try
                        p_struct = jsondecode(fileread(json_path));
                        if ~isfield(p_struct, 'items'), p_struct.items = []; end
                        if iscolumn(p_struct.items), p_struct.items = p_struct.items'; end
                        if iscell(p_struct.items)
                             temp = [];
                             for k=1:numel(p_struct.items), temp = [temp, p_struct.items{k}]; end
                             p_struct.items = temp;
                        end
                        % Ensure new fields exist on load to avoid crashes
                        if ~isempty(p_struct.items)
                            if ~isfield(p_struct.items, 'plot_output')
                                for k=1:numel(p_struct.items)
                                    p_struct.items(k).plot_output = 0; 
                                end
                            end
                        end
                        pipelineList = [pipelineList, p_struct];
                    catch, end
                end
            end
            if isempty(pipelineList), pipelineList = struct('pipeline_name',{}, 'items',{}); end
        end
    end
end