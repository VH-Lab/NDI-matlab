function d = sAPI_image(name, exp)
% SAPI_IMAGE - Create a new SAPI_IMAGE object
%
%  D = SAPI_IMAGE(NAME, EXP)
%
%  Creates a new SAPI_IMAGE object with the name NAME and associated
%  with experiment EXP.
%  This is an abstract class that is overridden by specific devices.
%  %

sAPI_multifunctionDAQ_struct = struct('exp',exp); 


d = class(sAPI_image_struct, 'sAPI_image',sampleAPI_device(name));
