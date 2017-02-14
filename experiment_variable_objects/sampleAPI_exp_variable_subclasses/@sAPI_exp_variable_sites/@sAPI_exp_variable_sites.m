function exp_var = sAPI_exp_variable_sites( type, owner, data, description )
%SAPI_EXP_VARIABLE_SITES - Create a new EXPERIMENT VARIABLE SITES object
%
% EXP_VAR = SAPI_EXP_VARIABLE_SITES(TYPE, OWNER, DATA, DESCRIPTION) creates a new EXPERIMENT VARIABLE SITES object. The experiment has
% several attributes including type, owner, data and description
% This class is an subclass of the abstract experiment variable class.
%

if nargin <4,
	error(['Not enough input arguments.']);
elseif nargin == 4,
    sampleAPI_exp_varible_struct = struct('type',type, 'owner',owner,'data',data,'description',description);
    s = exp_var(sampleAPI_exp_varible_struct,'sAPI_exp_variable_sites');
else,
    error(['Too many input arguments.']);
end
end

