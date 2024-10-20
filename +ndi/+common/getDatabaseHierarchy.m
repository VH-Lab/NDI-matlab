function databaseHierarchy = getDatabaseHierarchy()
    
    persistent cachedDatabaseHierarchy
    if isempty(cachedDatabaseHierarchy)
        cachedDatabaseHierarchy = ndi.database.fun.databasehierarchyinit();
    end
    databaseHierarchy = cachedDatabaseHierarchy;
end
