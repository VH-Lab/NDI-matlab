classdef calculator < ndi.app & ndi.app.appdoc
        
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
				ndi_calculator_obj = ndi_calculator_obj@ndi.app(session,'calculator');
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

				parfor i=1:numel(all_parameters),
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
					q = ndi.query('ndi_document.id','exact_string',fixed_depends_on(i).value,'');
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
			% In the base class, this returns an empty structure.
			%
				query = vlt.data.emptystruct('name','query');
		end; % default_parameters_query()

		function docs = search_for_calculator_docs(ndi_calculator_obj, parameters)  % can call find_appdoc, most of the code should be put in find_appdoc
			% SEARCH_FOR_CALCULATOR_DOCS - search for previous calculators
			%
			% [DOCS] = SEARCH_FOR_CALCULATOR(NDI_CALCULATOR_OBJ, PARAMETERS)
			%
			% Performs a search to find all previously-created calculator
			% documents that this mini-app creates. 
			%
			% PARAMETERS is a structure with the following fields
			% |------------------------|----------------------------------|
			% | Fieldname              | Description                      |
			% |-----------------------------------------------------------|
			% | input_parameters       | A structure of input parameters  |
			% |                        |  needed by the calculator.      |
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
				
				q_input = ndi.query([property_list_name '.input_parameters'],'partial_struct',parameters.input_parameters,'');
				q_type = ndi.query('','isa',class_name,'');
				q = q_input & q_type;
				if isfield(parameters,'depends_on')
					for i=1:numel(parameters.depends_on),
						q = q & ndi.query('','depends_on',parameters.depends_on(i).name,parameters.depends_on(i).value);
					end;
				end;
				docs = ndi_calculator_obj.session.database_search(q);
		end; % search_for_calculator_docs()

		function b = is_valid_dependency_input(ndi_calculator_obj, name, value)
			% IS_VALID_DEPENDENCY_INPUT - is a potential dependency input actually valid for this calculator?
			%
			% B = IS_VALID_DEPENDENCY_INPUT(NDI_CALCULATOR_OBJ, NAME, VALUE)
			%
			% Tests whether a potential input to a calculator is valid.
			% The potential dependency name is provided in NAME and its ndi_document id is
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

		function doc_about(ndi_calculator_obj)
			% ----------------------------------------------------------------------------------------------
			% NDI_CALCULATOR: DOCTYPE1 (in subclasses, change this to your document type)
			% ----------------------------------------------------------------------------------------------
			%
			%   ---------------------
			%   | DOCTYPE1 -- ABOUT |
			%   ---------------------
			%
			%   DOCTYPE documents store X. It DEPENDS ON documents Y and Z. (Edit in subclasses.)
			%
			%   Definition: app/myapp/doctype1 (Edit in subclasses.)
			%
				eval(['help ndi.calculator.doc_about']);
		end; %doc_about()
	
		function appdoc_description(ndi_calculator_obj)
			% ----------------------------------------------------------------------------------------------
			% DOCUMENT INFO:
			% ----------------------------------------------------------------------------------------------
			%
			%   ---------
			%   | ABOUT |
			%   ---------
			%
			%   To see the ABOUT information for the document that is created by this calculator,
			%   see 'help ndi.calculator/doc_about'
			%
			%   ------------
			%   | CREATION |
			%   ------------
			%
			%   DOC = CALCULATE(NDI_CALCULATOR_OBJ, PARAMETERS)
			%
			%   PARAMETERS should contain the following fields:
			%   Fieldname                 | Description
			%   -------------------------------------------------------------------------
			%   input_parameters          | field1 description
			%   depends_on                | field2 description
			%
			%   -----------
			%   | FINDING |
			%   -----------
			%
			%   [DOC] = SEARCH_FOR_CALCULATOR_DOCS(NDI_CALCULATOR_OBJ, PARAMETERS)
			%
			%   PARAMETERS should contain the following fields:
			%   Fieldname                 | Description
			%   -------------------------------------------------------------------------
			%   input_parameters          | field1 description
			%   depends_on                | field2 description
			%
				eval(['help ndi.calculator/appdoc_description']);
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

				name = '';
				filename = '';
				type = '';
				calc.parameter_code_default = {'% Enter parameter code here, or start from a template'};
				calc.parameter_code = calc.parameter_code_default; 

				fig = []; % figure to use

				vlt.data.assign(varargin{:});

				calc.name = name;
				calc.filename = filename;
				calc.type = type;

				varlist_ud = {'calc','window_params'};

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
						% would read from file here
					command = 'NewWindow';
					if isempty(fig),
						fig = figure;
					end;
					% would check calc name and calc type and calc filename for validity here
					ud = get(fig,'userdata');
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

						% Documentation portion of window
						x = edge; y = top-row;
						uicontrol(uid.txt,'position',[x y title_width title_height],'string','Documentation','tag','DocTitleTxt');
						uicontrol(uid.popup,'position',[x+title_width+edge y menu_width menu_height],...
							'string',{'---', 'General','Searching for inputs','Output document'},'tag','DocPopup','callback',callbackstr);
						y = y - doc_height;
						uicontrol(uid.edit,'position',[x y doc_width doc_height],...
							'string','Please select one ducumentation type.',...
							'tag','DocTxt','min',0,'max',2,'enable','inactive');
						y = y - row;

						uicontrol(uid.txt,'position',[x y title_width title_height],'string','Parameter code:','tag','ParameterCodeTitleTxt');
						uicontrol(uid.popup,'position',[x+title_width+edge y menu_width menu_height],...
							'string',{'---','Example 1','Example 2','Example 3'},'tag','ParameterCodePopup', 'callback',callbackstr);
						y = y - parameter_code_height;
						uicontrol(uid.edit,'position',[x y parameter_code_width parameter_code_height],...
							'string','Please select one parameter code.','tag','ParameterCodeTxt','min',0,'max',2,'enable','inactive');
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
					case 'UpdateWindow',
					case 'DocPopup',
						% Step 1: search for the objects you need to work with
						docPopupObj = findobj(fig,'tag','DocPopup');
						val = get(docPopupObj, 'value');
						str = get(docPopupObj, 'string');
						%disp(val);
						%disp(str);
						docTextObj = findobj(fig,'tag','DocTxt');
						% Step 2, take action
						switch val,
							case 2, % General documentation
								disp(['Popup is ' str{val} '.']);
								type = 'general';
								%set(docTextObj,'string','Some General Document');
							case 3, % searching for inputs
								disp(['Popup is ' str{val} '.']);
								type = 'input';
								%set(docTextObj,'string','Some Input Document');
							case 4, % output documentation
								disp(['Popup is ' str{val} '.']);
								type = 'output';
								%set(docTextObj,'string','Some Output Document');
							otherwise,
								disp(['Popup ' val ' is out of bound.']);
						end;
		
						p = which('ndi.calc.vis.speed_tuning');
						[parentdir, appname] = fileparts(p);
						docfile_present = isfile([parentdir filesep appname '.docs.' type '.txt']);
						if docfile_present,
							mytext = vlt.file.text2cellstr([parentdir filesep appname '.docs.' type '.txt']);
							set(docTextObj,'string',mytext);
						elseif val~=1,
							msgbox('No documentation found.');
						end;
					case 'ParameterCodePopup',
						% Step 1: search for the objects you need to work with
						paramPopupObj = findobj(fig,'tag','ParameterCodePopup');
						val = get(paramPopupObj, 'value');
						str = get(paramPopupObj, 'string');
						paramTextObj = findobj(fig,'tag','ParameterCodeTxt');
						% Step 2, take action
						switch val,
							case 2, % example 1
								disp(['Popup is ' str{val} '.']);
								%set(docTextObj,'string','Some example 1');
								type = 'example1';
							case 3, % example 2
								disp(['Popup is ' str{val} '.']);
								%set(docTextObj,'string','Some example 2');
								type = 'example2';
							case 4, % example 3
								disp(['Popup is ' str{val} '.']);
								%set(docTextObj,'string','Some example 3');
								type = 'example3';
							otherwise,
								disp(['Popup ' val ' is out of bound.']);
							end;
					
						p = which('ndi.calc.vis.speed_tuning');
						[parentdir, appname] = fileparts(p);
						paramfile_present = isfile([parentdir filesep appname '.docs.' type '.txt']);
						if paramfile_present,
							mytext = vlt.file.text2cellstr([parentdir filesep appname '.docs.' type '.txt']);
							set(paramTextObj,'string',mytext);
						elseif val~=1,
							msgbox('No documentation found.');
						end;
		
					case 'CommandPopup',
						% Step 1: search for the objects you need to work with
						cmdPopupObj = findobj(fig,'tag','CommandPopup');
						val = get(cmdPopupObj, 'value');
						str = get(cmdPopupObj, 'string');
						docTextObj = findobj(fig,'tag','CommandTxt');
						% Step 2, take action
						switch val,
							case 2, % Try searching for inputs
								disp(['Popup is ' str{val} '.']);
								set(docTextObj,'string','Try searching for inputs');
							case 3, % Show existing outputs
								disp(['Popup is ' str{val} '.']);
								set(docTextObj,'string','Show existing outputs');
							case 4, % Plot existing outputs
								disp(['Popup is ' str{val} '.']);
								set(docTextObj,'string','Plot existing outputs');
							case 5, % Run but don''t replace existing docs
								disp(['Popup is ' str{val} '.']);
								set(docTextObj,'string','Run but don''t replace existing docs');
							case 6, % Run and replace existing docs
								disp(['Popup is ' str{val} '.']);
								set(docTextObj,'string','Run and replace existing docs');
							otherwise,
								disp(['Popup ' val ' is out of bound.']);
						end;
					case 'LoadBt',
						[file,path] = uigetfile('*.mat');
						if isequal(file,0)
							disp('User selected Cancel');
						else
							disp(['User selected ', fullfile(path,file)]);
						end
						
						file = load(fullfile(path,file));
						
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
						% what will we save?
						% let's save the parameter code
						% shall we save "preferences" for running? Let's not right now
						% shall we save the view that the user had? let's not right now
						
						% save doc
						%docPopupObj = findobj(fig,'tag','DocPopup');
						%docval = get(docPopupObj, 'value');
						%docstrs = get(docPopupObj, 'string');
						%docstr = docstrs{docval};
						%doctext = get(findobj(fig,'tag','DocTxt'),'String');
						
						% save param
						%paramPopupObj = findobj(fig,'tag','ParameterCodePopup');
						%paramval = get(paramPopupObj, 'value');
						%paramstrs = get(paramPopupObj, 'string');
						%paramstr = paramstrs{paramval};
						paramtext = get(findobj(fig,'tag','ParameterCodeTxt'),'String');

						% check filename
						if isempty(ud.calc.filename),
							ud.calc.filename = filename;
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
							defaultfilename = {['untitled']};
							prompt = {'File name:'};
							dlgtitle = 'Save As';
							extension_list = {['.mat']};
							[success,filename,replaces] = ndi.util.choosefile(prompt, defaultfilename, dlgtitle, extension_list);
							% success: need to save
							% replaces: original file is covered
							% [0, filename, 0]: do nothing
							% [1, filename, 0]: save and not replace
							% [1, filename, 1]: save and replace
							    
							% uncomment the following three lines to check 
							disp("success: "+success);
							disp("filename: "+filename);
							disp("replaces: "+replaces);
							if success
								save(filename,'docval','docstr','doctext','paramval','paramstr','paramtext');
							end
						end
					case 'CancelBt',
					otherwise,
						disp(['Unknown command ' command '.']);

				end; % switch(command)
		end; % graphical_edit_calculation_instance
            
	end; % Static methods
    

end

    