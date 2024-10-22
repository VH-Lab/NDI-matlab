classdef tuningcurve < ndi.calculator
    methods

        function tuningcurve_obj = tuningcurve(session)
            % TUNINGCURVE - a tuningcurve demonstration of an ndi.calculator object
            %
            % TUNINGCURVE_OBJ = TUNINGCURVE(SESSION)
            %
            % Creates a TUNINGCURVE ndi.calculator object
            %
                tuningcurve_obj = tuningcurve_obj@ndi.calculator(session,'tuningcurve_calc',...
                    fullfile(ndi.common.PathConstants.DocumentFolder,'apps','calculators','tuningcurve_calc.json'));
        end; % tuningcurve()

        function doc = calculate(ndi_calculator_obj, parameters)
            % CALCULATE - perform the calculator for ndi.calc.example.tuningcurve
            %
            % DOC = CALCULATE(NDI_CALCULATOR_OBJ, PARAMETERS)
            %
            % Creates a tuningcurve_calc document given input parameters.
            %
            % The document that is created tuningcurve
            % by the input parameters.
                % check inputs
                if ~isfield(parameters,'input_parameters'), error(['parameters structure lacks ''input_parameters''.']); end;
                if ~isfield(parameters,'depends_on'), error(['parameters structure lacks ''depends_on''.']); end;
                
                % Step 1: set up the output structure
                tuningcurve_calc = parameters;

                stim_response_doc = ndi_calculator_obj.session.database_search(ndi.query('base.id','exact_string',...
                    vlt.db.struct_name_value_search(parameters.depends_on,'stimulus_response_scalar_id'),''));
                if numel(stim_response_doc)~=1, 
                    error(['Could not find stimulus response doc..']);
                end;
                stim_response_doc = stim_response_doc{1};
            
                % Step 2: perform the calculator, which here creates a tuning curve from instructions

                % build input arguments for tuning curve app

                independent_label = split(parameters.input_parameters.independent_label,',');
                independent_parameter = split(parameters.input_parameters.independent_parameter,',');
                if numel(independent_label)~=numel(independent_parameter),
                    error(['There are not the same number of independent labels and independent parameters specified.']);
                end;
                for i=1:numel(independent_label),
                    independent_label{i} = strtrim(independent_label{i});
                    independent_parameter{i} = strtrim(independent_parameter{i});
                end;
                
                constraint = vlt.data.emptystruct('field','operation','param1','param2');

                log_str = '';

                deal_constraints = {};
                stim_property_list = {};

                for i=1:numel(parameters.input_parameters.selection),
                    if strcmp(lower(char(parameters.input_parameters.selection(i).operation)),'hasnumericvalue'),
                        pva = ndi_calculator_obj.property_value_array(stim_response_doc,parameters.input_parameters.selection(i).property);
                        match = 0;
                        for j=1:numel(pva),
                            if pva{j}==parameters.input_parameters.selection(i).value,
                                match = 1;
                                break;
                            end;
                        end;
                        if match==0, %if it doesn't have it, then quit
                            doc = {};
                            return;
                        end;
                    elseif strcmp(lower(char(parameters.input_parameters.selection(i).operation)),'hasnumericvalue>'),
                        pva = ndi_calculator_obj.property_value_array(stim_response_doc,parameters.input_parameters.selection(i).property);
                        match = 0;
                        for j=1:numel(pva),
                            if pva{j}>parameters.input_parameters.selection(i).value,
                                match = 1;
                                break;
                            end;
                        end;
                        if match==0, %if it doesn't have it, then quit
                            doc = {};
                            return;
                        end;
                    elseif strcmp(lower(char(parameters.input_parameters.selection(i).operation)),'hasnumericvalue<'),
                        pva = ndi_calculator_obj.property_value_array(stim_response_doc,parameters.input_parameters.selection(i).property);
                        match = 0;
                        for j=1:numel(pva),
                            if pva{j}<parameters.input_parameters.selection(i).value,
                                match = 1;
                                break;
                            end;
                        end;
                        if match==0, %if it doesn't have it, then quit
                            doc = {};
                            return;
                        end;
                    elseif strcmpi(char(parameters.input_parameters.selection(i).value),'best'),
                        % calculate best value
                        [n,v,stim_property_value] = ndi_calculator_obj.best_value(parameters.input_parameters.best_algorithm,...
                            stim_response_doc, parameters.input_parameters.selection(i).property);
                        constraint_here = struct('field',parameters.input_parameters.selection(i).property,...
                            'operation','exact_number','param1',stim_property_value,'param2','');
                        constraint(end+1) = constraint_here;
                        log_str = cat(2,log_str,[char(parameters.input_parameters.selection(i).property) ' best value is ' num2str(stim_property_value) ',']);
                    elseif strcmpi(char(parameters.input_parameters.selection(i).value),'greatest'),
                        pva = ndi_calculator_obj.property_value_array(stim_response_doc,parameters.input_parameters.selection(i).property);
                        match = 0;
                        greatest = -Inf;
                        for j=1:numel(pva),
                            if pva{j}>greatest,
                                match = 1;
                                greatest = pva{j};
                            end;
                        end;
                        if match==0, %if it doesn't have it, then quit
                            doc = {};
                            return;
                        end;
                        stim_property_value = greatest;
                        constraint_here = struct('field',parameters.input_parameters.selection(i).property,...
                            'operation','exact_number','param1',stim_property_value,'param2','');
                        constraint(end+1) = constraint_here;
                        log_str = cat(2,log_str,[char(parameters.input_parameters.selection(i).property) ' greatest value is ' num2str(stim_property_value) ',']);
                    elseif strcmpi(char(parameters.input_parameters.selection(i).value),'least'),
                        pva = ndi_calculator_obj.property_value_array(stim_response_doc,parameters.input_parameters.selection(i).property);
                        match = 0;
                        least = Inf;
                        for j=1:numel(pva),
                            if pva{j}<least,
                                match = 1;
                                least= pva{j};
                            end;
                        end;
                        if match==0, %if it doesn't have it, then quit
                            doc = {};
                            return;
                        end;
                        stim_property_value = least;
                        constraint_here = struct('field',parameters.input_parameters.selection(i).property,...
                            'operation','exact_number','param1',stim_property_value,'param2','');
                        constraint(end+1) = constraint_here;
                        log_str = cat(2,log_str,[char(parameters.input_parameters.selection(i).property) ' least value is ' num2str(stim_property_value) ',']);
                    elseif strcmpi(char(parameters.input_parameters.selection(i).value),'deal'),
                        stim_property_list{end+1} = parameters.input_parameters.selection(i).property;
                        pva = ndi_calculator_obj.property_value_array(stim_response_doc,parameters.input_parameters.selection(i).property);
                        deal_constraints_group = vlt.data.emptystruct('field','operation','param1','param2');
                        for j=1:numel(pva),
                            deal_constraints_here.field = parameters.input_parameters.selection(i).property;
                            deal_constraints_here.operation = 'exact_number';
                            deal_constraints_here.param1 = pva{j};
                            deal_constraints_here.param2 = '';
                            deal_constraints_group(end+1) = deal_constraints_here;
                        end;
                        deal_constraints{end+1} = deal_constraints_group;
                    elseif strcmpi(char(parameters.input_parameters.selection(i).value),'varies'),
                        pva = ndi_calculator_obj.property_value_array(stim_response_doc,parameters.input_parameters.selection(i).property);
                        if numel(pva)<2, % we don't have any variation in the parameter requested, quit
                            doc = {};
                            return;
                        end;
                    else,
                        constraint_here = struct('field',parameters.input_parameters.selection(i).property,...
                            'operation',parameters.input_parameters.selection(i).operation,...
                            'param1',parameters.input_parameters.selection(i).value,...
                            'param2','');
                        constraint(end+1) = constraint_here;
                    end;
                end;

                if numel(deal_constraints)==0,
                    deal_constraints{1} = 1;
                end;
                N_deal = 1;
                deal_str = '';

                sz_ = {};
                deal_constraints_dim = [];
                for i=1:numel(deal_constraints),
                    N_deal = N_deal * numel(deal_constraints{i});
                    deal_constraints_dim(i) = numel(deal_constraints{i});
                    deal_str = cat(2,deal_str,['sz_{' int2str(i) '},']);
                end;
                deal_str(end) = '';

                % Step 3: place the results of the calculator into an NDI document
                tapp = ndi.app.stimulus.tuning_response(ndi_calculator_obj.session);

                if numel(log_str)>1,
                    if log_str(end)==',',
                        log_str(end) = '.';
                    end;
                end;
                tuningcurve_calc.log = log_str;

                doc = {};

                for i=1:N_deal,
                    deal_log_str = '';
                    stim_property_list_values = [];

                    constraints_mod = constraint;
                    eval(['[' deal_str ']=ind2sub(deal_constraints_dim,i);']);
                    for j=1:numel(deal_constraints),
                        deal_here = deal_constraints{j}(sz_{j});
                        if isstruct(deal_here),
                            constraints_mod(end+1) = deal_here;
                            deal_log_str = cat(2,deal_str,['dealing ' deal_here.field ' = ' num2str(deal_here.param1) ',']);
                            stim_prop_index = find(strcmp(deal_here.field,stim_property_list));
                            % has to be a match, all dealt properties are in stim_property_list
                            stim_property_list_values(stim_prop_index) = deal_here.param1;
                        end;
                    end;

                    tuningcurve_calc_here = tuningcurve_calc;
                    tuningcurve_calc_here.log = cat(2,tuningcurve_calc_here.log,deal_log_str);
                    tuningcurve_calc_here.stim_property_list.names = stim_property_list(:)';
                    tuningcurve_calc_here.stim_property_list.values = stim_property_list_values(:)';

                    % we use the ndi.app.stimulus.tuning_response app to actually make the tuning curve
                    doc_here = tapp.tuning_curve(stim_response_doc,'independent_label',independent_label,...
                        'independent_parameter',independent_parameter,'constraint',constraints_mod,'do_Add',0);
                    if ~isempty(doc_here), % if doc is actually created, that is, all stimuli were not excluded
                        doc_here = ndi.document(ndi_calculator_obj.doc_document_types{1},'tuningcurve_calc',tuningcurve_calc_here) + doc_here;
                        doc{end+1} = doc_here;
                    end;
                end;
                if numel(doc)==1,
                    doc = doc{1};
                end;
        end; % calculate

        function parameters = default_search_for_input_parameters(ndi_calculator_obj)
            % DEFAULT_SEARCH_FOR_INPUT_PARAMETERS - default parameters for searching for inputs
            %
            % PARAMETERS = DEFAULT_SEARCH_FOR_INPUT_PARAMETERS(NDI_CALCULATOR_OBJ)
            %
            % Returns a list of the default search parameters for finding appropriate inputs
            % to the calculator. For tuningcurve_calc, there is no appropriate default parameters
            % so this search will yield empty.
            %
                parameters.input_parameters = struct('independent_label','','independent_parameter','','best_algorithm','empirical_maximum');
                parameters.input_parameters.selection = vlt.data.emptystruct('property','operation','value');
                parameters.depends_on = vlt.data.emptystruct('name','value');
                parameters.query = ndi_calculator_obj.default_parameters_query(parameters);
                parameters.query(end+1) = struct('name','will_fail','query',...
                    ndi.query('base.id','exact_string','123',''));
                    
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
            % For the ndi.calc.stimulus.tuningcurve_calc class, this first checks to see if 
            % fixed dependencies are already specified. If not, then it looks for 
            % documents of type 'stimulus_response_scalar' with 'response_type' fields
            % the contain 'mean' or 'F1'.
            %
            %

                q_default = default_parameters_query@ndi.calculator(ndi_calculator_obj, parameters_specification);

                if ~isempty(q_default),
                    query = q_default;
                    return;
                end;

                q1 = ndi.query('','isa','stimulus_response_scalar','');
                q2 = ndi.query('stimulus_response_scalar.response_type','contains_string','mean','');
                q3 = ndi.query('stimulus_response_scalar.response_type','contains_string','F1','');
                q4 = ndi.query('stimulus_response_scalar.response_type','contains_string','F2','');
                q234 = q2 | q3 ;
                q_total = q1 & q234;

                query = struct('name','stimulus_response_scalar_id','query',q_total);
        end; % default_parameters_query()

        function b = is_valid_dependency_input(ndi_calculator_obj, name, value)
            % IS_VALID_DEPENDENCY_INPUT - is a potential dependency input actually valid for this calculator?
            %
            % B = IS_VALID_DEPENDENCY_INPUT(NDI_CALCULATOR_OBJ, NAME, VALUE)
            %
            % Tests whether a potential input to a calculator is valid.
            % The potential dependency name is provided in NAME and its base id is
            % provided in VALUE.
            %
            % The base class behavior of this function is simply to return true, but it
            % can be overriden if additional criteria beyond an ndi.query are needed to
            % assess if a document is an appropriate input for the calculator.
            %
                b = 1;
                return;
                % the below is wrong..this function does not take tuningcurves or tuningcurve_calc objects as inputs
                q1 = ndi.query('base.id','exact_string',value,'');
                q2 = ndi.query('','isa','tuningcurve_calc','');
                % can't also be a tuningcurve_calc document or we could have infinite recursion
                b = isempty(ndi_calculator_obj.session.database_search(q1&q2));
        end; % is_valid_dependency_input()

        function doc_about(ndi_calculator_obj)
            % ----------------------------------------------------------------------------------------------
            % NDI_CALCULATOR: TUNINGCURVE_CALC
            % ----------------------------------------------------------------------------------------------
            %
            %   ------------------------
            %   | TUNINGCURVE_CALC -- ABOUT |
            %   ------------------------
            %
            %   TUNINGCURVE_CALC is a demonstration document. It simply produces the 'answer' that
            %   is provided in the input parameters. Each TUNINGCURVE_CALC document 'depends_on' an
            %   NDI daq system.
            %
            %   Definition: apps/tuningcurve_calc.json
            %
                eval(['help ndi.calc.example.tuningcurve.doc_about']);
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

                tc = doc.document_properties.stimulus_tuningcurve; % shorten our typing

                % if more than 2-d, complain
                
                if numel(tc.independent_variable_label)>2,
                    a = axis;
                    h.objects(end+1) = text(mean(a(1:2)),mean(a(3:4)),['Do not know how to plot with more than 2 independent axes.']);
                    return;
                end;

                if numel(tc.independent_variable_label)==1,
                    hold on;
                    h_baseline = plot([min(tc.independent_variable_value) max(tc.independent_variable_value)],...
                        [0 0],'k--','linewidth',1.0001);
                    h_baseline.Annotation.LegendInformation.IconDisplayStyle = 'off';
                    h.objects(end+1) = h_baseline;
                    net_responses = tc.response_mean - tc.control_response_mean;
                    [v,sortorder] = sort(tc.independent_variable_value);
                    h_errorbar = errorbar(tc.independent_variable_value(sortorder(:)),...
                        net_responses(sortorder(:)),tc.response_stderr(sortorder(:)),tc.response_stderr(sortorder(:)));
                    set(h_errorbar,'color',[0 0 0],'linewidth',1);
                    h.objects = cat(2,h.objects,h_errorbar);
                    if ~h.params.suppress_x_label,
                        h.xlabel = xlabel(tc.independent_variable_label);
                    end;
                    if ~h.params.suppress_y_label,
                        h.ylabel = ylabel(['Response (' tc.response_units ')']);
                    end;
                    box off;
                end;

                if numel(tc.independent_variable_label)==2,
                    net_responses = tc.response_mean - tc.control_response_mean;
                    first_dim = unique(tc.independent_variable_value(:,1));
                    colormap = spring(numel(first_dim));
                    h_baseline = plot([min(tc.independent_variable_value(:,2)) max(tc.independent_variable_value(:,2))],...
                        [0 0],'k--','linewidth',1.0001);
                    h_baseline.Annotation.LegendInformation.IconDisplayStyle = 'off';
                    h.objects(end+1) = h_baseline;
                    hold on;
                    for i=1:numel(first_dim),
                        indexes = find(tc.independent_variable_value(:,1)==first_dim(i));
                        [v,sortorder] = sort(tc.independent_variable_value(indexes,2));
                        h_errorbar = errorbar(tc.independent_variable_value(indexes(sortorder),2),...
                            tc.response_mean(indexes(sortorder)),...
                            tc.response_stderr(indexes(sortorder)), tc.response_stderr(indexes(sortorder)));
                        set(h_errorbar,'color',colormap(i,:),'linewidth',1,...
                            'DisplayName',...
                            [tc.independent_variable_label{1} '=' num2str(tc.independent_variable_value(indexes(1),1))]);
                        h.objects = cat(2,h.objects,h_errorbar);
                    end;
                    if ~h.params.suppress_x_label,
                        h.xlabel = xlabel(tc.independent_variable_label{2});
                    end;
                    if ~h.params.suppress_y_label,
                        h.ylabel = ylabel(['Response (' tc.response_units ')']);
                    end;
                    legend;
                    box off;
                end;
        end; % plot()

        % NEW functions in tuningcurve_calc that are not overriding any superclass functions

        function [n,v,property_value] = best_value(ndi_calculator_obj, algorithm, stim_response_doc, property)
            % BEST_VALUE - calculate the stimulus with the "best" response
            %
            % [N,V,PROPERTY_VALUE] = ndi.calc.stimulus.tuningcurve.best_value(NDI_CALC_STIMULUS_TUNINGCURVE, ALGORITHM, ...
            %   STIM_RESPONSE_DOC, PROPERTY)
            %
            % Given an ndi.document of type STIMULUS_RESPONSE_SCALAR, return the stimulus presentation number N with
            % the "best" response, as determined by ALGORITHM, for any stimulus that has the property PROPERTY.  
            %
            % N is the stimulus number that meets the criteria. V is the best response value. PROPERTY_VALUE
            % is the value of the PROPERTY of stimulus N.
            %
            % The algorithms known are:
            % -------------------------------------------------------------------------------------
            % 'empirical_maximum'      | Use the stimulus with the empirically largest mean value.
            %
            %
                n = NaN;
                v = -Inf;
                switch lower(algorithm),
                    case 'empirical_maximum',
                        [n,v,property_value] = ndi_calculator_obj.best_value_empirical(stim_response_doc,property);
                    otherwise,
                        error(['Unknown algorithm ' algorithm '.']);
                end;
        end; % best_value

        function [n,v,property_value] = best_value_empirical(ndi_calculator_obj, stim_response_doc, property)
            % BEST_VALUE_EMPIRICAL - find the best response value for a given stimulus property
            %
            % [N, V, PROPERTY_VALUE] = ndi.calc.stimulus.tuningcurve.best_value_empirical(NDI_CALC_STIMULUS_TUNINGCURVE_OBJ, STIM_RESPONSE_DOC, PROPERTY)
            %
            % Given an ndi.document of type STIMULUS_RESPONSE_SCALAR, return the stimulus presentation number N with
            % largest mean response for any stimulus that has the property PROPERTY.  If the value is complex-valued,
            % then the largest absolute value is used.
            %
            % N is the stimulus number that meets the criteria. V is the best response value. PROPERTY_VALUE
            % is the value of the PROPERTY of stimulus N.
            %
            % If this function cannot find a stimulus presentation document for the STIM_RESPONSE_DOC, it produces
            % an error.
            %
                stim_pres_doc = ndi_calculator_obj.session.database_search(ndi.query('base.id', 'exact_string', ...
                                        stim_response_doc.dependency_value('stimulus_presentation_id'),''));

                if numel(stim_pres_doc)~=1, 
                    error(['Could not find stimulus presentation doc for document ' stim_response_doc.id() '.']);
                end;
                stim_pres_doc = stim_pres_doc{1};

                % see which stimuli to include

                include = [];
                for i=1:numel(stim_pres_doc.document_properties.stimulus_presentation.stimuli),
                    if isfield(stim_pres_doc.document_properties.stimulus_presentation.stimuli(i).parameters,property),
                        include(end+1) = i;
                    end;
                end;

                n = NaN;
                v = -Inf;
                property_value = '';

                R = stim_response_doc.document_properties.stimulus_response_scalar.responses;

                for i=1:numel(include),
                    indexes = find(stim_pres_doc.document_properties.stimulus_presentation.presentation_order==include(i));
                    r_value = [];
                    if ~isempty(indexes),
                        for j=1:numel(indexes),
                            r_value(end+1) = R.response_real(indexes(j)) + sqrt(-1)*R.response_imaginary(indexes(j));
                            control_value = R.control_response_real(indexes(j)) + sqrt(-1)*R.control_response_imaginary(indexes(j));
                            if ~isnan(control_value),
                                r_value(end) = r_value(end) - control_value;
                            end;
                        end;
                        mn = nanmean(r_value);
                        if ~isreal(mn),
                            mn = abs(mn);
                        end;
                        if mn> v,
                            v = mn;
                            n = include(i);
                            property_value = getfield(stim_pres_doc.document_properties.stimulus_presentation.stimuli(include(i)).parameters,property);
                        end;
                    end;
                end;

        end; % best_value_empirical()

        function [pva] = property_value_array(ndi_calculator_obj, stim_response_doc, property)
            % PROPERTY_VALUE_ARRAY - find all values of a stimulus property
            %
            % [PVA] = ndi.calc.stimulus.tuningcurve.property_value_array(NDI_CALC_STIMULUS_TUNINGCURVE_OBJ, STIM_RESPONSE_DOC, PROPERTY)
            %
            % Given an ndi.document of type STIMULUS_RESPONSE_SCALAR, return all values of the parameter PROPERTY that were
            % used in the stimulus.
            %
            % Values will be returned in a cell array.
            %
            % If this function cannot find a stimulus presentation document for the STIM_RESPONSE_DOC, it produces
            % an error.
            %
                stim_pres_doc = ndi_calculator_obj.session.database_search(ndi.query('base.id', 'exact_string', ...
                                        stim_response_doc.dependency_value('stimulus_presentation_id'),''));

                if numel(stim_pres_doc)~=1, 
                    error(['Could not find stimulus presentation doc for document ' stim_response_doc.id() '.']);
                end;
                stim_pres_doc = stim_pres_doc{1};

                pva = {};

                for i=1:numel(stim_pres_doc.document_properties.stimulus_presentation.stimuli),
                    if isfield(stim_pres_doc.document_properties.stimulus_presentation.stimuli(i).parameters,property),
                        % why not just use UNIQUE? because it cares about whether the data are numbers or strings, doesn't work on numbers
                        value_here = getfield(stim_pres_doc.document_properties.stimulus_presentation.stimuli(i).parameters,property);
                        match_already = 0;
                        for k=1:numel(pva),
                            if vlt.data.eqlen(pva{k},value_here),
                                match_already = 1;
                                break;
                            end;
                        end;
                        if ~match_already,
                            pva{end+1} = value_here;
                        end;
                    end;
                end;

        end; % property_value_array
    end; % methods()
end % tuningcurve
