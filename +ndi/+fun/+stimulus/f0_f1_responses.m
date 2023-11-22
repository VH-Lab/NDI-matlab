function [f0,f1] = f0_f1_responses(S, doc, stimulus_index)
% F0_F1_RESPONSES - get the F0 and F1 responses for a tuning curve document 
%
% [F0,F1] = F0_F1_RESPONSES(S, DOC, [STIMULUS_INDEX])
%
% Given an ndi.document object of type stimulus_tuningcurve and a stimulus index,
% returns the f0 and f1 responses for that stimulus. This function looks up the 
% appropriate stimulus_tuningcurve objects.
% 
% If STIMULUS_INDEX is not given, then the overall maximum response rate (either mean or F1)
% is examined and that location is taken as the STIMULUS_INDEX.
% 

response_type = '';
stim_response_scalar_doc = {};

dependency_list_to_check = {'stimulus_response_scalar_id',...
	'stimulus_tuningcurve_id'};

dependency_action = {'finish', 'recursive'};

for i=1:numel(dependency_list_to_check),
	d = doc.dependency_value(dependency_list_to_check{i},'ErrorIfNotFound',0);
	if ~isempty(d),
		q_doc = ndi.query('base.id','exact_string',d);
		newdoc = S.database_search(q_doc);
		if numel(newdoc)~=1,
			error(['Could not find dependent doc ' d '.']);
		end;
		switch(dependency_action{i}),
			case 'recursive',
				[response_type,stim_response_scalar_doc] = ndi.fun.stimulus.tuning_curve_to_response_type(S,newdoc{1});
				return;
			case 'finish',
				try,
					response_type = newdoc{1}.document_properties.stimulus_response_scalar.response_type;
                    stim_response_scalar_doc = newdoc{1};
				catch,
					error(['Could not find field ''response_type'' in document.']);
				end;
				return;
			otherwise,
				error(['Unknown action type']);
		end;
	end;
end;

