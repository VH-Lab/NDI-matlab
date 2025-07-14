function [response_type,stim_response_scalar_doc] = tuning_curve_to_response_type(S, doc)
    % TUNING_CURVE_TO_RESPONSE_TYPE - get the response type ('mean', 'F1', etc) of a tuning curve document
    %
    % [RESPONSE_TYPE,STIM_RESPONSE_SCALAR_DOC] = ndi.fun.stimulus.tuning_curve_to_response_type(S, DOC)
    %
    % Given an ndi.document object DOC that is either a stimulus_tuningcurve or a
    % document that has a dependency, 'stimulus_tuningcurve_id', this function
    % looks up the 'stimulus_response_scalar' document and returns its
    % 'response_type' field. This is typically 'mean', 'F1','F2', etc.
    %

    response_type = '';
    stim_response_scalar_doc = {};

    dependency_list_to_check = {'stimulus_response_scalar_id',...
        'stimulus_tuningcurve_id'};

    dependency_action = {'finish', 'recursive'};

    for i=1:numel(dependency_list_to_check)
        d = doc.dependency_value(dependency_list_to_check{i},'ErrorIfNotFound',0);
        if ~isempty(d)
            q_doc = ndi.query('base.id','exact_string',d);
            newdoc = S.database_search(q_doc);
            if numel(newdoc)~=1
                error(['Could not find dependent doc ' d '.']);
            end
            switch(dependency_action{i})
                case 'recursive'
                    [response_type,stim_response_scalar_doc] = ndi.fun.stimulus.tuning_curve_to_response_type(S,newdoc{1});
                    return;
                case 'finish'
                    try
                        response_type = newdoc{1}.document_properties.stimulus_response_scalar.response_type;
                        stim_response_scalar_doc = newdoc{1};
                    catch
                        error(['Could not find field ''response_type'' in document.']);
                    end
                    return;
                otherwise
                    error(['Unknown action type']);
            end
        end
    end
