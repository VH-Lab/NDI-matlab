function dataType = load_dataType_from_cloud(dataType_names)
%LOAD_DATATYPE_FROM_CLOUD Summary of this function goes here
%   Detailed explanation goes here
[names, options] = ndi.database.metadata_app.fun.getOpenMindsInstances("SemanticDataType");
for i = 1:numel(names)
    dt_obj{i} = openminds.controlledterms.SemanticDataType(names{i});
    dt_names{i}  = dt_obj{i}.name;
end

isMember = cellfun(@(x) any(ismember(x, dataType_names)), dt_names);
dataType = names(isMember);
end

