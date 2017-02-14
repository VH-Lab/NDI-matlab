function exp_var = sampleAPI_exp_variable( type, owner, data, description )
%EXPERIMENT_VARIABLE_OBJECT - Create a new EXPERIMENT VARIABLE object
%
% VAR = SAMPLEAPI_VARIABLE(TYPE, OWNER, DATA, DESCRIPTION) creates a new EXPERIMENT VARIABLE object. The experiment has
% several attributes including type, owner, data and description
% This class is an abstract class and typically an end user will open a specific subclass.
%

if nargin <4,
	error(['Not enough input arguments.']);
elseif nargin == 4,
    sampleAPI_exp_varible_struct = struct('type',type, 'owner',owner,'data',data,'description',description);
    s = exp_var(sampleAPI_exp_varible_struct,'sampleAPI_exp_variable');
else,
    error(['Too many input arguments.']);
end


end

