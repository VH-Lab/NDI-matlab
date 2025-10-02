classdef cpipeline
    % A class for managing pipelines of ndi.calculator objects in NDI.
    %
    % To test and for a demo, use
    %
    %    ndi.test.pipeline.editpipeline()
    properties (SetAccess=protected,GetAccess=public)
    end % properties
    methods
    end % methods
    methods (Static)
        function p = defaultPath()
            % DEFAULTPATH - return the default path for cpipeline JSON files
            %
            % P = NDI.CPIPELINE.DEFAULTPATH
            %
            % Returns the default path for NDI CPIPELINE files.
            % This is typically [ndi.common.PathConstants.LogFolder '/../My Pipelines'].
            % If this folder does not exist, it is created.
            %
            p = fullfile(ndi.common.PathConstants.LogFolder, '..', 'My Pipelines');
            if ~isfolder(p)
                mkdir(p);
            end
        end
        function edit(options)
            % EDIT - create and control a GUI to graphically edit a CPIPELINE
            %
            %   EDIT(Name, Value, ...)
            %
            %   Creates and controls a graphical user interface for creating an instance of
            %   a cpipeline.editor object.
            %
            %   This function accepts the following optional arguments as name-value pairs:
            %
            %   'command'           A character array specifying the GUI command.
            %                       Default: 'new'.
            %
            %   'pipelinePath'      The full path to the directory containing the pipelines.
            %                       Default: ndi.cpipeline.defaultPath().
            %
            %   'session'           An ndi.session object.
            %                       Default: ndi.session.empty().
            %
            %   'window_params'     A structure with 'height' and 'width' fields.
            %                       Default: struct('height', 500, 'width', 400).
            %
            %   'fig'               A handle to an existing figure to use.
            %                       Default: [].
            %
            
            arguments
                options.command (1,:) char {mustBeMember(options.command, ...
                    {'new','NewWindow','UpdatePipelines','LoadPipelines','UpdateCalculatorInstanceList',...
                    'PipelinePopup','NewPipelineButton','DeletePipelineButton','NewCalculatorInstanceButton','DeleteCalculatorInstanceButton',...
                    'EditButton','RunButton','PipelineContentList','DoEnableDisable',...
                    'PipelineObjectTypePopup','PipelineObjectVariablePopup'})} = 'new'
                options.pipelinePath (1,:) char = ndi.cpipeline.defaultPath()
                options.session ndi.session = ndi.session.empty();
                options.window_params (1,1) struct = struct('height', 500, 'width', 400)
                options.fig {mustBeA(options.fig,["matlab.ui.Figure","double"])} = []
                options.selectedPipeline (1,:) char = ''
                options.pipeline_name (1,:) char = ''
            end
            fig = options.fig;
            % Enforce that 'fig' must be provided for all commands except 'new'
            if ~strcmpi(options.command,'new') && isempty(fig)
                error('The ''fig'' argument must be provided for all commands except ''new''.');
            end
            if strcmpi(options.command,'new')
                if isempty(fig)
                    fig = figure;
                end
                command = 'NewWindow';
                % new window, set userdata
                if ~isempty(options.pipelinePath)
                    % is it a valid directory?
                    if isfolder(options.pipelinePath)
                        ud.pipelinePath = options.pipelinePath;
                        ud.pipelineList = []; % initially empty
                        ud.pipelineListChar = {}; % initially empty, MUST BE CELL
                        ud.linked_object = options.session;
                        set(fig,'userdata',ud);
                    else
                        error(['The provided pipeline path does not exist: ' options.pipelinePath '.']);
                    end
                else
                    error(['No pipelinePath provided.']);
                end
            else
                % not new window, get userdata
                ud = get(fig,'userdata');
                command = options.command;
            end
            disp(['Command is ' command '.']);
            switch (command)
                case 'NewWindow'
                    set(fig,'tag','ndi.cpipeline.edit');
                    uid = vlt.ui.basicuitools_defs;
                    callbackstr = [  'eval([get(gcbf,''Tag'') ''(''''command'''','''''' get(gcbo,''Tag'') '''''' ,''''fig'''',gcbf);'']);'];

                    % Step 1: Define colors and normalized geometry
                    fig_bg_color = [0.8 0.8 0.8];
                    edit_bg_color = [1 1 1];
                    top = options.window_params.height;
                    right = options.window_params.width;
                    
                    edge_h_n = 10/right;
                    edge_v_n = 10/top;
                    row_h_n = 25/top;
                    gap_v_n = 15/top;
                    gap_h_n = 5/right;
                    
                    % Step 2: Set up the figure
                    set(fig,'position',[50 50 right top], ...
                        'Color', fig_bg_color, ...
                        'NumberTitle','off', ...
                        'Name',['Editing ' ud.pipelinePath], ...
                        'MenuBar','none', ...
                        'ToolBar','none',...
                        'Units','normalized',...
                        'Resize','on');

                    % Step 3: Create UI elements using a top-down normalized layout
                    y_cursor = 1 - edge_v_n;
                    
                    % Pipeline selection
                    y_cursor = y_cursor - row_h_n;
                    uicontrol(uid.txt,'Units','normalized','position',[edge_h_n y_cursor 1-2*edge_h_n row_h_n],'string','Select pipeline:',...
                        'BackgroundColor',fig_bg_color,'FontWeight','bold','HorizontalAlignment','left');
                    y_cursor = y_cursor - row_h_n;
                    uicontrol(uid.popup,'Units','normalized','position',[edge_h_n y_cursor 1-2*edge_h_n row_h_n],...
                        'string',ud.pipelineListChar,'tag','PipelinePopup','callback',callbackstr,'BackgroundColor',edit_bg_color);
                    
                    % Object Linking (Stacked)
                    y_cursor = y_cursor - gap_v_n - row_h_n;
                    uicontrol(uid.txt,'Units','normalized','position',[edge_h_n y_cursor 1-2*edge_h_n row_h_n],'string','Link object type:',...
                        'BackgroundColor',fig_bg_color,'FontWeight','bold','HorizontalAlignment','left');
                    y_cursor = y_cursor - row_h_n;
                    uicontrol(uid.popup,'Units','normalized','position',[edge_h_n y_cursor 1-2*edge_h_n row_h_n],...
                        'string',{'ndi.session', 'ndi.dataset', 'Workspace variable'},'tag','PipelineObjectTypePopup','callback',callbackstr,...
                        'BackgroundColor',edit_bg_color);

                    y_cursor = y_cursor - gap_v_n/2 - row_h_n;
                    uicontrol(uid.txt,'Units','normalized','position',[edge_h_n y_cursor 1-2*edge_h_n row_h_n],'string','NDI Data:',...
                         'BackgroundColor',fig_bg_color,'FontWeight','bold','HorizontalAlignment','left');
                    y_cursor = y_cursor - row_h_n;
                    uicontrol(uid.popup,'Units','normalized','position',[edge_h_n y_cursor 1-2*edge_h_n row_h_n],...
                        'string',{'None'},'tag','PipelineObjectVariablePopup','callback',callbackstr,'BackgroundColor',edit_bg_color);
                    
                    % Main Area (Listbox on left, Buttons on right)
                    y_cursor = y_cursor - gap_v_n;
                    main_area_top = y_cursor;
                    main_area_bottom = edge_v_n;
                    main_area_height = main_area_top - main_area_bottom;

                    % Listbox title and box
                    list_w_n = (2/3)*(1 - 2*edge_h_n) - gap_h_n;
                    uicontrol(uid.txt,'Units','normalized','position',[edge_h_n main_area_top-row_h_n list_w_n row_h_n],'string','Calculator Instances',...
                        'BackgroundColor',fig_bg_color,'FontWeight','bold','HorizontalAlignment','left');
                    uicontrol(uid.edit,'style','listbox','Units','normalized','position',[edge_h_n main_area_bottom list_w_n main_area_height-row_h_n],...
                        'string',{'Please select or create a pipeline.'},...
                        'tag','PipelineContentList','min',0,'max',2,'callback',callbackstr,'BackgroundColor',edit_bg_color);

                    % Button Panel with Titles
                    btn_panel_left_n = edge_h_n + list_w_n + gap_h_n;
                    btn_panel_w_n = 1 - btn_panel_left_n - edge_h_n;
                    btn_w_n = 0.8 * btn_panel_w_n; % 80% of panel width
                    btn_x_n = btn_panel_left_n + (btn_panel_w_n - btn_w_n)/2;
                    
                    btn_h_n = 25/top;
                    label_h_n = 15/top;
                    
                    y_btn_panel_top = main_area_top;
                    
                    btn_titles = {'Run Pipeline','New Pipeline','Delete Pipeline','New Calculator','Delete Calculator','Edit Calculator'};
                    btn_tags = {'RunButton','NewPipelineButton','DeletePipelineButton','NewCalculatorInstanceButton','DeleteCalculatorInstanceButton','EditButton'};
                    btn_strings = {'->','+','-','+','-','Edit'};
                    
                    y_btn_cursor = y_btn_panel_top;
                    small_gap = 5/top;
                    large_gap = 15/top;

                    % Manually stack buttons with titles and specific gaps
                    slot_h = btn_h_n + label_h_n;
                    y_btn_cursor = y_btn_cursor - slot_h;
                    uicontrol(uid.txt,'Units','normalized','string',btn_titles{1},'position',[btn_x_n y_btn_cursor+btn_h_n btn_w_n label_h_n],'BackgroundColor',fig_bg_color,'FontWeight','bold','HorizontalAlignment','center');
                    uicontrol(uid.button,'Units','normalized','string',btn_strings{1},'tag',btn_tags{1},'position',[btn_x_n y_btn_cursor btn_w_n btn_h_n],'callback',callbackstr);

                    y_btn_cursor = y_btn_cursor - large_gap - slot_h;
                    uicontrol(uid.txt,'Units','normalized','string',btn_titles{2},'position',[btn_x_n y_btn_cursor+btn_h_n btn_w_n label_h_n],'BackgroundColor',fig_bg_color,'FontWeight','bold','HorizontalAlignment','center');
                    uicontrol(uid.button,'Units','normalized','string',btn_strings{2},'tag',btn_tags{2},'position',[btn_x_n y_btn_cursor btn_w_n btn_h_n],'callback',callbackstr);
                    y_btn_cursor = y_btn_cursor - small_gap - slot_h;
                    uicontrol(uid.txt,'Units','normalized','string',btn_titles{3},'position',[btn_x_n y_btn_cursor+btn_h_n btn_w_n label_h_n],'BackgroundColor',fig_bg_color,'FontWeight','bold','HorizontalAlignment','center');
                    uicontrol(uid.button,'Units','normalized','string',btn_strings{3},'tag',btn_tags{3},'position',[btn_x_n y_btn_cursor btn_w_n btn_h_n],'callback',callbackstr);

                    y_btn_cursor = y_btn_cursor - large_gap - slot_h;
                    uicontrol(uid.txt,'Units','normalized','string',btn_titles{4},'position',[btn_x_n y_btn_cursor+btn_h_n btn_w_n label_h_n],'BackgroundColor',fig_bg_color,'FontWeight','bold','HorizontalAlignment','center');
                    uicontrol(uid.button,'Units','normalized','string',btn_strings{4},'tag',btn_tags{4},'position',[btn_x_n y_btn_cursor btn_w_n btn_h_n],'callback',callbackstr);
                    y_btn_cursor = y_btn_cursor - small_gap - slot_h;
                    uicontrol(uid.txt,'Units','normalized','string',btn_titles{5},'position',[btn_x_n y_btn_cursor+btn_h_n btn_w_n label_h_n],'BackgroundColor',fig_bg_color,'FontWeight','bold','HorizontalAlignment','center');
                    uicontrol(uid.button,'Units','normalized','string',btn_strings{5},'tag',btn_tags{5},'position',[btn_x_n y_btn_cursor btn_w_n btn_h_n],'callback',callbackstr);
                    y_btn_cursor = y_btn_cursor - small_gap - slot_h;
                    uicontrol(uid.txt,'Units','normalized','string',btn_titles{6},'position',[btn_x_n y_btn_cursor+btn_h_n btn_w_n label_h_n],'BackgroundColor',fig_bg_color,'FontWeight','bold','HorizontalAlignment','center');
                    uicontrol(uid.button,'Units','normalized','string',btn_strings{6},'tag',btn_tags{6},'position',[btn_x_n y_btn_cursor btn_w_n btn_h_n],'callback',callbackstr);
                    
                    ndi.cpipeline.edit('command','PipelineObjectTypePopup','fig',fig);
                    ndi.cpipeline.edit('command','LoadPipelines','fig',fig);
                case 'PipelineObjectTypePopup'
                    popup_type_obj = findobj(fig,'tag','PipelineObjectTypePopup');
                    type_val = get(popup_type_obj,'value');
                    type_str_list = get(popup_type_obj,'string');
                    selected_type = type_str_list{type_val};

                    vars = evalin('base', 'whos');
                    var_names = {};
                    for i = 1:length(vars)
                        is_match = strcmp(vars(i).class, selected_type);
                        if strcmp(selected_type, 'Workspace variable') && ~strcmp(vars(i).class,'matlab.ui.Figure')
                            is_match = true;
                        end
                        if is_match, var_names{end+1} = vars(i).name; end
                    end
                    popup_strings = {'None', var_names{:}};
                    
                    popup_var_obj = findobj(fig, 'tag','PipelineObjectVariablePopup');
                    set(popup_var_obj, 'string', popup_strings, 'userdata', {[], var_names{:}});

                    initial_value = 1; % Default to 'None'
                    if ~isempty(ud.linked_object) && (strcmp(class(ud.linked_object), selected_type) || strcmp(selected_type,'Workspace variable'))
                        for i=1:numel(var_names)
                            workspace_obj = evalin('base', var_names{i});
                            if isequal(ud.linked_object, workspace_obj)
                                initial_value = i + 1;
                                break;
                            end
                        end
                    end
                    set(popup_var_obj, 'value', initial_value);
                    
                    if initial_value == 1 && ~isempty(ud.linked_object)
                        ud.linked_object = [];
                        set(fig,'userdata',ud);
                    end
                case 'PipelineObjectVariablePopup'
                    popup_obj = findobj(fig, 'tag', 'PipelineObjectVariablePopup');
                    val = get(popup_obj, 'value');
                    var_names_list = get(popup_obj, 'userdata');
                    selected_var_name = var_names_list{val};
                    
                    if isempty(selected_var_name)
                        ud.linked_object = [];
                        disp('Pipeline object link cleared.');
                    else
                        ud.linked_object = evalin('base', selected_var_name);
                        disp(['Pipeline linked to workspace variable ''' selected_var_name '''.']);
                    end
                    set(fig, 'userdata', ud);
                case 'UpdatePipelines' % invented command that is not a callback
                    ud.pipelineList = ndi.cpipeline.getPipelines(ud.pipelinePath);
                    ud.pipelineListChar = ndi.cpipeline.pipelineListToChar(ud.pipelineList);
                    set(fig,'userdata',ud);
                case 'LoadPipelines' % invented command that is not a callback
                    % called on startup or if the user ever changes the file path through some future mechanism
                    ud.pipelineList = ndi.cpipeline.getPipelines(ud.pipelinePath);
                    ud.pipelineListChar = ndi.cpipeline.pipelineListToChar(ud.pipelineList);
                    set(fig,'userdata',ud);
                    pipelinePopupObj = findobj(fig,'tag','PipelinePopup');
                    index = 1;
                    if ~isempty(options.selectedPipeline)
                        index = find(strcmp(options.selectedPipeline,ud.pipelineListChar));
                    end
                    set(pipelinePopupObj, 'string',ud.pipelineListChar,'Value',index);
                    pipelineContentObj = findobj(fig,'tag','PipelineContentList');
                    if isempty(ud.pipelineListChar) || index == 1
                        set(pipelineContentObj, 'string', {}, 'Value', 1);
                    else
                        calculatorInstanceList = ndi.cpipeline.getCalculatorInstancesFromPipeline(ud.pipelineList, ud.pipelineListChar{index});
                        calculatorInstanceListChar = ndi.cpipeline.calculatorInstancesToChar(calculatorInstanceList);
                        pipelineContentObj = findobj(fig,'tag','PipelineContentList');
                        set(pipelineContentObj, 'string', calculatorInstanceListChar, 'Value', min(numel(calculatorInstanceListChar),1));
                    end
                    ndi.cpipeline.edit('command','DoEnableDisable','fig',fig);
                case 'UpdateCalculatorInstanceList' % invented command that is not a callback
                    calculatorInstanceList = ndi.cpipeline.getCalculatorInstancesFromPipeline(ud.pipelineList, options.pipeline_name);
                    calculatorInstanceListChar = ndi.cpipeline.calculatorInstancesToChar(calculatorInstanceList);
                    pipelineContentObj = findobj(fig,'tag','PipelineContentList');
                    set(pipelineContentObj, 'string', calculatorInstanceListChar, 'Value', min(numel(calculatorInstanceListChar),1));
                    ndi.cpipeline.edit('command','DoEnableDisable','fig',fig);
                case 'PipelinePopup'
                    % Step 1: search for the objects you need to work with
                    pipelinePopupObj = findobj(fig,'tag','PipelinePopup');
                    val = get(pipelinePopupObj, 'value');
                    str = get(pipelinePopupObj, 'string');
                    % Step 2, check not the "---" one and display
                    if isempty(str) || val == 1
                        msgbox('Please select or create a pipeline.');
                        pipelineContentObj = findobj(fig,'tag','PipelineContentList');
                        set(pipelineContentObj, 'string', {}, 'Value', 1);
                    else
                        pipeline_name = str{val};
                        ndi.cpipeline.edit('command','UpdateCalculatorInstanceList','pipeline_name',pipeline_name,'fig',fig);
                    end
                    ndi.cpipeline.edit('command','DoEnableDisable','fig',fig);
                case 'NewPipelineButton'
                    % get dir
                    read_dir = [ud.pipelinePath filesep];
                    % create dialog box
                    defaultfilename = {['untitled']};
                    prompt = {'Pipeline name:'};
                    dlgtitle = 'Save new pipeline';
                    extension_list = {['']};
                    % check if the user want to create/replace
                    [success,filename,replaces] = ndi.util.choosefileordir(read_dir, prompt, defaultfilename, dlgtitle, extension_list);
                    if success % if success, add pipeline
                        if replaces
                            rmdir([read_dir filesep filename], 's');
                        end
                        mkdir(read_dir,filename);
                        % update and load pipelines
                        ndi.cpipeline.edit('command','LoadPipelines','selectedPipeline',filename,'fig',fig);
                    end
                case 'DeletePipelineButton'
                    pipelinePopupObj = findobj(fig,'tag','PipelinePopup');
                    val = get(pipelinePopupObj, 'value');
                    % check not the "---"
                    if val == 1
                        msgbox('Please select a pipeline to delete.');
                        return
                    end
                    str = get(pipelinePopupObj, 'string');
                    % get dir
                    read_dir = [ud.pipelinePath filesep];
                    filename = str{val};
                    % ask and delete
                    msgBox = sprintf('Do you want to delete this pipeline?');
                    title = 'Delete file';
                    b = questdlg(msgBox, title, 'Yes', 'No', 'Yes');
                    if strcmpi(b, 'Yes')
                        rmdir([read_dir filesep filename], 's');
                    end
                    % update and load pipelines
                    ndi.cpipeline.edit('command','LoadPipelines','fig',fig);
                case 'NewCalculatorInstanceButton'
                    pipelinePopupObj = findobj(fig,'tag','PipelinePopup');
                    val = get(pipelinePopupObj, 'value');
                    % check not the "---"
                    if val == 1
                        msgbox('Please select or create a pipeline.');
                        return;
                    end
                    str = get(pipelinePopupObj, 'string');
                    pipeline_name = str{val};
                    
                    % Dynamically find all calculator subclasses
                    calcTypeList = ndi.calculator.find_calculator_subclasses();
                    if isempty(calcTypeList)
                        msgbox('No calculator types were found on the path.');
                        return;
                    end
                    [calcTypeIndex, isSelectionMade] = listdlg('PromptString','Choose a calculator type:',...
                        'SelectionMode','single','ListString',calcTypeList);
                    if ~isSelectionMade % check selection
                        return
                    end
                    calculatorInstanceType = calcTypeList{calcTypeIndex};
                    
                    % ask for instance name
                    answer = inputdlg('Enter a name for this calculator instance:', 'New Calculator Instance');
                    if isempty(answer)
                        return; % User cancelled
                    end
                    calculatorInstanceName = answer{1};
                    
                    % create a valid filename
                    base_filename = matlab.lang.makeValidName(calculatorInstanceName);
                    json_filename = [base_filename '.json'];
                    full_json_path = fullfile(ud.pipelinePath, pipeline_name, json_filename);
                    if isfile(full_json_path)
                        b = questdlg(['File ' json_filename ' already exists. Overwrite?'],'Overwrite file','Yes','No','No');
                        if strcmp(b,'No')
                            return;
                        end
                    end
                    
                    newCalculatorInstance = ndi.cpipeline.setDefaultCalculatorInstance(calculatorInstanceType, calculatorInstanceName);
                    
                    fid = fopen(full_json_path,'w');
                    fprintf(fid,jsonencode(newCalculatorInstance));
                    fclose(fid);
                    
                    % update and load calculator
                    ndi.cpipeline.edit('command','UpdatePipelines','fig',fig);
                    ndi.cpipeline.edit('command','UpdateCalculatorInstanceList','pipeline_name',pipeline_name,'fig',fig);
                case 'DeleteCalculatorInstanceButton'
                    pipelinePopupObj = findobj(fig,'tag','PipelinePopup');
                    pip_val = get(pipelinePopupObj, 'value');
                    % check not the "---"
                    if pip_val == 1
                        msgbox('Please select or create a pipeline.');
                        return;
                    end
                    pip_str = get(pipelinePopupObj, 'string');
                    msgBox = sprintf('Do you want to delete this Calculator instance?');
                    title = 'Delete Calculator instance';
                    b = questdlg(msgBox, title, 'Yes', 'No', 'Yes');
                    if strcmpi(b, 'Yes')
                        pipeline_name = pip_str{pip_val};
                        pipelineContentObj = findobj(fig,'tag','PipelineContentList');
                        calculatorInstance_val = get(pipelineContentObj, 'value');
                        
                        % Get the correct filename from the userdata structure
                        selected_pipeline = ud.pipelineList(pip_val);
                        filename_to_delete = selected_pipeline.calculatorInstances(calculatorInstance_val).JSONFilename;
                        
                        full_filename = fullfile(ud.pipelinePath, pipeline_name, filename_to_delete);
                        delete(full_filename);
                        
                        % update and load pipelines
                        ndi.cpipeline.edit('command','UpdatePipelines','fig',fig);
                        ndi.cpipeline.edit('command','UpdateCalculatorInstanceList','pipeline_name',pipeline_name,'fig',fig);
                    end
                case 'EditButton'
                    pipelinePopupObj = findobj(fig,'tag','PipelinePopup');
                    pip_val = get(pipelinePopupObj, 'value');
                    % check not the "---"
                    if pip_val == 1
                        msgbox('Please select or create a pipeline.');
                        return;
                    end
                    pip_str = get(pipelinePopupObj, 'string');
                    pipeline_name = pip_str{pip_val};
                    pipelineContentObj = findobj(fig,'tag','PipelineContentList');
                    calculatorInstance_val = get(pipelineContentObj, 'value');
                    
                    % Get the correct filename from the userdata structure
                    selected_pipeline = ud.pipelineList(pip_val);
                    filename_to_edit = selected_pipeline.calculatorInstances(calculatorInstance_val).JSONFilename;
                    
                    full_calculatorInstance_name = fullfile(ud.pipelinePath, pipeline_name, filename_to_edit);
                    ndi.calculator.graphical_edit_calculator('command','Edit','filename',full_calculatorInstance_name,'session',ud.linked_object);
                case 'RunButton'
                    disp([command ' is not implemented yet.']);
                case 'PipelineContentList'
                    ndi.cpipeline.edit('command','DoEnableDisable','fig',fig);
                case 'DoEnableDisable'
                    % Get handles
                    pipelinePopupObj = findobj(fig,'tag','PipelinePopup');
                    pipelineContentObj = findobj(fig,'tag','PipelineContentList');
                    runButton = findobj(fig,'tag','RunButton');
                    deletePipelineButton = findobj(fig,'tag','DeletePipelineButton');
                    deleteCalcButton = findobj(fig,'tag','DeleteCalculatorInstanceButton');
                    editButton = findobj(fig,'tag','EditButton');
                    % Get state
                    pipeline_index = get(pipelinePopupObj,'Value');
                    if isempty(pipeline_index) % handle case where popup list is empty
                        pipeline_index = 1;
                    end
                    is_real_pipeline = pipeline_index > 1;
                    calculator_indices = get(pipelineContentObj,'Value');
                    calculator_strings = get(pipelineContentObj,'String');
                    
                    % For multi-select listbox, Value is [] if nothing is selected
                    is_calculator_selected = ~isempty(calculator_indices);
                    % Use numel because String can be '' (empty char) which is not empty
                    has_calculators = numel(calculator_strings) > 0;
                    % Set enable/disable states
                    on_off = {'off','on'};
                    set(deletePipelineButton, 'Enable', on_off{is_real_pipeline+1});
                    set(runButton, 'Enable', on_off{(is_real_pipeline && has_calculators)+1});
                    set(deleteCalcButton, 'Enable', on_off{(is_real_pipeline && is_calculator_selected)+1});
                    set(editButton, 'Enable', on_off{(is_real_pipeline && is_calculator_selected)+1});
                otherwise
                    disp(['Unknown command ' command '.']);
            end % switch(command)
        end % pipeline_edit()
        function calculatorInstanceList = getCalculatorInstancesFromPipeline(pipelineList, pipeline_name)
            %
            % ndi.cpipeline.getCalculatorInstancesFromPipeline - read a calculatorInstanceList from PIPELINELIST
            %
            % CALCLIST = ndi.cpipeline.getCalculatorInstancesFromPipeline(PIPELINELIST, PIPELINE_NAME)
            %
            % Input:
            %   PIPELINELIST: a list of pipelines
            %   PIPELINE_NAME: a name string of a specific pipeline in this pipeline list
            % Output:
            %   calculatorInstanceList: a list of calculators
            %
            calculatorInstanceList = [];
            for i = 1:length(pipelineList)
                if strcmp(pipelineList(i).pipeline_name, pipeline_name)
                    calculatorInstanceList = pipelineList(i).calculatorInstances;
                end
            end
        end % getCalculatorInstancesFromPipeline
        function calculatorInstanceListChar = calculatorInstancesToChar(calculatorInstanceList)
            %
            % ndi.cpipeline.calculatorInstancesToChar - read names of a calculatorInstanceList as a list of strings
            %
            % CALCLISTCHAR = ndi.cpipeline.calculatorInstancesToChar(calculatorInstanceList)
            %
            % Input:
            %   calculatorInstanceList: a list of calculators
            % Output:
            %   calculatorInstanceListChar: a list of strings, representing names of calculators in calculatorInstanceList
            %
            calculatorInstanceListChar = {};
            for i = 1:numel(calculatorInstanceList)
                calculatorInstanceListChar{i} = [calculatorInstanceList(i).instanceName ' (' calculatorInstanceList(i).JSONFilename ')'];
            end
        end % calculatorInstancesToChar
        function newCalculatorInstance = setDefaultCalculatorInstance(calculatorInstanceType, name)
            %
            % ndi.cpipeline.setDefaultCalculatorInstance - set default parameters for a new calculator
            %
            % NEWCALC = ndi.cpipeline.setDefaultCalculatorInstance(CALCULATOR, NAME)
            %
            % Input
            %   calculatorInstanceType: a type of calculator (EXAMPLE: ndi.calc.stimulus.tuningcurve)
            %   NAME: a name string of calculator
            % Output:
            %   newCalculatorInstance: a new calculator created by this function
            %
            newCalculatorInstance.calculatorClassname = calculatorInstanceType;
            newCalculatorInstance.instanceName = name;
            % Note: parameter_code is no longer part of the default instance
            newCalculatorInstance.default_options = containers.Map("if_document_exists_do","NoAction");
        end % setDefaultCalculatorInstance
        function pipelineList = getPipelines(read_dir)
            %
            % ndi.cpipeline.getPipelines - read a PIPELINE_LIST from directory READ_DIR
            %
            % PIPELINELIST = ndi.cpipeline.getPipelines(READ_DIR)
            %
            % Input:
            %   READ_DIR: a directory where the pipelines are stored as a PIPELINE_LIST
            % Output:
            %   PIPELINELIST: a list of pipelines
            %
            d = dir(read_dir);
            isub = [d(:).isdir];
            nameList = {d(isub).name}';
            nameList(ismember(nameList,{'.','..'})) = [];
            
            % Create a standard empty struct for calculator instances
            field_names = {'calculatorClassname','instanceName','JSONFilename','default_options'};
            empty_vals = cell(size(field_names));
            empty_calc_struct = cell2struct(empty_vals, field_names, 2);
            
            pipelineList(1).pipeline_name = '---';
            pipelineList(1).calculatorInstances = empty_calc_struct;

            for i = 1:numel(nameList)
                pipelineList(i+1).pipeline_name = nameList{i};
                D = dir(fullfile(read_dir, nameList{i}, '*.json'));
                if ~isempty(D)
                    temp_cell = {}; % Grow cell array safely
                    for d_i = 1:numel(D)
                        full_json_path = fullfile(read_dir, nameList{i}, D(d_i).name);
                        json_text = fileread(full_json_path);
                        
                        decoded_json = [];
                        try
                            if ~isempty(strtrim(json_text))
                                decoded_json = jsondecode(json_text);
                            else
                                % File is empty or whitespace only, don't even try to decode
                                warning('JSON file is empty and will be skipped: %s', full_json_path);
                            end
                        catch ME
                            warning('Could not decode JSON file, it may be corrupt and will be skipped: %s', full_json_path);
                            disp('For debugging, the full error report is below:');
                            disp(ME.getReport());
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
        end % getPipelines
        function pipelineListChar = pipelineListToChar(pipelineList)
            %
            % ndi.cpipeline.pipelineListToChar - read names of a PIPELINELIST as a list of strings
            %
            % PIPELINELISTCHAR = ndi.cpipeline.pipelineListToChar(PIPELINELIST)
            %
            % Input:
            %   PIPELINELIST: a list of pipelines
            % Output:
            %   PIPELINELISTCHAR: a list of strings, representing names of pipelines in PIPELINELIST
            %
            pipelineListChar = {pipelineList.pipeline_name};
        end % pipelineListToChar
        % }
    end % static methods
end % class