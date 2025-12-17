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
                options.window_params (1,1) struct = struct('height', 600, 'width', 700)
                options.fig {mustBeA(options.fig,["matlab.ui.Figure","double"])} = []
                options.selectedPipeline (1,:) char = ''
                options.slider_val (1,1) double = 0
                options.order_idx (1,1) double = 0
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
                    margin = 0.04; row_h = 0.04;
                    
                    set(fig,'position',[50 50 options.window_params.width top], 'Color', fig_bg, ...
                        'NumberTitle','off', 'Name',['Editing Pipelines at ' ud.pipelinePath], ...
                        'MenuBar','none', 'ToolBar','none', 'Units','normalized', 'Resize','on');
                    
                    y = 1 - margin - row_h;
                    
                    % Top Controls
                    uicontrol(uid.txt,'Units','normalized','position',[margin y 0.4 row_h],'string','Select Pipeline:',...
                        'BackgroundColor',fig_bg,'FontWeight','bold','HorizontalAlignment','left');
                    y = y - row_h;
                    uicontrol(uid.popup,'Units','normalized','position',[margin y 0.94 row_h],...
                        'string',{'---'},'tag','PipelinePopup','callback',callbackstr,'BackgroundColor',edit_bg);
                    
                    y = y - row_h - 0.02; 
                    uicontrol(uid.txt,'Units','normalized','position',[margin y 0.4 row_h],'string','NDI Data:',...
                         'BackgroundColor',fig_bg,'FontWeight','bold','HorizontalAlignment','left');
                    y = y - row_h;
                    uicontrol(uid.popup,'Units','normalized','position',[margin y 0.94 row_h],...
                        'string',{'None'},'tag','PipelineObjectVariablePopup','callback',callbackstr,'BackgroundColor',edit_bg);
                    
                    y = y - 0.05; 
                    header_y = y;
                    
                    % Headers
                    uicontrol(uid.txt,'Units','normalized','position',[margin header_y 0.38 row_h],'string','Calculator Instance',...
                        'BackgroundColor',fig_bg,'FontWeight','bold','HorizontalAlignment','left');
                    uicontrol(uid.txt,'Units','normalized','position',[0.45 header_y 0.35 row_h],'string','Input Parameters',...
                        'BackgroundColor',fig_bg,'FontWeight','bold','HorizontalAlignment','left');
                    uicontrol(uid.txt,'Units','normalized','position',[0.82 header_y 0.12 row_h],'string','Order',...
                        'BackgroundColor',fig_bg,'FontWeight','bold','HorizontalAlignment','left');
                    
                    % Main List Area
                    list_top = header_y; 
                    bottom_area_height = 0.20;
                    list_height = list_top - bottom_area_height;
                    list_bottom = bottom_area_height + 0.01;
                    
                    panel_pos = [margin, list_bottom, 1-(2*margin), list_height];
                    
                    % LIST CONTAINER
                    uipanel('Units','normalized', 'Position', panel_pos, 'BackgroundColor', [1 1 1], ...
                        'Tag', 'ListContainerPanel', 'BorderType', 'line', 'HighlightColor', [0.6 0.6 0.6], ...
                        'Visible', 'on');
                    
                    slider_w = 0.04;
                    uicontrol('Style','slider','Units','normalized',...
                        'Position',[panel_pos(1)+panel_pos(3), list_bottom, slider_w, list_height],...
                        'Tag','ListSlider', 'Callback', callbackstr, 'Min', 0, 'Max', 1, 'Value', 1);
                    
                    % Buttons
                    btn_h = 0.05; gap = 0.015; 
                    y_row_top = 0.11; y_row_bot = y_row_top - btn_h - gap;
                    btn_w = 0.22; 
                    
                    x = margin;
                    uicontrol(uid.button,'Units','normalized','position',[x y_row_top btn_w btn_h],...
                        'string','New Pipeline','tag','NewPipelineButton','callback',callbackstr);
                    x = x + btn_w + gap;
                    uicontrol(uid.button,'Units','normalized','position',[x y_row_top btn_w btn_h],...
                        'string','Delete Pipeline','tag','DeletePipelineButton','callback',callbackstr);
                    
                    x = margin;
                    uicontrol(uid.button,'Units','normalized','position',[x y_row_bot btn_w btn_h],...
                        'string','New Calculator','tag','NewCalculatorInstanceButton','callback',callbackstr);
                    x = x + btn_w + gap;
                    uicontrol(uid.button,'Units','normalized','position',[x y_row_bot btn_w btn_h],...
                        'string','Delete Calculator','tag','DeleteCalculatorInstanceButton','callback',callbackstr);
                    x = x + btn_w + gap;
                    uicontrol(uid.button,'Units','normalized','position',[x y_row_bot btn_w btn_h],...
                        'string','Edit Calculator','tag','EditButton','callback',callbackstr);
                    
                    run_x = x + btn_w + 0.05; run_w = 1 - run_x - margin;
                    run_h = 0.08; run_y = y_row_bot + ((y_row_top+btn_h)-y_row_bot-run_h)/2;
                    
                    uicontrol(uid.button,'Units','normalized','position',[run_x run_y run_w run_h],...
                        'string','RUN PIPELINE','tag','RunButton','callback',callbackstr, ...
                        'FontWeight','bold', 'FontSize', 10, 'BackgroundColor',[0.8 1 0.8]);
                    
                    ndi.cpipeline.edit('command','RefreshObjectVariablePopup','fig',fig);
                    ndi.cpipeline.edit('command','LoadPipelines','fig',fig);
                case 'PipelinePopup'
                    ndi.cpipeline.edit('command','UpdateCalculatorInstanceList','fig',fig);
                    
                case 'UpdateCalculatorInstanceList'
                    container = findobj(fig, 'Tag', 'ListContainerPanel');
                    if ~isempty(container.Children), delete(container.Children); end
                    drawnow limitrate; 
                    
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
                    
                    row_h_pix = 30; total_h_pix = n_calcs * row_h_pix;
                    
                    slider = findobj(fig, 'Tag', 'ListSlider');
                    if total_h_pix > panel_h
                        set(slider, 'Enable', 'on', 'Min', 0, 'Max', total_h_pix - panel_h, ...
                            'SliderStep', [row_h_pix/(total_h_pix-panel_h), 5*row_h_pix/(total_h_pix-panel_h)]);
                    else
                        set(slider, 'Enable', 'off', 'Value', 0, 'Max', 0);
                    end
                    
                    slider_val = get(slider, 'Value'); slider_max = get(slider, 'Max');
                    scroll_offset = slider_max - slider_val;
                    
                    ud.gui_rows = struct('bg',{},'order_popup',{},'name',{},'param',{});
                    
                    for i = 1:n_calcs
                        item_top_virtual = (i-1) * row_h_pix; 
                        y_pix = panel_h + scroll_offset - item_top_virtual - row_h_pix;
                        if (y_pix + row_h_pix < 0) || (y_pix > panel_h), continue; end
                        bg_color = [1 1 1];
                        if isfield(ud,'selected_row_index') && ~isempty(ud.selected_row_index) && ud.selected_row_index == i
                            bg_color = [0.7 0.85 1];
                        end
                        
                        w_name = 0.40 * panel_w; w_param = 0.35 * panel_w; w_order = 0.12 * panel_w;
                        
                        bg = uicontrol(container, 'Style', 'text', 'Units', 'pixels', ...
                            'Position', [0, y_pix, panel_w, row_h_pix], ...
                            'BackgroundColor', bg_color, 'Enable', 'inactive', ...
                            'ButtonDownFcn', @(s,e)ndi.cpipeline.edit('command','SelectRow','fig',fig,'slider_val',i));
                        
                        txt = uicontrol(container, 'Style', 'text', 'Units', 'pixels', ...
                            'Position', [5, y_pix+5, w_name, row_h_pix-10], ...
                            'String', calc_items(i).instanceName, ...
                            'BackgroundColor', bg_color, 'HorizontalAlignment', 'left', 'FontSize', 10, ...
                            'Enable', 'inactive', 'ButtonDownFcn', @(s,e)ndi.cpipeline.edit('command','SelectRow','fig',fig,'slider_val',i));
                        
                        try, global_params = ndi.calculator.get_available_parameters(calc_items(i).calculatorClass, ud.pipelinePath);
                        catch, global_params = {'Error loading params'}; end
                        
                        curr_sel = calc_items(i).selected_param_name;
                        val_idx = find(strcmp(global_params, curr_sel));
                        if isempty(val_idx), val_idx = 1; end
                        
                        pop = uicontrol(container, 'Style', 'popupmenu', 'Units', 'pixels', ...
                            'Position', [10+w_name, y_pix+5, w_param, row_h_pix-8], ...
                            'String', global_params, 'Value', val_idx, 'BackgroundColor', [1 1 1], ...
                            'Callback', @(s,e)ndi.cpipeline.edit('command','ParamChange','fig',fig,'slider_val',i));
                        
                        order_popup = uicontrol(container, 'Style', 'popupmenu', 'Units', 'pixels', ...
                            'Position', [15+w_name+w_param, y_pix+5, w_order, row_h_pix-8], ...
                            'String', order_options, 'Value', calc_items(i).order, 'BackgroundColor', [1 1 1], ...
                            'Callback', @(s,e)ndi.cpipeline.edit('command','OrderChange','fig',fig,'order_idx',i));
                        
                        ud.gui_rows(i).bg = bg; ud.gui_rows(i).order_popup = order_popup;
                        ud.gui_rows(i).name = txt; ud.gui_rows(i).param = pop;
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
                    current_pipeline.items(actual_index).selected_param_name = items{v};
                    
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
                            fprintf('Step %d/%d: Running ''%s'' (%s)...\n', i, numel(items), calc_name, items(i).calculatorClass);
                            waitbar((i-1)/numel(items), h_wait, ['Running ' calc_name]);
                            
                            try
                                fprintf('   > Loading parameters...\n');
                                forced_code = '';
                                if strcmpi(items(i).selected_param_name, 'Default')
                                    def_file = fullfile(ud.pipelinePath, 'Calculator_Parameters', items(i).calculatorClass, 'Default.json');
                                    if isfile(def_file)
                                        try
                                            txt = fileread(def_file);
                                            j = jsondecode(txt);
                                            if isfield(j, 'code'), forced_code = j.code; end
                                        catch
                                        end
                                    end
                                end
                                
                                if ~isempty(forced_code)
                                    param_code = forced_code;
                                else
                                    param_code = ndi.calculator.load_parameter_code(items(i).calculatorClass, items(i).selected_param_name, ud.pipelinePath);
                                end
                                
                                if iscell(param_code), param_code = strjoin(param_code, newline);
                                elseif isstring(param_code) && numel(param_code) > 1, param_code = join(param_code, newline); end
                                param_code = char(param_code);
                                
                                S = pipeline_session;
                                if exist('parameters','var'), clear parameters; end
                                eval(param_code); 
                                
                                if ~exist('parameters','var')
                                    thecalc = feval(items(i).calculatorClass, pipeline_session);
                                    parameters = thecalc.default_search_for_input_parameters();
                                end
                                
                                fprintf('   > Calculating...\n');
                                calc_obj = feval(items(i).calculatorClass, pipeline_session);
                                new_docs = calc_obj.run('NoAction', parameters);
                                doc_count = 0;
                                if iscell(new_docs), doc_count = numel(new_docs);
                                elseif isa(new_docs, 'ndi.document'), doc_count = numel(new_docs); 
                                end
                                fprintf('   > Success. Generated/Found %d documents.\n', doc_count);
                            catch run_err
                                fprintf(2, '   > EXECUTION ERROR: %s\n', run_err.message);
                                err_msg = sprintf('Error executing calculator "%s":\n\n%s\n\nCheck your Input Parameters.', calc_name, run_err.message);
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
                        
                        ndi.calculator.graphical_edit_calculator('command','Edit', 'session', session_to_pass, ...
                            'pipelinePath', ud.pipelinePath, 'calculatorClassname', calc_entry.calculatorClass, ...
                            'name', calc_entry.instanceName, 'paramName', calc_entry.selected_param_name); 
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
                                % CODE GENERATION LOGIC
                                % -------------------------------------------------------------
                                code_cell = {};
                                code_cell{end+1} = sprintf('thecalc = %s(pipeline_session);', chosenClass);
                                code_cell{end+1} = 'parameters = thecalc.default_search_for_input_parameters();';
                                code_cell{end+1} = ''; 
                                
                                query_lines = {};
                                query_vars = {};
                                
                                try
                                    % Find source file
                                    m_file = which(chosenClass);
                                    if ~isempty(m_file)
                                        txt = fileread(m_file);
                                        lines = splitlines(txt);
                                        
                                        for k=1:numel(lines)
                                            l = strtrim(lines{k});
                                            if startsWith(l, '%'), continue; end 
                                            
                                            % REGEX: Matches 'var = ndi.query('field', 'op', value'
                                            pat = '(\w+)\s*=\s*ndi\.query\s*\(\s*''([^'']+)''\s*,\s*[^,]+\s*,\s*([^,\);]+)';
                                            tokens = regexp(l, pat, 'tokens');
                                            
                                            if ~isempty(tokens)
                                                q_var = tokens{1}{1};
                                                q_field = tokens{1}{2};
                                                raw_val = strtrim(tokens{1}{3});
                                                
                                                % AUTO-CORRECT: tuning_curve -> stimulus_tuningcurve
                                                if startsWith(q_field, 'tuning_curve.')
                                                    q_field = replace(q_field, 'tuning_curve.', 'stimulus_tuningcurve.');
                                                end

                                                if startsWith(raw_val, '''') && ~strcmp(q_var, 'query')
                                                    % Safe string literal, force 'contains_string'
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
                                        code_cell{end+1} = 'query_struct = struct(''name'',''generated_id'',''query'',q_total);';
                                        code_cell{end+1} = '';
                                        code_cell{end+1} = 'parameters.query = query_struct;';
                                    end
                                else
                                    code_cell{end+1} = '% No specific static text queries found in source.';
                                end
                                
                                json_struct = struct();
                                json_struct.name = 'Default';
                                json_struct.code = code_cell; 
                                
                                fid_j = fopen(fullfile(param_dir, 'Default.json'), 'w');
                                fprintf(fid_j, '%s', jsonencode(json_struct, 'PrettyPrint', true));
                                fclose(fid_j);
                                
                                rehash; pause(0.5); 
                                
                                new_item.calculatorClass = chosenClass; new_item.instanceName = dlg_ans{1};
                                new_item.selected_param_name = 'Default'; 
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
                        pipelineList = [pipelineList, p_struct];
                    catch, end
                end
            end
            if isempty(pipelineList), pipelineList = struct('pipeline_name',{}, 'items',{}); end
        end
    end
end