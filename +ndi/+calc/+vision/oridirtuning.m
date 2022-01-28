classdef oridirtuning < ndi.calculation

	methods

		function oridirtuning_obj = oridirtuning(session)
			% oridirtuning - ndi.calculation object that
			% calculates orientation and direction tuning curves from spike
			% elements
			%
			% ORIDIRTUNING_OBJ = ORIDIRTUNING(SESSION)
			%
			% Creates a oridirtuning ndi.calculation object
			%
				ndi.globals;
				oridirtuning_obj = oridirtuning_obj@ndi.calculation(session,'oridirtuning',...
					fullfile(ndi_globals.path.documentpath,'apps','calculations','oridirtuning.json'));
		end; % oridirtuning() creator

		function doc = calculate(ndi_calculation_obj, parameters)
			% CALCULATE - perform the calculation for
			% ndi.calc.oridirtuning
			%
			% DOC = CALCULATE(NDI_CALCULATION_OBJ, PARAMETERS)
			%
			% Creates a oridirtuning_direction_tuning_calc document given input parameters.
			
                % Step 1. Check inputs
                if ~isfield(parameters,'input_parameters'), error(['parameters structure lacks ''input_parameters.''']); end;
				if ~isfield(parameters,'depends_on'), error(['parameters structure lacks ''depends_on.''']); end;
				
                % Step 2. Set up output structure
                oridirtuning = parameters;
				
                tuning_doc = ndi_calculation_obj.session.database_search(ndi.query('ndi_document.id','exact_number',...
					vlt.db.struct_name_value_search(parameters.depends_on,'stimulus_tuningcurve_id'),''));
				if numel(tuning_doc)~=1, 
					error(['Could not find stimulus tuning curve doc..']);
				end;
				tuning_doc = tuning_doc{1};
                
%               tuning_doc = ndi.document(ndi_calculation_obj.doc_document_types{1},'oridirtuning',oridirtuning);
% 				for i=1:numel(parameters.depends_on),
% 					doc = doc.set_dependency_value(parameters.depends_on(i).name,parameters.depends_on(i).value);
% 				end;
				
                % Step 3. Calculate oridirtuning and direction indexes from
                % stimulus responses and write output into a document
                doc = ndi_calculation_obj.calculate_oridir_indexes(tuning_doc);

                % Step 4. Check if doc exists
                if ~isempty(doc), 
                    doc = ndi.document(ndi_calculation_obj.doc_document_types{1},'oridirtuning',oridirtuning) + doc;
					doc = doc.set_dependency_value('stimulus_tuningcurve_id',tuning_response_doc.id());
				end;
                
		end; % calculate

		function parameters = default_search_for_input_parameters(ndi_calculation_obj, varargin)
			% DEFAULT_SEARCH_FOR_INPUT_PARAMETERS - default parameters for searching for inputs
			%
			% PARAMETERS = DEFAULT_SEARCH_FOR_INPUT_PARAMETERS(NDI_CALCULATION_OBJ)
			%
			% Returns a list of the default search parameters for finding appropriate inputs
			% to the calculation.
			%

            % search for stimulus_tuningcurve_id
            parameters.input_parameters = struct('independent_label','','independent_parameter','','best_algorithm','empirical_maximum');
            parameters.input_parameters.selection = vlt.data.emptystruct('property','operation','value');
            parameters.depends_on = vlt.data.emptystruct('name','value');
            parameters.query = ndi_calculation_obj.default_parameters_query(parameters);
            parameters.query(end+1) = struct('name','will_fail','query',...
                ndi.query('ndi_document.id','exact_string','123',''));
                        
		end; % default_search_for_input_parameters

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
                q2 = ndi.query('','depends_on','stimulus_response_scalar_id',

                q_total = q1 & q2;
                
                query = struct('name','stimulus_tuningcurve_id','query',q_total);
        end; % default_parameters_query()
        
        function oridir_doc = calculate_oridir_indexes(ndi_calculation_obj, tuning_doc)
			% CALCULATE_SPEED_INDEXES - calculate speed index values from a tuning curve
			%
			% SPEED_PROPS_DOC = CALCULATE_SPEED_INDEXES(NDI_SPEED_TUNING_CALC_OBJ, TUNING_DOC)
			%
			% Given a 2-dimensional tuning curve document with measurements at many spatial and
			% and temporal frequencies, this function calculates speed response
			% parameters and stores them in SPEED_TUNING document SPEED_PROPS_DOC.
			%
			%
				ind = {};
				ind_real = {};
				control_ind = {};
				control_ind_real = {};
				response_ind = {};
				response_mean = [];
				response_stddev = [];
				response_stderr = [];
                properties.response_units = tuning_doc.document_properties.tuning_curve.response_units;
		
        end; %calculate_oridir_indexes()
        
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
				return;

				% could also use the below, but will require an extra query operation
				% and updating for speed
	
				switch lower(name),
					case lower('stimulus_tuningcurve_id'),
						q = ndi.query('ndi_document.id','exact_string',value,'');
						d = ndi_calculation_obj.S.database_search(q);
						b = (numel(d.document_properties.independent_variable_label) ==2);
				end;
		end; % is_valid_dependency_input()
        
		function doc_about(ndi_calculation_obj)
			% ----------------------------------------------------------------------------------------------
			% NDI_CALCULATION: ORIDIRTUNING
			% ----------------------------------------------------------------------------------------------
			%
			%   ------------------------
			%   | ORIDIRTUNING -- ABOUT |
			%   ------------------------
			%
			%   ORIDIRTUNING is an ndi.calculation object that calculates the oridirtuning and direction tuning
			%   curves from spike elements.
            %   
			%   Each  document 'depends_on' an NDI daq system.
			%
			%   Definition: apps/calc/oridirtuning.json
			%
				eval(['help ndi.calc.vision.oridirtuning.doc_about']);
		end; %doc_about()
	end; % methods()
			
end % oridirtuning
