function [names, shortNames] = getCCByLicences()
    % getCCByLicences - Get names and short names for CC BY licences from openMINDS
    %
    %   Syntax
    %       [names, shortNames] = ndi.database.metadata_app.fun.getCCByLicences()

    %   Output arguments
    %       names - String array of openMINDS names for cc by licenses
    %       shortNames - String array of corresponding short names

    instanceTable = openminds.internal.listControlledInstances('License');
    isCcBy = contains(instanceTable.InstanceName, 'CC-BY');

    names = instanceTable.InstanceName(isCcBy);
    filePaths = instanceTable.Filepath(isCcBy);
    shortNames = repmat("", size(names));
    for i = 1:numel(names)
        S = openminds.internal.utility.json.decode(fileread(filePaths(i)));
        shortNames(i) = S.shortName;
    end
end
