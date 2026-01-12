function mustBeClassnameOfType(classname, requiredType)
% MUSTBECLASSNAMEOFTYPE - validation function that checks if a classname is a subclass of a required type
%
% MUSTBECLASSNAMEOFTYPE(CLASSNAME, REQUIREDTYPE)
%
% Checks if CLASSNAME is a valid class name and if it inherits from REQUIREDTYPE.
% Throws an error if not.
%

    % Check input types
    if ~ischar(classname) && ~isstring(classname)
        error('ndi:validators:mustBeClassnameOfType:invalidType', 'Input must be a character array or string.');
    end

    if ~ischar(requiredType) && ~isstring(requiredType)
        error('ndi:validators:mustBeClassnameOfType:invalidType', 'Required type must be a character array or string.');
    end

    classname = char(classname);
    requiredType = char(requiredType);

    % Check if class exists
    if exist(classname, 'class') == 0
        error('ndi:validators:mustBeClassnameOfType:classNotFound', ['Class ' classname ' does not exist.']);
    end

    % Check inheritance
    try
        metaObj = meta.class.fromName(classname);
        if isempty(metaObj)
             error('ndi:validators:mustBeClassnameOfType:metaInfoMissing', ['Could not obtain meta information for class ' classname '.']);
        end
    catch
        error('ndi:validators:mustBeClassnameOfType:metaInfoError', ['Error obtaining meta information for class ' classname '.']);
    end

    if ~checkInheritance(metaObj, requiredType)
        error('ndi:validators:mustBeClassnameOfType:notSubclass', ['Class ' classname ' must be a subclass of ' requiredType '.']);
    end
end

function tf = checkInheritance(metaObj, requiredType)
    if strcmp(metaObj.Name, requiredType)
        tf = true;
        return;
    end

    tf = false;
    for i = 1:numel(metaObj.SuperclassList)
        if checkInheritance(metaObj.SuperclassList(i), requiredType)
            tf = true;
            return;
        end
    end
end
