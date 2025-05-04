function strainInstanceMap = getAllStrains()

    import ndi.database.metadata_app.fun.loadUserInstanceCatalog
    import ndi.database.metadata_ds_core.conversion.convertStrains

    strainCatalog = loadUserInstanceCatalog('Strain');

    % Todo: Adapt conversion to also convert custom species.
    strainInstanceMap = convertStrains(strainCatalog.getAll() );
end
