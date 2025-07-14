function format_names = find_instance_name(unformat_names,value)
    %FIND_INSTANCE_NAME Summary of this function goes here
    %   Detailed explanation goes here

    if (strcmp(value,'TechniquesEmployed'))
        format_names = ndi.util.openminds.find_techniques_names(unformat_names);
        return;
    else
        [names, ~] = ndi.database.metadata_app.fun.getOpenMindsInstances(value);
        names = names';
    end

    for i = 1:numel(names)
        command = sprintf('openminds.controlledterms.%s(names{i})',value);
        obj{i} = eval(command);
        all_names{i}  = obj{i}.name;
    end

    isMember = cellfun(@(x) any(ismember(x, unformat_names)), all_names);
    format_names = names(isMember);
end
