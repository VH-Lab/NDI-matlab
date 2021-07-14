classdef calculation < ndi.app & ndi.appdoc

	properties (SetAccess=protected,GetAccess=public)
	end; % properties

	methods

		function ndi_calculation_obj = calculation(varargin)
			% CALCULATION - create an ndi.calculation object
			%
			% NDI_CALCULATION_OBJ = CALCULATION(SESSION)
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

				% calculation subclasses should include the following to include its appdoc type,
				% to be able to use the appdoc document handling functions:
				% ndi_calculation_obj = ndi_calculation_obj@ndi.app.appdoc({'document_type_name_here'},...
				%   {'your/path/to/ndi_document'}, session);
				% TODO: add an actual type here
		end; % calculation creator

		function docs = run(ndi_calculation_obj, docExistsAction, parameters)
			% RUN - run calculation on all possible inputs that match some parameters
			%
			% DOCS = RUN(NDI_CALCULATION_OBJ, DOCEXISTSACTION, PARAMETERS)
			%
			%

		end; % run()

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
				fixed_input_parameters = parameters_specification_input_parameters;
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
						error(['Could not locate ndi document with id ' fixed_depends_on(i).value ' that corresponded to name ' fixed_depends_on(i).name ']);
					end;
				end;

				if ~isfield(parameters_specification,'query'),
					% we are done, everything is fixed
					parameters.input_parameters = fixed_input_parameters;
					parameters.depends_on = fixed_depends_on;
					parameters = {parameters}; % a single cell entry
					return;
				end;

				doclist = {};
				V = [];
				for i=1:numel(parameters_specification.query),
					doclist{i} = ndi_calculation_obj.session.database_search(parameters_specification.query(i));
					V(i) = numel(doclist{i});
				end;

				counter = ones(size(V));

				while ~vlt.data.eqlen(counter,V),

				end;

		end; % search_for_input_parameters()

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
				class_name = myemptydoc.document_properties.document_class.class_name;
				
				q_input = ndi.query([property_list_name '.input_parameters'],'partial_struct',parameters.input_parameters,'');
				q_type = ndi.query('','isa',class_name,'');
				q = q_input & q_type;
				if isfield(parameters,'depends_on')
					for i=1:numel(parameters.depends),
						q = q & ndi.query('','depends_on',parameters.depends(i).name,parameters(depends(i)).value);
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

		function diagnostic_plot(ndi_calculation_obj, doc_or_parameters. varargin)

		end;


	end; % methods
end
				
				
			
				

