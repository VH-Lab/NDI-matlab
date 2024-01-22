function [names, labels] = getOpenMindsInstances(schemaName, addOptions)
% getCCByLicences - Get names and short names for controlled term instances from openMINDS
%   
%   Syntax
%       [names, labels] = ndi.database.metadata_app.fun.getOpenMindsInstances(schemaName)

%   Output arguments
%       names - String array of openMINDS names 
%       labels - String array of corresponding labels

    if nargin < 2; addOptions = false; end
    
    instanceTable = openminds.internal.listControlledInstances(schemaName);

    names = instanceTable.InstanceName;
    labels = repmat("", size(names));

    for i = 1:numel(names)
        S = openminds.internal.getControlledInstance(names{i}, schemaName, 'controlledTerms');
        labels(i) = S.name;
    end

    if addOptions
        [labels, names] = ndi.database.metadata_app.fun.expandDropDownItems(labels, names, schemaName);
    end
end