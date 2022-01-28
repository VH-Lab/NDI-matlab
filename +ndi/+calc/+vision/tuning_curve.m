classdef tuning_curve < ndi.calculation

	methods

		function tuning_curve_obj = tuning_curve(session)
			% TUNING_CURVE - ndi.calculation object that calculates the
			% tuning curve from spike elements
			%
			% TUNING_CURVE_OBJ = TUNING_CURVE(SESSION)
			%
			% Creates a TUNING_CURVE ndi.calculation object
			%
				ndi.globals;
				tuning_curve_obj = tuning_curve_obj@ndi.calculation(session,'tuning_curve',...
					fullfile(ndi_globals.path.documentpath,'apps','calculations','tuning_curve.json'));
		end; % tuning_curve() creator

		function doc = calculate(ndi_calculation_obj, parameters)
			% CALCULATE - performs the tuning curve calculations for each
			% spike element
			%
			% DOC = CALCULATE(NDI_CALCULATION_OBJ, PARAMETERS)
			%
			% Creates a tuning_curve document given input parameters.
			%
			% The document that is created has an 'answer' that is given
			% by the input parameters.
				
                % check inputs
<<<<<<< Updated upstream
				if ~isfield(parameters,'input_parameters'), error(['parameters structure lacks ''input_parameters.''']); end;
				if ~isfield(parameters,'depends_on'), error(['parameters structure lacks ''depends_on.''']); end;
				
				tuning_curve = parameters;
                tuning_curve.independent_variable_label = parameters.input_parameters.independent_variable_label;
                tuning_curve.independent_label = parameters.input_parameters.independent_variable_value;
                
                % calculate
=======
				if ~isfield(parameters,'input_parameters'), error(['parameters structure lacks ''input_parameters''.']); end;
				if ~isfield(parameters,'depends_on'), error(['parameters structure lacks ''depends_on''.']); end;
				
                % Step 1: set up output structure
				tuning_curve = parameters;
                
				stim_response_doc = ndi_calculation_obj.session.database_search(ndi.query('ndi_document.id','exact_number',...
					vlt.db.struct_name_value_search(parameters.depends_on,'stimulus_response_scalar_id'),''));
				if numel(stim_response_doc)~=1, 
					error(['Could not find stimulus response doc..']);
				end;
				stim_response_doc = stim_response_doc{1};

%                 tuning_curve.independent_variable_label = parameters.input_parameters.independent_variable_label;
%                 tuning_curve.independent_label = parameters.input_parameters.independent_variable_value;
                
                % Step 2: perform calculation and create a tuning curve
>>>>>>> Stashed changes
                E = ndi_calc_tuning_curve_obj.session;
                rapp = ndi.app.stimulus.tuning_response(E);
                
				tuning_curve.independent_parameter = {'angle'};
                tuning_curve.independent_label = {'direction'};
                tuning_curve.constraint = struct('field','sFrequency','operation','hasfield','param1','','param2','');
                
<<<<<<< Updated upstream
=======
                % Step 3: place results of calculation into an NDI document
                
>>>>>>> Stashed changes
%                doc = rapp.tuning_curve(rdoc,'independent_parameter',independent_parameter,...
%                    'independent_label',independent_label,'constraint',constraint);

                doc = ndi.document(ndi_calculation_obj.doc_document_types{1},'tuning_curve',tuning_curve);                
                for i=1:numel(parameters.depends_on),
					doc = doc.set_dependency_value(parameters.depends_on(i).name,parameters.depends_on(i).value);
				end;
                             
		end; % calculate

		function parameters = default_search_for_input_parameters(ndi_calculation_obj)
			% DEFAULT_SEARCH_FOR_INPUT_PARAMETERS - default parameters for searching for inputs
			%
			% PARAMETERS = DEFAULT_SEARCH_FOR_INPUT_PARAMETERS(NDI_CALCULATION_OBJ)
			%
			% Returns a list of the default search parameters for finding appropriate inputs
			% to the calculation.
			%
                parameters.input_parameters = struct('independent_variable_label','','independent_variable_value','');
				parameters.depends_on = vlt.data.emptystruct('name','value');
                
<<<<<<< Updated upstream
              	q = ndi.query('','isa','stimulus_tuningcurve','');
                q = q&ndi.query('element.ndi_element_class','contains_string','ndi.stimulus_tuning_curve','');
                parameters.query = struct('name', 'stimulus_response_scalar_id','query',q);
                
