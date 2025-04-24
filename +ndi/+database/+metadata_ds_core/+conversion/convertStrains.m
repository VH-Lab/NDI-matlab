function [strainInstanceMap] = convertStrains(items)

    import ndi.database.metadata_ds_core.conversion.internal.createInstance
    
    strainInstanceMap = containers.Map();

    % Convert items without background strains
    for i = 1:numel(items)
        thisItem = items(i);
        thisItem = rmfield(thisItem, 'backgroundStrain');

        thisInstance = createInstance(thisItem, 'openminds.core.Strain');

        strainInstanceMap(thisItem.name) = thisInstance;
    end

    % "Recursively" link together background strains
    for i = 1:numel(items)
        thisItem = items(i);
        thisInstance = strainInstanceMap(thisItem.name);

        for j = 1:numel(thisItem.backgroundStrain)
            bgStrainName = thisItem.backgroundStrain(j);
            bgInstance = strainInstanceMap(bgStrainName);
            thisInstance.backgroundStrain(j) = bgInstance;
        end
    end
end
