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
                    'EditButton','RunButton','PipelineContentList','DoEnableDisable'})} = 'new'
                options.pipelinePath (1,:) char = ndi.cpipeline.defaultPath()
                options.session ndi.session = ndi.session.empty();
                options.window_params (1,1) struct = struct('height', 500, 'width', 400)
                options.fig {mustBeA(options.fig,["matlab.ui.Figure","double"])} = []
                options.selectedPipeline (1,:) char = ''
                options.pipeline_name (1,:) char = ''
            end

            if isempty(options.fig)
                fig = gcf;
            else
                fig = options.fig;
            end

            if strcmpi(options.command,'new')
                if isempty(options.fig)
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
                        ud.session = options.session;
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
            if isempty(fig)
                error(['Empty figure, do not know what to work on.']);
            end
            disp(['Command is ' command '.']);
            switch (command)
                case 'NewWindow'
                    set(fig,'tag','ndi.cpipeline.edit');
                    uid = vlt.ui.basicuitools_defs;
                    callbackstr = [  'eval([get(gcbf,''Tag'') ''(''''command'''','''''' get(gcbo,''Tag'') '''''' ,''''fig'''',gcbf);'']);'];
                    % Step 1: Establish window geometry
                    top = options.window_params.height;
                    right = options.window_params.width;
                    row = 25;
                    title_height = 25;
                    title_width = 200;
                    edge = 5;
                    doc_width = (right - 2*edge)/3*2;
                    doc_height = (options.window_params.height)/4*3;
                    menu_width = right - 2*edge;
                    menu_height = title_height;
                    button_width = 120;
                    button_height = 25;
                    button_y = [400-2*row 400-4.5*row 400-6*row 400-8.5*row 400-10*row 400-11.5*row];
                    button_center = right-(right-doc_width)/2;
                    % Step 2 now build it
                    set(fig,'position',[50 50 right top]);
                    set(fig,'NumberTitle','off');
                    set(fig,'Name',['Editing ' ud.pipelinePath]);
                    % Pipeline selection portion of window
                    x = edge; y = top-row;
                    uicontrol(uid.txt,'position',[x y title_width title_height],'string','Select pipeline:','tag','PipelineTitleTxt');
                    uicontrol(uid.popup,'position',[x y-title_height menu_width menu_height],...
                        'string',ud.pipelineListChar,'tag','PipelinePopup','callback',callbackstr);
                    y = y - doc_height;
                    uicontrol(uid.edit,'style','listbox','position',[x y-2*title_height doc_width doc_height],...
                        'string',{'Please select or create a pipeline.'},...
                        'tag','PipelineContentList','min',0,'max',2,'callback',callbackstr);
                    uicontrol(uid.button,'position',[button_center-0.5*button_width button_y(1) button_width button_height],...
                        'string','->','tag','RunButton','callback',callbackstr,'Tooltipstring','Run pipeline calculations in order');
                    uicontrol(uid.button,'position',[button_center-0.5*button_width button_y(2) button_width button_height],...
                        'string','+','tag','NewPipelineButton','Tooltipstring','Create new pipeline',...
                        'callback',callbackstr);
                    uicontrol(uid.button,'position',[button_center-0.5*button_width button_y(3) button_width button_height],...
                        'string','-','Tooltipstring','Delete current pipeline','tag','DeletePipelineButton',...
                        'callback',callbackstr);
                    uicontrol(uid.button,'position',[button_center-0.5*button_width button_y(4) button_width button_height],...
                        'string','+','Tooltipstring','Create new Calculator instance','tag','NewCalculatorInstanceButton',...
                        'callback',callbackstr);
                    uicontrol(uid.button,'position',[button_center-0.5*button_width button_y(5) button_width button_height],...
                        'string','-','Tooltipstring','Delete current Calculator instance','tag','DeleteCalculatorInstanceButton','callback',callbackstr);
                    uicontrol(uid.button,'position',[button_center-0.5*button_width button_y(6) button_width button_height],...
                        'string','Edit','tooltipstring','Edit selected Calculator instance','tag','EditButton','callback',callbackstr);
                    ndi.cpipeline.edit('command','LoadPipelines','fig',fig); % load the pipelines from disk
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
                    if index == 1
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
                    if val == 1
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
                    % get calculator type
                    calcTypeList = {'ndi.calc.not_finished_yet','ndi.calc.need_calculator_types','ndi.calc.this_is_a_placeholder'};
                    [calcTypeStr,calcTypeVal] = listdlg('PromptString','Choose a calculator type:',...
                        'SelectionMode','single','ListString',calcTypeList);
                    if (calcTypeVal == 0) % check selection
                        return
                    end
                    calculatorInstanceType = calcTypeList{calcTypeStr};
                    % ask for file name
                    read_dir = [ud.pipelinePath filesep pipeline_name filesep];
                    prompt = {'Calculator instance name:'};
                    dlgtitle = 'Create new Calculator instance';
                    defaultfilename = {['untitled']};
                    extension_list = {['.json']};
                    [success,calculatorInstanceName,replaces] = ndi.util.choosefileordir(read_dir, prompt, defaultfilename, dlgtitle, extension_list);
                    if success % if success, create and save newCalc
                        if replaces
                            delete([read_dir filesep calculatorInstanceName '.json']);
                        end
                        newCalculatorInstance = ndi.cpipeline.setDefaultCalculatorInstance(calculatorInstanceType, calculatorInstanceName);
                        json_filename = char(strcat(read_dir,calculatorInstanceName,'.json'));
                        fid = fopen(json_filename,'w');
                        fprintf(fid,jsonencode(newCalculatorInstance));
                        fclose(fid);
                        % update and load calculator
                        ndi.cpipeline.edit('command','UpdatePipelines','fig',fig);
                        ndi.cpipeline.edit('command','UpdateCalculatorInstanceList','pipeline_name',pipeline_name,'fig',fig);
                    end
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
                    ndi.calculator.graphical_edit_calculator('command','Edit','filename',full_calculatorInstance_name,'session',ud.session);
                case 'RunButton'
                    disp([command 'is not implemented yet.']);
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
            newCalculatorInstance.parameter_code = '';
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
            pipelineList(1).pipeline_name = '---';
            pipelineList(1).calculatorInstances = vlt.data.emptystruct('calculatorClassname','instanceName','JSONFilename','parameter_code','default_options');
            for i = 1:numel(nameList)
                pipelineList(i+1).pipeline_name = nameList{i};
                D = dir([read_dir filesep nameList{i} filesep '*.json']);
                if ~isempty(D)
                    temp_cell = cell(1, numel(D));
                    for d_i = 1:numel(D)
                        json_text = vlt.file.textfile2char([read_dir filesep nameList{i} filesep D(d_i).name]);
                        decoded_json = jsondecode(json_text);
                        
                        % Flatten the structure from the old format to the new format
                        new_instance = struct();
                        new_instance.calculatorClassname = decoded_json.ndi_pipeline_element.calculator;
                        new_instance.instanceName = decoded_json.ndi_pipeline_element.name;
                        new_instance.parameter_code = decoded_json.ndi_pipeline_element.parameter_code;
                        new_instance.default_options = decoded_json.ndi_pipeline_element.default_options;
                        new_instance.JSONFilename = D(d_i).name; % Add the filename

                        temp_cell{d_i} = new_instance;
                    end
                    pipelineList(i+1).calculatorInstances = [temp_cell{:}];
                else
                    pipelineList(i+1).calculatorInstances = vlt.data.emptystruct('calculatorClassname','instanceName','JSONFilename','parameter_code','default_options');
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
