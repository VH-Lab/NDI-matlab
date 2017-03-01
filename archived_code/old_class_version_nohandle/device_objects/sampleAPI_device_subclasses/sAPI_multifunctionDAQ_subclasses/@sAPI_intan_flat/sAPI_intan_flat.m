function d = sAPI_intan_flat(name, thedatatree, exp)
% SAPI_INTAN_FLAT - Create a new SAPI_INTAN_FLAT object
%
%  D = SAPI_INTAN_FLAT(NAME,THEDATATREE, EXP)
%
%  Creates a new SAPI_INTAN_FLAT object with NAME, THEDATATREE and
%  associated EXP
%  

sAPI_intan_flat_struct = struct([]); 
S = sAPI_multifunctionDAQ(name,thedatatree,exp);

d = class(sAPI_intan_flat_struct, 'sAPI_intan_flat',S);





