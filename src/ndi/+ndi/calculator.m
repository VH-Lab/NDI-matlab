classdef calculator < ndi.app & ndi.app.appdoc & ndi.mock.ctest
    properties (SetAccess=protected,GetAccess=public)
        fast_start = 'ndi.calculator.graphical_edit_calculator(''command'',''new'',''type'',''ndi.calc.vis.contrast'',''name'',''mycalc'')';
    end 
    methods
        function ndi_calculator_obj = calculator(varargin)
            session = []; if nargin>0, session = varargin{1}; end
            ndi_calculator_obj = ndi_calculator_obj@ndi.app(session);
            if nargin>1, document_type = varargin{2}; else, document_type = ''; end
            if nargin>2, path_to_doc_type = varargin{3}; else, path_to_doc_type = ''; end
            ndi_calculator_obj = ndi_calculator_obj@ndi.app.appdoc({document_type}, {path_to_doc_type},session);
            ndi_calculator_obj.name = class(ndi_calculator_obj);
        end 
        
        function docs = run(ndi_calculator_obj, docExistsAction, parameters)
            docs = {}; docs_tocat = {}; docs_to_add = {};
            if nargin<3, parameters = ndi_calculator_obj.default_search_for_input_parameters(); end
            all_parameters = ndi_calculator_obj.search_for_input_parameters(parameters);
            for i=1:numel(all_parameters)
                previous_calculators_here = ndi_calculator_obj.search_for_calculator_docs(all_parameters{i});
                do_calc = 0;
                if ~isempty(previous_calculators_here)
                    switch(docExistsAction)
                        case 'Error', error(['Doc exists.']);
                        case {'NoAction','ReplaceIfDifferent'}, docs_tocat{i} = previous_calculators_here; continue;
                        case {'Replace'}, ndi_calculator_obj.session.database_rm(previous_calculators_here); do_calc = 1;
                    end
                else, do_calc = 1; end
                if do_calc
                    docs_out = ndi_calculator_obj.calculate(all_parameters{i});
                    if ~iscell(docs_out), docs_out = {docs_out}; end
                    docs_tocat{i} = docs_out; docs_to_add = cat(2, docs_to_add, docs_out);
                end
            end
            for i=1:numel(all_parameters), if i <= numel(docs_tocat), docs = cat(2,docs,docs_tocat{i}); end; end
            if ~isempty(docs_to_add)
                app_doc = ndi_calculator_obj.newdocument();
                for i=1:numel(docs_to_add), docs_to_add{i} = docs_to_add{i}.setproperties('app',app_doc.document_properties.app); end
                ndi_calculator_obj.session.database_add(docs_to_add);
            end
        end 
        
        function parameters = default_search_for_input_parameters(ndi_calculator_obj)
            parameters.input_parameters = [];
            parameters.depends_on = vlt.data.emptystruct('name','value');
        end 
        
        function parameters = search_for_input_parameters(ndi_calculator_obj, parameters_specification, varargin)
            if ~isstruct(parameters_specification), error('parameters_specification must be a structure.'); end
            fixed_input_parameters = parameters_specification.input_parameters;
            if isfield(parameters_specification,'depends_on'), fixed_depends_on = parameters_specification.depends_on; else, fixed_depends_on = vlt.data.emptystruct('name','value'); end
            if ~isfield(parameters_specification,'query'), parameters_specification.query = ndi_calculator_obj.default_parameters_query(parameters_specification); end
            if numel(parameters_specification.query)==0
                parameters.input_parameters = fixed_input_parameters; parameters.depends_on = fixed_depends_on; parameters = {parameters}; return;
            end
            doclist = {}; V = [];
            for i=1:numel(parameters_specification.query)
                doclist{i} = ndi_calculator_obj.session.database_search(parameters_specification.query(i).query);
                V(i) = numel(doclist{i});
            end
            parameters = {};
            for n=1:prod(V)
                is_valid = 1; g = vlt.math.group_enumeration(V,n); extra_depends = vlt.data.emptystruct('name','value');
                for i=1:numel(parameters_specification.query)
                    s = struct('name',parameters_specification.query(i).name,'value',doclist{i}{g(i)}.id());
                    is_valid = is_valid & ndi_calculator_obj.is_valid_dependency_input(s.name,s.value);
                    extra_depends(end+1) = s; if ~is_valid, break; end
                end
                if is_valid
                    parameters_here.input_parameters = fixed_input_parameters; parameters_here.depends_on = cat(1,fixed_depends_on(:),extra_depends(:)); parameters{end+1} = parameters_here;
                end
            end
        end 
        
        function query = default_parameters_query(ndi_calculator_obj, parameters_specification)
             query = vlt.data.emptystruct('name','query');
        end 
        
        function docs = search_for_calculator_docs(ndi_calculator_obj, parameters)
            myemptydoc = ndi.document(ndi_calculator_obj.doc_document_types{1});
            property_list_name = myemptydoc.document_properties.document_class.property_list_name;
            [~,class_name,~] = fileparts(myemptydoc.document_properties.document_class.definition);
            q = ndi.query('','isa',class_name,'');
            if isfield(parameters,'depends_on')
                for i=1:numel(parameters.depends_on), if ~isempty(parameters.depends_on(i).value), q = q & ndi.query('','depends_on',parameters.depends_on(i).name,parameters.depends_on(i).value); end; end
            end
            docs = ndi_calculator_obj.session.database_search(q);
            matches = [];
            for i=1:numel(docs)
                try, input_param = eval(['docs{i}.document_properties.' property_list_name '.input_parameters;']); catch, input_param = []; end
                if ndi_calculator_obj.are_input_parameters_equivalent(input_param,parameters.input_parameters), matches(end+1) = i; end
            end
            docs = docs(matches);
        end 
        
        function b = are_input_parameters_equivalent(ndi_calculator_obj, input_parameters1, input_parameters2)
            if ~isempty(input_parameters1), input_parameters1 = vlt.data.columnize_struct(input_parameters1); end
            if ~isempty(input_parameters2), input_parameters2 = vlt.data.columnize_struct(input_parameters2); end
            b = eqlen(input_parameters1, input_parameters2);
        end
        function b = is_valid_dependency_input(ndi_calculator_obj, name, value), b = 1; end 
        function doc = calculate(ndi_calculator_obj, parameters), doc = {}; end 
        
        function h=plot(ndi_calculator_obj, doc_or_parameters, varargin)
            params = ndi.calculator.plot_parameters(varargin{:});
            h.figure = []; if params.newfigure, h.figure = figure; else, h.figure = gcf; end
            h.axes = gca; 
            h.objects = []; 
            h.params = params; % This fixes the "Unrecognized field name 'params'" error
            if ~params.suppress_title && isa(doc_or_parameters,'ndi.document'), h.title = title([doc_or_parameters.id()],'interp','none'); end
            if params.holdstate, hold on; else, hold off; end
        end 
        
        function b = isequal_appdoc_struct(ndi_app_appdoc_obj, appdoc_type, appdoc_struct1, appdoc_struct2)
            b = vlt.data.partial_struct_match(appdoc_struct1, appdoc_struct2);
        end 
        function text = doc_about(ndi_calculator_obj), text = ndi.calculator.docfiletext(class(ndi_calculator_obj), 'output'); end 
        function text = appdoc_description(ndi_calculator_obj), text = ndi_calculator_obj.doc_about(); end 
    end 
    
    methods (Static)
        function param = plot_parameters(varargin)
            newfigure = 0; holdstate = 0; suppress_x_label = 0; suppress_y_label = 0; suppress_z_label = 0; suppress_title = 0;
            vlt.data.assign(varargin{:});
            param = vlt.data.workspace2struct(); param = rmfield(param,'varargin');
        end
        
        function graphical_edit_calculator(options)
            arguments
                options.command (1,:) char {mustBeMember(options.command, {'New','Edit','Close',...
                    'NewWindow','UpdateWindow','DocPopup', 'ParameterCodePopup',...
                    'CommandPopup', 'SaveButton', 'CancelButton', 'ExitButton', 'SaveAsButton',...
                    'DeleteParameterInstanceButton', 'RefreshParameterPopup', 'RefreshPipelineButton'})} = 'New'
                options.session = [] 
                options.name (1,:) char = ''
                options.calculatorClassname (1,:) char = ''
                options.window_params (1,1) struct = struct('height', 600, 'width', 700)
                options.fig {mustBeA(options.fig,["matlab.ui.Figure","double"])} = []
                options.pipelinePath (1,:) char = '' 
                options.paramName (1,:) char = '' 
            end
            
            command = options.command; fig = options.fig;
            
            if strcmp(command,'New')
                ud.calculatorInstance.instanceName = options.name;
                ud.calculatorInstance.calculatorClassname = options.calculatorClassname;
                ud.window_params = options.window_params;
                ud.linked_object = options.session; 
                ud.active_parameter_name = ''; ud.pipelinePath = options.pipelinePath;
                ud.paramName = options.paramName;
                if isempty(fig), fig = figure; end; command = 'NewWindow';
            elseif strcmp(command,'Edit')
                ud.calculatorInstance.instanceName = options.name;
                ud.calculatorInstance.calculatorClassname = options.calculatorClassname;
                ud.linked_object = options.session; ud.pipelinePath = options.pipelinePath;
                ud.active_parameter_name = options.paramName;
                if ~isfield(ud,'window_params'), ud.window_params = options.window_params; end
                if isempty(fig), fig = figure; end; command = 'NewWindow';
            else
                ud = get(fig,'userdata');
            end
            
            switch (command)
                case 'NewWindow'
                    set(fig,'tag','ndi.calculator.graphical_edit_calculator', 'userdata',ud); 
                    uid = vlt.ui.basicuitools_defs;
                    callbackstr = [  'eval([get(gcbf,''Tag'') ''(''''command'''','''''' get(gcbo,''Tag'') '''''' ,''''fig'''',gcbf);'']);'];
                    fig_bg_color = [0.8 0.8 0.8]; edit_bg_color = [1 1 1];
                    top = ud.window_params.height; right = ud.window_params.width;
                    edge_n = 10/right; row_h_n = 25/top; gap_v_n = 15/top; button_area_h_n = 5*row_h_n;
                    
                    set(fig,'position',[50 50 right top], 'Color', fig_bg_color, 'NumberTitle','off',...
                        'Name',['Editing ' ud.calculatorInstance.instanceName ' (' ud.calculatorInstance.calculatorClassname ')'],...
                        'MenuBar','none','ToolBar','none','Units','normalized');
                    
                    y_cursor = 1 - edge_n - row_h_n;
                    uicontrol(uid.txt,'Units','normalized','position',[edge_n y_cursor 0.6 row_h_n],'string','Documentation','BackgroundColor',fig_bg_color,'FontWeight','bold','HorizontalAlignment','left');
                    uicontrol(uid.popup,'Units','normalized','position',[edge_n+0.6 y_cursor 1-2*edge_n-0.6 row_h_n],'string',{'General','Calculator Input Options','Output document'},'tag','DocPopup','callback',callbackstr,'value',1,'BackgroundColor',edit_bg_color);
                    y_cursor = y_cursor - (0.2 * (1 - button_area_h_n));
                    uicontrol(uid.edit,'Units','normalized','position',[edge_n y_cursor 1-2*edge_n 0.2*(1-button_area_h_n)],'string','...','tag','DocTxt','max',2,'enable','inactive','HorizontalAlignment','left');
                    
                    y_cursor = y_cursor - gap_v_n - row_h_n;
                    uicontrol(uid.txt,'Units','normalized','position',[edge_n y_cursor 0.6 row_h_n],'string','Parameter code:','BackgroundColor',fig_bg_color,'FontWeight','bold','HorizontalAlignment','left');
                    
                    global_opts = ndi.calculator.get_available_parameters(ud.calculatorInstance.calculatorClassname, ud.pipelinePath);
                    popup_str = [{'Template','---'}, global_opts];
                    val_idx = 1;
                    if ~isempty(ud.active_parameter_name)
                         idx = find(strcmp(popup_str, ud.active_parameter_name));
                         if ~isempty(idx), val_idx = idx(1); end
                    end
                    uicontrol(uid.popup,'Units','normalized','position',[edge_n+0.6 y_cursor 1-2*edge_n-0.6 row_h_n],'string',popup_str,'tag','ParameterCodePopup', 'callback',callbackstr,'value',val_idx,'BackgroundColor',edit_bg_color);
                    y_cursor = y_cursor - (0.4 * (1 - button_area_h_n));
                    init_code = ndi.calculator.load_parameter_code(ud.calculatorInstance.calculatorClassname, ud.active_parameter_name, ud.pipelinePath);
                    uicontrol(uid.edit,'Units','normalized','position',[edge_n y_cursor 1-2*edge_n 0.4*(1-button_area_h_n)],'string',init_code,'tag','ParameterCodeTxt','max',2,'BackgroundColor',edit_bg_color,'HorizontalAlignment','left');
                    
                    y_cursor = y_cursor - gap_v_n - row_h_n;
                    uicontrol(uid.popup,'Units','normalized','position',[edge_n y_cursor 1-2*edge_n row_h_n],'string',{'Commands:','---','Try searching for inputs','Show existing outputs','Plot existing outputs','Run but don''t replace','Run and replace'},'tag','CommandPopup','callback',callbackstr,'BackgroundColor',edit_bg_color);
                    y_cursor = y_cursor - gap_v_n - row_h_n;
                    
                    num_buttons = 5; button_w_n = 0.16;
                    button_centers_n = linspace(edge_n+button_w_n/2, 1-edge_n-button_w_n/2, num_buttons);
                    uicontrol(uid.button,'Units','normalized','position',[button_centers_n(1)-button_w_n/2 y_cursor button_w_n row_h_n],'string','Save','tag','SaveButton','callback',callbackstr);
                    uicontrol(uid.button,'Units','normalized','position',[button_centers_n(2)-button_w_n/2 y_cursor button_w_n row_h_n],'string','Save As...','tag','SaveAsButton','callback',callbackstr);
                    uicontrol(uid.button,'Units','normalized','position',[button_centers_n(3)-button_w_n/2 y_cursor button_w_n row_h_n],'string','Delete...','tag','DeleteParameterInstanceButton','callback',callbackstr);
                    uicontrol(uid.button,'Units','normalized','position',[button_centers_n(4)-button_w_n/2 y_cursor button_w_n row_h_n],'string','Refresh','tag','RefreshPipelineButton','callback',callbackstr);
                    uicontrol(uid.button,'Units','normalized','position',[button_centers_n(5)-button_w_n/2 y_cursor button_w_n row_h_n],'string','Exit','tag','ExitButton','callback',callbackstr);
                    
                    ndi.calculator.graphical_edit_calculator('command','DocPopup','fig',fig);
                case 'DocPopup'
                    docPopupObj = findobj(fig,'tag','DocPopup');
                    docTextObj = findobj(fig,'tag','DocTxt');
                    types = {'general','searching','output'};
                    mytext = ndi.calculator.docfiletext(ud.calculatorInstance.calculatorClassname, types{get(docPopupObj,'value')});
                    set(docTextObj,'string',mytext);
                    
                case 'CommandPopup'
                    cmdPopupObj = findobj(fig,'tag','CommandPopup'); val = get(cmdPopupObj, 'value');
                    if val <= 2, return; end
                    
                    if isempty(ud.linked_object)
                        msgbox('No NDI Session linked. Cannot search database.', 'Connection Error'); 
                        set(cmdPopupObj, 'Value', 1); return; 
                    end
                    
                    assignin('base','pipeline_session',ud.linked_object);
                    
                    code = get(findobj(fig,'tag','ParameterCodeTxt'),'string');
                    if iscell(code), code = strjoin(code, newline); end; code = char(code);
                    try, evalin('base', code); catch ME, errordlg(ME.message, 'Code Error'); return; end
                    
                    calcName = upper(ud.calculatorInstance.instanceName);
                    paramName = ud.active_parameter_name;
                    if isempty(paramName), paramName = 'Manual/Unsaved'; end
                    
                    switch val
                        case 3 % Try searching for inputs
                             fprintf('\n--- %s CALCULATOR COMMAND RUN ---\n', calcName);
                             fprintf('STEP: Try searching for inputs (Parameters: %s)...\n', paramName);
                             
                             % Execute logic in base, set a simple status flag
                             check_cmd = ['if exist(''parameters'',''var'') && isstruct(parameters) && isfield(parameters,''query'') && ~isempty(parameters.query), ' ...
                                          '  if isfield(parameters.query(1),''query''), ' ...
                                          '    MYQ = parameters.query(1).query; ' ...
                                          '    DOCS = pipeline_session.database_search(MYQ); ' ...
                                          '    NDI_CMD_STATUS = 1; ' ...
                                          '  else, NDI_CMD_STATUS = 0; end; ' ...
                                          'else, NDI_CMD_STATUS = -1; end'];
                             evalin('base', check_cmd);
                             
                             % Retrieve status and act
                             status = evalin('base', 'NDI_CMD_STATUS');
                             if status == 1
                                 count = evalin('base', 'numel(DOCS)');
                                 fprintf('  Result: Found %d matching documents for the current query.\n', count);
                                 msgbox({'Search Check Complete.', 'Look at Command Window for document count.', 'See variable DOCS for document information.'}, 'Search Results', 'modal');
                             elseif status == 0
                                 fprintf('  Result: Error - parameters.query(1) missing "query" field.\n');
                             else
                                 fprintf('  Result: Error - parameters variable is not a valid structure or missing "query" field.\n');
                             end
                             evalin('base', 'clear NDI_CMD_STATUS');
                            
                        case 4 % Show existing outputs
                            fprintf('\n--- %s CALCULATOR COMMAND RUN ---\n', calcName);
                            fprintf('STEP: Show existing outputs (Parameters: %s)...\n', paramName);
                            search_code = ['thecalc=' ud.calculatorInstance.calculatorClassname '(pipeline_session); ' ...
                                           'if ~exist(''parameters'',''var'') || ~isstruct(parameters), parameters=thecalc.default_search_for_input_parameters(); end; ' ...
                                           'ED=thecalc.search_for_calculator_docs(parameters);'];
                            try
                                evalin('base',search_code);
                                ED = evalin('base','ED');
                                assignin('base', 'NDI_CALCULATOR_OUTPUT_DOCS', ED);
                                
                                if ~isempty(ED)
                                    evalin('base', 'openvar(''NDI_CALCULATOR_OUTPUT_DOCS'')');
                                    fprintf('  Result: %d Output documents found and opened in Variable Editor.\n', numel(ED));
                                    msgbox(sprintf('Found %d Output documents.\nOpened in MATLAB Variable Editor.', numel(ED)), 'Outputs Found', 'modal');
                                else
                                    fprintf('  Result: No existing output documents found.\n');
                                    msgbox('No existing output documents found for these parameters.', 'No Outputs', 'modal');
                                end
                            catch ME
                                fprintf('  Result: Error searching outputs - %s\n', ME.message);
                                errordlg(ME.message, 'Error Searching Outputs');
                            end
                            
                        case 5 % Plot existing outputs
                             fprintf('\n--- %s CALCULATOR COMMAND RUN ---\n', calcName);
                             fprintf('STEP: Plot existing outputs (Parameters: %s)...\n', paramName);
                             search_code = ['thecalc=' ud.calculatorInstance.calculatorClassname '(pipeline_session); ' ...
                                            'if ~exist(''parameters'',''var'') || ~isstruct(parameters), parameters=thecalc.default_search_for_input_parameters(); end; ' ...
                                            'ED=thecalc.search_for_calculator_docs(parameters);'];
                             try
                                 evalin('base',search_code);
                                 ED = evalin('base','ED');
                                 
                                 if isempty(ED)
                                     fprintf('  Result: No docs to plot.\n');
                                     msgbox('No docs to plot.', 'Plotting', 'modal');
                                 else
                                     answer = questdlg('Plot individual figures or create subplots?', ...
                                         'Plot Mode', 'Individual', 'Subplots', 'Individual');
                                     
                                     calc_obj = feval(ud.calculatorInstance.calculatorClassname, ud.linked_object);
                                     
                                     if strcmp(answer, 'Individual')
                                         for i = 1:numel(ED)
                                             calc_obj.plot(ED{i}, 'newfigure', 1);
                                         end
                                         fprintf('  Result: Generated %d individual plots.\n', numel(ED));
                                     elseif strcmp(answer, 'Subplots')
                                         N = numel(ED);
                                         num_figs = max(1, min(5, ceil(N/5))); 
                                         fprintf('  Result: Generating %d subplot figures for %d documents...\n', num_figs, N);
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
                                                 ax = subplot(n_rows, n_cols, k);
                                                 try
                                                     calc_obj.plot(current_chunk{k}, 'newfigure', 0, 'suppress_title', 0);
                                                 catch plot_err
                                                     text(0.5, 0.5, 'Error plotting', 'HorizontalAlignment', 'center');
                                                     warning(['Error plotting doc ' num2str(k) ': ' plot_err.message]);
                                                 end
                                             end
                                         end
                                         fprintf('  Result: Plotting complete.\n');
                                     end
                                 end
                             catch ME
                                 fprintf('  Result: Error plotting - %s\n', ME.message);
                                 errordlg(ME.message, 'Plotting Error');
                             end
                            
                        case 6 % Run (No Replace)
                            fprintf('\n--- %s CALCULATOR COMMAND RUN ---\n', calcName);
                            fprintf('STEP: Run but do not replace (Parameters: %s)...\n', paramName);
                            try 
                                evalin('base',['thecalc=' ud.calculatorInstance.calculatorClassname '(pipeline_session);']);
                                evalin('base', 'if ~exist(''parameters'',''var''), parameters = thecalc.default_search_for_input_parameters(); end');
                                evalin('base', 'RUNDOCS=thecalc.run(''NoAction'',parameters);');
                                
                                num_docs = evalin('base', 'numel(RUNDOCS)');
                                fprintf('  Result: %d docs generated.\n', num_docs);
                                msgbox(sprintf('Run complete. Results in RUNDOCS variable.\nDocs returned: %d', num_docs), 'Success', 'modal'); 
                            catch ME
                                fprintf(2, '  Result: Execution Failed (%s).\n', ME.message);
                                errordlg(ME.message, 'Execution Error'); 
                            end
                            
                        case 7 % Run (Replace)
                            fprintf('\n--- %s CALCULATOR COMMAND RUN ---\n', calcName);
                            fprintf('STEP: Run and replace (Parameters: %s)...\n', paramName);
                            try 
                                evalin('base',['thecalc=' ud.calculatorInstance.calculatorClassname '(pipeline_session);']);
                                evalin('base', 'if ~exist(''parameters'',''var''), parameters = thecalc.default_search_for_input_parameters(); end');
                                evalin('base', 'RUNDOCS=thecalc.run(''Replace'',parameters);');
                                
                                num_docs = evalin('base', 'numel(RUNDOCS)');
                                fprintf('  Result: %d docs generated and replaced existing docs.\n', num_docs);
                                msgbox(sprintf('Run complete. Results in RUNDOCS variable.\nDocs returned: %d', num_docs), 'Success', 'modal'); 
                            catch ME
                                fprintf(2, '  Result: Execution Failed (%s).\n', ME.message);
                                errordlg(ME.message, 'Execution Error'); 
                            end
                    end
                    set(cmdPopupObj, 'Value', 1);
                    bring_gui_to_front(fig); 
                    
                case 'ParameterCodePopup'
                    paramPopupObj = findobj(fig,'tag','ParameterCodePopup'); val = get(paramPopupObj, 'value');
                    str = get(paramPopupObj, 'string'); ud.active_parameter_name = str{val};
                    if strcmp(ud.active_parameter_name,'Template') || strcmp(ud.active_parameter_name,'---'), ud.active_parameter_name = ''; end
                    code = ndi.calculator.load_parameter_code(ud.calculatorInstance.calculatorClassname, ud.active_parameter_name, ud.pipelinePath);
                    set(findobj(fig,'tag','ParameterCodeTxt'),'string',code); set(fig,'userdata',ud);
                    
                case 'SaveButton'
                    if isempty(ud.active_parameter_name) || strcmp(ud.active_parameter_name, 'Template')
                        msgbox('Please use "Save As".', 'Error'); return;
                    end
                    code = get(findobj(fig,'tag','ParameterCodeTxt'), 'String');
                    ndi.calculator.save_parameter_file(ud.calculatorInstance.calculatorClassname, ud.active_parameter_name, code, ud.pipelinePath);
                    msgbox('Saved.', 'Success'); bring_gui_to_front(fig);
                    
                case 'SaveAsButton'
                    code = get(findobj(fig,'tag','ParameterCodeTxt'), 'String'); ans = inputdlg('Name:');
                    if ~isempty(ans)
                        ndi.calculator.save_parameter_file(ud.calculatorInstance.calculatorClassname, ans{1}, code, ud.pipelinePath);
                        ud.active_parameter_name = ans{1}; set(fig,'userdata',ud);
                        ndi.calculator.graphical_edit_calculator('command','RefreshPipelineButton','fig',fig);
                    end
                    bring_gui_to_front(fig);
                    
                case 'RefreshPipelineButton'
                    ndi.calculator.graphical_edit_calculator('command','RefreshParameterPopup','fig',fig);
                    pipeline_fig = findobj('tag','ndi.cpipeline.edit');
                    if ~isempty(pipeline_fig), ndi.cpipeline.edit('command','UpdateCalculatorInstanceList','fig',pipeline_fig(1)); end
                
                case 'RefreshParameterPopup'
                    global_opts = ndi.calculator.get_available_parameters(ud.calculatorInstance.calculatorClassname, ud.pipelinePath);
                    popup_str = [{'Template','---'}, global_opts];
                    current_sel = ud.active_parameter_name; val_idx = 1;
                    if ~isempty(current_sel), idx = find(strcmp(popup_str, current_sel)); if ~isempty(idx), val_idx = idx(1); end; end
                    set(findobj(fig,'tag','ParameterCodePopup'), 'String', popup_str, 'Value', val_idx);
                    
                case 'ExitButton'
                    close(fig);
            end
            
            function bring_gui_to_front(fig)
                 pipeline_fig = findobj('tag','ndi.cpipeline.edit');
                 if ~isempty(pipeline_fig), figure(pipeline_fig(1)); end
                 if ishandle(fig), figure(fig); end
            end
        end
        
        function params = get_available_parameters(classname, root_dir)
            params = {}; if isempty(root_dir), return; end
            param_dir = fullfile(root_dir, 'Calculator_Parameters', classname);
            if ~isfolder(param_dir), mkdir(param_dir); end
            if ~isfile(fullfile(param_dir, 'Default.json'))
                try, def_code = ndi.calculator.parameter_default(classname);
                    ndi.calculator.save_parameter_file(classname, 'Default', def_code, root_dir);
                catch, end
            end
            d = dir(fullfile(param_dir, '*.json'));
            for i=1:numel(d), [~, name, ~] = fileparts(d(i).name); params{end+1} = name; end
        end
        
        function code = load_parameter_code(classname, param_name, root_dir)
            if isempty(param_name) || strcmp(param_name, 'Template'), code = ndi.calculator.user_parameter_template(classname); return; end
            if strcmp(param_name, 'Default')
                json_f = fullfile(root_dir, 'Calculator_Parameters', classname, 'Default.json');
                if ~isfile(json_f), code = ndi.calculator.parameter_default(classname); return; end
            end
            json_f = fullfile(root_dir, 'Calculator_Parameters', classname, [param_name '.json']);
            if isfile(json_f), try, s = jsondecode(fileread(json_f)); code = s.code; catch, code = '% Error'; end
            else, code = '% Not found'; end
        end
        
        function save_parameter_file(classname, param_name, code, root_dir)
            param_dir = fullfile(root_dir, 'Calculator_Parameters', classname);
            if ~isfolder(param_dir), mkdir(param_dir); end
            s.name = param_name; s.code = code;
            fid = fopen(fullfile(param_dir, [param_name '.json']), 'w');
            fprintf(fid, '%s', jsonencode(s, 'PrettyPrint', true)); fclose(fid);
        end
        
        function text = docfiletext(calculator_type, doc_type)
            % Clean Input
            calculator_type = strtrim(char(calculator_type));
            w = which(calculator_type);
            if isempty(w)
                text = {['Calculator Class not found: ' calculator_type], 'Make sure it is on your MATLAB path.'}; return;
            end
            [parentdir, appname] = fileparts(w);
            switch (lower(doc_type))
                case 'general', doctype = 'general';
                case 'searching', doctype = 'searching';
                case 'output', doctype = 'output';
                otherwise, error(['Unknown doc type ' doc_type]);
            end
            filename = fullfile(parentdir, 'docs', [appname '.docs.' doctype '.txt']);
            if isfile(filename)
                fid=fopen(filename,'r'); text=regexp(fread(fid,'*char')','\r?\n','split')'; fclose(fid);
            else, text={'Documentation file missing.'}; end
        end
        
        function contents = parameter_default(calculator_type)
            contents = sprintf('thecalc = %s(pipeline_session);\nparameters = thecalc.default_search_for_input_parameters();\n', calculator_type);
            try
                txt = fileread(which(calculator_type));
                pat = 'ndi\.query\s*\(\s*''([^'']*independent_variable_label[^'']*)''\s*,\s*''([^'']*)''\s*,\s*''([^'']*)''';
                tokens = regexp(txt, pat, 'tokens');
                seen = {}; items = {};
                for i=1:numel(tokens)
                   if ~ismember(tokens{i}{3}, seen) && ~strcmp(tokens{i}{3},'independent_variable')
                       seen{end+1} = tokens{i}{3}; items{end+1} = tokens{i};
                   end
                end
                if isempty(items)
                    contents = [contents 'parameters.query = struct(''name'',''default_query'', ''query'', ndi.query(''stimulus_tuningcurve.independent_variable_label'',''contains_string'',''independent_variable'',''''));'];
                else
                    or_vars = {};
                    for i=1:numel(items)
                        field_name = items{i}{1};
                        if startsWith(field_name, 'tuning_curve.'), field_name = replace(field_name, 'tuning_curve.', 'stimulus_tuningcurve.'); end
                        
                        contents = [contents sprintf('q%d = ndi.query(''%s'',''contains_string'',''%s'','''');\n', i, field_name, items{i}{3})];
                        or_vars{end+1} = sprintf('q%d',i);
                    end
                    contents = [contents 'parameters.query = struct(''name'',''default_query'', ''query'', ' strjoin(or_vars,' | ') ');'];
                end
            catch
                contents = [contents 'parameters.query = struct(''name'',''default_query'', ''query'', ndi.query(''stimulus_tuningcurve.independent_variable_label'',''contains_string'',''independent_variable'',''''));'];
            end
        end
        
        function contents = user_parameter_template(calculator_type)
            contents = sprintf('%% User parameters for %s\nthecalc = %s(pipeline_session);\nparameters = thecalc.default_search_for_input_parameters();\n', calculator_type, calculator_type);
            contents = [contents 'parameters.query.query = ndi.query(''stimulus_tuningcurve.independent_variable_label'',''contains_string'',''independent_variable'','''');'];
        end
        
        function calc_list = find_calculator_subclasses(forceUpdate)
            arguments, forceUpdate (1,1) logical = false; end
            persistent cached_calc_list;
            if isempty(cached_calc_list) || forceUpdate
                calc_list = {}; all_paths = strsplit(path, pathsep);
                roots = {};
                for i = 1:numel(all_paths)
                    p = all_paths{i}; if isfolder(fullfile(p, '+ndi', '+calc')), roots{end+1} = fullfile(p, '+ndi', '+calc'); end
                end
                roots = unique(roots);
                if isempty(roots), cached_calc_list = {}; calc_list = {}; return; end
                for i = 1:numel(roots)
                    sub_classes = find_recursively(roots{i}, 'ndi.calc');
                    calc_list = [calc_list, sub_classes];
                end
                cached_calc_list = unique(calc_list); 
            end
            calc_list = cached_calc_list(:);
            function list = find_recursively(pth, pkg)
                list = {}; d = dir(pth); d = d(~ismember({d.name}, {'.', '..'}));
                base_meta = ?ndi.calculator;
                for k = 1:numel(d)
                    if d(k).isdir && startsWith(d(k).name, '+') 
                        list = [list, find_recursively(fullfile(pth, d(k).name), [pkg '.' d(k).name(2:end)])];
                    elseif endsWith(d(k).name, '.m') 
                        [~, n] = fileparts(d(k).name); cname = [pkg '.' n];
                        try, mc = meta.class.fromName(cname); if mc < base_meta && ~mc.Abstract, list{end+1} = mc.Name; end; catch, end
                    end
                end
            end 
        end 
    end 
end