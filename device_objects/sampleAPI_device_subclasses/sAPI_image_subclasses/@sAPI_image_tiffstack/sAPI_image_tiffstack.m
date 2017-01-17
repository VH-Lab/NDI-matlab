function d = sAPI_image_tiffstack(name, exp)
% SAPI_IMAGE_TIFFSTACK - Create a new SAPI_IMAGE_TIFFSTACK object
%
%  D = SAPI_IMAGE_TIFFSTACK(NAME, EXP)
%
%  Creates a new SAPI_IMAGE_TIFFSTACK object with the name NAME and associated
%  with experiment EXP.
%  This is an abstract class that is overridden by specific devices.
%  %

sAPI_image_tiffstack_struct = struct([]); 
S = sAPI_image(name,exp);

d = class(sAPI_image_tiffstack_struct, 'sAPI_image_tiffstack',S);

