function varargout = parseOpenMINDSAtID(semanticName)
    % parseOpenMINDSAtID - Parse an openMINDS @id
    %
    %   Syntax:
    %       S = parseOpenMINDSAtID(semanticName)
    %
    %       [type, name] = parseOpenMINDSAtID(semanticName)
    %
    %   Input:
    %       semanticName : A URI representing an openMINDS instance @id. Ex: https://openminds.ebrains.eu/instances/geneticStrainType/knockout
    %
    %   Output:
    %       S : A struct with fields
    %           - Type
    %           - Name
    %
    %       OR
    %
    %       type : openMINDS type, i.e schema specification
    %       name : name of instance
    %
    %   Example:
    %
    %    atId = "https://openminds.ebrains.eu/instances/geneticStrainType/knockout"
    %    S = ndi.database.metadata_app.fun.parseOpenMINDSAtID(atId)
    %
    %    S =
    %
    %      struct with fields:
    %
    %        Type: "geneticStrainType"
    %        Name: "knockout"

    URI = matlab.net.URI(semanticName);

    URIPath = URI.Path;
    URIPath(URIPath=="")=[];

    assert( URIPath(1) == "instances", ...
        'Provided value "%s" is not a valid @id', semanticName)

    type = URIPath(2);
    name = URIPath(3);

    if nargout <= 1
        varargout = {struct('Type', type, 'Name', name)};
    else
        varargout = {type, name};
    end
end
