function saveUserInstances(name, instances)
    % saveUserInstances - Save user instances of metadata based on openMINDS
    %
    %   Syntax:
    %       ndi.database.metadata_app.fun.saveUserInstances(name, instance)
    %
    %   Input arguments:
    %       name - A name describing what kind of instances are saved.
    %       instances - A struct array of instances
    %
    %   See also ndi.database.metadata_app.fun.loadUserInstances

    %   Todo: These instances should be saved as jsonld files based on the
    %   openminds serialization.

    arguments
        name (1,1) string
        instances (1,:) struct
    end

    import ndi.database.metadata_app.fun.getOpenmindsInstanceFile

    filename = sprintf('%s_instances.mat', name);
    savePath = getOpenmindsInstanceFile(filename);
    save(savePath, 'instances')
end
