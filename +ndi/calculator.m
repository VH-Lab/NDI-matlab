classdef calculator < ndi.app & ndi.app.appdoc & ndi.mock.ctest
        
	properties (SetAccess=protected,GetAccess=public)
		fast_start = 'ndi.calculator.graphical_edit_calculator(''command'',''new'',''type'',''ndi.calc.vis.contrast'',''name'',''mycalc'')';
	end; % properties

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
				if nargin>0,
					session = varargin{1};
				end;
				ndi_calculator_obj = ndi_calculator_obj@ndi.app(session);
				if nargin>1,
					document_type = varargin{2};
				else,
					document_type = '';
				end;
				if nargin>2,
					path_to_doc_type = varargin{3};
				else,
					path_to_doc_type = '';
				end;
				ndi_calculator_obj = ndi_calculator_obj@ndi.app.appdoc({document_type}, ...
					{path_to_doc_type},session);
				ndi_calculator_obj.name = class(ndi_calculator_obj);
		end; % calculator creator

		function docs = run(ndi_calculator_obj, docExistsAction, parameters)
			% RUN - run calculator on all possible inputs that match some parameters
			%
			% DOCS = RUN(NDI_CALCULATOR_OBJ, DOCEXISTSACTION, PARAMETERS)
			%
			%
			% DOCEXISTSACTION can be 'Error', 'NoAction', 'Replace', or 'ReplaceIfDifferent'
			% For calculators, 'ReplaceIfDifferent' is equivalent to 'NoAction' because 
			% the input parameters define the calculator.
			%
				% Step 1: set up input parameters; they can either be completely specified by
				% the caller, or defaults can be used

				docs = {};
				docs_tocat = {};

				if nargin<3,
					parameters = ndi_calculator_obj.default_search_for_input_parameters();
				end;

				% Step 2: identify all sets of possible input parameters that are compatible with
				% what was specified by 'parameters'

				all_parameters = ndi_calculator_obj.search_for_input_parameters(parameters);

				% Step 3: check if we've already done the calculator for these parameters; if we have,
				% take the appropriate action. If we need to, perform the calculator.

				ndi.globals();

				mylog = ndi_globals.log;
				mylog.msg('system',1,['Beginning calculator by class ' class(ndi_calculator_obj) '...']);

				for i=1:numel(all_parameters),
					mylog.msg('system',1,['Performing calculator ' int2str(i) ' of ' int2str(numel(all_parameters)) '.']);
					previous_calculators_here = ndi_calculator_obj.search_for_calculator_docs(all_parameters{i});
					do_calc = 0;
					if ~isempty(previous_calculators_here),
						switch(docExistsAction),
							case 'Error',
								error(['Doc for input parameters already exists; error was requested.']);
							case {'NoAction','ReplaceIfDifferent'},
								docs_tocat{i} = previous_calculators_here;
								continue; % skip to the next calculator
							case {'Replace'},
								ndi_calculator_obj.session.database_rm(previous_calculators_here);
								do_calc = 1;
						end;
					else,
						do_calc = 1;
					end;
					if do_calc,
						docs_out = ndi_calculator_obj.calculate(all_parameters{i});
						if ~iscell(docs_out),
							docs_out = {docs_out};
						end;
						docs_tocat{i} = docs_out;
					end;
				end;
				for i=1:numel(all_parameters),
					docs = cat(2,docs,docs_tocat{i});
				end;
				app_doc = ndi_calculator_obj.newdocument();
				for i=1:numel(docs),
					docs{i} = docs{i}.setproperties('app',app_doc.document_properties.app);
				end;
				if ~isempty(docs),
					ndi_calculator_obj.session.database_add(docs);
				end;
				mylog.msg('system',1,'Concluding calculator.');
		end; % run()

		function parameters = default_search_for_input_parameters(ndi_calculator_obj)
			% DEFAULT_SEARCH_FOR_INPUT_PARAMETERS - default parameters for searching for inputs
			% 
			% PARAMETERS = DEFAULT_SEARCH_FOR_INPUT_PARAMETERS(NDI_CALCULATOR_OBJ)
			%
			% Returns a list of the default search parameters for finding appropriate inputs
			% to the calculator.
			%
				parameters.input_parameters = [];
				parameters.depends_on = vlt.data.emptystruct('name','value');
		end; % default_search_for_input_parameters
			
		function parameters = search_for_input_parameters(ndi_calculator_obj, parameters_specification, varargin)
			% SEARCH_FOR_INPUT_PARAMETERS - search for valid inputs to the calculator
			%
			% PARAMETERS = SEARCH_FOR_INPUT_PARAMETERS(NDI_CALCULATOR_OBJ, PARAMETERS_SPECIFICATION)
			%
			% Identifies all possible sets of specific input PARAMETERS that can be
			% used as inputs to the calculator. PARAMETERS is a cell array of parameter
			% structures with fields 'input_parameters' and 'depends_on'.
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
				if isfield(parameters_specification,'depends_on'),
					fixed_depends_on = parameters_specification.depends_on;
				else,
					fixed_depends_on = vlt.data.emptystruct('name','value');
				end;
				% validate fixed depends_on values
				for i=1:numel(fixed_depends_on),
					q = ndi.query('base.id','exact_string',fixed_depends_on(i).value,'');
					l = ndi_calculator_obj.session.database_search(q);
					if numel(l)~=1,
						error(['Could not locate ndi document with id ' fixed_depends_on(i).value ' that corresponded to name ' fixed_depends_on(i).name '.']);
					end;
				end;

				if ~isfield(parameters_specification,'query'),
					parameters_specification.query = ndi_calculator_obj.default_parameters_query(parameters_specification);
				end;

				if numel(parameters_specification.query)==0,
					% we are done, everything is fixed
					parameters.input_parameters = fixed_input_parameters;
					parameters.depends_on = fixed_depends_on;
					parameters = {parameters}; % a single cell entry
					return;
				end;

				doclist = {};
				V = [];
				for i=1:numel(parameters_specification.query),
					doclist{i} = ndi_calculator_obj.session.database_search(parameters_specification.query(i).query);
					V(i) = numel(doclist{i});
				end;

				parameters = {};

				for n=1:prod(V),
					is_valid = 1;
					g = vlt.math.group_enumeration(V,n);
					extra_depends = vlt.data.emptystruct('name','value');
					for i=1:numel(parameters_specification.query),
						s = struct('name',parameters_specification.query(i).name,'value',doclist{i}{g(i)}.id());
						is_valid = is_valid & ndi_calculator_obj.is_valid_dependency_input(s.name,s.value);
						extra_depends(end+1) = s;
						if ~is_valid,
							break;
						end;
					end;
					if is_valid,
						parameters_here.input_parameters = fixed_input_parameters;
						parameters_here.depends_on = cat(1,fixed_depends_on(:),extra_depends(:));
						parameters{end+1} = parameters_here;
					end;
				end;
		end; % search_for_input_parameters()

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
			% fixed 'depends_on' entries (entires that have both a 'name' and a 'value').
			% If it finds any, it creates a query indicating that the 'depends_on' field
			% must match the specified name and value.
			%
				query = vlt.data.emptystruct('name','query');
                if isfield(parameters_specification.input_parameters,'depends_on')
				    for i=1:numel(parameters_specification.input_parameters.depends_on),
					    if ~isempty(parameters_specification.input_parameters.depends_on(i).value) & ...
						    ~isempty(parameters_specification.input_parameters.depends_on(i).name),
						    query_here = struct('name',parameters_specification.input_parameters.depends_on(i).name,...
							    'query',...
							    ndi.query('base.id','exact_string',parameters_specification.input_parameters.depends_on(i).value,''));
						    query(end+1) = query_here;
					    end;
				    end;
                end;
		end; % default_parameters_query()

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
				myemptydoc = ndi.document(ndi_calculator_obj.doc_document_types{1});
				property_list_name = myemptydoc.document_properties.document_class.property_list_name;
				%class_name = myemptydoc.document_properties.document_class.class_name
				[parent,class_name,ext] = fileparts(myemptydoc.document_properties.document_class.definition);
				
				% this is not a good way to do things; every database will not be able to implement it
				q_type = ndi.query('','isa',class_name,'');
				q = q_type;
				if isfield(parameters,'depends_on')
					for i=1:numel(parameters.depends_on),
						if ~isempty(parameters.depends_on(i).value),
							q = q & ndi.query('','depends_on',parameters.depends_on(i).name,parameters.depends_on(i).value);
						end;
					end;
				end;
				docs = ndi_calculator_obj.session.database_search(q);
				% now identify the subset that have the same input_parameters
				matches = [];
				for i=1:numel(docs),
					try,
						input_param = eval(['docs{i}.document_properties.' property_list_name '.input_parameters;']);
					catch,
						input_param = []
					end;
					if ndi_calculator_obj.are_input_parameters_equivalent(input_param,parameters.input_parameters),
						matches(end+1) = i;
					end;
				end;
				docs = docs(matches);
		end; % search_for_calculator_docs()

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
				if ~isempty(input_parameters1),
					input_parameters1 = vlt.data.columnize_struct(input_parameters1);
				end;
				if ~isempty(input_parameters2),
					input_parameters2 = vlt.data.columnize_struct(input_parameters2);
				end;
				b = eqlen(input_parameters1, input_parameters2);
		end;

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
			% can be overriden if additional criteria beyond an ndi.query are needed to
			% assess if a document is an appropriate input for the calculator.
			%
				b = 1; % base class behavior
		end; % is_valid_dependency_input()

		function doc = calculate(ndi_calculator_obj, parameters)
			% CALCULATE - perform calculator and generate an ndi document with the answer
			%
			% DOC = CALCULATE(NDI_CALCULATOR_OBJ, PARAMETERS)
			%
			% Perform the calculator and return an ndi.document with the answer.
			%
			% In the base class, this always returns empty.
				doc = {};
		end; % calculate()

		function h=plot(ndi_calculator_obj, doc_or_parameters, varargin)
			% PLOT - provide a diagnostic plot to show the results of the calculator, if appropriate
			%
			% H=PLOT(NDI_CALCULATOR_OBJ, DOC_OR_PARAMETERS, ...)
			%
			% Produce a diagnostic plot that can indicate to a reader whether or not
			% the calculator has been performed in a manner that makes sense with
			% its input data. Useful for debugging / validating a calculator.
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
				if params.newfigure,
					h.figure = figure;
				else,
					h.figure = gcf;
				end;
				h.axes = gca;
				if ~params.suppress_title,
					if isa(doc_or_parameters,'ndi.document'),
						id = doc_or_parameters.id();
						h.title = title([id],'interp','none');
					end;
				end;
				if params.holdstate,
					hold on;
				else,
					hold off;
				end;
		end; % plot()


		%%%% methods that override ndi.appdoc %%%%

		%function struct2doc - should call calculator
		%function doc2struct - should build the input parameters from the document
		%function defaultstruct_appdoc - should call default search for input parameters and return a structure

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
		end; % isequal_appdoc_struct()

		function text = doc_about(ndi_calculator_obj)
			% DOC_ABOUT - return the about information for an NDI calculator
			%
			% TEXT = DOC_ABOUT(NDI_CALCULATOR_OBJ)
			%
			% Returns the help information for the document type for an NDI
			% calculator object.
			%
				text = ndi.calculator.docfiletext(class(ndi_calculator_obj), 'output');
		end; %doc_about()
	
		function text = appdoc_description(ndi_calculator_obj)
			% APPDOC_DESCRIPTION - return documentation for the type of document that is created by this calculator.
			%
			% TEXT = APP_DOC_DESCRIPTION(NDI_CALCULATOR_OBJ)
			%
			% Returns the help information for the document type for an NDI
			% calculator object.
			%
				text = ndi_calculator_obj.doc_about();
		end; % appdoc_description()

	end; % methods
    
        
	methods (Static)

		function param = plot_parameters(varargin);
			% PLOT - provide a diagnostic plot to show the results of the calculator, if appropriate
			%
			% PLOT(NDI_CALCULATOR_OBJ, DOC_OR_PARAMETERS, ...)
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
		end;

		function graphical_edit_calculator(varargin)
			% GRAPHICAL_EDIT_CALCULATOR - create and control a GUI to graphically edit an NDI calculator instance
			%
			% GRAPHICAL_EDIT_CALCULATOR(...)
			%
			% Creates and controls a graphical user interface for creating an instance of
			% an ndi.calculator object.
			% 
			% Usage by the user:
			%
			%   GRAPHICAL_EDIT_CALCULATOR('command','NEW','type','ndi.calc.TYPE','filename',filename,'name',name)
			%      or
			%   GRAPHICAL_EDIT_CALCULATOR('command','EDIT','filename',filename)
			%
			%
				command = '';
				window_params.height = 600;
				window_params.width = 400;
				session = [];

				name = '';
				filename = '';
				type = '';
				fig = []; % figure to use

				vlt.data.assign(varargin{:});

				calc.name = name;
				calc.filename = filename;
				calc.type = type;
				if ~isempty(type),
					calc.parameter_code_default = ndi.calculator.parameter_default(calc.type); 
					calc.parameter_code = calc.parameter_code_default; 
					[calc.parameter_example_names,calc.parameter_example_code] = ndi.calculator.parameter_examples(calc.type);
				end;


				varlist_ud = {'calc','window_params','session'};
				edit = false;
                
				if strcmpi(command,'new'),
					% set up for new window
					for i=1:numel(varlist_ud),
						eval(['ud.' varlist_ud{i} '=' varlist_ud{i} ';']);
					end;
					if isempty(fig),
						fig = figure;
					end;
					command = 'NewWindow';
					% would check calc name and calc type and calc filename for validity here
				elseif strcmpi(command,'edit'),
					% set up for editing
					% read from file
					edit = true;
					ud = jsondecode(vlt.file.textfile2char(filename))
					if ~exist('ud.calc','var')
						ud.calc.type = ud.ndi_pipeline_element.calculator;
						ud.calc.parameter_code_default = ndi.calculator.parameter_default(ud.calc.type);
						ud.calc.parameter_code = ud.ndi_pipeline_element.parameter_code;
						ud.calc.parameter_code_old = ud.ndi_pipeline_element.parameter_code;
						ud.calc.name = ud.ndi_pipeline_element.name;
						ud.calc.filename = filename;
						[ud.calc.parameter_example_names,ud.calc.parameter_example_code] = ndi.calculator.parameter_examples(ud.calc.type);
						ud.session = session;
					end
					if ~exist('ud.window_params','var')
						ud.window_params.height = 600;
						ud.window_params.width = 400;
					end
					command = 'NewWindow';
					if isempty(fig),
						fig = figure;
					end;
				end;

				if isempty(fig),
					error(['Empty figure, do not know what to work on.']);
				end;

				disp(['Command is ' command '.']);
				switch (command),
					case 'NewWindow',
						set(fig,'tag','ndi.calculator.graphical_edit_calculator');
						set(fig,'userdata',ud); % set initial userdata variables
						
						% now build the window
						uid = vlt.ui.basicuitools_defs;

						callbackstr = [  'eval([get(gcbf,''Tag'') ''(''''command'''','''''' get(gcbo,''Tag'') '''''' ,''''fig'''',gcbf);'']);']; 

						% Step 1: Establish window geometry

						top = ud.window_params.height;
						right = ud.window_params.width;
						row = 25;
						title_height = 25;
						title_width = 200;
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
						button_center = [ linspace(edge+0.5*button_width,right-edge-0.5*button_width, 3) ];


						% Step 2 now build it
					
						set(fig,'position',[50 50 right top]);
						set(fig,'NumberTitle','off');
						set(fig,'Name',['Editing ' ud.calc.name ' of type ' ud.calc.type ]);

						session_title = ['Empty session'];
						if isa(ud.session,'ndi.session'),
							session_title = session.reference;
						end;

						x = edge;
						y = top-row;
						uicontrol(uid.txt,'position',[x y title_width title_height],'string','Session:','tag','sessionTxt');
						uicontrol(uid.txt,'position',[x+title_width+edge y title_width menu_height],'string',session_title,'tag','sessionTitleTxt');

						% Documentation portion of window
						y = top - row;
						x = edge;
						y = y-row;
						uicontrol(uid.txt,'position',[x y title_width title_height],'string','Documentation','tag','DocTitleTxt');
						uicontrol(uid.popup,'position',[x+title_width+edge y menu_width menu_height],...
							'string',{'General','Searching for inputs','Output document'},'tag','DocPopup','callback',callbackstr,...
							'value',1);
						y = y - doc_height;
						uicontrol(uid.edit,'position',[x y doc_width doc_height],...
							'string','Please select one ducumentation type.',...
							'tag','DocTxt','min',0,'max',2,'enable','inactive');
						set(findobj(fig,'tag','DocTxt'),'units','normalized');
						y = y - row;

						uicontrol(uid.txt,'position',[x y title_width title_height],'string','Parameter code:','tag','ParameterCodeTitleTxt');
						uicontrol(uid.popup,'position',[x+title_width+edge y menu_width menu_height],...
							'string',{'User parameter code', '---', 'default', '---',ud.calc.parameter_example_names{:}},...
							'tag','ParameterCodePopup', 'callback',callbackstr,'userdata',1);
						y = y - parameter_code_height;
						uicontrol(uid.edit,'position',[x y parameter_code_width parameter_code_height],...
							'string',ud.calc.parameter_code,'tag','ParameterCodeTxt','min',0,'max',2); 
						set(findobj(fig,'tag','ParameterCodeTxt'),'units','normalized');
						y = y - row;
						y = y - row;

						uicontrol(uid.popup,'position',[x y commands_popup_width commands_popup_height],...
							'string',{'Commands:','---','Try searching for inputs','Show existing outputs',...
							'Plot existing outputs','Run but don''t replace existing docs','Run and replace existing docs'},...
							'tag','CommandPopup','callback',callbackstr);
						
						y = y - row;
						y = y - row;
						uicontrol(uid.button,'position',[button_center(1)-0.5*button_width y button_width button_height],...
							'string','Load','tag','LoadBt','callback',callbackstr);
						uicontrol(uid.button,'position',[button_center(2)-0.5*button_width y button_width button_height],...
							'string','Save','tag','SaveBt','callback',callbackstr);
						uicontrol(uid.button,'position',[button_center(3)-0.5*button_width y button_width button_height],...
							'string','Cancel','tag','CancelBt','callback',callbackstr);
						if edit
							if isfield(ud,'paramstrs') && isfield(ud,'paramval') && isfield(ud,'paramtext')
								% load param
								paramPopupObj = findobj(fig,'tag','ParameterCodePopup');
								set(paramPopupObj,'Value',ud.paramval);
								set(findobj(fig,'tag','ParameterCodeTxt'),'String',ud.paramtext);
							end
							if isfield(ud,'docstrs') && isfield(ud,'docval') && isfield(ud,'doctext')
								% load doc
								docPopupObj = findobj(fig,'tag','DocPopup');
								set(docPopupObj,'Value',ud.docval);
								set(findobj(fig,'tag','DocTxt'),'String',ud.doctext);
							end
						end
						ndi.calculator.graphical_edit_calculator('command','DocPopup','fig',fig);
					case 'UpdateWindow',
					case 'DocPopup',
						% Step 1: search for the objects you need to work with
						docPopupObj = findobj(fig,'tag','DocPopup');
						ud = get(fig,'userdata')
						val = get(docPopupObj, 'value');
						str = get(docPopupObj, 'string');
						%disp(val);
						%disp(str);
						docTextObj = findobj(fig,'tag','DocTxt');
						% Step 2, take action
						switch val,
							case 1, % General documentation
								disp(['Popup is ' str{val} '.']);
								type = 'general';
								%set(docTextObj,'string','Some General Document');
							case 2, % searching for inputs
								disp(['Popup is ' str{val} '.']);
								type = 'searching for inputs';
								%set(docTextObj,'string','Some Input Document');
							case 3, % output documentation
								disp(['Popup is ' str{val} '.']);
								type = 'output';
								%set(docTextObj,'string','Some Output Document');
							otherwise,
								disp(['Popup ' val ' is out of bound.']);
						end;
		
						mytext = ndi.calculator.docfiletext(ud.ndi_pipeline_element.calculator,type);
						set(docTextObj,'string',mytext);
					case 'ParameterCodePopup',
						ud = get(fig,'userdata');
						% Step 1: search for the objects you need to work with
						paramPopupObj = findobj(fig,'tag','ParameterCodePopup');
						val = get(paramPopupObj, 'value');
						str = get(paramPopupObj, 'string');
						paramTextObj = findobj(fig,'tag','ParameterCodeTxt');
						lastval = get(paramPopupObj,'userdata');
						if lastval == 1 & val ~=1, % if we are switching away from user code, save it
							ud.calc.parameter_code = get(paramTextObj,'string');
							set(fig,'userdata',ud);
						end;
						% Step 2, take action
						if val==1, % this is the users's code
							set(paramTextObj,'string',ud.calc.parameter_code);
						elseif val==3,
							% view the default code
							set(paramTextObj,'string',ud.calc.parameter_code_default);
						elseif val>=5, % this is an example
							set(paramTextObj,'string',ud.calc.parameter_example_code{val-4});
						end;
						if ~any(val==[2 4]), % if it's not a spacer
							set(paramPopupObj,'userdata',val); % store the last menu setting in userdata
						end;
					case 'CommandPopup',
						% Step 1: search for the objects you need to work with
						ud = get(fig,'userdata');
						cmdPopupObj = findobj(fig,'tag','CommandPopup');
						val = get(cmdPopupObj, 'value');
						str = get(cmdPopupObj, 'string');
						docTextObj = findobj(fig,'tag','CommandTxt');
						% Step 2, take action
						switch val,
							case 3, % Try searching for inputs
								disp(['Popup is ' str{val} '.']);
								set(docTextObj,'string','Try searching for inputs');
								if isempty(ud.session),
									error('No session is linked to the calculator editor.');
								end;
								assignin('base','pipeline_session',ud.session);
								disp(['About to evaluate parameter code on the main workspace.']);
								param_code = ud.calc.parameter_code;
								evalin('base',param_code);
								disp(['About to search for inputs. Variable IP will have input combinations that were found.']);
								search_code = ['thecalc=' ud.calc.type '(pipeline_session); if ~exist(''parameters'',''var''), parameters=thecalc.default_search_for_input_parameters(); end; IP=thecalc.search_for_input_parameters(parameters);'];
								evalin('base',search_code);
								disp(['Search done, variable IP now has input combinations found.']);
							case 4, % Show existing outputs
								disp(['Popup is ' str{val} '.']);
								set(docTextObj,'string','Show existing outputs');
								if isempty(ud.session),
									error('No session is linked to the calculator editor.');
								end;
								assignin('base','pipeline_session',ud.session);
								evalin('base','clear parameters;');
								disp(['About to evaluate parameter code on the main workspace.']);
								param_code = ud.calc.parameter_code;
								evalin('base',param_code);
								disp(['About to search for existing documents calculated with those input parameters.']);
								disp(['Variable ED will have input combinations that were found.']);
								search_code = ['thecalc=' ud.calc.type '(pipeline_session); ED=thecalc.search_for_calculator_docs(parameters);'];
								evalin('base',search_code);
								disp(['Search done, variable ED now has existing calculation documents found.']);
								ED = evalin('base','ED');
								if ~isempty(ED),
									if isfield(ud,'docViewer'),
										figure(ud.docViewer.fig); % bring to front
									else, % we need to build it
										ud.docViewer = ndi.gui.docViewer();
										set(fig,'userdata',ud);
									end;
									ud.docViewer.addDoc(ED);
								end;
							case 5, % Plot existing outputs
								disp(['Popup is ' str{val} '.']);
								set(docTextObj,'string','Plot existing outputs');

								if isempty(ud.session),
									error('No session is linked to the calculator editor.');
								end;
								assignin('base','pipeline_session',ud.session);
								disp(['About to evaluate parameter code on the main workspace.']);
								param_code = ud.calc.parameter_code;
								evalin('base',param_code);
								disp(['About to search for existing documents calculated with those input parameters.']);
								disp(['Variable ED will have input combinations that were found.']);
								search_code = ['thecalc=' ud.calc.type '(pipeline_session); ED=thecalc.search_for_calculator_docs(parameters);'];
								evalin('base',search_code);
								disp(['Search done, variable ED now has existing calculation documents found.']);
								disp(['Now will plot all of these ' int2str(evalin('base','numel(ED)')) ' documents.']);
								evalin('base',['for i=1:numel(ED), figure; thecalc.plot(ED{i}); end;']);
								disp(['Finished plotting.']);
							case 6, % Run but don''t replace existing docs
								disp(['Popup is ' str{val} '.']);
								set(docTextObj,'string','Run but don''t replace existing docs');

								if isempty(ud.session),
									error('No session is linked to the calculator editor.');
								end;
								assignin('base','pipeline_session',ud.session);
								disp(['About to evaluate parameter code on the main workspace.']);
								param_code = ud.calc.parameter_code;
								evalin('base',param_code);
								disp(['About to run without replacement of existing docs.']);
								run_code = ['thecalc=' ud.calc.type '(pipeline_session); RUNDOCS=thecalc.run(''NoAction'',parameters);'];
								evalin('base',run_code);
								disp(['Run done, variable RUNDOCS now has calculation documents created.']);

							case 7, % Run and replace existing docs
								disp(['Popup is ' str{val} '.']);
								set(docTextObj,'string','Run and replace existing docs');

								if isempty(ud.session),
									error('No session is linked to the calculator editor.');
								end;
								assignin('base','pipeline_session',ud.session);
								disp(['About to evaluate parameter code on the main workspace.']);
								param_code = ud.calc.parameter_code;
								evalin('base',param_code);
								disp(['About to run with replacement of any existing docs.']);
								run_code = ['thecalc=' ud.calc.type '(pipeline_session); RUNDOCS=thecalc.run(''Replace'', parameters);'];
								evalin('base',run_code);
								disp(['Run done, variable RUNDOCS now has calculation documents created.']);

							otherwise,
								disp(['Popup ' val ' is out of bounds.']);
						end;
					case 'LoadBt',
						[file,path] = uigetfile('*.json');
						if isequal(file,0)
							disp('User selected Cancel');
						else
							disp(['User selected ', fullfile(path,file)]);
						end

						file = jsondecode(vlt.file.textfile2char([path filesep file]));
						ud = file;
						set(fig,'userdata',ud);
						                        
						docPopupObj = findobj(fig,'tag','DocPopup');
						str = get(docPopupObj, 'string');
						val = 1;
						for i = 1:size(str,1)
							if strcmp(file.docstr, string(str{i}))
								val = i;
								break;
							end
						end
						set(docPopupObj, 'Value', val);
						docTextObj = findobj(fig,'tag','DocTxt');
						set(docTextObj,'string',file.doctext);
						
						paramPopupObj = findobj(fig,'tag','ParameterCodePopup');
						str = get(paramPopupObj, 'string');
						val = 1;
						for i = 1:size(str,1)
							if strcmp(file.paramstr, string(str{i}))
								val = i;
								break;
							end
						end
						set(paramPopupObj, 'Value', val);
						paramTextObj = findobj(fig,'tag','ParameterCodeTxt');
						set(paramTextObj,'string',file.paramtext);
					case 'SaveBt',
						fig = gcf;
						% not new window, get userdata
						ud = get(fig,'userdata');
						% what will we save?
						% let's save the parameter code
						% shall we save "preferences" for running? Let's not right now
						% shall we save the view that the user had? let's not right now
						
						% save param
						%paramPopupObj = findobj(fig,'tag','ParameterCodePopup');
						%paramval = get(paramPopupObj, 'value');
						%paramstrs = get(paramPopupObj, 'string');
						%paramstr = paramstrs{paramval};
						%paramtext = get(findobj(fig,'tag','ParameterCodeTxt'),'String');

						% check filename
						filepath = '';
						filename = 'untitled';
						ext = '.json';
						if exist('ud','var') && isfield(ud,'calc') && isfield(ud.calc, 'filename'),
							[filepath,filename,ext] = fileparts(ud.calc.filename);
							filepath = strcat(filepath, filesep);
						end;

						% save doc
						docPopupObj = findobj(fig,'tag','DocPopup');
									docval = get(docPopupObj, 'value');
						docstrs = get(docPopupObj, 'string');
						docstr = docstrs{docval};
						doctext = get(findobj(fig,'tag','DocTxt'),'String');
						
						% save param
						paramPopupObj = findobj(fig,'tag','ParameterCodePopup');
									paramval = get(paramPopupObj, 'value');
						paramstrs = get(paramPopupObj, 'string');
						paramstr = paramstrs{docval};
						paramtext = get(findobj(fig,'tag','ParameterCodeTxt'),'String');
						
						if docval == 1 
							msgbox('Please select documentation.')
						elseif paramval == 1
							msgbox('Please select parameter code')
						else
							defaultfilename = {[filename]};
							prompt = {'File name:'};
							dlgtitle = 'Save As';
							extension_list = {[ext]};
							dir = filepath;
							[success,filename,replaces] = ndi.util.choosefileordir(dir, prompt, defaultfilename, dlgtitle, extension_list);
							json_filename = char(strcat(filepath, filesep, filename,'.json'));
							if success
								if replaces
									origin_file = fileread(json_filename);
									saveTo = jsondecode(origin_file);
								end
								saveTo.docval = docval;
								saveTo.docstr = docstr;
								saveTo.doctext = doctext;
								saveTo.docstrs = docstrs;
								saveTo.paramval = paramval;
								saveTo.paramstr = paramstr;
								saveTo.paramtext = paramtext;
								saveTo.paramstrs = paramstrs;
								fid = fopen(json_filename,'w');
								fprintf(fid,jsonencode(saveTo));
								fclose(fid);
							end
						end
					case 'CancelBt',
						close(fig);
					otherwise,
						disp(['Unknown command ' command '.']);

				end; % switch(command)
		end; % graphical_edit_calculation ()

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

				switch (lower(doc_type)),
					case 'general',
						doctype = 'general';
					case 'searching for inputs',
						doctype = 'searching';
					case 'output',
						doctype = 'output';
					otherwise,
						error(['Unknown document type ' doc_type '.']);
				end;
					
				w = which(calculator_type);
				if isempty(w),
					error(['No known calculator on the path called ' calculator_type '.']);
				end;
				[parentdir, appname] = fileparts(w);
				filename = [parentdir filesep 'docs' filesep appname '.docs.' doctype '.txt'];

				paramfile_present = isfile(filename);
				if paramfile_present,
					text = vlt.file.text2cellstr(filename);
				else,
					error(['No such file ' filename '.']);
				end;
		end; 

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
				if isempty(w),
					error(['No known calculator on the path called ' calculator_type '.']);
				end;
				[parentdir, appname] = fileparts(w);

				dirname = [parentdir filesep 'docs' filesep appname '.docs.parameter.examples']

				d = dir([dirname filesep '*.txt'])

				contents = {};
				names = {};

				for i=1:numel(d),
					names{end+1} = d(i).name;
					contents{end+1} = vlt.file.textfile2char([dirname filesep d(i).name]);
				end;

		end;

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
				if isempty(w),
					error(['No known calculator on the path called ' calculator_type '.']);
				end;
				[parentdir, appname] = fileparts(w);

				filename = [parentdir filesep 'docs' filesep appname '.docs.parameter.default.txt'];
				if isfile(filename),
					contents = vlt.file.textfile2char(filename);
				else,
					warning(['No default parameter code file ' filename ' found.']);
					contents = '';
				end;
		end;
               
	end; % Static methods
end

    
