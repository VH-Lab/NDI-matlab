function catalog = loadOpenMindsInstanceCatalog(openMindsType, options)
    % loadOpenMindsInstanceCatalog - Get a catalog of controlled instances from openMINDS
    %
    %   Syntax
    %       catalog = ndi.database.metadata_app.fun.loadOpenMindsInstanceCatalog(openMindsType)
    %
    %   Input arguments
    %       openMindsType - Name of the openMINDS type, i.e "Species"
    %
    %   Output arguments
    %       catalog - A catalog of openMINDS controlled instances.

    arguments
        openMindsType (1,1) string
        options.PrimaryField = "name"
    end

    instanceTable = openminds.internal.listControlledInstances(openMindsType);

    names = instanceTable.InstanceName;

    catalog = Catalog();
    catalog.NameField = options.PrimaryField;

    for i = 1:numel(names)
        S = openminds.internal.getControlledInstance(names{i}, openMindsType, 'controlledTerms');
        catalog.add(S)
    end
end
