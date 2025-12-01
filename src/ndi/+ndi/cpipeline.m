classdef cpipeline
    % A class for managing pipelines of ndi.calculator objects in NDI.
    properties (SetAccess=protected,GetAccess=public)
    end % properties
    methods
    end % methods
    methods (Static)
        function p = defaultPath()
            p = fullfile(ndi.common.PathConstants.LogFolder, '..', 'My Pipelines');
            if ~isfolder(p)
                mkdir(p);
            end
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
                    
                    fig_bg_color = [0.8 0.8 0.8]; % Darker grey as requested
                    edit_bg_color = [1 1 1];
                    top = options.window_params.height;
                    
                    % Layout Constants (Normalized 0 to 1)
                    margin = 0.04; 
                    row_h = 0.04;  
                    
                    set(fig,'position',[50 50 options.window_params.width top], 'Color', fig_bg_color, ...
                        'NumberTitle','off', 'Name',['Editing ' ud.pipelinePath], ...
                        'MenuBar','none', 'ToolBar','none', 'Units','normalized', 'Resize','on');
                    
                    % FIX 1: Start lower to prevent cutoff. 
                    % y is the BOTTOM of the control. So 1-margin-row_h ensures the TOP is at 1-margin.
                    y = 1 - margin - row_h;
                    
                    % --- TOP CONTROLS ---
                    % Pipeline Select
                    uicontrol(uid.txt,'Units','normalized','position',[margin y 0.4 row_h],'string','Select Pipeline:',...
                        'BackgroundColor',fig_bg_color,'FontWeight','bold','HorizontalAlignment','left');
                    y = y - row_h;
                    uicontrol(uid.popup,'Units','normalized','position',[margin y 0.94 row_h],...
                        'string',ud.pipelineListChar,'tag','PipelinePopup','callback',callbackstr,'BackgroundColor',edit_bg_color);
                    
                    y = y - row_h - 0.02; % Gap
                    
                    % NDI Data Select
                    uicontrol(uid.txt,'Units','normalized','position',[margin y 0.4 row_h],'string','NDI Data:',...
                         'BackgroundColor',fig_bg_color,'FontWeight','bold','HorizontalAlignment','left');
                    y = y - row_h;
                    uicontrol(uid.popup,'Units','normalized','position',[margin y 0.94 row_h],...
                        'string',{'None'},'tag','PipelineObjectVariablePopup','callback',callbackstr,'BackgroundColor',edit_bg_color);
                    
                    y = y - 0.05; % Gap
                    
                    % --- LIST HEADERS ---
                    % FIX 2: Reduce space between header and box.
                    header_y = y;
                    uicontrol(uid.txt,'Units','normalized','position',[margin header_y 0.4 row_h],'string','Calculator Instances',...
                        'BackgroundColor',fig_bg_color,'FontWeight','bold','HorizontalAlignment','left');
                    uicontrol(uid.txt,'Units','normalized','position',[0.5 header_y 0.4 row_h],'string','Input Parameters',...
                        'BackgroundColor',fig_bg_color,'FontWeight','bold','HorizontalAlignment','left');
                    
                    % The top of the list box will be immediately below the header text
                    list_top = header_y; 
                    
                    % --- BUTTON AREA CALCULATION ---
                    bottom_area_height = 0.20;
                    list_height = list_top - bottom_area_height;
                    
                    % --- SCROLLABLE CONTAINER ---
                    panel_pos = [margin, bottom_area_height, 1-(2*margin), list_height];
                    uipanel('Units','normalized', 'Position', panel_pos, 'BackgroundColor', [1 1 1], ...
                        'Tag', 'ListContainerPanel', 'BorderType', 'line', 'HighlightColor', [0.6 0.6 0.6]);
                    
                    % Slider
                    slider_w = 0.04;
                    uicontrol('Style','slider','Units','normalized',...
                        'Position',[panel_pos(1)+panel_pos(3), bottom_area_height, slider_w, list_height],...
                        'Tag','ListSlider', 'Callback', callbackstr, 'Min', 0, 'Max', 1, 'Value', 1);
                    
                    % --- BUTTONS ---
                    btn_h = 0.05; 
                    gap_v = 0.015; 
                    gap_h = 0.015; 
                    
                    % Y positions for 2 rows
                    y_row_top = 0.11; 
                    y_row_bot = y_row_top - btn_h - gap_v;
                    
                    % Standard Width for editing buttons
                    btn_w = 0.18; 
                    
                    % FIX 3: Aligned Grid
                    
                    % -- Row 1: Pipeline Ops (Top) --
                    % Col 1
                    x1 = margin;
                    uicontrol(uid.button,'Units','normalized','position',[x1 y_row_top btn_w btn_h],...
                        'string','New Pipeline','tag','NewPipelineButton','callback',callbackstr);
                    
                    % Col 2
                    x2 = x1 + btn_w + gap_h;
                    uicontrol(uid.button,'Units','normalized','position',[x2 y_row_top btn_w btn_h],...
                        'string','Delete Pipeline','tag','DeletePipelineButton','callback',callbackstr);
                    
                    % -- Row 2: Calculator Ops (Bottom) --
                    % Col 1 (Aligned with New Pipeline)
                    uicontrol(uid.button,'Units','normalized','position',[x1 y_row_bot btn_w btn_h],...
                        'string','New Calculator','tag','NewCalculatorInstanceButton','callback',callbackstr);
                    
                    % Col 2 (Aligned with Delete Pipeline)
                    uicontrol(uid.button,'Units','normalized','position',[x2 y_row_bot btn_w btn_h],...
                        'string','Delete Calculator','tag','DeleteCalculatorInstanceButton','callback',callbackstr);
                    
                    % Col 3 (Edit Calculator - specific to row 2)
                    x3 = x2 + btn_w + gap_h;
                    uicontrol(uid.button,'Units','normalized','position',[x3 y_row_bot btn_w btn_h],...
                        'string','Edit Calculator','tag','EditButton','callback',callbackstr);
                    
                    % -- Run Button (Right Side) --
                    run_x = x3 + btn_w + 0.05; 
                    run_w = 1 - run_x - margin;
                    % Center Run button vertically between the two rows
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
                    
                    pipeline_name = str{val};
                    calc_list = ndi.cpipeline.getCalculatorInstancesFromPipeline(ud.pipelineList, pipeline_name);
                    
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
                            opts = {'Default'};
                            [names, ~] = ndi.calculator.readParameterCode(calc_class);
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
                            
                            current_val = 1; 
                            if i <= numel(ud.row_params) && ~isempty(ud.row_params{i})
                                idx = find(strcmp(opts, ud.row_params{i}));
                                if ~isempty(idx), current_val = idx; end
                            end
                            
                            pop = uicontrol(container, 'Style', 'popupmenu', 'Units', 'normalized', ...
                                'Position', [0.5, y_norm+0.1*h_norm, 0.48, h_norm*0.8], 'String', opts, ...
                                'Value', current_val, ...
                                'BackgroundColor', [1 1 1], ...
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
                                set(ud.gui_rows(i).bg, 'BackgroundColor', [0.6 0.8 1]);
                                set(ud.gui_rows(i).name, 'BackgroundColor', [0.6 0.8 1]);
                            else
                                set(ud.gui_rows(i).bg, 'BackgroundColor', [1 1 1]);
                                set(ud.gui_rows(i).name, 'BackgroundColor', [1 1 1]);
                            end
                        end
                    end
                    
                case 'RunButton'
                    pipelinePopupObj = findobj(fig,'tag','PipelinePopup');
                    val = get(pipelinePopupObj, 'value');
                    if val <= 1, msgbox('Select a pipeline.'); return; end
                    
                    % --- ROBUST DATA LINKING START ---
                    dataPopupObj = findobj(fig, 'tag', 'PipelineObjectVariablePopup');
                    data_val = get(dataPopupObj, 'value');
                    data_list = get(dataPopupObj, 'userdata'); 
                    
                    if data_val > 1 && numel(data_list) >= data_val
                        selected_var = data_list{data_val};
                        try
                            ud.linked_object = evalin('base', selected_var);
                            set(fig, 'userdata', ud);
                        catch
                            msgbox(['Error accessing variable "' selected_var '" in base workspace.']); return;
                        end
                    end
                    
                    if isempty(ud.linked_object)
                        msgbox('Please link an NDI Data object (Session) using the dropdown menu.'); return;
                    end
                    
                    selected_pipeline = ud.pipelineList(val);
                    calc_instances = selected_pipeline.calculatorInstances;
                    if isempty(calc_instances), return; end
                    
                    fprintf('\n\n--- PIPELINE EXECUTION STARTED ---\n');
                    fprintf('PIPELINE: Calling %s...\n', selected_pipeline.pipeline_name);
                    
                    try
                        fprintf('DEBUG: Using NDI Session at path: %s\n', ud.linked_object.path);
                    catch
                        fprintf('DEBUG: Using NDI Session (path unknown)\n');
                    end
                    
                    h_wait = waitbar(0, 'Initializing pipeline...', 'Name', 'Running Pipeline');
                    
                    try
                        for i = 1:numel(calc_instances)
                            this_instance = calc_instances(i);
                            calc_class = this_instance.calculatorClassname;
                            calc_name = this_instance.instanceName;
                            
                            param_source = 'Default';
                            if i <= numel(ud.row_params) && ~isempty(ud.row_params{i})
                                param_source = ud.row_params{i};
                            elseif i <= numel(ud.gui_rows) && ~isempty(ud.gui_rows(i).param) && isvalid(ud.gui_rows(i).param)
                                str = get(ud.gui_rows(i).param, 'String');
                                val = get(ud.gui_rows(i).param, 'Value');
                                if iscell(str), param_source = str{val}; else, param_source = str; end
                            end
                            
                            fprintf('\nSTEP %d: %s (Params: %s)\n', i, calc_name, param_source);
                            waitbar((i-1)/numel(calc_instances), h_wait, sprintf('Running %s...', calc_name));
                            
                            if exist(calc_class, 'class')
                                calc_obj = feval(calc_class, ud.linked_object);
                                params = struct();
                                
                                if strcmp(param_source, 'Default')
                                    params = calc_obj.default_search_for_input_parameters();
                                    disp('  DEBUG: Using Defaults.');
                                else
                                    [names, contents] = ndi.calculator.readParameterCode(calc_class);
                                    idx = find(strcmp(names, param_source), 1);
                                    if ~isempty(idx)
                                        code = contents{idx};
                                        S = ud.linked_object; pipeline_session = S;
                                        try
                                            if exist('parameters','var'), clear parameters; end
                                            eval(code);
                                            if exist('parameters','var')
                                                params = parameters;
                                                disp('  DEBUG: Custom code executed.');
                                            else
                                                error('Custom code did not create "parameters" variable.');
                                            end
                                        catch e
                                            if isvalid(h_wait), delete(h_wait); end
                                            errordlg(sprintf('Error in param code "%s":\n%s', param_source, e.message));
                                            rethrow(e);
                                        end
                                    else
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
                                    w = calc_obj.default_search_for_input_parameters();
                                    w.input_parameters = params; params = w;
                                elseif isstruct(params) && ~isfield(params,'input_parameters')
                                    w = calc_obj.default_search_for_input_parameters();
                                    w.input_parameters = params; params = w;
                                end
                                
                                candidates = calc_obj.search_for_input_parameters(params);
                                fprintf('  DEBUG: Matches found: %d\n', numel(candidates));
                                
                                generated_docs = calc_obj.run('NoAction', params);
                                
                                num_docs = 0;
                                if iscell(generated_docs), num_docs = numel(generated_docs); 
                                elseif ~isempty(generated_docs), num_docs = numel(generated_docs); end
                                fprintf('  Result: %d docs generated/updated.\n', num_docs);
                            end
                        end
                        if isvalid(h_wait), delete(h_wait); end
                        msgbox('Pipeline Finished!');
                    catch e
                        if isvalid(h_wait), delete(h_wait); end
                        errordlg(e.message);
                    end

                % --- Pass-throughs ---
                case {'LoadPipelines','RefreshObjectVariablePopup','PipelinePopup','PipelineObjectVariablePopup'}
                    if strcmp(command,'LoadPipelines')
                        ud.pipelineList = ndi.cpipeline.getPipelines(ud.pipelinePath);
                        ud.pipelineListChar = ndi.cpipeline.pipelineListToChar(ud.pipelineList);
                        set(fig,'userdata',ud);
                        set(findobj(fig,'Tag','PipelinePopup'),'String',ud.pipelineListChar);
                    elseif strcmp(command,'RefreshObjectVariablePopup')
                         vars = evalin('base', 'whos');
                         vn = {};
                         for i=1:length(vars), if ismember(vars(i).class, {'ndi.session','ndi.session.dir','ndi.dataset'}), vn{end+1}=vars(i).name; end; end
                         set(findobj(fig,'Tag','PipelineObjectVariablePopup'),'String',[{'None'}, vn]);
                         set(findobj(fig,'Tag','PipelineObjectVariablePopup'),'userdata',[{[]}, vn]);
                    end
                    ndi.cpipeline.edit('command','UpdateCalculatorInstanceList','fig',fig);
                    
                case 'DeleteCalculatorInstanceButton'
                     if isfield(ud, 'selected_row_index') && ~isempty(ud.selected_row_index)
                         pipelinePopupObj = findobj(fig,'tag','PipelinePopup');
                         val = get(pipelinePopupObj, 'value');
                         str = get(pipelinePopupObj, 'string');
                         pipeline_name = str{val};
                         selected_pipeline = ud.pipelineList(val);
                         idx = ud.selected_row_index;
                         if idx <= numel(selected_pipeline.calculatorInstances)
                             fname = selected_pipeline.calculatorInstances(idx).JSONFilename;
                             full_f = fullfile(ud.pipelinePath, pipeline_name, fname);
                             delete(full_f);
                             ndi.cpipeline.edit('command','UpdatePipelines','fig',fig); 
                             ndi.cpipeline.edit('command','UpdateCalculatorInstanceList','fig',fig);
                         end
                     else
                         msgbox('Please select a calculator instance to delete.');
                     end
                     
                case 'EditButton'
                    if isfield(ud, 'selected_row_index') && ~isempty(ud.selected_row_index)
                         pipelinePopupObj = findobj(fig,'tag','PipelinePopup');
                         val = get(pipelinePopupObj, 'value');
                         str = get(pipelinePopupObj, 'string');
                         pipeline_name = str{val};
                         selected_pipeline = ud.pipelineList(val);
                         idx = ud.selected_row_index;
                         fname = selected_pipeline.calculatorInstances(idx).JSONFilename;
                         full_f = fullfile(ud.pipelinePath, pipeline_name, fname);
                         ndi.calculator.graphical_edit_calculator('command','Edit','filename',full_f,'session',ud.linked_object);
                    else
                         msgbox('Please select a calculator instance to edit.');
                    end
                    
                case 'NewPipelineButton'
                    read_dir = [ud.pipelinePath filesep];
                    [success,filename,replaces] = ndi.util.choosefileordir(read_dir, {'Pipeline name:'}, {['untitled']}, 'Save new pipeline', {['']});
                    if success
                        if replaces, rmdir([read_dir filesep filename], 's'); end
                        mkdir(read_dir,filename);
                        ndi.cpipeline.edit('command','LoadPipelines','selectedPipeline',filename,'fig',fig);
                    end
                case 'DeletePipelineButton'
                    pipelinePopupObj = findobj(fig,'tag','PipelinePopup');
                    val = get(pipelinePopupObj, 'value');
                    if val>1
                        str = get(pipelinePopupObj, 'string');
                        filename = str{val};
                        rmdir([ud.pipelinePath filesep filename], 's');
                        ndi.cpipeline.edit('command','LoadPipelines','fig',fig);
                    end
                case 'NewCalculatorInstanceButton'
                    pipelinePopupObj = findobj(fig,'tag','PipelinePopup');
                    val = get(pipelinePopupObj, 'value');
                    if val > 1
                        str = get(pipelinePopupObj, 'string');
                        pipeline_name = str{val};
                        calcTypeList = ndi.calculator.find_calculator_subclasses();
                        if ~isempty(calcTypeList)
                            [calcTypeIndex, isSel] = listdlg('ListString',calcTypeList);
                            if isSel
                                answer = inputdlg('Name:');
                                if ~isempty(answer)
                                    calcName = answer{1};
                                    base = matlab.lang.makeValidName(calcName);
                                    full_p = fullfile(ud.pipelinePath, pipeline_name, [base '.json']);
                                    newC = ndi.cpipeline.setDefaultCalculatorInstance(calcTypeList{calcTypeIndex}, calcName);
                                    fid = fopen(full_p,'w'); fprintf(fid,jsonencode(newC)); fclose(fid);
                                    ndi.cpipeline.edit('command','UpdatePipelines','fig',fig);
                                    ndi.cpipeline.edit('command','UpdateCalculatorInstanceList','pipeline_name',pipeline_name,'fig',fig);
                                end
                            end
                        end
                    end
            end
        end
        % ... Helper functions ...
        function calculatorInstanceList = getCalculatorInstancesFromPipeline(pipelineList, pipeline_name)
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
        end
        function pipelineList = getPipelines(read_dir)
            d = dir(read_dir);
            isub = [d(:).isdir];
            nameList = {d(isub).name}';
            nameList(ismember(nameList,{'.','..'})) = [];
            
            field_names = {'calculatorClassname','instanceName','JSONFilename','default_options'};
            empty_vals = cell(size(field_names));
            empty_calc_struct = cell2struct(empty_vals, field_names, 2);
            
            pipelineList(1).pipeline_name = '---';
            pipelineList(1).calculatorInstances = empty_calc_struct;
            for i = 1:numel(nameList)
                pipelineList(i+1).pipeline_name = nameList{i};
                D = dir(fullfile(read_dir, nameList{i}, '*.json'));
                if ~isempty(D)
                    temp_cell = {}; 
                    for d_i = 1:numel(D)
                        full_json_path = fullfile(read_dir, nameList{i}, D(d_i).name);
                        json_text = fileread(full_json_path);
                        decoded_json = [];
                        try
                            if ~isempty(strtrim(json_text))
                                decoded_json = jsondecode(json_text);
                            end
                        catch
                        end
                        if ~isempty(decoded_json)
                            decoded_json.JSONFilename = D(d_i).name;
                            temp_cell{end+1} = decoded_json;
                        end
                    end
                    if ~isempty(temp_cell)
                        pipelineList(i+1).calculatorInstances = [temp_cell{:}];
                    else
                        pipelineList(i+1).calculatorInstances = empty_calc_struct;
                    end
                else
                    pipelineList(i+1).calculatorInstances = empty_calc_struct;
                end
            end
        end
        function pipelineListChar = pipelineListToChar(pipelineList)
            pipelineListChar = {pipelineList.pipeline_name};
        end
    end
end