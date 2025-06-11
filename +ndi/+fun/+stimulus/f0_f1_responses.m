function [f0,f1,f0_tuningcurve_doc,f1_tuningcurve_doc] = f0_f1_responses(S, doc, response_index)
    % F0_F1_RESPONSES - get the F0 and F1 responses for a tuning curve document
    %
    % [F0,F1] = F0_F1_RESPONSES(S, DOC, [STIMULUS_INDEX])
    %
    % Given an ndi.document object of type stimulus_tuningcurve (or a document that has a single
    % dependency of 'stimulus_tuningcurve_id'), and a response_index number (the entry in the 'mean'
    % response array of responses), this function returns the f0 and f1 responses for that stimulus.
    % This function looks up the appropriate stimulus_tuningcurve objects.
    %
    % If STIMULUS_INDEX is not given, then the overall maximum response rate (either mean or F1)
    % is examined and that location is taken as the STIMULUS_INDEX.
    %

    f0 = NaN;
    f1 = NaN;
    f0_tuningcurve_doc = [];
    f1_tuningcurve_doc = [];

    if nargin<3
        response_index = [];
    end

    [rt,stim_resp_scalar_doc] = ndi.fun.stimulus.tuning_curve_to_response_type(S,doc);

    % pass 1: find the tuning curve associated with the doc we are given

    if doc.doc_isa('stimulus_tuningcurve')
        % we have a tuning curve
        tc_doc = doc;
    else
        d = doc.dependency_value('stimulus_tuningcurve_id','ErrorIfNotFound',0);
        if ~isempty(d)
            q_doc = ndi.query('base.id','exact_string',d);
            newdoc = S.database_search(q_doc);
            if numel(newdoc)~=1
                error(['Could not find dependent doc ' d '.']);
            end
            tc_doc = newdoc{1};
        else
            error(['DOC is not a stimulus_tuningcurve AND it does not have a dependency of ''stimulus_tuningcurve_id''.']);
        end
    end

    switch lower(rt)
        case 'mean'
            f0_tuning_curve = tc_doc;
            target_response_type = 'F1';

        case 'f1'
            f1_tuning_curve = tc_doc;
            target_response_type = 'mean';

        otherwise
            error(['Unknown response type (expected mean or F1): ' rt]);
    end

    % how to find tuning curve for f1?
    % first find stimulus responses
    element_id = tc_doc.dependency_value('element_id');
    q1 = ndi.query('','depends_on','element_id',element_id);
    q2 = ndi.query('','isa','stimulus_response_scalar');
    q3 = ndi.query('stimulus_response.stimulator_epochid','exact_string', ...
        stim_resp_scalar_doc.document_properties.stimulus_response.stimulator_epochid);
    q4 = ndi.query('stimulus_response.element_epochid','exact_string', ...
        stim_resp_scalar_doc.document_properties.stimulus_response.element_epochid);
    q5 = ndi.query('stimulus_response_scalar.response_type','exact_string',target_response_type);

    candidate_stim_resp_scalars = S.database_search(q1&q2&q3&q4&q5);

    q_tc_r = [];
    for i=1:numel(candidate_stim_resp_scalars)
        q_here = ndi.query('','depends_on','stimulus_response_scalar_id',...
            candidate_stim_resp_scalars{i}.id());
        if isempty(q_tc_r)
            q_tc_r = q_here;
        else
            q_tc_r = q_tc_r | q_here;
        end
    end
    if isempty(q_tc_r) % we don't have any
        return;
    end

    tc_candidates = S.database_search(q_tc_r&ndi.query('','isa','stimulus_tuningcurve'));
    matches = [];
    for i=1:numel(tc_candidates)
        if vlt.data.eqlen(tc_candidates{i}.document_properties.stimulus_tuningcurve.independent_variable_label, ...
                tc_doc.document_properties.stimulus_tuningcurve.independent_variable_label)
            matches(end+1) = i;
        end
    end

    if numel(matches)>1
        warning(['Too many ' target_response_type ' found (' int2str(numel(matches))   ').']);
        matches = matches(1);
    end

    if numel(matches)==0
        error(['No corresponding ' target_response_type ' found.']);
    elseif numel(matches)>1
        error(['Too many ' target_response_type ' found (' int2str(numel(matches))   ').']);
    else
        switch (rt)
            case 'mean'
                f1_tuning_curve = tc_candidates{matches};
            case 'F1'
                f0_tuning_curve = tc_candidates{matches};
        end
    end

    % now we have f1_tuning_curve and f0_tuning_curve

    resp_f0 = ndi.app.stimulus.tuning_response.tuningcurvedoc2vhlabrespstruct(f0_tuning_curve);
    resp_f1 = ndi.app.stimulus.tuning_response.tuningcurvedoc2vhlabrespstruct(f1_tuning_curve);

    if isempty(response_index) % have to figure it out
        [mx_f0,mx_local_f0] = max(resp_f0.curve(2,:));
        [mx_f1,mx_local_f1] = max(resp_f1.curve(2,:));
        if mx_f0 > mx_f1
            response_index = mx_local_f0;
        else
            response_index = mx_local_f1;
        end
    end

    f0 = resp_f0.curve(2,response_index);
    f1 = resp_f1.curve(2,response_index);
