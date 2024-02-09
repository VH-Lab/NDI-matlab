function instances = loadUserInstances(name)
% loadUserInstances - Load user instances of metadata based on openMINDS
%
%   Syntax:
%       instances = ndi.database.metadata_app.fun.loadUserInstances(name)
%
%   Input arguments:
%       name - A name describing what kind of instances to load.
%
%   Output arguments:
%       instances - A struct array of instances
%
%   See also ndi.database.metadata_app.fun.saveUserInstances
    
%   Todo: These instances should be loaded from jsonld files based on 
%   the openminds serialization. 

    arguments
        name (1,1) string
    end

    import ndi.database.metadata_app.fun.getOpenmindsInstanceFile

    filename = sprintf('%s_instances.mat', name);
    loadPath = getOpenmindsInstanceFile(filename);
    
    if isfile(loadPath)
        S = load(loadPath);
        instances = S.instances;
    else
        instances = struct.empty;
    end
end