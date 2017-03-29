function exp_var = NSD_exp_variable_regions( type, owner, data, description )
%SAPI_EXP_VARIABLE_REGIONS - Create a new EXPERIMENT VARIABLE REGIONS object
%
% EXP_VAR = SAPI_EXP_VARIABLE_REGIONS(TYPE, OWNER, DATA, DESCRIPTION) creates a new EXPERIMENT VARIABLE REGIONS object. The experiment has
% several attributes including type, owner, data and description
% This class is an subclass of the abstract experiment variable class.
%

if nargin <4,
	error(['Not enough input arguments.']);
elseif nargin == 4,
    NSD_exp_varible_struct = struct('type',type, 'owner',owner,'data',data,'description',description);
    s = exp_var(NSD_exp_varible_struct,'NSD_exp_variable_regions');
else,
    error(['Too many input arguments.']);
end
end

