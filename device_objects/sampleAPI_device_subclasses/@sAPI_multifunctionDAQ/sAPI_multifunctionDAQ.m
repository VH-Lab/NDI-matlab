function d = sAPI_multifunctionDAQ(name, exp)
% SAPI_MULTIFUNCTIONDAQ - Create a new SAPI_MULTIFUNCTIONDAQ object
%
%  D = SAPI_MULTIFUNCTIONDAQ(NAME, EXP)
%
%  Creates a new SAPI_MULTIFUNCTIONDAQ object with the name NAME and associated
%  with experiment EXP.
%  This is an abstract class that is overridden by specific devices.
%  %

sAPI_multifunctionDAQ_struct = struct('exp',exp); 


d = class(sAPI_multifunctionDAQ_struct, 'sAPI_multifunctionDAQ',sampleAPI_device(name));
