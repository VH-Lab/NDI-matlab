function log_str = stimulus_tuningcurve_log(S, doc)
% STIMULUS_TUNINGCURVE_LOG - retrieve stimulus_tuningcurve log string from dependent document
%
% LOG_STR = STIMULUS_TUNINGCURVE_LOG(S, DOC)
%
% Given an ndi.document that has a dependency 'stimulus_tuningcurve_id'
% that was created by ndi.calc.stimulus.tuningcuve, 
% this function looks up the DOC's dependent tuningcurve_calc document
% and retrieves the 'log' string field.
% 

log_str = '';

stim_tune_doc_id = doc.dependency_value('stimulus_tuningcurve_id');

q1 = ndi.query('base.id','exact_string',stim_tune_doc_id);
q2 = ndi.query('','isa','tuningcurve_calc');

stim_tune_doc = S.database_search(q1&q2);

if ~isempty(stim_tune_doc),
	if isfield(stim_tune_doc{1}.document_properties.tuningcurve_calc,'log'),
		log_str = stim_tune_doc{1}.document_properties.tuningcurve_calc.log;
	end;
end;


