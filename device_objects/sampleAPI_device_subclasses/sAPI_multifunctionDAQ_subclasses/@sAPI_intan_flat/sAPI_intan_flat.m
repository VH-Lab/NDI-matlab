function d = sAPI_intan_flat(name, exp)
% SAPI_INTAN_FLAT - Create a new SAPI_INTAN_FLAT object
%
%  D = SAPI_INTAN_FLAT(NAME, EXP)
%
%  Creates a new SAPI_INTAN_FLAT object with the name NAME and associated
%  with experiment EXP.
%  This is an abstract class that is overridden by specific devices.
%  %

sAPI_intan_flat_struct = struct([]); 
S = sAPI_multifunctionDAQ(name,exp);

d = class(sAPI_intan_flat_struct, 'sAPI_intan_flat',S);

