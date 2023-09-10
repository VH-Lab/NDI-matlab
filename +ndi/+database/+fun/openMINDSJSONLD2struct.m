function s = openMINDSJSONLD2struct(openMindsInstance)
% openMINDSJSONLD2struct - convert an openMINDS JSON-LD instance to a Matlab structure
%
% S = ndi.database.fun.openMINDSJSONLD2struct(OPENMINDSINTSTANCE)
%
% Creates a Matlab structure S from an openMINDS JSON-LD instance.
% 
% Example:
%   p = organizationWithTwoIds();
%   i = saveInstances(p);
% 

g = jsondecode(openMindsInstance);

 % required fields, x_context, x_type, x_id

for i=1:numel(g),
    fn = fieldnames(g{i});
    for j=1:numel(fn),

    end;

end;
