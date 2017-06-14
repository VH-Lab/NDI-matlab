function d = NSD_multifunctionDAQ(name, thefiletree, exp)
% SAPI_MULTIFUNCTIONDAQ - Create a new SAPI_MULTIFUNCTIONDAQ object
%
%  D = SAPI_MULTIFUNCTIONDAQ(NAME, THEFILETREE, EXP)
%
%  Creates a new SAPI_MULTIFUNCTIONDAQ object with NAME, FILETREE and associated EXP.
%  This is an abstract class that is overridden by specific devices.
%  

NSD_multifunctionDAQ_struct = struct('exp',exp); 


d = class(NSD_multifunctionDAQ_struct, 'NSD_multifunctionDAQ',NSD_device(name,thefiletree));
