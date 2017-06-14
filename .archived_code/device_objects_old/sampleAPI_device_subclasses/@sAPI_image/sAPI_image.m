function d = NSD_image(name, thefiletree,exp)
% SAPI_IMAGE - Create a new SAPI_IMAGE object
%
%  D = SAPI_IMAGE(NAME, THEFILETREE,EXP)
%
%  Creates a new SAPI_IMAGE object with NAME, THEFILETREE and associated EXP.
%  This is an abstract class that is overridden by specific devices.
%  

NSD_image_struct = struct('exp',exp); 


d = class(NSD_image_struct, 'NSD_image',NSD_device(name,thefiletree));
