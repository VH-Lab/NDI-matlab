function techniques = find_techniques_names(unformatted_names)
%FIND_TECHNIQUES_NAMES Summary of this function goes here
%   Detailed explanation goes here


allowedTypes = openminds.core.DatasetVersion.LINKED_PROPERTIES.technique;
allowedTypes = replace(allowedTypes, 'openminds.controlledterms.', '');
name_to_technique = containers.Map();
for i = 1:numel(allowedTypes)
    type = allowedTypes{i};
    [names, ~] = ndi.database.metadata_app.fun.getOpenMindsInstances(type);
    for j = 1:numel(names)
        technique = sprintf('%s (%s)', names{i}, allowedTypes{i});
        command = sprintf('openminds.controlledterms.%s(names{j})',type);
        obj = eval(command);
        name_to_technique(obj.name) = technique;
    end
end

techniques = cell(size(unformatted_names));
for i = 1:numel(unformatted_names)
    if isKey(name_to_technique, unformatted_names{i})
        techniques{i} = name_to_technique(unformatted_names{i});
    else
        techniques{i} = 'InvalidFormat';
    end
end

end