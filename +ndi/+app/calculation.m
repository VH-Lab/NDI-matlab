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


		function docs = search_for_calculation(ndi_calculation_obj, parameters)
			% SEARCH_FOR_CALCULATION - search and perform a calculation
			%
			% [DOCS] = SEARCH_FOR_CALCULATION(NDI_CALCULATION_OBJ, PARAMETERS)
			%
			% Performs a search to find all eligible document inputs for our function
			% CALCULATION. 
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
				if isfield(parameters,'depends')
					for i=1:numel(parameters.depends),
						q = q & ndi.query('','depends_on',parameters.depends(i).name,parameters(depends(i)).value);
					end;
				end;
				docs = ndi_calculation_obj.session.database_seearch(q);
		end; % search_for_calculation()
		

		function doc = calculate(ndi_calculation_obj, parameters)
			% CALCULATE - perform calculation and generate an ndi document with the answer
			%
			% DOC = CALCULATE(NDI_CALCULATION_OBJ, PARAMETERS)
			%
			% Perform the calculation and return an ndi.document with the answer
			%



		end; % calculate()


	end; % methods
end
				
				
			
				

