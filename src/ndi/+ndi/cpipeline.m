classdef cpipeline
    % A class for managing pipelines of ndi.calculator objects in NDI.
    properties (SetAccess=protected,GetAccess=public)
    end % properties
    methods
    end % methods
    methods (Static)
        function p = defaultPath()
            % Returns the root 'My Pipelines' folder
            p = fullfile(ndi.common.PathConstants.LogFolder, '..', 'My Pipelines');
            if ~isfolder(p)
                mkdir(p);
            end
            % Ensure subdirectories exist
            if ~isfolder(fullfile(p, 'Pipelines')), mkdir(fullfile(p, 'Pipelines')); end
            if ~isfolder(fullfile(p, 'Instances')), mkdir(fullfile(p, 'Instances')); end
        end
        
        function edit(options)
            arguments
                options.command (1,:) char = 'new'
                options.pipelinePath (1,:) char = ndi.cpipeline.defaultPath()
                options.session ndi.session = ndi.session.empty()
                options.window_params (1,1) struct = struct('height', 600, 'width', 700)
                options.fig {mustBeA(options.fig,["matlab.ui.Figure","double"])} = []
                options.selectedPipeline (1,:) char = ''
                options.pipeline_name (1,:) char = ''
                options.slider_val (1,1) double = 0
            end
            
            fig = options.fig;
            if ~strcmpi(options.command,'new') && isempty(fig)
                error('The ''fig'' argument must be provided for all commands except ''new''.');
            end
            
            if strcmpi(options.command,'new')
                if isempty(fig), fig = figure; end
                command = 'NewWindow';
                if ~isempty(options.pipelinePath) && isfolder(options.pipelinePath)
                    ud.pipelinePath = options.pipelinePath;
                    ud.pipelineList = []; 
                    ud.pipelineListChar = {}; 
                    ud.linked_object = options.session;
                    ud.gui_rows = []; 
                    ud.row_params = {}; 
                    ud.selected_row_index = []; 
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
                    
                    fig_bg_color = [0.8 0.8 0.8];
                    edit_bg_color = [1 1 1];
                    top = options.window_params.height;
                    
                    margin = 0.04; 
                    row_h = 0.04;  
                    
                    set(fig,'position',[50 50 options.window_params.width top], 'Color', fig_bg_color, ...
                        'NumberTitle','off', 'Name',['Editing Pipelines at ' ud.pipelinePath], ...
                        'MenuBar','none', 'ToolBar','none', 'Units','normalized', 'Resize','on');
                    
                    y = 1 - margin - row_h;
                    
                    % --- TOP CONTROLS ---
                    uicontrol(uid.txt,'Units','normalized','position',[margin y 0.4 row_h],'string','Select Pipeline / Instance:',...
                        'BackgroundColor',fig_bg_color,'FontWeight','bold','HorizontalAlignment','left');
                    y = y - row_h;
                    uicontrol(uid.popup,'Units','normalized','position',[margin y 0.94 row_h],...
                        'string',ud.pipelineListChar,'tag','PipelinePopup','callback',callbackstr,'BackgroundColor',edit_bg_color);
                    
                    y = y - row_h - 0.02; 
                    
                    uicontrol(uid.txt,'Units','normalized','position',[margin y 0.4 row_h],'string','NDI Data:',...
                         'BackgroundColor',fig_bg_color,'FontWeight','bold','HorizontalAlignment','left');
                    y = y - row_h;
                    uicontrol(uid.popup,'Units','normalized','position',[margin y 0.94 row_h],...
                        'string',{'None'},'tag','PipelineObjectVariablePopup','callback',callbackstr,'BackgroundColor',edit_bg_color);
                    
                    y = y - 0.05; 
                    
                    header_y = y;
                    uicontrol(uid.txt,'Units','normalized','position',[margin header_y 0.4 row_h],'string','Calculator Instance',...
                        'BackgroundColor',fig_bg_color,'FontWeight','bold','HorizontalAlignment','left');
                    uicontrol(uid.txt,'Units','normalized','position',[0.5 header_y 0.4 row_h],'string','Input Parameters',...
                        'BackgroundColor',fig_bg_color,'FontWeight','bold','HorizontalAlignment','left');
                    
                    list_top = header_y; 
                    bottom_area_height = 0.20;
                    list_height = list_top - bottom_area_height;
                    list_bottom = bottom_area_height + 0.01;
                    
                    panel_pos = [margin, list_bottom, 1-(2*margin), list_height];
                    uipanel('Units','normalized', 'Position', panel_pos, 'BackgroundColor', [1 1 1], ...
                        'Tag', 'ListContainerPanel', 'BorderType', 'line', 'HighlightColor', [0.6 0.6 0.6]);
                    
                    slider_w = 0.04;
                    uicontrol('Style','slider','Units','normalized',...
                        'Position',[panel_pos(1)+panel_pos(3), list_bottom, slider_w, list_height],...
                        'Tag','ListSlider', 'Callback', callbackstr, 'Min', 0, 'Max', 1, 'Value', 1);
                    
                    % --- BUTTONS ---
                    btn_h = 0.05; 
                    gap_v = 0.015; 
                    gap_h = 0.015; 
                    
                    y_row_top = 0.11; 
                    y_row_bot = y_row_top - btn_h - gap_v;
                    btn_w = 0.18; 
                    
                    % Top Row: New, Delete, SAVE
                    x1 = margin;
                    uicontrol(uid.button,'Units','normalized','position',[x1 y_row_top btn_w btn_h],...
                        'string','New Pipeline','tag','NewPipelineButton','callback',callbackstr);
                    x2 = x1 + btn_w + gap_h;
                    uicontrol(uid.button,'Units','normalized','position',[x2 y_row_top btn_w btn_h],...
                        'string','Delete Pipeline','tag','DeletePipelineButton','callback',callbackstr);
                    x3 = x2 + btn_w + gap_h;
                    uicontrol(uid.button,'Units','normalized','position',[x3 y_row_top btn_w btn_h],...
                        'string','Save Pipeline','tag','SavePipelineButton','callback',callbackstr, ...
                        'Tooltip', 'Save current configuration as a shareable Instance');
                    
                    % Bottom Row: New Calc, Delete Calc, Edit Calc
                    uicontrol(uid.button,'Units','normalized','position',[x1 y_row_bot btn_w btn_h],...
                        'string','New Calculator','tag','NewCalculatorInstanceButton','callback',callbackstr);
                    uicontrol(uid.button,'Units','normalized','position',[x2 y_row_bot btn_w btn_h],...
                        'string','Delete Calculator','tag','DeleteCalculatorInstanceButton','callback',callbackstr);
                    uicontrol(uid.button,'Units','normalized','position',[x3 y_row_bot btn_w btn_h],...
                        'string','Edit Calculator','tag','EditButton','callback',callbackstr);
                    
                    run_x = x3 + btn_w + 0.05; 
                    run_w = 1 - run_x - margin;
                    total_btn_block_h = (y_row_top + btn_h) - y_row_bot;
                    run_h = 0.08; 
                    run_y = y_row_bot + (total_btn_block_h - run_h)/2;
                    
                    uicontrol(uid.button,'Units','normalized','position',[run_x run_y run_w run_h],...
                        'string','RUN PIPELINE','tag','RunButton','callback',callbackstr, ...
                        'FontWeight','bold', 'FontSize', 10, 'BackgroundColor',[0.8 1 0.8]);
                    ndi.cpipeline.edit('command','RefreshObjectVariablePopup','fig',fig);
                    ndi.cpipeline.edit('command','LoadPipelines','fig',fig);
                    
                case 'UpdateCalculatorInstanceList'
                    if ~isfield(ud,'row_params'), ud.row_params = {}; set(fig,'userdata',ud); end
                    container = findobj(fig, 'Tag', 'ListContainerPanel');
                    delete(container.Children); 
                    pipelinePopupObj = findobj(fig,'tag','PipelinePopup');
                    val = get(pipelinePopupObj, 'value');
                    str = get(pipelinePopupObj, 'string');
                    
                    if val <= 1 || isempty(str)
                        ud.gui_rows = []; set(fig,'userdata',ud); return;
                    end
                    
                    selected_pipeline = ud.pipelineList(val);
                    is_instance = strcmp(selected_pipeline.type, 'instance');
                    
                    % Toggle Button Enable State based on type
                    edit_btns = findobj(fig, '-regexp', 'Tag', '(NewCalculator|DeleteCalculator|EditButton|NewPipeline|DeletePipeline)');
                    
                    if is_instance
                        enable_val = 'off';
                    else
                        enable_val = 'on';
                    end
                    
                    set(edit_btns, 'Enable', enable_val);
                    set(findobj(fig,'Tag','SavePipelineButton'), 'Enable', enable_val);
                    
                    % Specifically handle EditButton text
                    editBtn = findobj(fig,'Tag','EditButton');
                    if is_instance
                        set(editBtn, 'Enable', 'on', 'String', 'View Calculator');
                    else
                        set(editBtn, 'Enable', 'on', 'String', 'Edit Calculator');
                    end
                    
                    calc_list = selected_pipeline.calculatorInstances;
                    n_calcs = numel(calc_list);
                    row_h_pix = 30; 
                    total_h_pix = n_calcs * row_h_pix;
                    
                    set(container, 'Units', 'pixels');
                    p_pos = get(container, 'Position');
                    panel_h = p_pos(4);
                    set(container, 'Units', 'normalized');
                    
                    slider = findobj(fig, 'Tag', 'ListSlider');
                    if total_h_pix > panel_h
                        set(slider, 'Enable', 'on', 'Min', 0, 'Max', total_h_pix - panel_h, ...
                            'SliderStep', [row_h_pix/(total_h_pix-panel_h), 3*row_h_pix/(total_h_pix-panel_h)]);
                    else
                        set(slider, 'Enable', 'off', 'Value', 0, 'Max', 0);
                    end
                    
                    slider_val = get(slider, 'Value');
                    slider_max = get(slider, 'Max');
                    scroll_offset = slider_max - slider_val;
                    
                    ud.gui_rows = struct('bg',{},'name',{},'param',{},'calc_class',{});
                    
                    % Determine Path for Parameter Loading
                    if ~is_instance
                        pipeline_dir = fullfile(ud.pipelinePath, 'Pipelines', selected_pipeline.pipeline_name);
                    end
                    
                    for i = 1:n_calcs
                        row_y_bottom = panel_h - (i * row_h_pix) + scroll_offset;
                        
                        if (row_y_bottom + row_h_pix > 0) && (row_y_bottom < panel_h + row_h_pix)
                            y_norm = row_y_bottom / panel_h;
                            h_norm = row_h_pix / panel_h;
                            
                            bg_color = [1 1 1];
                            if isfield(ud,'selected_row_index') && ~isempty(ud.selected_row_index) && ud.selected_row_index == i
                                bg_color = [0.7 0.85 1];
                            end
                            
                            bg = uicontrol(container, 'Style', 'text', 'Units', 'normalized', ...
                                'Position', [0, y_norm, 1, h_norm], 'BackgroundColor', bg_color, ...
                                'Enable', 'inactive', ...
                                'ButtonDownFcn', @(s,e)ndi.cpipeline.edit('command','SelectRow','fig',fig,'slider_val',i));
                            
                            txt = uicontrol(container, 'Style', 'text', 'Units', 'normalized', ...
                                'Position', [0.02, y_norm, 0.45, h_norm*0.8], 'String', calc_list(i).instanceName, ...
                                'BackgroundColor', bg_color, 'HorizontalAlignment', 'left', 'FontSize', 10, ...
                                'Enable', 'inactive', ...
                                'ButtonDownFcn', @(s,e)ndi.cpipeline.edit('command','SelectRow','fig',fig,'slider_val',i));
                            
                            calc_class = calc_list(i).calculatorClassname;
                            
                            if is_instance
                                % In Instance mode, options are fixed to the saved parameter name
                                opts = {calc_list(i).selected_param_name}; 
                                enable_pop = 'off';
                            else
                                % In Pipeline mode, load available options
                                opts = {'Default'};
                                % Pass the pipeline-specific user_parameter file
                                user_param_file = fullfile(pipeline_dir, 'user_parameters.json');
                                [names, ~] = ndi.calculator.readParameterCode(calc_class, user_param_file);
                                if ~isempty(names), opts = [opts, names]; end
                                
                                if ~isempty(ud.linked_object)
                                    try
                                        search_q = ndi.query('ndi_document.name','.*',''); 
                                        docs = ud.linked_object.search('ndi_document', search_q);
                                        for d=1:numel(docs)
                                            if isfield(docs{d}.document_properties.ndi_document,'name')
                                                opts{end+1} = docs{d}.document_properties.ndi_document.name;
                                            end
                                        end
                                    catch, end
                                end
                                opts = unique(opts, 'stable');
                                enable_pop = 'on';
                            end
                            
                            current_val = 1; 
                            if i <= numel(ud.row_params) && ~isempty(ud.row_params{i})
                                idx = find(strcmp(opts, ud.row_params{i}));
                                if ~isempty(idx), current_val = idx; end
                            end
                            
                            pop = uicontrol(container, 'Style', 'popupmenu', 'Units', 'normalized', ...
                                'Position', [0.5, y_norm+0.1*h_norm, 0.48, h_norm*0.8], 'String', opts, ...
                                'Value', current_val, ...
                                'BackgroundColor', [1 1 1], ...
                                'Enable', enable_pop, ...
                                'Callback', @(s,e)ndi.cpipeline.edit('command','ParamChange','fig',fig,'slider_val',i));
                            
                            ud.gui_rows(i).bg = bg;
                            ud.gui_rows(i).name = txt;
                            ud.gui_rows(i).param = pop;
                            ud.gui_rows(i).calc_class = calc_class;
                        else
                            ud.gui_rows(i).bg = [];
                        end
                    end
                    set(fig, 'userdata', ud);
                    
                case 'ParamChange'
                    idx = options.slider_val;
                    if idx <= numel(ud.gui_rows) && isvalid(ud.gui_rows(idx).param)
                        items = get(ud.gui_rows(idx).param, 'String');
                        val = get(ud.gui_rows(idx).param, 'Value');
                        ud.row_params{idx} = items{val}; 
                        set(fig, 'userdata', ud);
                    end
                    
                case 'ListSlider'
                    val = get(gcbo, 'Value');
                    max_val = get(gcbo, 'Max');
                    ndi.cpipeline.edit('command','UpdateCalculatorInstanceList','fig',fig, 'slider_val', max_val - val);
                    
                case 'SelectRow'
                    idx = options.slider_val;
                    ud.selected_row_index = idx;
                    set(fig, 'userdata', ud);
                    for i=1:numel(ud.gui_rows)
                        if ~isempty(ud.gui_rows(i).bg) && isvalid(ud.gui_rows(i).bg)
                            if i == idx
                                set(ud.gui_rows(i).bg, 'BackgroundColor', [0.7 0.85 1]);
                                set(ud.gui_rows(i).name, 'BackgroundColor', [0.7 0.85 1]);
                            else
                                set(ud.gui_rows(i).bg, 'BackgroundColor', [1 1 1]);
                                set(ud.gui_rows(i).name, 'BackgroundColor', [1 1 1]);
                            end
                        end
                    end
                    
                case 'RunButton'
                    pipelinePopupObj = findobj(fig,'tag','PipelinePopup');
                    val = get(pipelinePopupObj, 'value');
                    if val <= 1, msgbox('Select a pipeline.', 'Error', 'modal'); return; end
                    
                    % Determine if Instance
                    selected_pipeline = ud.pipelineList(val);
                    is_instance = strcmp(selected_pipeline.type, 'instance');
                    
                    dataPopupObj = findobj(fig, 'tag', 'PipelineObjectVariablePopup');
                    data_val = get(dataPopupObj, 'value');
                    data_list = get(dataPopupObj, 'userdata'); 
                    if data_val > 1 && numel(data_list) >= data_val
                        selected_var = data_list{data_val};
                        try, ud.linked_object = evalin('base', selected_var); set(fig, 'userdata', ud);
                        catch, msgbox(['Error accessing variable "' selected_var '" in base workspace.'], 'Error', 'modal'); return; end
                    end
                    if isempty(ud.linked_object), msgbox('Please link an NDI Data object.', 'Error', 'modal'); return; end
                    
                    calc_instances = selected_pipeline.calculatorInstances;
                    if isempty(calc_instances), return; end
                    
                    % If not an instance, set up path to read user_params
                    if ~is_instance
                        pipeline_dir = fullfile(ud.pipelinePath, 'Pipelines', selected_pipeline.pipeline_name);
                        user_param_file = fullfile(pipeline_dir, 'user_parameters.json');
                    end
                    
                    fprintf('\n\n--- PIPELINE EXECUTION STARTED ---\n');
                    h_wait = waitbar(0, 'Running Pipeline...');
                    
                    try
                        for i = 1:numel(calc_instances)
                            this_instance = calc_instances(i);
                            calc_class = this_instance.calculatorClassname;
                            calc_name = this_instance.instanceName;
                            
                            % Determine Parameter Source
                            if is_instance
                                param_source = this_instance.selected_param_name;
                                param_code_text = this_instance.selected_param_code; % Embedded code
                            else
                                param_source = 'Default';
                                if i <= numel(ud.row_params) && ~isempty(ud.row_params{i})
                                    param_source = ud.row_params{i};
                                elseif i <= numel(ud.gui_rows) && ~isempty(ud.gui_rows(i).param) && isvalid(ud.gui_rows(i).param)
                                    str = get(ud.gui_rows(i).param, 'String');
                                    val = get(ud.gui_rows(i).param, 'Value');
                                    if iscell(str), param_source = str{val}; else, param_source = str; end
                                end
                                param_code_text = ''; 
                            end
                            
                            fprintf('\nSTEP %d: %s (Params: %s)\n', i, calc_name, param_source);
                            waitbar((i-1)/numel(calc_instances), h_wait, sprintf('Running %s...', calc_name));
                            
                            if exist(calc_class, 'class')
                                calc_obj = feval(calc_class, ud.linked_object);
                                params = struct();
                                if strcmp(param_source, 'Default')
                                    params = calc_obj.default_search_for_input_parameters();
                                else
                                    code = '';
                                    found_code = false;
                                    
                                    if is_instance
                                        % Use embedded code from instance file
                                        code = param_code_text;
                                        found_code = ~isempty(code);
                                        % Fallback if stored code is empty but it was 'Default'
                                        if isempty(code) && strcmp(param_source, 'Default')
                                            try
                                                code = ndi.calculator.parameter_default(calc_class);
                                                found_code = true;
                                            catch, end
                                        end
                                    else
                                        % Look up code in pipeline file
                                        [names, contents] = ndi.calculator.readParameterCode(calc_class, user_param_file);
                                        idx = find(strcmp(names, param_source), 1);
                                        if ~isempty(idx)
                                            code = contents{idx};
                                            found_code = true;
                                        end
                                    end
                                    
                                    if found_code
                                        % --- FIX: SANITIZE CODE FOR EVAL ---
                                        if iscell(code), code = strjoin(code, newline); end
                                        if isstring(code) && numel(code) > 1, code = strjoin(code, newline); end
                                        if isstring(code), code = char(code); end
                                        % -----------------------------------
                                        
                                        S = ud.linked_object; pipeline_session = S;
                                        try
                                            if exist('parameters','var'), clear parameters; end
                                            eval(code);
                                            if exist('parameters','var'), params = parameters;
                                            else, error('Custom code did not create "parameters".'); end
                                        catch e
                                            error(sprintf('Error in param code "%s":\n%s', param_source, e.message));
                                        end
                                    else
                                        % Fallback to searching DB for a named doc
                                        try
                                            q = ndi.query('ndi_document.name','exact_string',param_source);
                                            d = ud.linked_object.search('ndi_document',q);
                                            if ~isempty(d), params = d{1}; 
                                            else, params = calc_obj.default_search_for_input_parameters(); end
                                        catch
                                            params = calc_obj.default_search_for_input_parameters();
                                        end
                                    end
                                end
                                
                                if ~isstruct(params) && ~isa(params,'ndi.document')
                                    w = calc_obj.default_search_for_input_parameters(); w.input_parameters = params; params = w;
                                elseif isstruct(params) && ~isfield(params,'input_parameters')
                                    w = calc_obj.default_search_for_input_parameters(); w.input_parameters = params; params = w;
                                end
                                generated_docs = calc_obj.run('NoAction', params);
                                num_docs = 0;
                                if iscell(generated_docs), num_docs = numel(generated_docs); 
                                elseif ~isempty(generated_docs), num_docs = numel(generated_docs); end
                                fprintf('  Result: %d docs generated/updated.\n', num_docs);
                            end
                        end
                        if isvalid(h_wait), delete(h_wait); end
                        m = msgbox('Pipeline Finished!', 'Success', 'modal');
                        figure(fig); 
                    catch e
                        if isvalid(h_wait), delete(h_wait); end
                        errordlg(e.message, 'Execution Error', 'modal');
                    end
                case {'LoadPipelines','RefreshObjectVariablePopup','PipelinePopup','PipelineObjectVariablePopup'}
                    if strcmp(command,'LoadPipelines')
                        ud.pipelineList = ndi.cpipeline.getPipelines(ud.pipelinePath);
                        ud.pipelineListChar = ndi.cpipeline.pipelineListToChar(ud.pipelineList);
                        set(fig,'userdata',ud);
                        set(findobj(fig,'Tag','PipelinePopup'),'String',ud.pipelineListChar);
                        
                        % If a selectedPipeline was passed, select it
                        if isfield(options, 'selectedPipeline') && ~isempty(options.selectedPipeline)
                           idx = find(strcmp(ud.pipelineListChar, options.selectedPipeline));
                           if ~isempty(idx), set(findobj(fig,'Tag','PipelinePopup'),'Value',idx(1)); end
                        end
                        
                    elseif strcmp(command,'RefreshObjectVariablePopup')
                         vars = evalin('base', 'whos');
                         vn = {};
                         for i=1:length(vars), if ismember(vars(i).class, {'ndi.session','ndi.session.dir','ndi.dataset'}), vn{end+1}=vars(i).name; end; end
                         set(findobj(fig,'Tag','PipelineObjectVariablePopup'),'String',[{'None'}, vn]);
                         set(findobj(fig,'Tag','PipelineObjectVariablePopup'),'userdata',[{[]}, vn]);
                    end
                    ndi.cpipeline.edit('command','UpdateCalculatorInstanceList','fig',fig);
                
                case 'SavePipelineButton'
                    % Logic: Gather current pipeline + selected params, save to Instances/
                    pipelinePopupObj = findobj(fig,'tag','PipelinePopup');
                    val = get(pipelinePopupObj, 'value');
                    if val <= 1, return; end
                    
                    selected_pipeline = ud.pipelineList(val);
                    if strcmp(selected_pipeline.type, 'instance')
                         msgbox('Cannot save an Instance as another Instance (not implemented). Load the original pipeline to make changes.', 'Info', 'modal');
                         return;
                    end
                    
                    ans = inputdlg('Enter name for this Pipeline Instance:', 'Save Instance');
                    if isempty(ans), return; end
                    instance_name = ans{1};
                    
                    % Build structure
                    instanceStruct.pipeline_name = selected_pipeline.pipeline_name;
                    instanceStruct.type = 'instance';
                    instanceStruct.calculatorInstances = selected_pipeline.calculatorInstances;
                    
                    % Path to current pipeline parameters to fetch code
                    pipeline_dir = fullfile(ud.pipelinePath, 'Pipelines', selected_pipeline.pipeline_name);
                    user_param_file = fullfile(pipeline_dir, 'user_parameters.json');
                    
                    % Iterate rows to lock in params
                    for i = 1:numel(instanceStruct.calculatorInstances)
                        param_name = 'Default';
                        param_code = '';
                        
                        if i <= numel(ud.row_params) && ~isempty(ud.row_params{i})
                             param_name = ud.row_params{i};
                        elseif i <= numel(ud.gui_rows) && ~isempty(ud.gui_rows(i).param)
                             items = get(ud.gui_rows(i).param, 'String');
                             idx = get(ud.gui_rows(i).param, 'Value');
                             if iscell(items), param_name = items{idx}; else, param_name = items; end
                        end
                        
                        % If custom, fetch the code now and save it into the instance
                        if ~strcmp(param_name, 'Default')
                             [names, contents] = ndi.calculator.readParameterCode(instanceStruct.calculatorInstances(i).calculatorClassname, user_param_file);
                             k = find(strcmp(names, param_name), 1);
                             if ~isempty(k)
                                 param_code = contents{k};
                             end
                        else
                             % UPDATED: If Default, generate and save the default code string
                             param_code = ndi.calculator.parameter_default(instanceStruct.calculatorInstances(i).calculatorClassname);
                        end
                        
                        instanceStruct.calculatorInstances(i).selected_param_name = param_name;
                        instanceStruct.calculatorInstances(i).selected_param_code = param_code;
                    end
                    
                    % Save
                    save_path = fullfile(ud.pipelinePath, 'Instances', [matlab.lang.makeValidName(instance_name) '.json']);
                    fid = fopen(save_path, 'w');
                    fprintf(fid, '%s', jsonencode(instanceStruct, 'PrettyPrint', true));
                    fclose(fid);
                    
                    msgbox(['Instance "' instance_name '" saved successfully.'], 'Success');
                    ndi.cpipeline.edit('command','LoadPipelines','fig',fig);

                case 'DeleteCalculatorInstanceButton'
                     if isfield(ud, 'selected_row_index') && ~isempty(ud.selected_row_index)
                         pipelinePopupObj = findobj(fig,'tag','PipelinePopup');
                         val = get(pipelinePopupObj, 'value');
                         str = get(pipelinePopupObj, 'string');
                         pipeline_name = str{val};
                         selected_pipeline = ud.pipelineList(val);
                         if strcmp(selected_pipeline.type, 'instance'), return; end % Safety
                         
                         idx = ud.selected_row_index;
                         if idx <= numel(selected_pipeline.calculatorInstances)
                             fname = selected_pipeline.calculatorInstances(idx).JSONFilename;
                             full_f = fullfile(ud.pipelinePath, 'Pipelines', pipeline_name, fname);
                             try
                                 if isfile(full_f), delete(full_f); end
                                 ndi.cpipeline.edit('command','LoadPipelines','fig',fig); 
                             catch ME
                                 errordlg(['Could not delete file: ' ME.message]);
                             end
                         end
                     else
                         msgbox('Please select a calculator instance to delete.', 'Error', 'modal');
                     end
                     
                case 'EditButton'
                    pipelinePopupObj = findobj(fig,'tag','PipelinePopup');
                    val = get(pipelinePopupObj, 'value');
                    selected_pipeline = ud.pipelineList(val);
                    is_instance = strcmp(selected_pipeline.type, 'instance');
                    
                    if isfield(ud, 'selected_row_index') && ~isempty(ud.selected_row_index)
                         idx = ud.selected_row_index;
                         fname = selected_pipeline.calculatorInstances(idx).JSONFilename;
                         
                         if is_instance
                             % View Mode: Pass embedded code directly
                             raw_code = selected_pipeline.calculatorInstances(idx).selected_param_code;
                             
                             if isfield(selected_pipeline.calculatorInstances(idx), 'selected_param_name')
                                 param_name_str = selected_pipeline.calculatorInstances(idx).selected_param_name;
                             else
                                 param_name_str = 'View Only';
                             end
                             
                             % SANITIZE CODE INPUT TO PREVENT ERRORS
                             if isstring(raw_code), raw_code = char(raw_code); end
                             if iscell(raw_code), raw_code = strjoin(raw_code, newline); end
                             if isempty(raw_code), raw_code = ''; end
                             
                             % FALLBACK: If code is empty but it was 'Default', generate it
                             if isempty(raw_code) && strcmp(param_name_str, 'Default')
                                 raw_code = ndi.calculator.parameter_default(selected_pipeline.calculatorInstances(idx).calculatorClassname);
                             end
                             
                             param_code = raw_code;
                             
                             ndi.calculator.graphical_edit_calculator('command','Edit','filename','', ...
                                 'session',ud.linked_object, 'pipelinePath', '', ...
                                 'viewOnly', true, 'code', param_code, ...
                                 'paramName', param_name_str, ...
                                 'name', selected_pipeline.calculatorInstances(idx).instanceName, ...
                                 'calculatorClassname', selected_pipeline.calculatorInstances(idx).calculatorClassname);
                         else
                             % Edit Mode
                             str = get(pipelinePopupObj, 'string');
                             pipeline_name = str{val};
                             pipeline_dir = fullfile(ud.pipelinePath, 'Pipelines', pipeline_name);
                             full_f = fullfile(pipeline_dir, fname);
                             ndi.calculator.graphical_edit_calculator('command','Edit','filename',full_f,'session',ud.linked_object, 'pipelinePath', pipeline_dir);
                         end
                    else
                         action_word = 'edit';
                         if is_instance, action_word = 'view'; end
                         msgbox(['Please select a calculator instance to ' action_word '.'], 'Error', 'modal');
                    end
                    
                case 'NewPipelineButton'
                    read_dir = fullfile(ud.pipelinePath, 'Pipelines');
                    [success,filename,replaces] = ndi.util.choosefileordir(read_dir, {'Pipeline name:'}, {['untitled']}, 'Save new pipeline', {['']});
                    if success
                        if replaces, rmdir(fullfile(read_dir, filename), 's'); end
                        mkdir(read_dir,filename);
                        ndi.cpipeline.edit('command','LoadPipelines','selectedPipeline',filename,'fig',fig);
                    end
                    
                case 'DeletePipelineButton'
                    pipelinePopupObj = findobj(fig,'tag','PipelinePopup');
                    val = get(pipelinePopupObj, 'value');
                    if val>1
                        selected_pipeline = ud.pipelineList(val);
                        if strcmp(selected_pipeline.type, 'instance')
                            target_path = fullfile(ud.pipelinePath, 'Instances', [selected_pipeline.display_name '.json']);
                            msg = ['Delete Instance "' selected_pipeline.display_name '"?'];
                            is_dir = false;
                        else
                            target_path = fullfile(ud.pipelinePath, 'Pipelines', selected_pipeline.pipeline_name);
                            msg = ['Delete Pipeline Folder "' selected_pipeline.pipeline_name '" and all contents?'];
                            is_dir = true;
                        end
                        
                        button = questdlg(msg, 'Confirm Delete', 'Yes', 'No', 'No');
                        if strcmp(button, 'Yes')
                            if is_dir
                                rmdir(target_path, 's');
                            else
                                delete(target_path);
                            end
                            % ADDED: Reset popup to 1 before reloading
                            set(findobj(fig,'Tag','PipelinePopup'), 'Value', 1);
                            ndi.cpipeline.edit('command','LoadPipelines','fig',fig);
                        end
                    end
                case 'NewCalculatorInstanceButton'
                    pipelinePopupObj = findobj(fig,'tag','PipelinePopup');
                    val = get(pipelinePopupObj, 'value');
                    if val > 1
                        str = get(pipelinePopupObj, 'string');
                        pipeline_name = str{val};
                        selected_pipeline = ud.pipelineList(val);
                        if strcmp(selected_pipeline.type, 'instance'), return; end
                        
                        calcTypeList = ndi.calculator.find_calculator_subclasses();
                        if ~isempty(calcTypeList)
                            [calcTypeIndex, isSel] = listdlg('ListString',calcTypeList);
                            if isSel
                                answer = inputdlg('Name:');
                                if ~isempty(answer)
                                    calcName = answer{1};
                                    newC = ndi.cpipeline.setDefaultCalculatorInstance(calcTypeList{calcTypeIndex}, calcName);
                                    
                                    try
                                        pipeline_dir = fullfile(ud.pipelinePath, 'Pipelines', pipeline_name);
                                        ndi.cpipeline.saveCalculatorInstanceFile(pipeline_dir, newC);
                                        ndi.cpipeline.edit('command','LoadPipelines','fig',fig); 
                                    catch ME
                                        errordlg(['Error creating calculator instance: ' ME.message], 'Error');
                                    end
                                end
                            end
                        end
                    end
            end
        end
        % ... Helper functions ...
        function saveCalculatorInstanceFile(directory_path, instanceStruct)
             base_name = matlab.lang.makeValidName(instanceStruct.instanceName);
             filename = [base_name '.json'];
             full_p = fullfile(directory_path, filename);
             
             try
                 fid = fopen(full_p,'w'); 
                 if fid == -1, error('Cannot open file for writing. Check permissions.'); end
                 fprintf(fid, '%s', jsonencode(instanceStruct, 'PrettyPrint', true)); 
                 fclose(fid);
                 instanceStruct.JSONFilename = filename; 
             catch ME
                 if exist('fid','var') && fid > -1, fclose(fid); end
                 rethrow(ME);
             end
        end

        function calculatorInstanceList = getCalculatorInstancesFromPipeline(pipelineList, pipeline_name)
            % Deprecated mostly by direct access in UpdateCalculatorInstanceList, but kept for compat
            calculatorInstanceList = [];
            for i = 1:length(pipelineList)
                if strcmp(pipelineList(i).pipeline_name, pipeline_name)
                    calculatorInstanceList = pipelineList(i).calculatorInstances;
                end
            end
        end 
        function calculatorInstanceListChar = calculatorInstancesToChar(calculatorInstanceList)
            calculatorInstanceListChar = {};
            for i = 1:numel(calculatorInstanceList)
                calculatorInstanceListChar{i} = [calculatorInstanceList(i).instanceName ' (' calculatorInstanceList(i).JSONFilename ')'];
            end
        end
        function newCalculatorInstance = setDefaultCalculatorInstance(calculatorInstanceType, name)
            newCalculatorInstance.calculatorClassname = calculatorInstanceType;
            newCalculatorInstance.instanceName = name;
            newCalculatorInstance.default_options = containers.Map("if_document_exists_do","NoAction");
            newCalculatorInstance.JSONFilename = ''; % To be filled on save
        end
        function pipelineList = getPipelines(root_dir)
            % Load Pipelines (Folders)
            pipelines_dir = fullfile(root_dir, 'Pipelines');
            d = dir(pipelines_dir);
            isub = [d(:).isdir];
            nameList = {d(isub).name}';
            nameList(ismember(nameList,{'.','..'})) = [];
            
            % IMPORTANT: Initialize as 0x0 struct so empty pipelines don't count as 1 item
            empty_calc_struct = struct('calculatorClassname',{},'instanceName',{},'JSONFilename',{},'default_options',{});
            
            pipelineList = struct('pipeline_name', {}, 'type', {}, 'display_name', {}, 'calculatorInstances', {});
            
            pipelineList(1).pipeline_name = '---';
            pipelineList(1).display_name = '---';
            pipelineList(1).type = 'none';
            pipelineList(1).calculatorInstances = empty_calc_struct;
            
            % Process Editable Pipelines
            for i = 1:numel(nameList)
                p_struct.pipeline_name = nameList{i};
                p_struct.display_name = nameList{i};
                p_struct.type = 'definition';
                
                D = dir(fullfile(pipelines_dir, nameList{i}, '*.json'));
                temp_cell = {}; 
                if ~isempty(D)
                    for d_i = 1:numel(D)
                        if strcmp(D(d_i).name, 'user_parameters.json'), continue; end % Skip param file
                        full_json_path = fullfile(pipelines_dir, nameList{i}, D(d_i).name);
                        try
                            json_text = fileread(full_json_path);
                            if ~isempty(strtrim(json_text))
                                decoded_json = jsondecode(json_text);
                                if isfield(decoded_json, 'calculatorClassname')
                                    decoded_json.JSONFilename = D(d_i).name;
                                    temp_cell{end+1} = decoded_json;
                                end
                            end
                        catch, end
                    end
                end
                if ~isempty(temp_cell)
                    p_struct.calculatorInstances = [temp_cell{:}];
                else
                    p_struct.calculatorInstances = empty_calc_struct;
                end
                pipelineList(end+1) = p_struct;
            end
            
            % Process Saved Instances
            instances_dir = fullfile(root_dir, 'Instances');
            D_inst = dir(fullfile(instances_dir, '*.json'));
            for i = 1:numel(D_inst)
                 try
                     json_text = fileread(fullfile(instances_dir, D_inst(i).name));
                     inst_data = jsondecode(json_text);
                     if isfield(inst_data, 'type') && strcmp(inst_data.type, 'instance')
                         [~, fname, ~] = fileparts(D_inst(i).name);
                         p_struct.pipeline_name = inst_data.pipeline_name;
                         p_struct.display_name = [fname ' (Instance)'];
                         p_struct.type = 'instance';
                         p_struct.calculatorInstances = inst_data.calculatorInstances;
                         pipelineList(end+1) = p_struct;
                     end
                 catch, end
            end
        end
        function pipelineListChar = pipelineListToChar(pipelineList)
            pipelineListChar = {pipelineList.display_name};
        end
    end
end