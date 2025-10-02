classdef calculator < ndi.app & ndi.app.appdoc & ndi.mock.ctest
    properties (SetAccess=protected,GetAccess=public)
        fast_start = 'ndi.calculator.graphical_edit_calculator(''command'',''new'',''type'',''ndi.calc.vis.contrast'',''name'',''mycalc'')';
    end % properties
    methods
        function ndi_calculator_obj = calculator(varargin)
            % CALCULATOR - create an ndi.calculator object
            %
            % NDI_CALCULATOR_OBJ = CALCULATOR(SESSION, DOC_TYPE, PATH_TO_DOC_TYPE)
            %
            % Creates a new ndi.calculator mini-app for performing
            % a particular calculator. SESSION is the ndi.session object
            % to operate on.
            %
            % Classes that override this function should call
            % the creator for ndi.appdoc to record the document type
            % that is used by the ndi.calculator mini-app.
            %
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
            %
            % DOCS = RUN(NDI_CALCULATOR_OBJ, DOCEXISTSACTION, PARAMETERS)
            %
            % DOCEXISTSACTION can be 'Error', 'NoAction', 'Replace', or 'ReplaceIfDifferent'
            % For calculators, 'ReplaceIfDifferent' is equivalent to 'NoAction' because
            % the input parameters define the calculator.
            %
            % This function is primarily intended to be called by external programs and users.
            %
              % Step 1: set up input parameters; they can either be completely specified by
              % the caller, or defaults can be used
            docs = {};
            docs_tocat = {};
            if nargin<3
                parameters = ndi_calculator_obj.default_search_for_input_parameters();
            end
            % Step 2: identify all sets of possible input parameters that are compatible with
            % what was specified by 'parameters'
            all_parameters = ndi_calculator_obj.search_for_input_parameters(parameters);
            % Step 3: check if we've already done the calculator for these parameters; if we have,
            % take the appropriate action. If we need to, perform the calculator.
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
                end
            end
            for i=1:numel(all_parameters)
                docs = cat(2,docs,docs_tocat{i});
            end
            app_doc = ndi_calculator_obj.newdocument();
            for i=1:numel(docs)
                docs{i} = docs{i}.setproperties('app',app_doc.document_properties.app);
            end
            if ~isempty(docs)
                ndi_calculator_obj.session.database_add(docs);
            end
            mylog.msg('system',1,'Concluding calculator.');
        end % run()
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
            parameters.input_parameters = [];
            parameters.depends_on = vlt.data.emptystruct('name','value');
        end % default_search_for_input_parameters
        function parameters = search_for_input_parameters(ndi_calculator_obj, parameters_specification, varargin)
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
            t_start = tic;
            fixed_input_parameters = parameters_specification.input_parameters;
            if isfield(parameters_specification,'depends_on')
                fixed_depends_on = parameters_specification.depends_on;
            else
                fixed_depends_on = vlt.data.emptystruct('name','value');
            end
            % validate fixed depends_on values
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
                % we are done, everything is fixed
                parameters.input_parameters = fixed_input_parameters;
                parameters.depends_on = fixed_depends_on;
                parameters = {parameters}; % a single cell entry
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
                    s = struct('name',parameters_specification.query(i).name,'value',doclist{i}{g(i)}.id());
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
        end % search_for_input_parameters()
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
            myemptydoc = ndi.document(ndi_calculator_obj.doc_document_types{1});
            property_list_name = myemptydoc.document_properties.document_class.property_list_name;
            % class_name = myemptydoc.document_properties.document_class.class_name
            [parent,class_name,ext] = fileparts(myemptydoc.document_properties.document_class.definition);
            % this is not a good way to do things; every database will not be able to implement it
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
            % now identify the subset that have the same input_parameters
            matches = [];
            for i=1:numel(docs)
                try
                    input_param = eval(['docs{i}.document_properties.' property_list_name '.input_parameters;']);
                catch
                    input_param = []
                end
                if ndi_calculator_obj.are_input_parameters_equivalent(input_param,parameters.input_parameters)
                    matches(end+1) = i;
                end
            end
            docs = docs(matches);
        end % search_for_calculator_docs()
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
            doc = {};
        end % calculate()
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
            params = ndi.calculator.plot_parameters(varargin{:});
            % base class does nothing except pop up figure and title after the doc name
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
        end % plot()
        %%%% methods that override ndi.appdoc %%%%
        % function struct2doc - should call calculator
        % function doc2struct - should build the input parameters from the document
        % function defaultstruct_appdoc - should call default search for input parameters and return a structure
        function b = isequal_appdoc_struct(ndi_app_appdoc_obj, appdoc_type, appdoc_struct1, appdoc_struct2)
            % ISEQUAL_APPDOC_STRUCT - are two APPDOC data structures the same (equal)?
            %
            % B = ISEQUAL_APPDOC_STRUCT(NDI_APPDOC_OBJ, APPDOC_TYPE, APPDOC_STRUCT1, APPDOC_STRUCT2)
            %
            % Returns 1 if the structures APPDOC_STRUCT1 and APPDOC_STRUCT2 are valid and equal. This is true if
            % APPDOC_STRUCT2
            % true if APPDOC_STRUCT1 and APPDOC_STRUCT2 have the same field names and same values and same sizes. That is,
            % B is vlt.data.eqlen(APPDOC_STRUCT1, APPDOC_STRUCT2).
            %
            b = vlt.data.partial_struct_match(appdoc_struct1, appdoc_struct2);
        end % isequal_appdoc_struct()
        function text = doc_about(ndi_calculator_obj)
            % DOC_ABOUT - return the about information for an NDI calculator
            %
            % TEXT = DOC_ABOUT(NDI_CALCULATOR_OBJ)
            %
            % Returns the help information for the document type for an NDI
            % calculator object.
            %
            % This function is intended to be called by external users or code.
            %
            text = ndi.calculator.docfiletext(class(ndi_calculator_obj), 'output');
        end %doc_about()
        function text = appdoc_description(ndi_calculator_obj)
            % APPDOC_DESCRIPTION - return documentation for the type of document that is created by this calculator.
            %
            % TEXT = APP_DOC_DESCRIPTION(NDI_CALCULATOR_OBJ)
            %
            % Returns the help information for the document type for an NDI
            % calculator object.
            %
            % This function is intended to be called by external users or code.
            %
            text = ndi_calculator_obj.doc_about();
        end % appdoc_description()
    end % methods
    methods (Static)
        function param = plot_parameters(varargin)
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
            % GRAPHICAL_EDIT_CALCULATOR - Create and control a GUI to graphically edit an NDI calculator instance
            %
            %   FIG_OUT = GRAPHICAL_EDIT_CALCULATOR(Name, Value, ...)
            %
            %   Creates and controls a graphical user interface for creating or editing
            %   an instance of an ndi.calculator object.
            %
            %   This function accepts the following optional arguments as name-value pairs:
            %
            %   'command'           A character array specifying the GUI command to
            %                       implement. Must be one of 'New' (default), 'Edit', or 'Close'.
            %
            %   'session'           An ndi.session object to associate with the GUI.
            %                       Defaults to an empty ndi.session object.
            %
            %   'name'              A character array for the user-defined name of this
            %                       calculator instance. Defaults to ''.
            %
            %   'filename'          The full path to the JSON file where the calculator's
            %                       information is stored. Defaults to ''.
            %
            %   'calculatorClassname' The classname of the calculator to create.
            %                       Defaults to ''.
            %
            %   'window_params'     A structure with 'height' and 'width' fields that
            %                       specify the window dimensions in pixels.
            %                       Defaults to struct('height', 600, 'width', 400).
            %
            %   'fig'               The handle of an existing figure to use or manage.
            %                       If empty (default), a new figure is created.
            %
            
            % Use an arguments block for robust name-value pair parsing
            arguments
                % The GUI command, must be 'New', 'Edit', 'Close', etc.
                options.command (1,:) char {mustBeMember(options.command, {'New','Edit','Close',...
                    'NewWindow','UpdateWindow','DocPopup', 'ParameterCodePopup',...
                    'CommandPopup', 'SaveButton', 'CancelButton', 'SaveAsButton',...
                    'DeleteParameterInstanceButton', 'RefreshParameterPopup'})} = 'New'
        
                % The NDI session object, must be a scalar ndi.session
                options.session ndi.session = ndi.session.empty()
        
                % The user's name for the calculator instance
                options.name (1,:) char = ''
        
                % The JSON file for storing calculator state
                options.filename (1,:) char = ''
        
                % The classname of the calculator
                options.calculatorClassname (1,:) char = ''
        
                % Window parameters structure, must be a scalar struct
                options.window_params (1,1) struct = struct('height', 600, 'width', 400)
        
                % Optional figure handle. Can be a figure object or empty ([]).
                options.fig {mustBeA(options.fig,["matlab.ui.Figure","double"])} = []
            end
            command = options.command;
            fig = options.fig;
            % Enforce that 'fig' must be provided for all commands except 'New' and 'Edit'
            if ~ismember(command, {'New','Edit'}) && isempty(fig)
                error('The ''fig'' argument must be provided for the command ''%s''.', command);
            end
            if strcmp(command,'New')
                % set up for new window
                calculatorInstance.JSONFilename = options.filename;
                calculatorInstance.instanceName = options.name;
                calculatorInstance.calculatorClassname = options.calculatorClassname;
                
                % Note: the 'parameter_code' field is no longer part of the instance JSON
                
                ud.calculatorInstance = calculatorInstance;
                ud.window_params = options.window_params;
                ud.linked_object = options.session; 
                ud.active_parameter_name = ''; % Indicates we are editing a new template
                if isempty(fig)
                    fig = figure;
                end
                command = 'NewWindow';
            elseif strcmp(command,'Edit')
                % set up for editing from a file
                ud.calculatorInstance = jsondecode(fileread(options.filename));
                ud.calculatorInstance.JSONFilename = options.filename; % ensure this is set
                
                ud.linked_object = options.session; 
                ud.active_parameter_name = ''; % Start with template, even when editing
                
                if ~isfield(ud,'window_params')
                    ud.window_params = options.window_params;
                end
                command = 'NewWindow';
                if isempty(fig)
                    fig = figure;
                end
            else
                ud = get(fig,'userdata');
            end
            if isempty(fig)
                error(['Empty figure, do not know what to work on.']);
            end
            
            disp(['Command is ' command '.']);
            switch (command)
                case 'NewWindow'
                    set(fig,'tag','ndi.calculator.graphical_edit_calculator');
                    set(fig,'userdata',ud); % set initial userdata variables
                    % now build the window
                    uid = vlt.ui.basicuitools_defs;
                    callbackstr = [  'eval([get(gcbf,''Tag'') ''(''''command'''','''''' get(gcbo,''Tag'') '''''' ,''''fig'''',gcbf);'']);'];
                    
                    % Step 1: Define colors and normalized geometry
                    fig_bg_color = [0.8 0.8 0.8];
                    box_bg_color = [0.9 0.9 0.9];
                    edit_bg_color = [1 1 1];
                    top = ud.window_params.height;
                    right = ud.window_params.width;
                    
                    edge_n = 10/right;
                    row_h_n = 25/top;
                    gap_v_n = 15/top;
                    button_area_h_n = 5*row_h_n;
                    
                    % Step 2 now build it
                    set(fig,'position',[50 50 right top],...
                        'Color', fig_bg_color, ...
                        'NumberTitle','off',...
                        'Name',['Editing ' ud.calculatorInstance.instanceName ' of type ' ud.calculatorInstance.calculatorClassname ],...
                        'MenuBar','none',...
                        'ToolBar','none',...
                        'Units','normalized');
                    
                    % Step 3: Create UI elements using a top-down normalized layout
                    y_cursor = 1 - edge_n;
                    
                    % Define main content area height (space between top and bottom buttons)
                    main_area_h = y_cursor - button_area_h_n - edge_n;
                    
                    % Allocate heights proportionally
                    doc_section_h = main_area_h * 0.25;
                    param_section_h = main_area_h * 0.75;
                    
                    % --- Documentation Section ---
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
                        
                    % --- Parameter Code Section ---
                    y_cursor = y_cursor - gap_v_n - row_h_n;
                     uicontrol(uid.txt,'Units','normalized','position',[edge_n y_cursor 0.6 row_h_n],'string','Parameter code:', ...
                        'tag','ParameterCodeTitleTxt','BackgroundColor',fig_bg_color,'FontWeight','bold','HorizontalAlignment','left');
                    [param_names,~] = ndi.calculator.readParameterCode(ud.calculatorInstance.calculatorClassname);
                    uicontrol(uid.popup,'Units','normalized','position',[edge_n+0.6 y_cursor 1-2*edge_n-0.6 row_h_n],...
                        'string',{'Template', 'Default', '---', param_names{:}},...
                        'tag','ParameterCodePopup', 'callback',callbackstr,'value',1,'BackgroundColor',edit_bg_color);
                    y_cursor = y_cursor - (param_section_h - row_h_n);
                    uicontrol(uid.edit,'Units','normalized','position',[edge_n y_cursor 1-2*edge_n param_section_h-row_h_n],...
                        'string',ndi.calculator.user_parameter_template(ud.calculatorInstance.calculatorClassname),...
                        'tag','ParameterCodeTxt','min',0,'max',2,'BackgroundColor',edit_bg_color,'HorizontalAlignment','left');
                    
                    % --- Bottom Controls ---
                    y_cursor = y_cursor - gap_v_n - row_h_n;
                    uicontrol(uid.popup,'Units','normalized','position',[edge_n y_cursor 1-2*edge_n row_h_n],...
                        'string',{'Commands:','---','Try searching for inputs','Show existing outputs',...
                        'Plot existing outputs','Run but don''t replace existing docs','Run and replace existing docs'},...
                        'tag','CommandPopup','callback',callbackstr,'BackgroundColor',edit_bg_color);
                    
                    y_cursor = y_cursor - gap_v_n - row_h_n;
                    button_w_n = 0.2;
                    button_centers_n = linspace(edge_n+button_w_n/2, 1-edge_n-button_w_n/2, 4);
                    
                    uicontrol(uid.button,'Units','normalized','position',[button_centers_n(1)-button_w_n/2 y_cursor button_w_n row_h_n],...
                        'string','Save','tag','SaveButton','callback',callbackstr);
                    uicontrol(uid.button,'Units','normalized','position',[button_centers_n(2)-button_w_n/2 y_cursor button_w_n row_h_n],...
                        'string','Save As...','tag','SaveAsButton','callback',callbackstr);
                    uicontrol(uid.button,'Units','normalized','position',[button_centers_n(3)-button_w_n/2 y_cursor button_w_n row_h_n],...
                        'string','Delete...','tag','DeleteParameterInstanceButton','callback',callbackstr);
                    uicontrol(uid.button,'Units','normalized','position',[button_centers_n(4)-button_w_n/2 y_cursor button_w_n row_h_n],...
                        'string','Cancel','tag','CancelButton','callback',callbackstr);
                    
                    ndi.calculator.graphical_edit_calculator('command','DocPopup','fig',fig);
                case 'DocPopup'
                    try
                        docPopupObj = findobj(fig,'tag','DocPopup');
                        val = get(docPopupObj, 'value');
                        docTextObj = findobj(fig,'tag','DocTxt');
                        
                        if isempty(docTextObj) || ~isvalid(docTextObj)
                            error('Could not find the documentation text box handle (tag=''DocTxt'').');
                        end

                        switch val
                            case 1, doc_type = 'general';
                            case 2, doc_type = 'searching for inputs';
                            case 3, doc_type = 'output';
                            otherwise, error('Unknown doc popup value.');
                        end

                        mytext = ndi.calculator.docfiletext(ud.calculatorInstance.calculatorClassname, doc_type);

                        if isempty(mytext)
                            mytext = {'Documentation file was found but is empty.'};
                        end
                        
                        set(docTextObj,'string',mytext);
                    catch ME
                        errordlg(['An error occurred while loading documentation: ' ME.message], 'Documentation Error');
                        rethrow(ME); % Also show error in command window for debugging
                    end
                case 'ParameterCodePopup'
                    paramPopupObj = findobj(fig,'tag','ParameterCodePopup');
                    val = get(paramPopupObj, 'value');
                    paramTextObj = findobj(fig,'tag','ParameterCodeTxt');
                    
                    [names, contents] = ndi.calculator.readParameterCode(ud.calculatorInstance.calculatorClassname);

                    switch val
                        case 1 % Template
                            set(paramTextObj,'string',ndi.calculator.user_parameter_template(ud.calculatorInstance.calculatorClassname));
                            ud.active_parameter_name = '';
                        case 2 % Default
                            set(paramTextObj,'string',ndi.calculator.parameter_default(ud.calculatorInstance.calculatorClassname));
                            ud.active_parameter_name = 'default';
                        case {4,5,6,7,8,9,10,11,12,13,14,15} % saved instances
                            example_index = val - 3;
                            if example_index <= numel(contents)
                                set(paramTextObj,'string',contents{example_index});
                                ud.active_parameter_name = names{example_index};
                            end
                    end
                    set(fig,'userdata',ud);
                case 'CommandPopup'
                    cmdPopupObj = findobj(fig,'tag','CommandPopup');
                    val = get(cmdPopupObj, 'value');
                    
                    if isempty(ud.linked_object) || ~isa(ud.linked_object,'ndi.session')
                        errordlg('A valid ndi.session object must be linked to run these commands.', 'Session Error');
                        return; % Stop execution
                    end
                    assignin('base','pipeline_session',ud.linked_object);
                    
                    paramTextObj = findobj(fig,'tag','ParameterCodeTxt');
                    code_from_box = get(paramTextObj,'string');
                    if iscell(code_from_box)
                        param_code = strjoin(code_from_box, sprintf('\n'));
                    else
                        param_code = code_from_box;
                    end
                    evalin('base',param_code);
                    
                    switch val
                        case 3 % Try searching for inputs
                            search_code = ['thecalc=' ud.calculatorInstance.calculatorClassname '(pipeline_session); if ~exist(''parameters'',''var''), parameters=thecalc.default_search_for_input_parameters(); end; IP=thecalc.search_for_input_parameters(parameters);'];
                            evalin('base',search_code);
                            disp(['Search done, variable IP now has input combinations found.']);
                        case 4 % Show existing outputs
                            search_code = ['thecalc=' ud.calculatorInstance.calculatorClassname '(pipeline_session); ED=thecalc.search_for_calculator_docs(parameters);'];
                            evalin('base',search_code);
                            disp(['Search done, variable ED now has existing calculation documents found.']);
                            ED = evalin('base','ED');
                            if ~isempty(ED)
                                if isfield(ud,'docViewer') && isvalid(ud.docViewer.fig)
                                    figure(ud.docViewer.fig); % bring to front
                                else % we need to build it
                                    ud.docViewer = ndi.gui.docViewer();
                                    set(fig,'userdata',ud);
                                end
                                ud.docViewer.addDoc(ED);
                            end
                        case 5 % Plot existing outputs
                            search_code = ['thecalc=' ud.calculatorInstance.calculatorClassname '(pipeline_session); ED=thecalc.search_for_calculator_docs(parameters);'];
                            evalin('base',search_code);
                            disp(['Search done, variable ED now has existing calculation documents found.']);
                            disp(['Now will plot all of these ' int2str(evalin('base','numel(ED)')) ' documents.']);
                            evalin('base',['for i=1:numel(ED), figure; thecalc.plot(ED{i}); end;']);
                            disp(['Finished plotting.']);
                        case 6 % Run but don''t replace existing docs
                            run_code = ['thecalc=' ud.calculatorInstance.calculatorClassname '(pipeline_session); RUNDOCS=thecalc.run(''NoAction'',parameters);'];
                            evalin('base',run_code);
                            disp(['Run done, variable RUNDOCS now has calculation documents created.']);
                        case 7 % Run and replace existing docs
                            run_code = ['thecalc=' ud.calculatorInstance.calculatorClassname '(pipeline_session); RUNDOCS=thecalc.run(''Replace'', parameters);'];
                            evalin('base',run_code);
                            disp(['Run done, variable RUNDOCS now has calculation documents created.']);
                    end
                case 'SaveButton'
                    if isempty(ud.active_parameter_name) || strcmp(ud.active_parameter_name, 'default')
                        msgbox('This is a template or default code. Please use "Save As..." to create a parameter instance file before saving.', 'Save Error');
                        return;
                    end
                    
                    paramTextObj = findobj(fig,'tag','ParameterCodeTxt');
                    code_from_box = get(paramTextObj,'String');
                    if iscell(code_from_box)
                        code_to_save = strjoin(code_from_box, sprintf('\n'));
                    else
                        code_to_save = code_from_box;
                    end
                    
                    % Use the new centralized save function
                    ndi.calculator.addParameterCode(ud.calculatorInstance.calculatorClassname, ...
                        ud.active_parameter_name, code_to_save);
                    
                    msgbox(['Changes to ''' ud.active_parameter_name ''' have been saved.'],'Save Complete');
                case 'SaveAsButton'
                    paramTextObj = findobj(fig,'tag','ParameterCodeTxt');
                    code_from_box = get(paramTextObj,'String');
                    if iscell(code_from_box)
                        code_to_save = strjoin(code_from_box, sprintf('\n'));
                    else
                        code_to_save = code_from_box;
                    end
                    
                    answer = inputdlg('Enter a name for this parameter instance (e.g., my_params):', 'Save Parameter Instance As');
                    if isempty(answer) || isempty(answer{1}), return; end; % User cancelled
                    
                    instance_name = answer{1};
                    
                    ndi.calculator.addParameterCode(ud.calculatorInstance.calculatorClassname, instance_name, code_to_save);
                    
                    ud.active_parameter_name = instance_name;
                    set(fig, 'userdata', ud);
                    
                    ndi.calculator.graphical_edit_calculator('command','RefreshParameterPopup','fig',fig);
                    msgbox(['New parameter instance ''' instance_name ''' saved.'], 'Save Complete');
                case 'DeleteParameterInstanceButton'
                    [names, ~] = ndi.calculator.readParameterCode(ud.calculatorInstance.calculatorClassname);
                    if isempty(names)
                        msgbox('There are no saved parameter instances to delete.', 'No Instances Found');
                        return;
                    end
                    
                    [selectedIndex, isSelectionMade] = listdlg('PromptString','Select a parameter instance to delete:',...
                        'SelectionMode','single','ListString',names);
                        
                    if isSelectionMade
                        name_to_delete = names{selectedIndex};
                        
                        b = questdlg(['Are you sure you want to permanently delete ''' name_to_delete '''?'], ...
                            'Confirm Delete', 'Yes', 'No', 'No');
                        
                        if strcmp(b,'Yes')
                            ndi.calculator.deleteParameterCode(ud.calculatorInstance.calculatorClassname, name_to_delete);
                            msgbox(['''' name_to_delete ''' was deleted.'], 'Delete Successful');

                            if strcmp(ud.active_parameter_name, name_to_delete)
                                paramTextObj = findobj(fig,'tag','ParameterCodeTxt');
                                set(paramTextObj,'string',ndi.calculator.user_parameter_template(ud.calculatorInstance.calculatorClassname));
                                ud.active_parameter_name = '';
                                set(fig,'userdata',ud);
                            end
                            ndi.calculator.graphical_edit_calculator('command','RefreshParameterPopup','fig',fig);
                        end
                    end
                case 'RefreshParameterPopup'
                    [new_names, ~] = ndi.calculator.readParameterCode(ud.calculatorInstance.calculatorClassname);
                    
                    paramPopupObj = findobj(fig,'tag','ParameterCodePopup');
                    new_string = {'Template', 'Default', '---', new_names{:}};
                    
                    % try to find the active parameter name in the new list and set the popup value
                    current_val = 1; % Default to template
                    if ~isempty(ud.active_parameter_name)
                        if strcmp(ud.active_parameter_name,'default')
                            current_val = 2;
                        else
                            found_it = find(strcmp(ud.active_parameter_name, new_names));
                            if ~isempty(found_it)
                                current_val = found_it(1) + 3; % +3 due to template, default, ---
                            end
                        end
                    end
                    set(paramPopupObj, 'string', new_string, 'value', current_val);
                case 'CancelButton'
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
                % Reverted to original working version as requested
                text = vlt.file.text2cellstr(filename);
            else
                error(['No such file ' filename '.']);
            end
        end
        function calc_list = find_calculator_subclasses(forceUpdate)
        % FIND_CALCULATOR_SUBCLASSES - Recursively finds all subclasses of ndi.calculator.
        %
        %   CALC_LIST = ndi.calculator.find_calculator_subclasses(FORCEUPDATE)
        %
        %   Scans the entire MATLAB path for all '+ndi/+calc' packages to discover
        %   all defined classes. It returns a cell array of strings containing the
        %   full names of only those classes that are non-abstract subclasses of
        %   'ndi.calculator'.
        %
        %   This function uses a persistent variable to cache the results for
        %   performance. On subsequent calls, it will return the cached list
        %   unless the optional FORCEUPDATE argument is set to true.
        %
        %   Inputs:
        %     FORCEUPDATE (logical): A boolean flag. If true, the function will
        %                            rescan the path and update the cached list.
        %                            Defaults to false.
        %
                
            arguments
                forceUpdate (1,1) logical = false;
            end
    
            persistent cached_calc_list;
            if isempty(cached_calc_list) || forceUpdate
                
                calc_list = {};
                
                % 1. Manually search the entire MATLAB path for directories containing '+ndi/+calc'
                all_paths = strsplit(path, pathsep);
                calc_package_roots = {};
                for i = 1:numel(all_paths)
                    p = all_paths{i};
                    potential_calc_path = fullfile(p, '+ndi', '+calc');
                    if isfolder(potential_calc_path)
                        calc_package_roots{end+1} = potential_calc_path;
                    end
                end
                calc_package_roots = unique(calc_package_roots);
    
                if isempty(calc_package_roots)
                    %warning('Could not find any ''+ndi/+calc'' directories on the MATLAB path.');
                    cached_calc_list = {}; % Cache the empty result
                    calc_list = cached_calc_list;
                    return;
                end
                
                % 2. Recursively search within each found path
                for i = 1:numel(calc_package_roots)
                    path_to_search = calc_package_roots{i};
                    sub_classes = find_recursively(path_to_search, 'ndi.calc');
                    calc_list = [calc_list, sub_classes];
                end
    
                cached_calc_list = unique(calc_list); % Store the result in the cache
            end
    
            % Return the cached list
            calc_list = cached_calc_list(:);
    
            % --- Nested Helper Function for Recursion ---
            function class_list = find_recursively(current_path, current_package_name)
                
                class_list = {};
                dir_contents = dir(current_path);
                base_meta = ?ndi.calculator;
    
                for item = dir_contents'
                    % Skip '.', '..', and non-M files/non-packages
                    if strcmp(item.name, '.') || strcmp(item.name, '..')
                        continue;
                    end
                    
                    full_item_path = fullfile(current_path, item.name);
    
                    if item.isdir && startsWith(item.name, '+') % It's a sub-package
                        sub_package_name = item.name(2:end);
                        full_subpackage_name = [current_package_name '.' sub_package_name];
                        sub_classes = find_recursively(full_item_path, full_subpackage_name);
                        class_list = [class_list, sub_classes];
                    elseif endsWith(item.name, '.m') % It's an M-file
                        [~, name_only] = fileparts(item.name);
                        full_class_name = [current_package_name '.' name_only];
                        try
                            mc = meta.class.fromName(full_class_name);
                            % Use '<' to check for subclass relationship
                            % Also, exclude the abstract base class itself
                            if mc < base_meta && ~mc.Abstract
                                class_list{end+1} = mc.Name;
                            end
                        catch
                            % Silently ignore files that are not valid classes
                        end
                    end
                end
            end % find_recursively
        end % find_calculator_subclasses
        function [contents] = parameter_default(calculator_type)
            % ndi.calculator.parameter_default - return the default parameter code for a given calculator_type
            %
            % [CONTENTS] = ndi.calculator.parameter_default(CALCULATOR_TYPE)
            %
            % Return the default parameter code CONTENTS for a given CALCULATOR_TYPE. CONTENTS is a
            % character string.
            %
            % Example:
            %   [contents] = ndi.calculator.parameter_default('ndi.calc.stimulus.tuningcurve');
            %
            w = which(calculator_type);
            if isempty(w)
                error(['No known calculator on the path called ' calculator_type '.']);
            end
            [parentdir, appname] = fileparts(w);
            filename = [parentdir filesep 'docs' filesep appname '.docs.parameter.default.txt'];
            if isfile(filename)
                contents = fileread(filename);
            else
                warning(['No default parameter code file ' filename ' found. Generating a generic default.']);
                contents = sprintf([...
                    '%% Default parameters for %s\r\n' ...
                    '%% This code is auto-generated because a specific default file was not found.\r\n\r\n' ...
                    'thecalc = %s(pipeline_session);\r\n' ...
                    'parameters = thecalc.default_search_for_input_parameters();\r\n' ...
                    '%% Default input set by calculator\r\n' ...
                    'parameters.query.query = ndi.query(''stimulus_tuningcurve.independent_variable_label'',''contains_string'',''Direction(BG=0.5)'','''');\r\n'], ...
                    calculator_type, calculator_type);
            end
        end
        function [contents] = user_parameter_template(calculator_type)
            % USER_PARAMETER_TEMPLATE - return a user-friendly template for parameter code
            %
            % [CONTENTS] = USER_PARAMETER_TEMPLATE(CALCULATOR_TYPE)
            %
            % Returns a user-friendly template for the parameter code for a given CALCULATOR_TYPE.
            % This template includes instructions and commented-out examples.
            %
                contents = sprintf([...
                    '%% User parameters for %s\r\n' ...
                    '%% Edit the following lines to generate a user-defined parameter file for this calculator instance.\r\n\r\n' ...
                    'thecalc = %s(pipeline_session);\r\n' ...
                    'parameters = thecalc.default_search_for_input_parameters();\r\n' ...
                    'parameters.query.query = ndi.query(''stimulus_tuningcurve.independent_variable_label'',''contains_string'',''Direction(BG=0.5)'','''');\r\n' ...
                    '%% Option to change Background from 0.5 to 0\r\n\r\n' ...
                    '%% You can add more specific constraints below.\r\n' ...
                    '%% For example, to restrict the search to a specific recording element:\r\n' ...
                    '%%\r\n' ...
                    '%% element_id = ''some_element_id_string''; %% replace with a real ID\r\n' ...
                    '%% parameters.query(end+1) = ndi.query('''',''depends_on'',''element_id'',element_id);\r\n'],...
                    calculator_type, calculator_type);
        end
        function path = get_user_parameters_path()
            % GET_USER_PARAMETERS_PATH - returns the full path to the user_parameters.json file
            path = fullfile(ndi.cpipeline.defaultPath(), 'user_parameters.json');
        end
        function [names, contents] = readParameterCode(calculator_classname)
            % READPARAMETERCODE - Read all parameter instances for a class from the central JSON file
            names = {};
            contents = {};
            json_path = ndi.calculator.get_user_parameters_path();
            if ~isfile(json_path), return; end
            
            json_text = fileread(json_path);
            if isempty(strtrim(json_text)), return; end
            
            all_params = jsondecode(json_text);
            class_field = matlab.lang.makeValidName(calculator_classname);
            
            if isfield(all_params, class_field)
                class_entries = all_params.(class_field);
                % BUG FIX: Handle case where jsondecode creates an empty double []
                if isempty(class_entries) && ~isstruct(class_entries), return; end
                % Handle backward compatibility: convert from cell to struct array if needed
                if iscell(class_entries), class_entries = [class_entries{:}]; end
                
                for i=1:numel(class_entries)
                    names{end+1} = class_entries(i).parameterCodeName;
                    contents{end+1} = class_entries(i).parameterCodeText;
                end
            end
        end
        function addParameterCode(calculator_classname, name, text)
            % ADDPARAMETERCODE - Add or update a parameter instance in the central JSON file
            json_path = ndi.calculator.get_user_parameters_path();
            all_params = struct();
            if isfile(json_path)
                json_text = fileread(json_path);
                if ~isempty(strtrim(json_text))
                    all_params = jsondecode(json_text);
                end
            end

            class_field = matlab.lang.makeValidName(calculator_classname);
            
            if ~isfield(all_params, class_field)
                % Initialize as empty struct array with correct fields
                all_params.(class_field) = struct('parameterCodeName',{}, 'parameterCodeText',{});
            end
            
            class_entries = all_params.(class_field);

            % BUG FIX: jsondecode turns empty arrays '[]' into 0x0 doubles.
            if isempty(class_entries) && ~isstruct(class_entries)
                class_entries = struct('parameterCodeName',{}, 'parameterCodeText',{});
            end
            % Handle backward compatibility: convert from cell to struct array if needed
            if iscell(class_entries), class_entries = [class_entries{:}]; end

            new_entry = struct('parameterCodeName', name, 'parameterCodeText', text);
            
            % Check if it exists to overwrite, otherwise append
            found_index = -1;
            for i=1:numel(class_entries)
                if strcmp(class_entries(i).parameterCodeName, name)
                    found_index = i;
                    break;
                end
            end
            
            if found_index > 0
                class_entries(found_index) = new_entry;
            else
                class_entries(end+1) = new_entry;
            end
            all_params.(class_field) = class_entries;
            
            json_text_out = jsonencode(all_params, 'PrettyPrint', true);
            fid = fopen(json_path, 'w');
            if fid == -1, error('Could not open %s for writing.', json_path); end
            fprintf(fid, '%s', json_text_out);
            fclose(fid);
        end
        function deleteParameterCode(calculator_classname, name)
            % DELETEPARAMETERCODE - Delete a parameter instance from the central JSON file
            json_path = ndi.calculator.get_user_parameters_path();
            if ~isfile(json_path), return; end
            
            json_text = fileread(json_path);
            if isempty(strtrim(json_text)), return; end
            all_params = jsondecode(json_text);

            class_field = matlab.lang.makeValidName(calculator_classname);

            if isfield(all_params, class_field)
                class_entries = all_params.(class_field);
                % BUG FIX: Handle case where jsondecode creates an empty double []
                if isempty(class_entries) && ~isstruct(class_entries), return; end
                % Handle backward compatibility
                if iscell(class_entries), class_entries = [class_entries{:}]; end
                
                indices_to_keep = [];
                for i=1:numel(class_entries)
                    if ~strcmp(class_entries(i).parameterCodeName, name)
                        indices_to_keep(end+1) = i;
                    end
                end
                all_params.(class_field) = class_entries(indices_to_keep);
            end

            json_text_out = jsonencode(all_params, 'PrettyPrint', true);
            fid = fopen(json_path, 'w');
            if fid == -1, error('Could not open %s for writing.', json_path); end
            fprintf(fid, '%s', json_text_out);
            fclose(fid);
        end
    end % Static methods
end % calculator class