=======

                
                parameters.query = ndi_calculation_obj.query
>>>>>>> Stashed changes
%                 if input ~= empty,
%                     response_doc = input;
%                     q = q&ndi.query('','depends_on','stimulus_response_scalar_id',response_doc.id());
%                 end;
%                parameters.query = ndi_app_calculation_obj.session.database_search(q);
		end; % default_search_for_input_parameters
<<<<<<< Updated upstream

=======
        
        function parameters = default_search_for_input_parameters(ndi_calculation_obj)
            % DEFAULT_SEARCH_FOR-INPUT_PARAMETERS - default parameters for
            % searching for inputs
            %
            % PARAMETERS =
            % DEFAULT_SEARCH_FOR_INPUT_PARAMETERS(NDI_CALCULATION_OBJ)
            %
            % Returns a list of the default search parameters for finding
            % appropriate 
        function query = default_parameters_query(ndi_calculation_obj, parameters_specification)
            % DEFAULT_PARAMETERS_QUERY - what queries should be used to
            % search for input parameters
            %
            % QUERY = DEFAULT_PARAMETERS_QUERY(NDI_CALCULATION_OBJ,
            % PARAMETERS_SPECIFICATION)
            %
            % Calling SEARCH_FOR_INPUT_PARAMETERS allows for users to
            % specify a 'query' structure to select particular documents to
            % be placed into the 'depends_on' parameter specification.
            % If a 'query' structure is not provided, the default will be
            % used.
            %
            % The function returns: 
            % |-----------|--------------------------------------------|
            % | query     | A structure with 'name' and 'query' fields |
            % |           | that describes a search to be performed to |
            % |           | identify inputs for the 'depends_on' field |
            % |           | in the PARAMETERS output.                  |
            % |-----------|--------------------------------------------|
            %
            % For the ndi.calc.vision.tuning_curve class, this looks for
            % documents of type 'stimulus_tuningcurve.json' with
            % 'response_type' fields that contain 'mean' or 'F1'.
            %
            %         
                q1 = ndi.query('','isa','stimulus_tuningcurve.json','');
                q2 = ndi.query('stimulus_response_scalar.response_type','contains_string','mean','');
                q3 = ndi.query('stimulus_response_scalar.response_type','contains_string','F1','');
                q23 = q2 | q3;
                q_total = q1 & q23;
%                q2 = ndi.query('element.ndi_element_class','contains_string','ndi.stimulus_tuning_curve','');
                
                query = struct('name','stimulus_response_scalar_id','query',q_total);
        end; % default_parameters_query()
        
        function b = is_valid_dependency_input(ndi_calculation_obj, name, value)
            % IS_VALID_DEPENDENCY_INPUT - checks if a potential dependency input
            % actually valid for this calculation
            % 
            % B = IS_VALID_DEPENDENCY_INPUT(NDI_CALCULATION_OBJ, NAME,
            % VALUE)
            %
            % Tests whether a potential input to a calculation is valid.
            % NAME - potential dependency name
            % VALUE - ndi_document id of the potential dependency name
            %
            % The base class behavior of this function will return true.
            % This is overridden if additional criteria beyond an ndi.query
            % are needed to assess if a document is an appropriate input
            % for the calculation.
                    
                    b = 1;
                    %if additional criteria 
                        b = 0; 
                    return;
                    
        end; % is_valid_dependency_input()
                       
>>>>>>> Stashed changes
		function doc_about(ndi_calculation_obj)
			% ----------------------------------------------------------------------------------------------
			% NDI_CALCULATION: TUNING_CURVE
			% ----------------------------------------------------------------------------------------------
			%
			%   ------------------------
			%   | TUNING_CURVE -- ABOUT |
			%   ------------------------
			%
			%   TUNING_CURVE calculates tuning curves given the provided input parameters. 
			%   Each TUNING_CURVE document 'depends_on' an NDI daq system.
			%
			%   Definition: apps/calc/tuning_curve.json
			%
<<<<<<< Updated upstream
				eval(['help ndi.calc.tuning_curve.doc_about']);
=======
				eval(['help ndi.calc.vision.tuning_curve.doc_about']);
>>>>>>> Stashed changes
		end; %doc_about()
	end; % methods()
			
end % tuning_curve
