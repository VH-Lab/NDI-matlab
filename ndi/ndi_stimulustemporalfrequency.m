function [tf_value, tf_name] = ndi_stimulustemporalfrequency(stimulus_parameters)
% NDI_STIMULUSTEMPORALFREQUENCY - given a stimulus parameter set, return the temporal frequency
%
% [TF_VALUE, TF_NAME] = NDI_STIMULUSTEMPORALFREQUENCY(STIMULUS_PARAMETERS)
%
% Given a set of STIMULUS_PARAMETERS (a structure array), this function will
% check to see if any names match those in NDI_STIMULUSTEMPORALFREQUENCY.JSON.
% If so, the value for this stimulus is returned in TF_VALUE and the name of
% the parameter is returned in TF_NAME.
%
% If no temporal frequency can be determined, TF_VALUE and TF_NAME are blank.
%

tf_value = [];
tf_name = '';

ndi_globals;

j = textfile2char([ndicommonpath filesep 'stimulus' filesep 'ndi_stimulusparameters2temporalfrequency.json']);

ndi_stimTFinfo = jsondecode(j);

for i=1:numel(ndi_stimTFinfo),
	if ~isempty(intersect(fieldnames(stimulus_parameters),ndi_stimTFinfo(i).parameter_name)),
		% have a match
		tf_value = getfield(stimulus_parameters,ndi_stimTFinfo(i).parameter_name);
		tf_value = ndi_stimTFinfo(i).temporalFrequencyAdder + ndi_stimTFinfo(i).temporalFrequencyMultiplier * tf_value;
		tf_name = ndi_stimTFinfo(i).parameter_name;
		return;
	end;
end;

