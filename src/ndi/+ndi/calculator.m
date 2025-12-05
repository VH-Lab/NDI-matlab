classdef calculator < ndi.app & ndi.app.appdoc & ndi.mock.ctest
    properties (SetAccess=protected,GetAccess=public)
        fast_start = 'ndi.calculator.graphical_edit_calculator(''command'',''new'',''type'',''ndi.calc.vis.contrast'',''name'',''mycalc'')';
    end % properties
    methods
        function ndi_calculator_obj = calculator(varargin)
            % CALCULATOR - create an ndi.calculator object
            session = [];
            if nargin>0
                session = varargin{1};
            end
            ndi_calculator_obj = ndi_calculator_obj@ndi.app(session);
            if nargin>1
                document_type = varargin{2};
            else
                document_type = '';
            end
            if nargin>2
                path_to_doc_type = varargin{3};
            else
                path_to_doc_type = '';
            end
            ndi_calculator_obj = ndi_calculator_obj@ndi.app.appdoc({document_type}, ...
                {path_to_doc_type},session);
            ndi_calculator_obj.name = class(ndi_calculator_obj);
        end % calculator creator
        
        function docs = run(ndi_calculator_obj, docExistsAction, parameters)
            % RUN - run calculator on all possible inputs that match some parameters
            docs = {};
            docs_tocat = {};
            docs_to_add = {}; % Documents that need to be saved to DB
            
            if nargin<3
                parameters = ndi_calculator_obj.default_search_for_input_parameters();
            end
            
            all_parameters = ndi_calculator_obj.search_for_input_parameters(parameters);
            
            mylog = ndi.common.getLogger();
            mylog.msg('system',1,['Beginning calculator by class ' class(ndi_calculator_obj) '...']);
            for i=1:numel(all_parameters)
                mylog.msg('system',1,['Performing calculator ' int2str(i) ' of ' int2str(numel(all_parameters)) '.']);
                previous_calculators_here = ndi_calculator_obj.search_for_calculator_docs(all_parameters{i});
                do_calc = 0;
                if ~isempty(previous_calculators_here)
                    switch(docExistsAction)
                        case 'Error'
                            error(['Doc for input parameters already exists; error was requested.']);
                        case {'NoAction','ReplaceIfDifferent'}
                            % We found existing docs, keep them for output, but DO NOT add to docs_to_add
                            docs_tocat{i} = previous_calculators_here;
                            continue; % skip to the next calculator
                        case {'Replace'}
                            ndi_calculator_obj.session.database_rm(previous_calculators_here);
                            do_calc = 1;
                    end
                else
                    do_calc = 1;
                end
                if do_calc
                    docs_out = ndi_calculator_obj.calculate(all_parameters{i});
                    if ~iscell(docs_out)
                        docs_out = {docs_out};
                    end
                    docs_tocat{i} = docs_out;
                    % These are new, so we must add them to the DB list
                    docs_to_add = cat(2, docs_to_add, docs_out);
                end
            end
            
            % Combine all docs for the return variable
            for i=1:numel(all_parameters)
                if i <= numel(docs_tocat)
                    docs = cat(2,docs,docs_tocat{i});
                end
            end
            
            % Process ONLY the new documents for database addition
            if ~isempty(docs_to_add)
                app_doc = ndi_calculator_obj.newdocument();
                for i=1:numel(docs_to_add)
                    docs_to_add{i} = docs_to_add{i}.setproperties('app',app_doc.document_properties.app);
                end
                ndi_calculator_obj.session.database_add(docs_to_add);
            end
            
            mylog.msg('system',1,'Concluding calculator.');
        end % run()
        
        function parameters = default_search_for_input_parameters(ndi_calculator_obj)
            parameters.input_parameters = [];
            parameters.depends_on = vlt.data.emptystruct('name','value');
        end 
        
        function parameters = search_for_input_parameters(ndi_calculator_obj, parameters_specification, varargin)
            if ~isstruct(parameters_specification)
                error('parameters_specification must be a structure. Received: %s', class(parameters_specification));
            end
            
            fixed_input_parameters = parameters_specification.input_parameters;
            if isfield(parameters_specification,'depends_on')
                fixed_depends_on = parameters_specification.depends_on;
            else
                fixed_depends_on = vlt.data.emptystruct('name','value');
            end
            for i=1:numel(fixed_depends_on)
                q = ndi.query('base.id','exact_string',fixed_depends_on(i).value,'');
                l = ndi_calculator_obj.session.database_search(q);
                if numel(l)~=1
                    error(['Could not locate ndi document with id ' fixed_depends_on(i).value ' that corresponded to name ' fixed_depends_on(i).name '.']);
                end
            end
            if ~isfield(parameters_specification,'query')
                parameters_specification.query = ndi_calculator_obj.default_parameters_query(parameters_specification);
            end
            if numel(parameters_specification.query)==0
                parameters.input_parameters = fixed_input_parameters;
                parameters.depends_on = fixed_depends_on;
                parameters = {parameters}; 
                return;
            end
            doclist = {};
            V = [];
            for i=1:numel(parameters_specification.query)
                doclist{i} = ndi_calculator_obj.session.database_search(parameters_specification.query(i).query);
                V(i) = numel(doclist{i});
            end
            parameters = {};
            for n=1:prod(V)
                is_valid = 1;
                g = vlt.math.group_enumeration(V,n);
                extra_depends = vlt.data.emptystruct('name','value');
                for i=1:numel(parameters_specification.query)
                    if isfield(parameters_specification.query(i), 'name')
                        q_name = parameters_specification.query(i).name;
                    else
                        q_name = ['query_' num2str(i)];
                    end
                    s = struct('name',q_name,'value',doclist{i}{g(i)}.id());
                    is_valid = is_valid & ndi_calculator_obj.is_valid_dependency_input(s.name,s.value);
                    extra_depends(end+1) = s;
                    if ~is_valid
                        break;
                    end
                end
                if is_valid
                    parameters_here.input_parameters = fixed_input_parameters;
                    parameters_here.depends_on = cat(1,fixed_depends_on(:),extra_depends(:));
                    parameters{end+1} = parameters_here;
                end
            end
        end 
        
        function query = default_parameters_query(ndi_calculator_obj, parameters_specification)
            query = vlt.data.emptystruct('name','query');
            if isfield(parameters_specification.input_parameters,'depends_on')
                for i=1:numel(parameters_specification.input_parameters.depends_on)
                    if ~isempty(parameters_specification.input_parameters.depends_on(i).value) & ...
                            ~isempty(parameters_specification.input_parameters.depends_on(i).name)
                        query_here = struct('name',parameters_specification.input_parameters.depends_on(i).name,...
                            'query',...
                            ndi.query('base.id','exact_string',parameters_specification.input_parameters.depends_on(i).value,''));
                        query(end+1) = query_here;
                    end
                end
            end
        end 
        
        function docs = search_for_calculator_docs(ndi_calculator_obj, parameters)
            myemptydoc = ndi.document(ndi_calculator_obj.doc_document_types{1});
            property_list_name = myemptydoc.document_properties.document_class.property_list_name;
            [parent,class_name,ext] = fileparts(myemptydoc.document_properties.document_class.definition);
            q_type = ndi.query('','isa',class_name,'');
            q = q_type;
            if isfield(parameters,'depends_on')
                for i=1:numel(parameters.depends_on)
                    if ~isempty(parameters.depends_on(i).value)
                        q = q & ndi.query('','depends_on',parameters.depends_on(i).name,parameters.depends_on(i).value);
                    end
                end
            end
            docs = ndi_calculator_obj.session.database_search(q);
            matches = [];
            for i=1:numel(docs)
                try
                    input_param = eval(['docs{i}.document_properties.' property_list_name '.input_parameters;']);
                catch
                    input_param = [];
                end
                if ndi_calculator_obj.are_input_parameters_equivalent(input_param,parameters.input_parameters)
                    matches(end+1) = i;
                end
            end
            docs = docs(matches);
        end 
        
        function b = are_input_parameters_equivalent(ndi_calculator_obj, input_parameters1, input_parameters2)
            if ~isempty(input_parameters1)
                input_parameters1 = vlt.data.columnize_struct(input_parameters1);
            end
            if ~isempty(input_parameters2)
                input_parameters2 = vlt.data.columnize_struct(input_parameters2);
            end
            b = eqlen(input_parameters1, input_parameters2);
        end
        
        function b = is_valid_dependency_input(ndi_calculator_obj, name, value)
            b = 1; 
        end 
        
        function doc = calculate(ndi_calculator_obj, parameters)
            doc = {};
        end 
        
        function h=plot(ndi_calculator_obj, doc_or_parameters, varargin)
            params = ndi.calculator.plot_parameters(varargin{:});
            h.axes = [];
            h.figure = [];
            h.objects = [];
            h.params = params;
            h.title = [];
            h.xlabel = [];
            h.ylabel = [];
            h.zlabel = [];
            if params.newfigure
                h.figure = figure;
            else
                h.figure = gcf;
            end
            h.axes = gca;
            if ~params.suppress_title
                if isa(doc_or_parameters,'ndi.document')
                    id = doc_or_parameters.id();
                    h.title = title([id],'interp','none');
                end
            end
            if params.holdstate
                hold on;
            else
                hold off;
            end
        end 
        
        function b = isequal_appdoc_struct(ndi_app_appdoc_obj, appdoc_type, appdoc_struct1, appdoc_struct2)
            b = vlt.data.partial_struct_match(appdoc_struct1, appdoc_struct2);
        end 
        
        function text = doc_about(ndi_calculator_obj)
            text = ndi.calculator.docfiletext(class(ndi_calculator_obj), 'output');
        end 
        
        function text = appdoc_description(ndi_calculator_obj)
            text = ndi_calculator_obj.doc_about();
        end 
    end % methods
    
    methods (Static)
        function param = plot_parameters(varargin)
            newfigure = 0;
            holdstate = 0;
            suppress_x_label = 0;
            suppress_y_label = 0;
            suppress_z_label = 0;
            suppress_title = 0;
            vlt.data.assign(varargin{:});
            param = vlt.data.workspace2struct();
            param = rmfield(param,'varargin');
        end
        
        function graphical_edit_calculator(options)
            arguments
                options.command (1,:) char {mustBeMember(options.command, {'New','Edit','Close',...
                    'NewWindow','UpdateWindow','DocPopup', 'ParameterCodePopup',...
                    'CommandPopup', 'SaveButton', 'CancelButton', 'ExitButton', 'SaveAsButton',...
                    'DeleteParameterInstanceButton', 'RefreshParameterPopup', 'RefreshPipelineButton'})} = 'New'
                options.session = [] 
                options.name (1,:) char = ''
                options.filename (1,:) char = ''
                options.calculatorClassname (1,:) char = ''
                options.window_params (1,1) struct = struct('height', 600, 'width', 700)
                options.fig {mustBeA(options.fig,["matlab.ui.Figure","double"])} = []
                options.pipelinePath (1,:) char = '' % Path to pipeline FOLDER
                options.viewOnly (1,1) logical = false
                options.code = '' % Relaxed validation: accept any text/empty
                options.paramName (1,:) char = '' % Title for view mode
            end
            
            % Validate Session if provided
            if ~isempty(options.session) && ~isa(options.session, 'ndi.session')
                error('The provided session is not a valid ndi.session object.');
            end
            
            command = options.command;
            fig = options.fig;
            
            if strcmp(command,'New')
                calculatorInstance.JSONFilename = options.filename;
                calculatorInstance.instanceName = options.name;
                calculatorInstance.calculatorClassname = options.calculatorClassname;
                ud.calculatorInstance = calculatorInstance;
                ud.window_params = options.window_params;
                ud.linked_object = options.session; 
                ud.active_parameter_name = ''; 
                ud.pipelinePath = options.pipelinePath;
                ud.viewOnly = options.viewOnly;
                ud.code = options.code;
                ud.paramName = options.paramName;
                if isempty(fig), fig = figure; end
                command = 'NewWindow';
            elseif strcmp(command,'Edit')
                if options.viewOnly
                    % View only mode for Instance: Create dummy struct if file doesn't exist
                     ud.calculatorInstance.JSONFilename = '';
                     ud.calculatorInstance.instanceName = options.name;
                     ud.calculatorInstance.calculatorClassname = options.calculatorClassname;
                else
                    try
                         ud.calculatorInstance = jsondecode(fileread(options.filename));
                    catch
                         error(['Unable to read calculator instance file: ' options.filename]);
                    end
                end
                
                ud.calculatorInstance.JSONFilename = options.filename; 
                ud.linked_object = options.session; 
                ud.active_parameter_name = ''; 
                ud.pipelinePath = options.pipelinePath;
                ud.viewOnly = options.viewOnly;
                ud.code = options.code;
                ud.paramName = options.paramName;
                
                if ~isfield(ud,'window_params'), ud.window_params = options.window_params; end
                command = 'NewWindow';
                if isempty(fig), fig = figure; end
            else
                ud = get(fig,'userdata');
            end
            
            % Construct path to user_parameters.json in the pipeline folder
            if ~isempty(ud.pipelinePath)
                user_param_file = fullfile(ud.pipelinePath, 'user_parameters.json');
            else
                user_param_file = '';
            end
            
            switch (command)
                case 'NewWindow'
                    set(fig,'tag','ndi.calculator.graphical_edit_calculator');
                    set(fig,'userdata',ud); 
                    uid = vlt.ui.basicuitools_defs;
                    callbackstr = [  'eval([get(gcbf,''Tag'') ''(''''command'''','''''' get(gcbo,''Tag'') '''''' ,''''fig'''',gcbf);'']);'];
                    
                    fig_bg_color = [0.8 0.8 0.8];
                    box_bg_color = [0.9 0.9 0.9];
                    edit_bg_color = [1 1 1];
                    top = ud.window_params.height;
                    right = ud.window_params.width;
                    
                    edge_n = 10/right;
                    row_h_n = 25/top;
                    gap_v_n = 15/top;
                    button_area_h_n = 5*row_h_n;
                    
                    title_prefix = 'Editing ';
                    if ud.viewOnly, title_prefix = 'Viewing '; end
                    
                    set(fig,'position',[50 50 right top], 'Color', fig_bg_color, 'NumberTitle','off',...
                        'Name',[title_prefix ud.calculatorInstance.instanceName ' of type ' ud.calculatorInstance.calculatorClassname ],...
                        'MenuBar','none','ToolBar','none','Units','normalized');
                    
                    y_cursor = 1 - edge_n;
                    main_area_h = y_cursor - button_area_h_n - edge_n;
                    doc_section_h = main_area_h * 0.25;
                    param_section_h = main_area_h * 0.75;
                    
                    y_cursor = y_cursor - row_h_n;
                    uicontrol(uid.txt,'Units','normalized','position',[edge_n y_cursor 0.6 row_h_n],'string','Documentation', ...
                        'tag','DocTitleTxt','BackgroundColor',fig_bg_color,'FontWeight','bold','HorizontalAlignment','left');
                    uicontrol(uid.popup,'Units','normalized','position',[edge_n+0.6 y_cursor 1-2*edge_n-0.6 row_h_n],...
                        'string',{'General','Calculator Input Options','Output document'},'tag','DocPopup','callback',callbackstr,...
                        'value',1,'BackgroundColor',edit_bg_color);
                    y_cursor = y_cursor - (doc_section_h - row_h_n);
                    uicontrol(uid.edit,'Units','normalized','position',[edge_n y_cursor 1-2*edge_n doc_section_h-row_h_n],...
                        'string','Please select one documentation type.',...
                        'tag','DocTxt','min',0,'max',2,'enable','inactive','BackgroundColor',box_bg_color,'HorizontalAlignment','left');
                        
                    y_cursor = y_cursor - gap_v_n - row_h_n;
                     uicontrol(uid.txt,'Units','normalized','position',[edge_n y_cursor 0.6 row_h_n],'string','Parameter code:', ...
                        'tag','ParameterCodeTitleTxt','BackgroundColor',fig_bg_color,'FontWeight','bold','HorizontalAlignment','left');
                    
                    if ud.viewOnly
                         popup_enable = 'off';
                         param_code_bg = box_bg_color;
                         param_code_enable = 'inactive';
                         init_code = ud.code;
                         if isempty(ud.paramName), popup_str = {'View Only'}; else, popup_str = {ud.paramName}; end
                    else
                         popup_enable = 'on';
                         param_code_bg = edit_bg_color;
                         param_code_enable = 'on';
                         init_code = ndi.calculator.user_parameter_template(ud.calculatorInstance.calculatorClassname);
                         [param_names,~] = ndi.calculator.readParameterCode(ud.calculatorInstance.calculatorClassname, user_param_file);
                         popup_str = {'Template', 'Default', '---', param_names{:}};
                    end
                    
                    uicontrol(uid.popup,'Units','normalized','position',[edge_n+0.6 y_cursor 1-2*edge_n-0.6 row_h_n],...
                        'string',popup_str,...
                        'tag','ParameterCodePopup', 'callback',callbackstr,'value',1,'BackgroundColor',edit_bg_color, 'Enable', popup_enable);
                        
                    y_cursor = y_cursor - (param_section_h - row_h_n);
                    
                    uicontrol(uid.edit,'Units','normalized','position',[edge_n y_cursor 1-2*edge_n param_section_h-row_h_n],...
                        'string',init_code,...
                        'tag','ParameterCodeTxt','min',0,'max',2,'BackgroundColor',param_code_bg,'HorizontalAlignment','left', 'Enable', param_code_enable);
                    
                    y_cursor = y_cursor - gap_v_n - row_h_n;
                    uicontrol(uid.popup,'Units','normalized','position',[edge_n y_cursor 1-2*edge_n row_h_n],...
                        'string',{'Commands:','---','Try searching for inputs','Show existing outputs',...
                        'Plot existing outputs','Run but don''t replace existing docs','Run and replace existing docs'},...
                        'tag','CommandPopup','callback',callbackstr,'BackgroundColor',edit_bg_color);
                    
                    y_cursor = y_cursor - gap_v_n - row_h_n;
                    
                    % --- BUTTON ROW CONFIGURATION (5 Buttons) ---
                    num_buttons = 5;
                    button_w_n = 0.16; % Narrower to fit 5
                    button_centers_n = linspace(edge_n+button_w_n/2, 1-edge_n-button_w_n/2, num_buttons);
                    
                    save_enable = 'on';
                    if ud.viewOnly, save_enable = 'off'; end
                    
                    % 1: Save
                    uicontrol(uid.button,'Units','normalized','position',[button_centers_n(1)-button_w_n/2 y_cursor button_w_n row_h_n],...
                        'string','Save','tag','SaveButton','callback',callbackstr, 'Enable', save_enable);
                    
                    % 2: Save As
                    uicontrol(uid.button,'Units','normalized','position',[button_centers_n(2)-button_w_n/2 y_cursor button_w_n row_h_n],...
                        'string','Save As...','tag','SaveAsButton','callback',callbackstr, 'Enable', save_enable);
                    
                    % 3: Delete
                    uicontrol(uid.button,'Units','normalized','position',[button_centers_n(3)-button_w_n/2 y_cursor button_w_n row_h_n],...
                        'string','Delete...','tag','DeleteParameterInstanceButton','callback',callbackstr, 'Enable', save_enable);
                    
                    % 4: Refresh
                    uicontrol(uid.button,'Units','normalized','position',[button_centers_n(4)-button_w_n/2 y_cursor button_w_n row_h_n],...
                        'string','Refresh','tag','RefreshPipelineButton','callback',callbackstr, 'Enable', save_enable);
                    
                    % 5: Exit (Replaces Cancel)
                    uicontrol(uid.button,'Units','normalized','position',[button_centers_n(5)-button_w_n/2 y_cursor button_w_n row_h_n],...
                        'string','Exit','tag','ExitButton','callback',callbackstr);
                    
                    ndi.calculator.graphical_edit_calculator('command','DocPopup','fig',fig);
                    
                % ... [DocPopup, CommandPopup cases unchanged] ...
                 case 'DocPopup'
                    try
                        docPopupObj = findobj(fig,'tag','DocPopup');
                        val = get(docPopupObj, 'value');
                        docTextObj = findobj(fig,'tag','DocTxt');
                        switch val
                            case 1, doc_type = 'general';
                            case 2, doc_type = 'searching for inputs';
                            case 3, doc_type = 'output';
                            otherwise, error('Unknown doc popup value.');
                        end
                        mytext = ndi.calculator.docfiletext(ud.calculatorInstance.calculatorClassname, doc_type);
                        set(docTextObj,'string',mytext);
                    catch ME
                        errordlg(['An error occurred while loading documentation: ' ME.message]);
                    end
                    
                case 'CommandPopup'
                    cmdPopupObj = findobj(fig,'tag','CommandPopup');
                    val = get(cmdPopupObj, 'value');
                    
                    if isempty(ud.linked_object) 
                        try 
                            ud.linked_object = evalin('base', 'S');
                        catch
                            errordlg('No NDI session linked and variable S not found in base workspace.', 'Session Error');
                            set(cmdPopupObj, 'Value', 1);
                            % Bring windows to front
                            pipeline_fig = findobj('tag','ndi.cpipeline.edit');
                            if ~isempty(pipeline_fig), figure(pipeline_fig(1)); end
                            figure(fig);
                            return;
                        end
                    end
                    
                    assignin('base','pipeline_session',ud.linked_object);
                    assignin('base','S',ud.linked_object); 
                    
                    paramTextObj = findobj(fig,'tag','ParameterCodeTxt');
                    code_from_box = get(paramTextObj,'string');
                    
                    if iscell(code_from_box)
                        param_code = strjoin(code_from_box, newline);
                    elseif size(code_from_box, 1) > 1
                        param_code = strjoin(cellstr(code_from_box), newline);
                    else
                        param_code = code_from_box;
                    end
                    
                    evalin('base', 'if exist(''parameters'',''var''), clear parameters; end');
                    
                    try
                        evalin('base',param_code);
                    catch ME
                         errordlg(['Error evaluating parameter code: ' ME.message]);
                         % Bring windows to front
                         pipeline_fig = findobj('tag','ndi.cpipeline.edit');
                         if ~isempty(pipeline_fig), figure(pipeline_fig(1)); end
                         figure(fig);
                         return;
                    end
                    
                    if ~evalin('base', 'exist(''parameters'',''var'')')
                        errordlg('Defined input parameters insufficient. Create a variable named ''parameters'' to run.', 'Parameter Error');
                        % Bring windows to front
                        pipeline_fig = findobj('tag','ndi.cpipeline.edit');
                        if ~isempty(pipeline_fig), figure(pipeline_fig(1)); end
                        figure(fig);
                        return;
                    end
                    
                    switch val
                        case 3 % Search
                             evalin('base', ['if exist(''parameters'',''var'') && isstruct(parameters) && isfield(parameters,''query'') && ~isempty(parameters.query), ' ...
                                             '  if isfield(parameters.query(1),''query''), ' ...
                                             '    MYQ = parameters.query(1).query; ' ...
                                             '    DOCS = pipeline_session.database_search(MYQ); ' ...
                                             '    disp([''Found '' num2str(numel(DOCS)) '' matching documents for the current query.'']); ' ...
                                             '  else, disp(''Error: parameters.query(1) missing "query" field.''); end; ' ...
                                             'else, disp(''Error: parameters variable is not a valid structure or missing "query" field.''); end']);
                             msgbox({'Search Check Complete.', 'Look at Command Window for document count.', 'See variable DOCS for document information.'}, 'Search Results', 'modal');
                             
                        case 4 % Show outputs
                             search_code = ['thecalc=' ud.calculatorInstance.calculatorClassname '(pipeline_session); ' ...
                                            'if ~exist(''parameters'',''var'') || ~isstruct(parameters), parameters=thecalc.default_search_for_input_parameters(); end; ' ...
                                            'ED=thecalc.search_for_calculator_docs(parameters);'];
                             evalin('base',search_code);
                             ED = evalin('base','ED');
                             assignin('base', 'NDI_CALCULATOR_OUTPUT_DOCS', ED);
                             
                             if ~isempty(ED)
                                 evalin('base', 'openvar(''NDI_CALCULATOR_OUTPUT_DOCS'')');
                                 msgbox('Output documents opened in MATLAB Variable Editor.', 'Outputs Found', 'modal');
                             else
                                 msgbox('No existing output documents found.', 'No Outputs', 'modal');
                             end
                             
                        case 5 % Plot outputs
                             search_code = ['thecalc=' ud.calculatorInstance.calculatorClassname '(pipeline_session); ' ...
                                            'if ~exist(''parameters'',''var'') || ~isstruct(parameters), parameters=thecalc.default_search_for_input_parameters(); end; ' ...
                                            'ED=thecalc.search_for_calculator_docs(parameters);'];
                             evalin('base',search_code);
                             ED = evalin('base','ED');
                             
                             if isempty(ED)
                                 msgbox('No docs to plot.', 'Plotting', 'modal');
                             else
                                 answer = questdlg('Plot individual figures or create subplots?', ...
                                     'Plot Mode', 'Individual', 'Subplots', 'Individual');
                                 
                                 calc_obj = feval(ud.calculatorInstance.calculatorClassname, ud.linked_object);
                                 
                                 if strcmp(answer, 'Individual')
                                     for i = 1:numel(ED)
                                         calc_obj.plot(ED{i}, 'newfigure', 1);
                                     end
                                 elseif strcmp(answer, 'Subplots')
                                     N = numel(ED);
                                     num_figs = max(1, min(5, ceil(N/5)));
                                     
                                     for f = 1:num_figs
                                         figure; 
                                         set(gcf, 'Name', sprintf('Subplots Batch %d of %d', f, num_figs), 'NumberTitle', 'on');
                                         items_per_fig = ceil(N / num_figs);
                                         start_idx = (f-1)*items_per_fig + 1;
                                         end_idx = min(f*items_per_fig, N);
                                         
                                         if start_idx > N, break; end
                                         current_chunk = ED(start_idx:end_idx);
                                         num_in_chunk = numel(current_chunk);
                                         
                                         n_cols = ceil(sqrt(num_in_chunk));
                                         n_rows = ceil(num_in_chunk / n_cols);
                                         
                                         for k = 1:num_in_chunk
                                             subplot(n_rows, n_cols, k);
                                             try
                                                 calc_obj.plot(current_chunk{k}, 'newfigure', 0, 'suppress_title', 0);
                                             catch plot_err
                                                  text(0.5, 0.5, 'Error plotting', 'HorizontalAlignment', 'center');
                                                  warning(['Error plotting doc ' num2str(k) ': ' plot_err.message]);
                                             end
                                         end
                                     end
                                 end
                             end
                       case 6 % Run (No Replace)
                             fprintf('\n--- CALCULATOR COMMAND RUN ---\n');
                             fprintf('STEP: %s (Params: %s)\n', ud.calculatorInstance.instanceName, ud.active_parameter_name);
                             
                             try
                                 evalin('base',['thecalc=' ud.calculatorInstance.calculatorClassname '(pipeline_session); RUNDOCS=thecalc.run(''NoAction'',parameters);']);
                                 RUNDOCS = evalin('base','RUNDOCS');
                                 num_docs = numel(RUNDOCS);
                                 fprintf('  Result: %d docs generated.\n', num_docs);
                                 msgbox('Run complete. Results in RUNDOCS.', 'Success', 'modal');
                             catch e
                                 errordlg(e.message, 'Execution Error', 'modal');
                                 fprintf('  Result: Execution Failed (%s).\n', e.message);
                             end
                             
                        case 7 % Run (Replace)
                             fprintf('\n--- CALCULATOR COMMAND RUN ---\n');
                             fprintf('STEP: %s (Params: %s)\n', ud.calculatorInstance.instanceName, ud.active_parameter_name);
                             
                             try
                                 evalin('base',['thecalc=' ud.calculatorInstance.calculatorClassname '(pipeline_session); RUNDOCS=thecalc.run(''Replace'', parameters);']);
                                 RUNDOCS = evalin('base','RUNDOCS');
                                 num_docs = numel(RUNDOCS);
                                 fprintf('  Result: %d docs generated and replaced existing docs.\n', num_docs);
                                 msgbox('Run complete. Results in RUNDOCS.', 'Success', 'modal');
                             catch e
                                 errordlg(e.message, 'Execution Error', 'modal');
                                 fprintf('  Result: Execution Failed (%s).\n', e.message);
                             end
                    end
                    
                    % Final Window Management: Bring Pipeline then Editor to Front
                    pipeline_fig = findobj('tag','ndi.cpipeline.edit');
                    if ~isempty(pipeline_fig), figure(pipeline_fig(1)); end
                    figure(fig);
                
                case 'ParameterCodePopup'
                    paramPopupObj = findobj(fig,'tag','ParameterCodePopup');
                    val = get(paramPopupObj, 'value');
                    paramTextObj = findobj(fig,'tag','ParameterCodeTxt');
                    [names, contents] = ndi.calculator.readParameterCode(ud.calculatorInstance.calculatorClassname, user_param_file);
                    switch val
                        case 1 
                            set(paramTextObj,'string',ndi.calculator.user_parameter_template(ud.calculatorInstance.calculatorClassname));
                            ud.active_parameter_name = '';
                        case 2 
                            set(paramTextObj,'string',ndi.calculator.parameter_default(ud.calculatorInstance.calculatorClassname));
                            ud.active_parameter_name = 'default';
                        case 3 
                            % separator
                        otherwise 
                            ex_idx = val - 3;
                            if ex_idx <= numel(contents)
                                set(paramTextObj,'string',contents{ex_idx});
                                ud.active_parameter_name = names{ex_idx};
                            end
                    end
                    set(fig,'userdata',ud);
                    
                case 'SaveButton'
                    if isempty(ud.active_parameter_name) || strcmp(ud.active_parameter_name, 'default')
                        msgbox('Use Save As for templates/defaults.', 'Error', 'modal'); 
                        pipeline_fig = findobj('tag','ndi.cpipeline.edit');
                        if ~isempty(pipeline_fig), figure(pipeline_fig(1)); end
                        figure(fig);
                        return;
                    end
                    paramTextObj = findobj(fig,'tag','ParameterCodeTxt');
                    code_from_box = get(paramTextObj,'String');
                    if iscell(code_from_box), code = strjoin(code_from_box, sprintf('\n')); else, code = code_from_box; end
                    
                    try
                        ndi.calculator.addParameterCode(ud.calculatorInstance.calculatorClassname, ud.active_parameter_name, code, user_param_file);
                        msgbox('Saved to pipeline folder.', 'Success', 'modal');
                    catch ME
                        errordlg(['Save failed: ' ME.message], 'Error', 'modal');
                    end
                    
                    pipeline_fig = findobj('tag','ndi.cpipeline.edit');
                    if ~isempty(pipeline_fig), figure(pipeline_fig(1)); end
                    figure(fig);
                    
                case 'SaveAsButton'
                    paramTextObj = findobj(fig,'tag','ParameterCodeTxt');
                    code_from_box = get(paramTextObj,'String');
                    if iscell(code_from_box), code = strjoin(code_from_box, sprintf('\n')); else, code = code_from_box; end
                    ans = inputdlg('Name:');
                    if isempty(ans), return; end
                    name = ans{1};
                    
                    try
                        ndi.calculator.addParameterCode(ud.calculatorInstance.calculatorClassname, name, code, user_param_file);
                        ud.active_parameter_name = name; set(fig,'userdata',ud);
                        ndi.calculator.graphical_edit_calculator('command','RefreshParameterPopup','fig',fig);
                    catch ME
                        errordlg(['Save failed: ' ME.message], 'Error', 'modal');
                    end
                    
                    pipeline_fig = findobj('tag','ndi.cpipeline.edit');
                    if ~isempty(pipeline_fig), figure(pipeline_fig(1)); end
                    figure(fig);
                    
                case 'DeleteParameterInstanceButton'
                    [names, ~] = ndi.calculator.readParameterCode(ud.calculatorInstance.calculatorClassname, user_param_file);
                    if isempty(names)
                        msgbox('Nothing to delete.', 'Info', 'modal'); 
                        pipeline_fig = findobj('tag','ndi.cpipeline.edit');
                        if ~isempty(pipeline_fig), figure(pipeline_fig(1)); end
                        figure(fig);
                        return; 
                    end
                    [idx, ok] = listdlg('ListString',names);
                    if ok
                        name = names{idx};
                        try
                            ndi.calculator.deleteParameterCode(ud.calculatorInstance.calculatorClassname, name, user_param_file);
                            ndi.calculator.graphical_edit_calculator('command','RefreshParameterPopup','fig',fig);
                        catch ME
                            errordlg(['Delete failed: ' ME.message], 'Error', 'modal');
                        end
                    end
                    pipeline_fig = findobj('tag','ndi.cpipeline.edit');
                    if ~isempty(pipeline_fig), figure(pipeline_fig(1)); end
                    figure(fig);
                    
                case 'RefreshParameterPopup'
                    [new_names, ~] = ndi.calculator.readParameterCode(ud.calculatorInstance.calculatorClassname, user_param_file);
                    paramPopupObj = findobj(fig,'tag','ParameterCodePopup');
                    new_string = {'Template', 'Default', '---', new_names{:}};
                    current_val = 1;
                    if ~isempty(ud.active_parameter_name)
                        if strcmp(ud.active_parameter_name,'default'), current_val=2;
                        else
                            f = find(strcmp(ud.active_parameter_name, new_names));
                            if ~isempty(f), current_val = f(1)+3; end
                        end
                    end
                    set(paramPopupObj, 'string', new_string, 'value', current_val);
                
                case 'RefreshPipelineButton'
                    pipeline_fig = findobj('tag','ndi.cpipeline.edit');
                    if ~isempty(pipeline_fig)
                        ndi.cpipeline.edit('command','UpdateCalculatorInstanceList','fig',pipeline_fig(1));
                        figure(fig); % Keep calculator focused
                    end
                    
                case 'ExitButton'
                    close(fig);
                    pipeline_fig = findobj('tag','ndi.cpipeline.edit');
                    if ~isempty(pipeline_fig), figure(pipeline_fig(1)); end
                    
                case 'CancelButton' 
                    % Maintained for backward compatibility if called programmatically, though UI uses ExitButton
                    close(fig);
                    pipeline_fig = findobj('tag','ndi.cpipeline.edit');
                    if ~isempty(pipeline_fig), figure(pipeline_fig(1)); end
            end
        end
        
        function text = docfiletext(calculator_type, doc_type)
            w = which(calculator_type);
            if isempty(w), error(['Calculator not found: ' calculator_type]); end
            [parentdir, appname] = fileparts(w);
            
            switch (lower(doc_type))
                case 'general', doctype = 'general';
                case 'searching for inputs', doctype = 'searching';
                case 'output', doctype = 'output';
                otherwise, error(['Unknown doc type ' doc_type]);
            end
            
            filename = fullfile(parentdir, 'docs', [appname '.docs.' doctype '.txt']);
            
            if isfile(filename)
                try
                   fid = fopen(filename, 'r');
                   raw = fread(fid, '*char')';
                   fclose(fid);
                   text = regexp(raw, '\r?\n', 'split')';
                catch
                   text = {['Error reading file: ' filename]};
                end
            else
                text = {['No documentation file found: ' filename]};
            end
        end
        
        % Internal Helper to safely Read Parameters from SPECIFIC file
        function all_params = read_parameter_file_internal(json_path)
            all_params = struct();
            if isfile(json_path)
                fid = fopen(json_path, 'r');
                if fid == -1, return; end 
                try
                    json_text = fread(fid, '*char')';
                    if ~isempty(strtrim(json_text))
                        all_params = jsondecode(json_text);
                    end
                catch
                end
                fclose(fid);
            end
        end

        % Internal Helper to safely Write Parameters to SPECIFIC file
        function write_parameter_file_internal(all_params, json_path)
            fid = fopen(json_path, 'w');
            if fid == -1, error(['Could not open parameter file for writing: ' json_path]); end
            try
                fprintf(fid, '%s', jsonencode(all_params, 'PrettyPrint', true));
                fclose(fid);
            catch ME
                fclose(fid);
                rethrow(ME);
            end
        end

        function [names, contents] = readParameterCode(calculator_classname, json_path)
            names = {}; contents = {};
            % SAFETY CHECK
            if nargin < 2 || isempty(json_path) || isempty(calculator_classname) || ~ischar(calculator_classname), return; end
            
            all_params = ndi.calculator.read_parameter_file_internal(json_path);
            
            class_field = matlab.lang.makeValidName(calculator_classname);
            if isfield(all_params, class_field)
                class_entries = all_params.(class_field);
                if isempty(class_entries) && ~isstruct(class_entries), return; end
                if iscell(class_entries), class_entries = [class_entries{:}]; end
                for i=1:numel(class_entries)
                    names{end+1} = class_entries(i).parameterCodeName;
                    contents{end+1} = class_entries(i).parameterCodeText;
                end
            end
        end

        function addParameterCode(calculator_classname, name, text, json_path)
            if nargin < 4 || isempty(json_path), error('No parameter file path provided.'); end
            
            all_params = ndi.calculator.read_parameter_file_internal(json_path);
            
            class_field = matlab.lang.makeValidName(calculator_classname);
            if ~isfield(all_params, class_field)
                all_params.(class_field) = struct('parameterCodeName',{}, 'parameterCodeText',{});
            end
            
            class_entries = all_params.(class_field);
            if isempty(class_entries) && ~isstruct(class_entries)
                class_entries = struct('parameterCodeName',{}, 'parameterCodeText',{});
            end
            if iscell(class_entries), class_entries = [class_entries{:}]; end
            
            new_entry = struct('parameterCodeName', name, 'parameterCodeText', text);
            found = false;
            for i=1:numel(class_entries)
                if strcmp(class_entries(i).parameterCodeName, name)
                    class_entries(i) = new_entry;
                    found = true; break;
                end
            end
            if ~found, class_entries(end+1) = new_entry; end
            all_params.(class_field) = class_entries;
            
            ndi.calculator.write_parameter_file_internal(all_params, json_path);
        end

        function deleteParameterCode(calculator_classname, name, json_path)
            if nargin < 3 || isempty(json_path), return; end
            
            all_params = ndi.calculator.read_parameter_file_internal(json_path);
            
            class_field = matlab.lang.makeValidName(calculator_classname);
            if isfield(all_params, class_field)
                class_entries = all_params.(class_field);
                if iscell(class_entries), class_entries = [class_entries{:}]; end
                indices = [];
                for i=1:numel(class_entries)
                    if ~strcmp(class_entries(i).parameterCodeName, name), indices(end+1)=i; end
                end
                all_params.(class_field) = class_entries(indices);
                
                ndi.calculator.write_parameter_file_internal(all_params, json_path);
            end
        end
        
        function [contents] = parameter_default(calculator_type)
            contents = sprintf('thecalc = %s(pipeline_session);\n', calculator_type);
            contents = [contents sprintf('parameters = thecalc.default_search_for_input_parameters();\n')];
            
            try
                filepath = which(calculator_type);
                if isempty(filepath)
                    contents = [contents sprintf('parameters.query = struct(''name'',''default_query'', ''query'', ndi.query(''stimulus_tuningcurve.independent_variable_label'',''contains_string'',''independent_variable'',''''));')];
                    return;
                end
                
                txt = fileread(filepath);
                
                % Parse entire file for independent_variable_label queries
                % Regex looks for: ndi.query('FIELD', 'OPERATOR', 'VALUE'...)
                pat = 'ndi\.query\s*\(\s*''([^'']*independent_variable_label[^'']*)''\s*,\s*''([^'']*)''\s*,\s*''([^'']*)''';
                tokens = regexp(txt, pat, 'tokens');
                
                % Ensure unique parameters by Value (Group 3)
                unique_entries = {};
                seen_params = {};
                
                for i = 1:numel(tokens)
                    val = tokens{i}{3};
                    if strcmp(val, 'independent_variable'), continue; end
                    
                    if ~ismember(val, seen_params)
                        seen_params{end+1} = val;
                        entry.field = tokens{i}{1};
                        entry.op = tokens{i}{2};
                        entry.val = tokens{i}{3};
                        unique_entries{end+1} = entry;
                    end
                end
                
                if isempty(unique_entries)
                    contents = [contents sprintf('parameters.query = struct(''name'',''default_query'', ''query'', ndi.query(''stimulus_tuningcurve.independent_variable_label'',''contains_string'',''independent_variable'',''''));')];
                elseif numel(unique_entries) == 1
                    % Single match case: HARDCODED Standardization to stimulus_tuningcurve + contains_string
                    e = unique_entries{1};
                    contents = [contents sprintf('parameters.query = struct(''name'',''default_query'', ''query'', ndi.query(''stimulus_tuningcurve.independent_variable_label'',''contains_string'',''%s'',''''));', e.val)];
                else
                    % Multiple matches: HARDCODED Standardization logic
                    or_vars = {};
                    for i = 1:numel(unique_entries)
                        e = unique_entries{i};
                        var_name = sprintf('q%d', i); 
                        % Hardcode field and operator, inject unique Value
                        contents = [contents sprintf('%s = ndi.query(''stimulus_tuningcurve.independent_variable_label'',''contains_string'',''%s'','''');\n', var_name, e.val)];
                        or_vars{end+1} = var_name;
                    end
                    
                    or_clause = strjoin(or_vars, ' | ');
                    contents = [contents sprintf('q_combined = %s;\n', or_clause)];
                    contents = [contents sprintf('parameters.query = struct(''name'',''default_query'', ''query'', q_combined);')];
                end
            catch
                % Error fallback
                contents = [contents sprintf('parameters.query = struct(''name'',''default_query'', ''query'', ndi.query(''stimulus_tuningcurve.independent_variable_label'',''contains_string'',''independent_variable'',''''));')];
            end
        end
        function [contents] = user_parameter_template(calculator_type)
            contents = sprintf('%% User parameters for %s\n%% Edit to customize\n', calculator_type);
            contents = [contents sprintf('thecalc = %s(pipeline_session);\n', calculator_type)];
            contents = [contents sprintf('parameters = thecalc.default_search_for_input_parameters();\n')];
            contents = [contents sprintf('parameters.query.query = ndi.query(''stimulus_tuningcurve.independent_variable_label'',''contains_string'',''independent_variable'','''');')];
        end
        function path = get_user_parameters_path()
            path = fullfile(ndi.cpipeline.defaultPath(), 'user_parameters.json');
        end
        function calc_list = find_calculator_subclasses(forceUpdate)
            arguments, forceUpdate (1,1) logical = false; end
            persistent cached_calc_list;
            if isempty(cached_calc_list) || forceUpdate
                calc_list = {};
                all_paths = strsplit(path, pathsep);
                calc_package_roots = {};
                for i = 1:numel(all_paths)
                    p = all_paths{i};
                    potential_calc_path = fullfile(p, '+ndi', '+calc');
                    if isfolder(potential_calc_path), calc_package_roots{end+1} = potential_calc_path; end
                end
                calc_package_roots = unique(calc_package_roots);
                if isempty(calc_package_roots), cached_calc_list = {}; calc_list = cached_calc_list; return; end
                for i = 1:numel(calc_package_roots)
                    sub_classes = find_recursively(calc_package_roots{i}, 'ndi.calc');
                    calc_list = [calc_list, sub_classes];
                end
                cached_calc_list = unique(calc_list); 
            end
            calc_list = cached_calc_list(:);
            function class_list = find_recursively(current_path, current_package_name)
                class_list = {}; dir_contents = dir(current_path); base_meta = ?ndi.calculator;
                for item = dir_contents'
                    if strcmp(item.name, '.') || strcmp(item.name, '..'), continue; end
                    full_item_path = fullfile(current_path, item.name);
                    if item.isdir && startsWith(item.name, '+') 
                        sub_package_name = item.name(2:end);
                        full_subpackage_name = [current_package_name '.' sub_package_name];
                        sub_classes = find_recursively(full_item_path, full_subpackage_name);
                        class_list = [class_list, sub_classes];
                    elseif endsWith(item.name, '.m') 
                        [~, name_only] = fileparts(item.name);
                        full_class_name = [current_package_name '.' name_only];
                        try, mc = meta.class.fromName(full_class_name); if mc < base_meta && ~mc.Abstract, class_list{end+1} = mc.Name; end; catch, end
                    end
                end
            end 
        end 
    end 
end