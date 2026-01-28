classdef calculator < ndi.app & ndi.app.appdoc & ndi.mock.ctest
    properties (SetAccess=protected,GetAccess=public)
        fast_start = 'ndi.calculator.graphical_edit_calculator(''command'',''new'',''type'',''ndi.calc.vis.contrast'',''name'',''mycalc'')';
        numberOfSelfTests = 0;
        defaultParametersCanFunction = false; % indicates whether or not the default parameters for a given calculator class can function without any overriding by the user
    end % properties

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
            % RUN - run calculator on all possible inputs that match some parameters
            %
            % DOCS = RUN(NDI_CALCULATOR_OBJ, DOCEXISTSACTION, PARAMETERS)
            %
            % DOCEXISTSACTION can be 'Error', 'NoAction', 'Replace', or 'ReplaceIfDifferent'
            % For calculators, 'ReplaceIfDifferent' is equivalent to 'NoAction' because
            % the input parameters define the calculator.
            %
            % This function is primarily intended to be called by external programs and users.
            %

            arguments
                ndi_calculator_obj (1,1) ndi.calculator
                docExistsAction (1,:) char {mustBeMember(docExistsAction,{'Error','NoAction','Replace','ReplaceIfDifferent'})}
                parameters (1,1) struct {ndi.validators.mustHaveFields(parameters, {'input_parameters','depends_on'})} = ndi_calculator_obj.default_search_for_input_parameters()
            end

              % Step 1: set up input parameters; they can either be completely specified by
              % the caller, or defaults can be used

            docs = {};
            docs_tocat = {};
            docs_to_add = {};

            % Step 2: identify all sets of possible input parameters that are compatible with
            % what was specified by 'parameters'

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
                            error('Doc for input parameters already exists; error was requested.');
                        case {'NoAction','ReplaceIfDifferent'}
                            docs_tocat{i} = previous_calculators_here;
                            continue; % skip to the next calculator
                        case {'Replace'}
                            ndi_calculator_obj.session.database_rm(previous_calculators_here);
                            do_calc = 1;
                    end
                else, do_calc = 1; end
                if do_calc
                    docs_out = ndi_calculator_obj.calculate(all_parameters{i});
                    if ~iscell(docs_out), docs_out = {docs_out}; end
                    docs_tocat{i} = docs_out;
                    docs_to_add = cat(2, docs_to_add, docs_out);
                end
            end
            for i=1:numel(all_parameters), if i <= numel(docs_tocat), docs = cat(2,docs,docs_tocat{i}); end; end
            if ~isempty(docs_to_add)
                app_doc = ndi_calculator_obj.newdocument();
                for i=1:numel(docs_to_add), docs_to_add{i} = docs_to_add{i}.setproperties('app',app_doc.document_properties.app); end
                ndi_calculator_obj.session.database_add(docs_to_add);
            end
            mylog.msg('system',1,'Concluding calculator.');
        end 
        
        function parameters = default_search_for_input_parameters(ndi_calculator_obj)
            % DEFAULT_SEARCH_FOR_INPUT_PARAMETERS - default parameters for searching for inputs
            %
            % PARAMETERS = DEFAULT_SEARCH_FOR_INPUT_PARAMETERS(NDI_CALCULATOR_OBJ)
            %
            % Returns a list of the default search parameters for finding appropriate inputs
            % to the calculator.
            % 
            % This function is primarily intended as an internal function but is left exposed
            % (not private) so that it can be used for debugging. But in general, user code should
            % not call this function.
            %
            arguments
                ndi_calculator_obj (1,1) ndi.calculator
            end
            parameters.input_parameters = [];
            parameters.depends_on = vlt.data.emptystruct('name','value');
        end % default_search_for_input_parameters

        function parameters = search_for_input_parameters(ndi_calculator_obj, parameters_specification)
            % SEARCH_FOR_INPUT_PARAMETERS - search for valid inputs to the calculator
            %
            % PARAMETERS = SEARCH_FOR_INPUT_PARAMETERS(NDI_CALCULATOR_OBJ, PARAMETERS_SPECIFICATION)
            %
            % Identifies all possible sets of specific input PARAMETERS that can be
            % used as inputs to the calculator. PARAMETERS is a cell array of parameter
            % structures with fields 'input_parameters' and 'depends_on'.
            %
            % This function is primarily intended as an internal function but is left exposed
            % (not private) so that it can be used for debugging. But in general, user code should
            % not call this function.
            %
            % PARAMETERS_SPECIFICATION is a structure with the following fields:
            % |----------------------------------------------------------------------|
            % | input_parameters      | A structure of fixed input parameters needed |
            % |                       |   by the calculator. Should not depend on   |
            % |                       |   values in other documents.                 |
            % | depends_on            | A structure with 'name' and 'value' fields   |
            % |                       |   that lists specific inputs that should be  |
            % |                       |   used for the 'depends_on' field in the     |
            % |                       |   PARAMETERS output.                         |
            % | query                 | A structure with 'name' and 'query' fields   |
            % |                       |   that describes a search to be performed to |
            % |                       |   identify inputs for the 'depends_on' field |
            % |                       |   in the PARAMETERS output.                  |
            % |-----------------------|-----------------------------------------------
            %
            %
            arguments
                ndi_calculator_obj (1,1) ndi.calculator
                parameters_specification (1,1) struct
            end
            t_start = tic;
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
                    if isfield(parameters_specification.query(i), 'name')
                        p_name = parameters_specification.query(i).name;
                    else
                        p_name = sprintf('input_%d', i);
                    end
                    s = struct('name', p_name, 'value', doclist{i}{g(i)}.id());
                    is_valid = is_valid & ndi_calculator_obj.is_valid_dependency_input(s.name,s.value);
                    extra_depends(end+1) = s; if ~is_valid, break; end
                end
                if is_valid
                    parameters_here.input_parameters = fixed_input_parameters; parameters_here.depends_on = cat(1,fixed_depends_on(:),extra_depends(:)); parameters{end+1} = parameters_here;
                end
            end
        end 
        
        function query = default_parameters_query(ndi_calculator_obj, parameters_specification)
            % DEFAULT_PARAMETERS_QUERY - what queries should be used to search for input parameters if none are provided?
            %
            % QUERY = DEFAULT_PARAMETERS_QUERY(NDI_CALCULATOR_OBJ, PARAMETERS_SPECIFICATION)
            %
            % When one calls SEARCH_FOR_INPUT_PARAMETERS, it is possible to specify a 'query' structure to
            % select particular documents to be placed into the parameters 'depends_on' specification.
            % If one does not provide any 'query' structure, then the default values here are used.
            %
            % The function returns:
            % |-----------------------|----------------------------------------------|
            % | query                 | A structure with 'name' and 'query' fields   |
            % |                       |   that describes a search to be performed to |
            % |                       |   identify inputs for the 'depends_on' field |
            % |                       |   in the PARAMETERS output.                  |
            % |-----------------------|-----------------------------------------------
            %
            % In the base class, this examines the parameters_specifications for
            % fixed 'depends_on' entries (entries that have both a 'name' and a 'value').
            % If it finds any, it creates a query indicating that the 'depends_on' field
            % must match the specified name and value.
            %
            % This function is primarily intended as an internal function but is left exposed
            % (not private) so that it can be used for debugging. But in general, user code should
            % not call this function.
            %
            arguments
                ndi_calculator_obj (1,1) ndi.calculator
                parameters_specification (1,1) struct
            end
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
        end % default_parameters_query()

        function docs = search_for_calculator_docs(ndi_calculator_obj, parameters)  % can call find_appdoc, most of the code should be put in find_appdoc
            % SEARCH_FOR_CALCULATOR_DOCS - search for previous calculators
            %
            % [DOCS] = SEARCH_FOR_CALCULATOR_DOCS(NDI_CALCULATOR_OBJ, PARAMETERS)
            %
            % Performs a search to find all previously-created calculator
            % documents that this mini-app creates.
            %
            % PARAMETERS is a structure with the following fields
            % |------------------------|----------------------------------|
            % | Fieldname              | Description                      |
            % |-----------------------------------------------------------|
            % | input_parameters       | A structure of input parameters  |
            % |                        |  needed by the calculator.       |
            % | depends_on             | A structure with fields 'name'   |
            % |                        |  and 'value' that indicates any  |
            % |                        |  exact matches that should be    |
            % |                        |  satisfied.                      |
            % |------------------------|----------------------------------|
            %
            % in the abstract class, this returns empty
            %
            % This function is primarily intended as an internal function but is left exposed
            % (not private) so that it can be used for debugging. But in general, user code should
            % not call this function.
            %
            arguments
                ndi_calculator_obj (1,1) ndi.calculator
                parameters (1,1) struct
            end
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
            % ARE_INPUT_PARAMETERS_EQUIVALENT? - are two sets of input parameters equivalent?
            %
            % B = ARE_INPUT_PARAMETERS_EQUIVALENT(NDI_CALCULATOR_OBJ, INPUT_PARAMETERS1, INPUT_PARAMETERS2)
            %
            % Are two sets of input parameters equivalent? This function is used by
            % SEARCH_FOR_CALCULATOR_DOCS to determine whether potential documents
            % were actually generated by identical input parameters.
            %
            % In the base class, the structures are first re-organized so that all one-dimensional
            % substructures are columns and then compared with vlt.data.eqlen(INPUT_PARAMETERS1, INPUT_PARAMETERS2).
            %
            % It is necessary to "columnize" the substructures because Matlab does not not necessarily preserve that
            % orientation when data is written to or read from JSON.
            %
            % This function is primarily intended as an internal function but is left exposed
            % (not private) so that it can be used for debugging. But in general, user code should
            % not call this function.
            %
            arguments
                ndi_calculator_obj (1,1) ndi.calculator
                input_parameters1
                input_parameters2
            end
            if ~isempty(input_parameters1)
                input_parameters1 = vlt.data.columnize_struct(input_parameters1);
            end
            if ~isempty(input_parameters2)
                input_parameters2 = vlt.data.columnize_struct(input_parameters2);
            end
            b = eqlen(input_parameters1, input_parameters2);
        end

        function b = is_valid_dependency_input(ndi_calculator_obj, name, value)
            % IS_VALID_DEPENDENCY_INPUT - is a potential dependency input actually valid for this calculator?
            %
            % B = IS_VALID_DEPENDENCY_INPUT(NDI_CALCULATOR_OBJ, NAME, VALUE)
            %
            % Tests whether a potential input to a calculator is valid.
            % The potential dependency name is provided in NAME and its ndi.document id is
            % provided in VALUE.
            %
            % The base class behavior of this function is simply to return true, but it
            % can be overridden if additional criteria beyond an ndi.query are needed to
            % assess if a document is an appropriate input for the calculator.
            %
            % This function is primarily intended as an internal function but is left exposed
            % (not private) so that it can be used for debugging. But in general, user code should
            % not call this function.
            %
            b = 1; % base class behavior
        end % is_valid_dependency_input()

        function doc = calculate(ndi_calculator_obj, parameters)
            % CALCULATE - perform calculator and generate an ndi document with the answer
            %
            % DOC = CALCULATE(NDI_CALCULATOR_OBJ, PARAMETERS)
            %
            % Perform the calculator and return an ndi.document with the answer.
            %
            % This function is primarily intended as an internal function but is left exposed
            % (not private) so that it can be used for debugging. But in general, user code should
            % not call this function.
            %
            % In the base class, this always returns empty.
            arguments
                ndi_calculator_obj (1,1) ndi.calculator
                parameters (1,1) struct {ndi.validators.mustHaveFields(parameters, {'input_parameters','depends_on'})}
            end
            doc = {};

        end % calculate()

        function [docs, doc_output, doc_expected_output] = generate_mock_docs(ndi_calculator_obj, scope, number_of_tests, options)
            % GENERATE_MOCK_DOCS - generate mock documents for testing
            %
            % [DOCS, DOC_OUTPUT, DOC_EXPECTED_OUTPUT] = GENERATE_MOCK_DOCS(NDI_CALCULATOR_OBJ, SCOPE, NUMBER_OF_TESTS, 'PARAM', VALUE, ...)
            %
            % The generate_mock_docs method is a testing utility present in NDI calculator classes.
            % It generates synthetic input data (mock documents) and runs the calculator to produce actual outputs,
            % which can then be compared against expected outputs.
            %
            % This method takes additional input arguments as name/value pairs:
            % |---------------------------|------------------------------------------------------|
            % | Parameter (default)       | Description                                          |
            % |---------------------------|------------------------------------------------------|
            % | generate_expected_docs    | If true, the method saves the current output as the  |
            % |   (false)                 | "expected" output for future tests. Use this when    |
            % |                           | updating the calculator logic or creating new tests. |
            % | specific_test_inds ([])   | Allows specifying a subset of test indices to run.   |
            % |                           | If empty, all NUMBER_OF_TESTS are run.               |
            % |---------------------------|------------------------------------------------------|
            %
            % This blank method, for the superclass, returns empty for all inputs.
            %
            arguments
                ndi_calculator_obj (1,1) ndi.calculator
                scope (1,:) char
                number_of_tests (1,1) double
                options.generate_expected_docs (1,1) logical = false
                options.specific_test_inds (1,:) double = []
            end

            docs = {};
            doc_output = {};
            doc_expected_output = {};
        end % generate_mock_docs()

        function h=plot(ndi_calculator_obj, doc_or_parameters, varargin)
            % PLOT - provide a diagnostic plot to show the results of the calculator, if appropriate
            %
            % H=PLOT(NDI_CALCULATOR_OBJ, DOC_OR_PARAMETERS, ...)
            %
            % Produce a diagnostic plot that can indicate to a reader whether or not
            % the calculator has been performed in a manner that makes sense with
            % its input data. Useful for debugging / validating a calculator.
            %
            % This function is intended to be called by external users and code.
            %
            % Handles to the figure, the axes, and any objects created are returned in H.
            %
            % By default, this plot is made in the current axes.
            %
            % This function takes additional input arguments as name/value pairs.
            % See ndi.calculator.plot_parameters for a description of those parameters.
            %
            arguments
                ndi_calculator_obj (1,1) ndi.calculator
                doc_or_parameters
            end
            arguments (Repeating)
                varargin
            end
            params = ndi.calculator.plot_parameters(varargin{:});
            h.figure = []; if params.newfigure, h.figure = figure; else, h.figure = gcf; end
            h.axes = gca; 
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
                    h.title = title(id,'interp','none');
                end
            end
            if params.holdstate
                hold on;
            else
                hold off;
            end
        end % plot()

        %%%% methods that override ndi.appdoc %%%%

        % function struct2doc - should call calculator
        % function doc2struct - should build the input parameters from the document
        % function defaultstruct_appdoc - should call default search for input parameters and return a structure

        function b = isequal_appdoc_struct(ndi_app_appdoc_obj, appdoc_type, appdoc_struct1, appdoc_struct2)
            b = vlt.data.partial_struct_match(appdoc_struct1, appdoc_struct2);
        end 
        function text = doc_about(ndi_calculator_obj), text = ndi.calculator.docfiletext(class(ndi_calculator_obj), 'output'); end 
        function text = appdoc_description(ndi_calculator_obj), text = ndi_calculator_obj.doc_about(); end 
    end 
    
    methods (Static)

        function param = plot_parameters(options)
            % PLOT_PARAMETERS - provide a diagnostic plot to show the results of the calculator, if appropriate
            %
            % PLOT_PARAMETERS(NDI_CALCULATOR_OBJ, DOC_OR_PARAMETERS, ...)
            %
            % Produce a diagnostic plot that can indicate to a reader whether or not
            % the calculator has been performed in a manner that makes sense with
            % its input data. Useful for debugging / validating a calculator.
            %
            % By default, this plot is made in the current axes.
            %
            % This function takes additional input arguments as name/value pairs:
            % |---------------------------|--------------------------------------|
            % | Parameter (default)       | Description                          |
            % |---------------------------|--------------------------------------|
            % | newfigure (0)             | 0/1 Should we make a new figure?     |
            % | holdstate (0)             | 0/1 Should we preserve the 'hold'    |
            % |                           |   state of the current axes?         |
            % | suppress_x_label (0)      | 0/1 Should we suppress the x label?  |
            % | suppress_y_label (0)      | 0/1 Should we suppress the y label?  |
            % | suppress_z_label (0)      | 0/1 Should we suppress the z label?  |
            % | suppress_title (0)        | 0/1 Should we suppress the title?    |
            % |---------------------------|--------------------------------------|
            %

            arguments
                options.newfigure (1,1) {mustBeNumericOrLogical} = 0
                options.holdstate (1,1) {mustBeNumericOrLogical} = 0
                options.suppress_x_label (1,1) {mustBeNumericOrLogical} = 0
                options.suppress_y_label (1,1) {mustBeNumericOrLogical} = 0
                options.suppress_z_label (1,1) {mustBeNumericOrLogical} = 0
                options.suppress_title (1,1) {mustBeNumericOrLogical} = 0
            end

            param.newfigure = options.newfigure;
            param.holdstate = options.holdstate;
            param.suppress_x_label = options.suppress_x_label;
            param.suppress_y_label = options.suppress_y_label;
            param.suppress_z_label = options.suppress_z_label;
            param.suppress_title = options.suppress_title;
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
                options.window_params (1,1) struct = struct('height', 450, 'width', 700)
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
                    
                    fs = 12;
                    
                    set(fig,'position',[50 50 right top], 'Color', fig_bg_color, 'NumberTitle','off',...
                        'Name',['Editing ' ud.calculatorInstance.instanceName ' (' ud.calculatorInstance.calculatorClassname ')'],...
                        'MenuBar','none','ToolBar','none','Units','normalized', 'Resize', 'on');
                    
                    y_cursor = 1 - edge_n - row_h_n;
                    uicontrol(uid.txt,'Units','normalized','position',[edge_n y_cursor 0.6 row_h_n],'string','Documentation','BackgroundColor',fig_bg_color,'FontWeight','bold','HorizontalAlignment','left','FontSize',fs);
                    uicontrol(uid.popup,'Units','normalized','position',[edge_n+0.6 y_cursor 1-2*edge_n-0.6 row_h_n],'string',{'General','Calculator Input Options','Output document'},'tag','DocPopup','callback',callbackstr,'value',1,'BackgroundColor',edit_bg_color,'FontSize',fs);
                    y_cursor = y_cursor - (0.2 * (1 - button_area_h_n));
                    uicontrol(uid.edit,'Units','normalized','position',[edge_n y_cursor 1-2*edge_n 0.2*(1-button_area_h_n)],'string','...','tag','DocTxt','max',2,'enable','inactive','HorizontalAlignment','left','FontSize',fs);
                    
                    y_cursor = y_cursor - gap_v_n - row_h_n;
                    uicontrol(uid.txt,'Units','normalized','position',[edge_n y_cursor 0.6 row_h_n],'string','Parameter code:','BackgroundColor',fig_bg_color,'FontWeight','bold','HorizontalAlignment','left','FontSize',fs);
                    
                    global_opts = ndi.calculator.get_available_parameters(ud.calculatorInstance.calculatorClassname, ud.pipelinePath);
                    popup_str = [{'Template','---'}, global_opts];
                    val_idx = 1;
                    if ~isempty(ud.active_parameter_name)
                         idx = find(strcmp(popup_str, ud.active_parameter_name));
                         if ~isempty(idx), val_idx = idx(1); end
                    end
                    uicontrol(uid.popup,'Units','normalized','position',[edge_n+0.6 y_cursor 1-2*edge_n-0.6 row_h_n],'string',popup_str,'tag','ParameterCodePopup', 'callback',callbackstr,'value',val_idx,'BackgroundColor',edit_bg_color,'FontSize',fs);
                    y_cursor = y_cursor - (0.4 * (1 - button_area_h_n));
                    init_code = ndi.calculator.load_parameter_code(ud.calculatorInstance.calculatorClassname, ud.active_parameter_name, ud.pipelinePath);
                    uicontrol(uid.edit,'Units','normalized','position',[edge_n y_cursor 1-2*edge_n 0.4*(1-button_area_h_n)],'string',init_code,'tag','ParameterCodeTxt','max',2,'BackgroundColor',edit_bg_color,'HorizontalAlignment','left','FontSize',fs);
                    
                    y_cursor = y_cursor - gap_v_n - row_h_n;
                    uicontrol(uid.popup,'Units','normalized','position',[edge_n y_cursor 1-2*edge_n row_h_n],'string',{'Commands:','---','Try searching for inputs','Show existing outputs','Plot existing outputs','Run but don''t replace','Run and replace'},'tag','CommandPopup','callback',callbackstr,'BackgroundColor',edit_bg_color,'FontSize',fs);
                    y_cursor = y_cursor - gap_v_n - row_h_n;
                    
                    num_buttons = 5; button_w_n = 0.16;
                    button_centers_n = linspace(edge_n+button_w_n/2, 1-edge_n-button_w_n/2, num_buttons);
                    uicontrol(uid.button,'Units','normalized','position',[button_centers_n(1)-button_w_n/2 y_cursor button_w_n row_h_n],'string','Save','tag','SaveButton','callback',callbackstr,'FontSize',fs);
                    uicontrol(uid.button,'Units','normalized','position',[button_centers_n(2)-button_w_n/2 y_cursor button_w_n row_h_n],'string','Save As...','tag','SaveAsButton','callback',callbackstr,'FontSize',fs);
                    uicontrol(uid.button,'Units','normalized','position',[button_centers_n(3)-button_w_n/2 y_cursor button_w_n row_h_n],'string','Delete...','tag','DeleteParameterInstanceButton','callback',callbackstr,'FontSize',fs);
                    uicontrol(uid.button,'Units','normalized','position',[button_centers_n(4)-button_w_n/2 y_cursor button_w_n row_h_n],'string','Refresh','tag','RefreshPipelineButton','callback',callbackstr,'FontSize',fs);
                    uicontrol(uid.button,'Units','normalized','position',[button_centers_n(5)-button_w_n/2 y_cursor button_w_n row_h_n],'string','Exit','tag','ExitButton','callback',callbackstr,'FontSize',fs);
                    
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
                             
                             % Execute logic in base
                             check_cmd = ['if exist(''parameters'',''var'') && isstruct(parameters) && isfield(parameters,''query'') && ~isempty(parameters.query), ' ...
                                          '  if isfield(parameters.query(1),''query''), ' ...
                                          '    MYQ = parameters.query(1).query; ' ...
                                          '    DOCS = pipeline_session.database_search(MYQ); ' ...
                                          '    NDI_CMD_STATUS = 1; ' ...
                                          '  else, NDI_CMD_STATUS = 0; end; ' ...
                                          'else, NDI_CMD_STATUS = -1; end'];
                             evalin('base', check_cmd);
                             
                             status = evalin('base', 'NDI_CMD_STATUS');
                             if status == 1
                                 count = evalin('base', 'numel(DOCS)');
                                 fprintf('  Result: Found %d matching documents.\n', count);
                                 msgbox({'Search Check Complete.', 'See Command Window for details.', 'See variable DOCS.'}, 'Results', 'modal');
                             elseif status == 0
                                 fprintf('  Result: Error - parameters.query(1) missing "query" field.\n');
                             else
                                 fprintf('  Result: Error - parameters variable invalid.\n');
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
                                    fprintf('  Result: %d Output documents found and opened.\n', numel(ED));
                                    msgbox(sprintf('Found %d Output documents.\nOpened in Variable Editor.', numel(ED)), 'Outputs Found', 'modal');
                                else
                                    fprintf('  Result: No existing output documents found.\n');
                                    msgbox('No existing output documents found.', 'No Outputs', 'modal');
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
                                     answer = questdlg('Plot individual figures or create subplots?', 'Plot Mode', 'Individual', 'Subplots', 'Individual');
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
                    ndi.calculator.bring_gui_to_front(fig); 
                    
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
                    msgbox('Saved.', 'Success'); ndi.calculator.bring_gui_to_front(fig);
                    
                case 'SaveAsButton'
                    code = get(findobj(fig,'tag','ParameterCodeTxt'), 'String'); ans = inputdlg('Name:');
                    if ~isempty(ans)
                        ndi.calculator.save_parameter_file(ud.calculatorInstance.calculatorClassname, ans{1}, code, ud.pipelinePath);
                        ud.active_parameter_name = ans{1}; set(fig,'userdata',ud);
                        ndi.calculator.graphical_edit_calculator('command','RefreshPipelineButton','fig',fig);
                    end
                    ndi.calculator.bring_gui_to_front(fig);
                    
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
                otherwise
                    disp(['Unknown command ' command '.']);

            end % switch(command)
        end % graphical_edit_calculation ()

        function text = docfiletext(calculator_type, doc_type)
            % ndi.calculator.docfiletext - return the text in the requested documentation file
            %
            % TEXT = ndi.calculator.docfiletext(CALCULATOR_TYPE, DOC_TYPE)
            %
            % Returns the text of the documentation files.
            % CALCULATOR_TYPE should be the full object name of the calculator of interest.
            %  (for example: 'ndi.calc.stimulus.tuningcurve' or 'ndi.calc.vis.contrasttuning')
            % DOC_TYPE should be the type of document requested ('general', 'output', 'searching for inputs')
            %
            % Example:
            %    text = ndi.calculator.docfiletext('ndi.calc.stimulus.tuningcurve','general');
            %

            arguments
                calculator_type (1,:) char {ndi.validators.mustBeClassnameOfType(calculator_type, 'ndi.calculator')}
                doc_type (1,:) char {mustBeMember(doc_type, {'general', 'searching for inputs', 'output'})}
            end

            switch (lower(doc_type))
                case 'general'
                    doctype = 'general';
                case 'searching for inputs'
                    doctype = 'searching';
                case 'output'
                    doctype = 'output';
                otherwise
                    error(['Unknown document type ' doc_type '.']);
            end

            w = which(calculator_type);
            if isempty(w)
                error(['No known calculator on the path called ' calculator_type '.']);
            end
            [parentdir, appname] = fileparts(w);
            filename = [parentdir filesep 'docs' filesep appname '.docs.' doctype '.txt'];

            paramfile_present = isfile(filename);
            if paramfile_present
                text = vlt.file.text2cellstr(filename);
            else
                error(['No such file ' filename '.']);
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
            for i=1:numel(d), [~, name, ~] = fileparts(d(i).name); if ~strcmp(name,'Default'), params{end+1} = name; end; end
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
                
        function contents = user_parameter_template(calculator_type)
            contents = sprintf(['%% User parameters for %s\n' ...
                                'thecalc = %s(pipeline_session);\n' ...
                                'parameters = thecalc.default_search_for_input_parameters();\n'], calculator_type, calculator_type);
            input_name = 'input_1'; 
            try
                txt = fileread(which(calculator_type));
                % Find default_parameters_query and search within it for name: 'something'
                idx_func = strfind(txt, 'default_parameters_query');
                if ~isempty(idx_func)
                    sub_txt = txt(idx_func(1):end);
                    t = regexp(sub_txt, '''name''\s*,\s*''([^'']+)''', 'tokens', 'once');
                    if ~isempty(t), input_name = t{1}; end
                end
            catch
            end
            query_line = sprintf('parameters.query = struct(''name'',''%s'',''query'',ndi.query(''stimulus_tuningcurve.independent_variable_label'',''contains_string'',''independent_label'',''''));\n', input_name);
            contents = [contents query_line];
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
        
        function bring_gui_to_front(fig)
             pipeline_fig = findobj('tag','ndi.cpipeline.edit');
             if ~isempty(pipeline_fig), figure(pipeline_fig(1)); end
             if ishandle(fig), figure(fig); end
        end
    end % End of methods (Static)
end % End of classdef