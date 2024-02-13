function instanceCatalog = loadUserInstanceCatalog(openMindsType, options)
% loadUserInstanceCatalog - Load a catalog of user metadata instances

    arguments
        openMindsType (1,1) string
        options.PrimaryField = "name"
    end

    import ndi.database.metadata_app.fun.getOpenmindsInstanceFile

    filename = sprintf('%s_instances.mat', lower(openMindsType) );
    filePath = getOpenmindsInstanceFile(filename);
    instanceCatalog = PersistentCatalog("SaveFolder", filePath);

    % Todo: Get the map for determining the "name" field from openMINDS repo...
    instanceCatalog.NameField = options.PrimaryField;
end