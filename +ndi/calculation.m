classdef calculation < ndi.app & ndi.app.appdoc

	properties (SetAccess=protected,GetAccess=public)
	end; % properties

	methods

		function ndi_calculation_obj = calculation(varargin)
			% CALCULATION - create an ndi.calculation object
			%
			% NDI_CALCULATION_OBJ = CALCULATION(SESSION, DOC_TYPE, PATH_TO_DOC_TYPE)
			%
			% Creates a new ndi.calculation mini-app for performing
			% a particular calculation. SESSION is the ndi.session object
			% to operate on.
			%
			% Classes that override this function should call
			% the creator for ndi.appdoc to record the document type
			% that is used by the ndi.calculation mini-app.
			%
				session = [];
				if nargin>0,
					session = varargin{1};
				end;
				ndi_calculation_obj = ndi_calculation_obj@ndi.app(session,'calculation');
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
				ndi_calculation_obj = ndi_calculation_obj@ndi.app.appdoc({document_type}, ...
					{path_to_doc_type},session);
		end; % calculation creator

		function docs = run(ndi_calculation_obj, docExistsAction, parameters)
			% RUN - run calculation on all possible inputs that match some parameters
			%
			% DOCS = RUN(NDI_CALCULATION_OBJ, DOCEXISTSACTION, PARAMETERS)
			%
			%
			% DOCEXISTSACTION can be 'Error', 'NoAction', 'Replace', or 'ReplaceIfDifferent'
			% For calculations, 'ReplaceIfDifferent' is equivalent to 'NoAction' because 
			% the input parameters define the calculation.
			%
				% Step 1: set up input parameters; they can either be completely specified by
				% the caller, or defaults can be used

				docs = {};

				if nargin<3,
					parameters = ndi_calculation_obj.default_search_for_input_parameters();
				end;

				% Step 2: identify all sets of possible input parameters that are compatible with
				% what was specified by 'parameters'

				all_parameters = ndi_calculation_obj.search_for_input_parameters(parameters);

				% Step 3: check if we've already done the calculation for these parameters; if we have,
				% take the appropriate action. If we need to, perform the calculation.

				ndi.globals();
				ndi_globals.log.msg('system',1,['Beginning calculation by class ' classname(ndi_calculation_obj) '...']);

				for i=1:numel(all_parameters),
					ndi_globals.log.msg('system',1,['Performing calculation ' int2str(i) ' of ' int2str(numel(all_parameters)) '.']);
					previous_calculations_here = ndi_calculation_obj.search_for_calculation_docs(all_parameters{i});
					do_calc = 0;
					if ~isempty(previous_calculations_here),
						switch(docExistsAction),
							case 'Error',
								error(['Doc for input parameters already exists; error was requested.']);
							case {'NoAction','ReplaceIfDifferent'},
								docs = cat(2,docs,previous_calculations_here);
								continue; % skip to the next calculation
							case {'Replace'},
								ndi_calculation_obj.session.database_rm(previous_calculations_here);
								do_calc = 1;
						end;
					else,
						do_calc = 1;
					end;
					if do_calc,
						docs_out = ndi_calculation_obj.calculate(all_parameters{i});
						if ~iscell(docs_out),
							docs_out = {docs_out};
						end;
						docs = cat(2,docs,docs_out);
					end;
				end;
				if ~isempty(docs),
					ndi_calculation_obj.session.database_add(docs);
				end;
				ndi_globals.log.msg('system',1,'Concluding calculation.');
		end; % run()

		function parameters = default_search_for_input_parameters(ndi_calculation_obj)
			% DEFAULT_SEARCH_FOR_INPUT_PARAMETERS - default parameters for searching for inputs
			% 
			% PARAMETERS = DEFAULT_SEARCH_FOR_INPUT_PARAMETERS(NDI_CALCULATION_OBJ)
			%
			% Returns a list of the default search parameters for finding appropriate inputs
			% to the calculation.
			%
				parameters.input_parameters = [];
				parameters.depends_on = vlt.data.emptystruct('name','value');
		end; % default_search_for_input_parameters
			
		function parameters = search_for_input_parameters(ndi_calculation_obj, parameters_specification, varargin)
			% SEARCH_FOR_INPUT_PARAMETERS - search for valid inputs to the calculation
			%
			% PARAMETERS = SEARCH_FOR_INPUT_PARAMETERS(NDI_CALCULATION_OBJ, PARAMETERS_SPECIFICATION)
			%
			% Identifies all possible sets of specific input PARAMETERS that can be
			% used as inputs to the calculation. PARAMETERS is a cell array of parameter
			% structures with fields 'input_parameters' and 'depends_on'.
			%
			% PARAMETERS_SPECIFICATION is a structure with the following fields:
			% |----------------------------------------------------------------------|
			% | input_parameters      | A structure of fixed input parameters needed |
			% |                       |   by the calculation. Should not depend on   |
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
					l = ndi_calculation_obj.session.database_search(q);
					if numel(l)~=1,
						error(['Could not locate ndi document with id ' fixed_depends_on(i).value ' that corresponded to name ' fixed_depends_on(i).name '.']);
					end;
				end;

				if ~isfield(parameters_specification,'query'),
					parameters_specification.query = ndi_calculation_obj.default_parameters_query(parameters_specification);
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
					doclist{i} = ndi_calculation_obj.session.database_search(parameters_specification.query(i).query);
					V(i) = numel(doclist{i});
				end;

				parameters = {};

				for n=1:prod(V),
					is_valid = 1;
					g = vlt.math.group_enumeration(V,n);
					extra_depends = vlt.data.emptystruct('name','value');
					for i=1:numel(parameters_specification.query),
						s = struct('name',parameters_specification.query(i).name,'value',doclist{i}{g(i)}.id());
						is_valid = is_valid & ndi_calculation_obj.is_valid_dependency_input(s.name,s.value);
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

		function query = default_parameters_query(ndi_calculation_obj, parameters_specification)
			% DEFAULT_PARAMETERS_QUERY - what queries should be used to search for input parameters if none are provided?
			%
			% QUERY = DEFAULT_PARAMETERS_QUERY(NDI_CALCULATION_OBJ, PARAMETERS_SPECIFICATION)
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

		function docs = search_for_calculation_docs(ndi_calculation_obj, parameters)  % can call find_appdoc, most of the code should be put in find_appdoc
			% SEARCH_FOR_CALCULATION_DOCS - search for previous calculations
			%
			% [DOCS] = SEARCH_FOR_CALCULATION(NDI_CALCULATION_OBJ, PARAMETERS)
			%
			% Performs a search to find all previously-created calculation
			% documents that this mini-app creates. 
			%
			% PARAMETERS is a structure with the following fields
			% |------------------------|----------------------------------|
			% | Fieldname              | Description                      |
			% |-----------------------------------------------------------|
			% | input_parameters       | A structure of input parameters  |
			% |                        |  needed by the calculation.      |
			% | depends_on             | A structure with fields 'name'   |
			% |                        |  and 'value' that indicates any  |
			% |                        |  exact matches that should be    |
			% |                        |  satisfied.                      |
			% |------------------------|----------------------------------|
			%
				% in the abstract class, this returns empty
				myemptydoc = ndi.document(ndi_calculation_obj.doc_document_types{1});
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
				docs = ndi_calculation_obj.session.database_search(q);
		end; % search_for_calculation_docs()

		function b = is_valid_dependency_input(ndi_calculation_obj, name, value)
			% IS_VALID_DEPENDENCY_INPUT - is a potential dependency input actually valid for this calculation?
			%
			% B = IS_VALID_DEPENDENCY_INPUT(NDI_CALCULATION_OBJ, NAME, VALUE)
			%
			% Tests whether a potential input to a calculation is valid.
			% The potential dependency name is provided in NAME and its ndi_document id is
			% provided in VALUE.
			%
			% The base class behavior of this function is simply to return true, but it
			% can be overriden if additional criteria beyond an ndi.query are needed to
			% assess if a document is an appropriate input for the calculation.
			%
				b = 1; % base class behavior
		end; % is_valid_dependency_input()

		function doc = calculate(ndi_calculation_obj, parameters)
			% CALCULATE - perform calculation and generate an ndi document with the answer
			%
			% DOC = CALCULATE(NDI_CALCULATION_OBJ, PARAMETERS)
			%
			% Perform the calculation and return an ndi.document with the answer.
			%
			% In the base class, this always returns empty.
				doc = {};
		end; % calculate()

		function h=plot(ndi_calculation_obj, doc_or_parameters, varargin)
			% PLOT - provide a diagnostic plot to show the results of the calculation, if appropriate
			%
			% H=PLOT(NDI_CALCULATION_OBJ, DOC_OR_PARAMETERS, ...)
			%
			% Produce a diagnostic plot that can indicate to a reader whether or not
			% the calculation has been performed in a manner that makes sense with
			% its input data. Useful for debugging / validating a calculation.
			%
			% Handles to the figure, the axes, and any objects created are returned in H.
			% 
			% By default, this plot is made in the current axes.
			%
			% This function takes additional input arguments as name/value pairs.
			% See ndi.calculation.plot_parameters for a description of those parameters.
			%
				params = ndi.calculation.plot_parameters(varargin{:});
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

		%function struct2doc - should call calculation
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

		function doc_about(ndi_calculation_obj)
			% ----------------------------------------------------------------------------------------------
			% NDI_CALCULATION: DOCTYPE1 (in subclasses, change this to your document type)
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
				eval(['help ndi.calculation.doc_about']);
		end; %doc_about()
	
		function appdoc_description(ndi_calculation_obj)
			% ----------------------------------------------------------------------------------------------
			% DOCUMENT INFO:
			% ----------------------------------------------------------------------------------------------
			%
			%   ---------
			%   | ABOUT |
			%   ---------
			%
			%   To see the ABOUT information for the document that is created by this calculation,
			%   see 'help ndi.calculation/doc_about'
			%
			%   ------------
			%   | CREATION |
			%   ------------
			%
			%   DOC = CALCULATE(NDI_CALCULATION_OBJ, PARAMETERS)
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
			%   [DOC] = SEARCH_FOR_CALCULATION_DOCS(NDI_CALCULATION_OBJ, PARAMETERS)
			%
			%   PARAMETERS should contain the following fields:
			%   Fieldname                 | Description
			%   -------------------------------------------------------------------------
			%   input_parameters          | field1 description
			%   depends_on                | field2 description
			%
				eval(['help ndi.calculation/appdoc_description']);
		end; % appdoc_description()

	end; % methods

	methods (Static)
		function param = plot_parameters(varargin);
			% PLOT - provide a diagnostic plot to show the results of the calculation, if appropriate
			%
			% PLOT(NDI_CALCULATION_OBJ, DOC_OR_PARAMETERS, ...)
			%
			% Produce a diagnostic plot that can indicate to a reader whether or not
			% the calculation has been performed in a manner that makes sense with
			% its input data. Useful for debugging / validating a calculation.
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

	end; % Static methods

end

