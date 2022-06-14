classdef hartley_calc < ndi.calculator

	methods
		function hartley_calc_obj = hartley_calc(session)
			% HARTLEY_CALC - a hartley_calc demonstration of an ndi.calculator object
			%
			% HARTLEY_CALC_OBJ = HARTLEY_CALC(SESSION)
			%
			% Creates a HARTLEY_CALC ndi.calculator object
			%
				ndi.globals;
				hartley_calc_obj = hartley_calc_obj@ndi.calculator(session,'hartley_calc',...
					fullfile(ndi_globals.path.documentpath,'apps','calculators','hartley_calc.json'));
		end; % hartley_calc()

		function doc = calculate(ndi_calculator_obj, parameters)
			% CALCULATE - perform the calculator for ndi.calc.example.hartley_calc
			%
			% DOC = CALCULATE(NDI_CALCULATOR_OBJ, PARAMETERS)
			%
			% Creates a hartley_calc_calc document given input parameters.
			%
			% The document that is created hartley_calc
			% by the input parameters.
				doc = {};
				% check inputs
				if ~isfield(parameters,'input_parameters'), error(['parameters structure lacks ''input_parameters''.']); end;
				if ~isfield(parameters,'depends_on'), error(['parameters structure lacks ''depends_on''.']); end;
				
				% Step 1: set up the output structure, and load the element_id and stimulus_presentation_doc
				hartley_calc = parameters;

				element_doc = ndi_calculator_obj.session.database_search(ndi.query('ndi_document.id','exact_number',...
					vlt.db.struct_name_value_search(parameters.depends_on,'element_id'),''));
				if numel(element_doc)~=1, 
					error(['Could not find element doc..']);
				end;
				element_doc = element_doc{1};
				element = ndi.database.fun.ndi_document2ndi_object(element_doc, ndi_calculator_obj.session);

				q1 = ndi.query('','isa','stimulus_presentation','');
				stimulus_presentation_docs = ndi_calculator_obj.session.database_search(q1);

				for i=1:numel(stimulus_presentation_docs),

					[b,stimids] = ndi.calc.vis.hartley_calc.ishartleystim(stimulus_presentation_docs{i});

					if ~b, continue; end;

					stimulus_element = ndi.database.fun.ndi_document2ndi_object(dependency_value(stimulus_presentation_docs{i},'stimulus_element_id'),...
						ndi_calculator_obj.session);

					% Step 2: do we have a stimulus presentation that has Hartley stims in it? Was it running at the same time as our element?

					et = stimulus_element.epochtable();

					% ASSUMPTION: each stimulus epoch will overlap a single element epoch
					stim_timeref = ndi.time.timereference(stimulus_element,...
						ndi.time.clocktype(stimulus_presentation_docs{i}.document_properties.stimulus_presentation.presentation_time(1).clocktype),...
						stimulus_presentation_docs{i}.document_properties.epochid,...
						stimulus_presentation_docs{i}.document_properties.stimulus_presentation.presentation_time(1).onset);
					[ts_epoch_t0_out, ts_epoch_timeref, msg] = ndi_calculator_obj.session.syncgraph.time_convert(stim_timeref,...
						0, element, ndi.time.clocktype('dev_local_time'));
					% time is 0 because stim_timeref is relative to 1st stim

					if ~isempty(ts_epoch_t0_out), % we have a match

						% Step 3: now to calculate
						
						% Step 3a: set up variables for returning

								% EDIT THIS SO IT TAKES ALL STIMIDS, MORE THAN JUST THE FIRST HARTLEY STIM
						hartley_reverse_correlation.stimulus_properties = ndi.calc.vis.hartley_calc.hartleystimdocstruct(...
							stimulus_presentation_docs{i}.document_properties.stimulus_presentation.stimuli(stimids(1)).parameters);
						hartley_reverse_correlation.reconstruction_properties = struct(...
							'T_coords', parameters.input_parameters.T,...
							'X_coords', 1:parameters.input_parameters.X_sample:hartley_reverse_correlation.stimulus_properties.M,...
							'Y_coords', 1:parameters.input_parameters.Y_sample:hartley_reverse_correlation.stimulus_properties.M);
						reverse_correlation.method = "Hartley";

						% Step 3b: load the spike times and spike parameters

						frameTimes_indexes = find(stimulus_presentation_docs{i}.document_properties.stimulus_presentation.presentation_time.stimevents(:,2)==1);
						frameTimes = stimulus_presentation_docs{i}.document_properties.stimulus_presentation.presentation_time.stimevents(frameTimes_indexes,1);
						[spike_values,spike_times] = element.readtimeseries(stim_timeref, ...
							stimulus_presentation_docs{i}.document_properties.stimulus_presentation.presentation_time(1).onset, ...
							stimulus_presentation_docs{i}.document_properties.stimulus_presentation.presentation_time(end).offset);

						% load the hartley states
						P = stimulus_presentation_docs{i}.document_properties.stimulus_presentation.stimuli(stimids(1)).parameters;
						P.rect = P.rect(:)';
						P.dispprefs = {};
						P.chromhigh = P.chromhigh(:)';
						P.chromlow = P.chromlow(:)';
						hartleys = hartleystim(P);
						[S,KXV,KYV,ORDER] = hartleynumbers(hartleys);

						hartley_reverse_correlation.hartley_numbers.S = S;
						hartley_reverse_correlation.hartley_numbers.KXV = KXV;
						hartley_reverse_correlation.hartley_numbers.KYV = KYV;
						hartley_reverse_correlation.hartley_numbers.ORDER = ORDER;

						hartley_reverse_correlation.spiketimes = spike_times;
						hartley_reverse_correlation.frameTimes = frameTimes;

						% write JSON file here for now

						mystring = vlt.data.jsonencodenan(hartley_reverse_correlation);
						myfile = fullfile(ndi_calculator_obj.session.path,...
							[stimulus_presentation_docs{i}.document_properties.epochid '_' ...
								element.elementstring() '_hartley.json']);
						mystring = char(vlt.data.prettyjson(mystring));
						vlt.file.str2text(myfile,mystring);

						% Step 3c: actually make the document
						if 0, % not doing this yet

							doc{end+1} = ndi.document(ndi_calculator_obj.doc_document_types{1},'hartley_calc',parameters_here,...
								'hartley_reverse_correlation',hartley_reverse_correlation,'reverse_correlation',reverse_correlation);
							doc{end} = doc{end}.set_dependency_value('element_id',element_doc.id());
							doc{end} = doc{end}.set_dependency_value('stimulus_presentation_id', stim_pres_id{i});
							doc{end} = doc{end}.set_dependency_value('stimulus_response_scalar_id',...
								stim_resp_scalar{stim_resp_index_value});

							% open the ngrid file
								
							% write the ngrid file

						end;
					end;
				end;
				
		end; % calculate

		function parameters = default_search_for_input_parameters(ndi_calculator_obj)
			% DEFAULT_SEARCH_FOR_INPUT_PARAMETERS - default parameters for searching for inputs
			%
			% PARAMETERS = DEFAULT_SEARCH_FOR_INPUT_PARAMETERS(NDI_CALCULATOR_OBJ)
			%
			% Returns a list of the default search parameters for finding appropriate inputs
			% to the calculator. For hartley_calc_calc, there is no appropriate default parameters
			% so this search will yield empty.
			%
				parameters.input_parameters = struct(...
					'T', 0:0.05:0.250, ...
					'X_sample', 1, ...
					'Y_sample', 1);
				parameters.depends_on = vlt.data.emptystruct('name','value');
				parameters.query = ndi_calculator_obj.default_parameters_query(parameters);
					
		end; % default_search_for_input_parameters

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
			% For the ndi.calc.stimulus.hartley_calc_calc class, this looks for 
			% documents of type 'stimulus_response_scalar.json' with 'response_type' fields
			% the contain 'mean' or 'F1'.
			%
			%
				q_total = ndi.query('element.type','exact_string','spikes','');

				query = struct('name','element_id','query',q_total);
		end; % default_parameters_query()

		function doc_about(ndi_calculator_obj)
			% ----------------------------------------------------------------------------------------------
			% NDI_CALCULATOR: HARTLEY_CALC
			% ----------------------------------------------------------------------------------------------
			%
			%   ------------------------
			%   | HARTLEY_CALC -- ABOUT |
			%   ------------------------
			%
			%   HARTLEY_CALC is a demonstration document. It simply produces the 'answer' that
			%   is provided in the input parameters. Each HARTLEY_CALC document 'depends_on' an
			%   NDI daq system.
			%
			%   Definition: apps/hartley_calc_calc.json
			%
				eval(['help ndi.calc.example.hartley_calc.doc_about']);
		end; %doc_about()

		function h=plot(ndi_calculator_obj, doc_or_parameters, varargin)
                        % PLOT - provide a diagnostic plot to show the results of the calculator
                        %
                        % H=PLOT(NDI_CALCULATOR_OBJ, DOC_OR_PARAMETERS, ...)
                        %
                        % Produce a plot of the tuning curve.
			%
                        % Handles to the figure, the axes, and any objects created are returned in H.
                        %
                        % This function takes additional input arguments as name/value pairs.
                        % See ndi.calculator.plot_parameters for a description of those parameters.

				% call superclass plot method to set up axes
				h=plot@ndi.calculator(ndi_calculator_obj, doc_or_parameters, varargin{:});

				if isa(doc_or_parameters,'ndi.document'),
					doc = doc_or_parameters;
				else,
					error(['Do not know how to proceed without an ndi document for doc_or_parameters.']);
				end;

				box off;

		end; % plot()
	end; % methods()

	methods (Static)
		function [b,stimids] = ishartleystim(stim_presentation_doc)
			% ISHARTLEYSTIM - does a stimulus presentation doc contain a Hartley stimulus?
			% 
			% [B,STIMIDS] = ndi.calc.hartley_calc.ishartleystim(STIM_PRESENTATION_DOC)
			%
			% Returns 1 iff STIM_PRESENTATION_DOC contains Hartley stimuli. Returns
			% the STIMIDS of any Hartley stimuli.
			%
				stimids = [];
				S = stim_presentation_doc.document_properties.stimulus_presentation.stimuli;
				for i=1:numel(S),
					thestruct = S(i).parameters;
					if isfield(thestruct,'M')&isfield(thestruct,'chromhigh')&isfield(thestruct,'K_absmax'), % hartley
						stimids(end+1) = i;
					end;
				end;
				b = ~isempty(stimids);
		end; % ishartleystim

		function hartleydocinfo = hartleystimdocstruct(stimstruct)
			% HARTLEYSTIMDOCSTRUCT - return the fields of the Hartley stimulus necessary for the hartley_reverse_correlation document
			%
			% HARTLEYDOCINFO = HARTLEYSTIMDOCSTRUCT(STIMSTRUCT)
			%
			% Returns the fields of the Hartley stim that are needed for the
			% NDI hartley_reverse_correlation document:
			%
			% Fields: M, L_max, K_max, sf_max, fps, color_high, color_low, rect
			% 
			%
				fields_out = {'M','L_max','K_max','sf_max','fps','color_high','color_low','rect'};
				fields_names = {'M', 'L_absmax','K_absmax','sfmax','fps','chromhigh','chromlow','rect'};
				hartleydocinfo = vlt.data.emptystruct(fields_out{:});
				hartleydocinfo(1).M = stimstruct.M;
				for i=1:numel(fields_out), 
					if ~isfield(stimstruct,fields_names{i}),
						error(['STIMSTRUCT has no field ' fields_names{i} '.']);
					end;
					hartleydocinfo = setfield(hartleydocinfo, fields_out{i}, getfield(stimstruct,fields_names{i}));
				end;
		end; % hartleystimdocinfo

	end; % static methods
		
end % hartley_calc
