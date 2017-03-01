function d = sAPI_image(name, thedatatree,exp)
% SAPI_IMAGE - Create a new SAPI_IMAGE object
%
%  D = SAPI_IMAGE(NAME, THEDATATREE,EXP)
%
%  Creates a new SAPI_IMAGE object with NAME, THEDATATREE and associated EXP.
%  This is an abstract class that is overridden by specific devices.
%  

sAPI_image_struct = struct('exp',exp); 


d = class(sAPI_image_struct, 'sAPI_image',sampleAPI_device(name,thedatatree));
