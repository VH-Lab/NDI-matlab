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
                    'CommandPopup', 'LoadButton', 'SaveButton', 'CancelButton', ...
                    'ObjectTypePopup', 'ObjectVariablePopup'})} = 'New'
        
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
                
                if ~isempty(options.calculatorClassname)
                    calculatorInstance.parameter_code_default = ndi.calculator.parameter_default(calculatorInstance.calculatorClassname);
                    % Use the new user template for the initial user code
                    calculatorInstance.parameter_code = ndi.calculator.user_parameter_template(calculatorInstance.calculatorClassname);
                    [calculatorInstance.parameter_example_names, calculatorInstance.parameter_example_code] = ndi.calculator.parameter_examples(calculatorInstance.calculatorClassname);
                else
                    % Provide empty defaults if no classname is given
                    calculatorInstance.parameter_code_default = '';
                    calculatorInstance.parameter_code = '';
                    calculatorInstance.parameter_example_names = {};
                    calculatorInstance.parameter_example_code = {};
                end
                
                ud.calculatorInstance = calculatorInstance;
                ud.window_params = options.window_params;
                ud.linked_object = options.session; % Use linked_object now
                if isempty(fig)
                    fig = figure;
                end
                command = 'NewWindow';
            elseif strcmp(command,'Edit')
                % set up for editing from a file
                ud.calculatorInstance = jsondecode(vlt.file.textfile2char(options.filename));
                ud.calculatorInstance.JSONFilename = options.filename; % ensure this is set
                
                ud.calculatorInstance.parameter_code_default = ndi.calculator.parameter_default(ud.calculatorInstance.calculatorClassname);
                [ud.calculatorInstance.parameter_example_names, ud.calculatorInstance.parameter_example_code] = ndi.calculator.parameter_examples(ud.calculatorInstance.calculatorClassname);
                ud.linked_object = options.session; % Use linked_object now
                
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
                    
                    % Step 1: Establish window geometry in pixels
                    top = ud.window_params.height;
                    right = ud.window_params.width;
                    row = 25;
                    title_height = 25;
                    title_width = 120; % Adjusted width for new layout
                    edge = 5;
                    doc_width = right - 2*edge;
                    doc_height = 200;
                    menu_width = right - 2*edge - title_width;
                    menu_height = title_height;
                    parameter_code_width = doc_width;
                    parameter_code_height = 150;
                    commands_popup_width = doc_width;
                    commands_popup_height = row;
                    button_width = 100;
                    button_height = row;
                    button_centers_px = [ linspace(edge+0.5*button_width,right-edge-0.5*button_width, 3) ];
                    
                    % Step 2 now build it
                    set(fig,'position',[50 50 right top],...
                        'NumberTitle','off',...
                        'Name',['Editing ' ud.calculatorInstance.instanceName ' of type ' ud.calculatorInstance.calculatorClassname ],...
                        'MenuBar','none',...
                        'ToolBar','none');
                    
                    % All UI positions are normalized so they resize with the window
                    x = edge;
                    y = top-row;

                    % New Row 1: Object Type Selection
                    uicontrol(uid.txt,'Units','normalized','position',[x/right y/top title_width/right title_height/top],'string','Link object type:');
                    uicontrol(uid.popup,'Units','normalized','position',[(x+title_width+edge)/right y/top menu_width/right menu_height/top],...
                        'string',{'ndi.session', 'ndi.dataset', 'Workspace variable'},'tag','ObjectTypePopup','callback',callbackstr);

                    % New Row 2: Object Variable Selection
                    y = y - row;
                    uicontrol(uid.txt,'Units','normalized','position',[x/right y/top title_width/right title_height/top],'string','NDI Dataset:');
                    uicontrol(uid.popup,'Units','normalized','position',[(x+title_width+edge)/right y/top menu_width/right menu_height/top],...
                        'string',{'None'},'tag','ObjectVariablePopup','callback',callbackstr);
                    
                    y = y-row; % adjust y for the new rows
                    
                    % Documentation portion of window
                    y = y-row;
                    uicontrol(uid.txt,'Units','normalized','position',[x/right y/top title_width/right title_height/top],'string','Documentation','tag','DocTitleTxt');
                    uicontrol(uid.popup,'Units','normalized','position',[(x+title_width+edge)/right y/top menu_width/right menu_height/top],...
                        'string',{'General','Calculator Input Options','Output document'},'tag','DocPopup','callback',callbackstr,...
                        'value',1);
                    y = y - doc_height;
                    uicontrol(uid.edit,'Units','normalized','position',[x/right y/top doc_width/right doc_height/top],...
                        'string','Please select one documentation type.',...
                        'tag','DocTxt','min',0,'max',2,'enable','inactive');
                    
                    y = y - row;
                    uicontrol(uid.txt,'Units','normalized','position',[x/right y/top title_width/right title_height/top],'string','Parameter code:','tag','ParameterCodeTitleTxt');
                    uicontrol(uid.popup,'Units','normalized','position',[(x+title_width+edge)/right y/top menu_width/right menu_height/top],...
                        'string',{'User defined parameters', 'User defined parameter template', '---', 'default', '---',ud.calculatorInstance.parameter_example_names{:}},...
                        'tag','ParameterCodePopup', 'callback',callbackstr,'userdata',1);
                    y = y - parameter_code_height;
                    uicontrol(uid.edit,'Units','normalized','position',[x/right y/top parameter_code_width/right parameter_code_height/top],...
                        'string',ud.calculatorInstance.parameter_code,'tag','ParameterCodeTxt','min',0,'max',2);
                    
                    y = y - 2*row;
                    uicontrol(uid.popup,'Units','normalized','position',[x/right y/top commands_popup_width/right commands_popup_height/top],...
                        'string',{'Commands:','---','Try searching for inputs','Show existing outputs',...
                        'Plot existing outputs','Run but don''t replace existing docs','Run and replace existing docs'},...
                        'tag','CommandPopup','callback',callbackstr);
                    
                    y = y - 2*row;
                    uicontrol(uid.button,'Units','normalized','position',[(button_centers_px(1)-0.5*button_width)/right y/top button_width/right button_height/top],...
                        'string','Load','tag','LoadButton','callback',callbackstr);
                    uicontrol(uid.button,'Units','normalized','position',[(button_centers_px(2)-0.5*button_width)/right y/top button_width/right button_height/top],...
                        'string','Save','tag','SaveButton','callback',callbackstr);
                    uicontrol(uid.button,'Units','normalized','position',[(button_centers_px(3)-0.5*button_width)/right y/top button_width/right button_height/top],...
                        'string','Cancel','tag','CancelButton','callback',callbackstr);
                    
                    ndi.calculator.graphical_edit_calculator('command','ObjectTypePopup','fig',fig); % initial population
                    ndi.calculator.graphical_edit_calculator('command','DocPopup','fig',fig);
                case 'ObjectTypePopup'
                    popup_type_obj = findobj(fig,'tag','ObjectTypePopup');
                    type_val = get(popup_type_obj,'value');
                    type_str_list = get(popup_type_obj,'string');
                    selected_type = type_str_list{type_val};

                    % Scan workspace for variables of the selected type
                    vars = evalin('base', 'whos');
                    var_names = {};
                    for i = 1:length(vars)
                        is_match = strcmp(vars(i).class, selected_type);
                        if strcmp(selected_type, 'Workspace variable') && ~strcmp(vars(i).class,'matlab.ui.Figure')
                            is_match = true;
                        end
                        if is_match
                            var_names{end+1} = vars(i).name;
                        end
                    end
                    popup_strings = {'None', var_names{:}};
                    popup_userdata = {[], var_names{:}}; % Store var names, [] for None

                    % Update the variable popup
                    popup_var_obj = findobj(fig, 'tag','ObjectVariablePopup');
                    set(popup_var_obj, 'string', popup_strings, 'userdata', popup_userdata);

                    % Set the value based on the currently linked object
                    initial_value = 1; % Default to 'None'
                    if ~isempty(ud.linked_object) && (strcmp(class(ud.linked_object), selected_type) || strcmp(selected_type,'Workspace variable'))
                        for i=1:numel(var_names)
                            workspace_obj = evalin('base', var_names{i});
                            if isequal(ud.linked_object, workspace_obj)
                                initial_value = i + 1; % +1 for 'None'
                                break;
                            end
                        end
                    end
                    set(popup_var_obj, 'value', initial_value);
                    
                    % If selection is now 'None', clear the linked object from userdata
                    if initial_value == 1 && ~isempty(ud.linked_object)
                        ud.linked_object = [];
                        set(fig,'userdata',ud);
                    end

                case 'ObjectVariablePopup'
                    % Get handles and values
                    popup_obj = findobj(fig, 'tag', 'ObjectVariablePopup');
                    val = get(popup_obj, 'value');
                    var_names_list = get(popup_obj, 'userdata');
                    
                    selected_var_name = var_names_list{val};
                    
                    % Update the linked object in userdata
                    if isempty(selected_var_name)
                        ud.linked_object = [];
                        disp('Calculator object link cleared.');
                    else
                        ud.linked_object = evalin('base', selected_var_name);
                        disp(['Calculator linked to workspace variable ''' selected_var_name '''.']);
                    end
                    set(fig, 'userdata', ud);

                case 'DocPopup'
                    % Step 1: search for the objects you need to work with
                    docPopupObj = findobj(fig,'tag','DocPopup');
                    val = get(docPopupObj, 'value');
                    docTextObj = findobj(fig,'tag','DocTxt');
                    % Step 2, take action
                    switch val
                        case 1, doc_type = 'general';
                        case 2, doc_type = 'searching for inputs';
                        case 3, doc_type = 'output';
                        otherwise, error(['Unknown doc popup value.']);
                    end
                    mytext = ndi.calculator.docfiletext(ud.calculatorInstance.calculatorClassname, doc_type);
                    set(docTextObj,'string',mytext);
                case 'ParameterCodePopup'
                    % Step 1: search for the objects you need to work with
                    paramPopupObj = findobj(fig,'tag','ParameterCodePopup');
                    val = get(paramPopupObj, 'value');
                    paramTextObj = findobj(fig,'tag','ParameterCodeTxt');
                    lastval = get(paramPopupObj,'userdata');
                    if lastval == 1 && val ~=1 % if we are switching away from the user parameters, save them to userdata
                        ud.calculatorInstance.parameter_code = get(paramTextObj,'string');
                        set(fig,'userdata',ud);
                    end
                    % Step 2, take action based on new menu
                    switch val
                        case 1 % User defined parameters
                            set(paramTextObj,'string',ud.calculatorInstance.parameter_code);
                        case 2 % User defined parameter template
                            template = ndi.calculator.user_parameter_template(ud.calculatorInstance.calculatorClassname);
                            set(paramTextObj, 'string', template);
                        case 4 % default
                            set(paramTextObj,'string',ud.calculatorInstance.parameter_code_default);
                        case {6,7,8,9,10,11,12,13,14,15} % examples (assuming not more than 10)
                            example_index = val - 5;
                            if example_index <= numel(ud.calculatorInstance.parameter_example_code)
                                set(paramTextObj,'string',ud.calculatorInstance.parameter_example_code{example_index});
                            end
                    end
                    if ~any(val==[3 5]) % if it's not a spacer
                        set(paramPopupObj,'userdata',val); % store the last menu setting in userdata
                    end
                case 'CommandPopup'
                    cmdPopupObj = findobj(fig,'tag','CommandPopup');
                    val = get(cmdPopupObj, 'value');
                    
                    if isempty(ud.linked_object) || ~isa(ud.linked_object,'ndi.session')
                        errordlg('A valid ndi.session object must be linked to run these commands.', 'Session Error');
                        return; % Stop execution
                    end
                    assignin('base','pipeline_session',ud.linked_object);
                    param_code = ud.calculatorInstance.parameter_code;
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
                case 'LoadButton'
                    [file,path] = uigetfile('*.json','Load Calculator Instance from file');
                    if ~isequal(file,0)
                        loaded_instance = jsondecode(vlt.file.textfile2char(fullfile(path,file)));
                        
                        % Update only the relevant fields, keep the original filename
                        ud.calculatorInstance.instanceName = loaded_instance.instanceName;
                        ud.calculatorInstance.calculatorClassname = loaded_instance.calculatorClassname;
                        ud.calculatorInstance.parameter_code = loaded_instance.parameter_code;
                        ud.calculatorInstance.default_options = loaded_instance.default_options;
                        
                        % Refresh the GUI with the new data
                        set(fig,'Name',['Editing ' ud.calculatorInstance.instanceName ' of type ' ud.calculatorInstance.calculatorClassname ]);
                        paramTextObj = findobj(fig,'tag','ParameterCodeTxt');
                        set(paramTextObj,'String',ud.calculatorInstance.parameter_code);
                        
                        set(fig,'userdata',ud);
                        disp(['Loaded settings from ', fullfile(path,file)]);
                    else
                        disp('User selected Cancel');
                    end
                case 'SaveButton'
                    json_filename = ud.calculatorInstance.JSONFilename;
                    if isempty(json_filename)
                        msgbox('Cannot save, the JSON filename is not known. Use "Save As" from the pipeline editor.');
                        return;
                    end
                    % Update the parameter code from the text box
                    paramTextObj = findobj(fig,'tag','ParameterCodeTxt');
                    ud.calculatorInstance.parameter_code = get(paramTextObj,'String');
                    
                    % Remove temporary fields before saving
                    instance_to_save = rmfield(ud.calculatorInstance, {'JSONFilename','parameter_code_default','parameter_example_names','parameter_example_code'});
                    
                    fid = fopen(json_filename,'w');
                    fprintf(fid,jsonencode(instance_to_save));
                    fclose(fid);
                    
                    msgbox(['Calculator instance saved to ' json_filename],'Save complete');
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
        function [names, contents] = parameter_examples(calculator_type)
            % ndi.calculator.parameter_examples - return the parameter code examples for a given calculator_type
            %
            % [NAMES, CONTENTS] = ndi.calculator.parameter_examples(CALCULATOR_TYPE)
            %
            % Return the example NAMES and parameter example code CONTENTS for a given CALCULATOR_TYPE.
            %
            % NAMES is a cell array of strings with the code example names. CONTENTS is a cell array of strings with
            % the contents of the code examples.
            %
            % Example:
            %   [names,contents] = ndi.calculator.parameter_examples('ndi.calc.stimulus.tuningcurve');
            %
            w = which(calculator_type);
            if isempty(w)
                error(['No known calculator on the path called ' calculator_type '.']);
            end
            [parentdir, appname] = fileparts(w);
            dirname = [parentdir filesep 'docs' filesep appname '.docs.parameter.examples'];
            d = dir([dirname filesep '*.txt']);
            contents = {};
            names = {};
            for i=1:numel(d)
                names{end+1} = d(i).name;
                contents{end+1} = vlt.file.textfile2char([dirname filesep d(i).name]);
            end
        end
        function [contents] = parameter_default(calculator_type)
            % ndi.calculator.parameter_default - return the default parameter code for a given calculator_type
            %
            % [CONTENTS] = ndi.calculator.parameter_examples(CALCULATOR_TYPE)
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
                contents = vlt.file.textfile2char(filename);
            else
                warning(['No default parameter code file ' filename ' found. Generating a generic default.']);
                contents = sprintf([...
                    '%% Default parameters for %s\r\n' ...
                    '%% This code is auto-generated because a specific default file was not found.\r\n\r\n' ...
                    'thecalc = %s();\r\n' ...
                    'parameters = thecalc.default_search_for_input_parameters();\r\n'], ...
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
                    'thecalc = %s();\r\n' ...
                    'parameters = thecalc.default_search_for_input_parameters();\r\n\r\n' ...
                    '%% You can add more specific constraints below.\r\n' ...
                    '%% For example, to restrict the search to a specific recording element:\r\n' ...
                    '%%\r\n' ...
                    '%% element_id = ''some_element_id_string''; %% replace with a real ID\r\n' ...
                    '%% parameters.query(end+1) = ndi.query('',''depends_on'',''element_id'',element_id);\r\n'],...
                    calculator_type, calculator_type);
        end
    end % Static methods
end % calculator class