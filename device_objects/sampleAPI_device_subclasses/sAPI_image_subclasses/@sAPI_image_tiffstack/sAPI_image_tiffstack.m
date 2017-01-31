function d = sAPI_image_tiffstack(name,thedatatree, exp)
% SAPI_IMAGE_TIFFSTACK - Create a new SAPI_IMAGE_TIFFSTACK object
%
%  D = SAPI_IMAGE_TIFFSTACK(NAME, THEDATATREE,EXP)
%
%  Creates a new SAPI_IMAGE_TIFFSTACK object with NAME, THEDATAREE and associated EXP.
%  

sAPI_image_tiffstack_struct = struct([]); 
S = sAPI_image(name,thedatatree,exp);

d = class(sAPI_image_tiffstack_struct, 'sAPI_image_tiffstack',S);

