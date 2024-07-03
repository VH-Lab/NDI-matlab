classdef JsonSerializable < handle
% JsonSerializable - A mixin class for serializing class instances to json

    % Todo: Don't serialize transient properties

    properties (Abstract, Constant)
        VERSION (1,1) string
        DESCRIPTION (1,1) string
    end

    properties (Access = private)
        DateCreated (1,1) string = missing
    end
    
    methods (Sealed)
        function jsonStr = toJson(obj, filePath)
            arguments
                obj (1,1) ndi.internal.mixin.JsonSerializable
                filePath (1,1) string = missing
            end
            
            % Create a struct with the required header fields
            jsonStruct = obj.createJsonHeader();
            
            % Check if the object is an array
            if numel(obj) > 1
                % Initialize an array of structs for each object
                objArray = arrayfun(@(o) o.toStruct(), obj, 'UniformOutput', false);
                jsonStruct.Properties = [objArray{:}];
            else
                % Convert single object to struct
                jsonStruct.Properties = obj.toStruct();
            end
            
            % Convert struct to JSON string
            jsonStr = jsonencode(jsonStruct, 'PrettyPrint', true);

            if ~ismissing(filePath)
                fid = fopen(filePath, 'w');
                fwrite(fid, jsonStr);
                fclose(fid);
            end
            if ~nargout
                clear jsonStr
            end
        end
    
        function tf = isClean(obj, filePath)
        % isDirty - Compare current object with serialized json
            if isfile(filePath)
                jsonStrA = jsonencode( obj.toStruct() );
    
                deserializedObject = jsondecode(fileread(filePath));
                jsonStrB = jsonencode(deserializedObject.Properties);
    
                tf = strcmp(jsonStrA, jsonStrB);
            else
                tf = ~obj.isInitialized();
            end
        end
    end

    methods (Access = private)
        function jsonStruct = createJsonHeader(obj)           
        % createStructWithHeader - Create a struct with required header fields
            jsonStruct = struct();
            jsonStruct.ClassName = class(obj);
            jsonStruct.Description = obj.DESCRIPTION;
            jsonStruct.Version = obj.VERSION;
            if ismissing(obj.DateCreated)
                [obj(:).DateCreated] = deal( string( datetime("today") ) );
            end
            jsonStruct.DateCreated = obj(1).DateCreated;
            jsonStruct.DateModified = string( datetime("today") );
        end
    end
    
    methods (Access = protected)
        
        function tf = isInitialized(obj)
        % isInitialized - Is data initialized?
        %
        % Subclasses can override. Is used in isClean. If no file exists
        % isClean depends on isInitialized.
            tf = true;
        end

        function s = toStruct(obj)
            % Convert object properties to a struct

            % Todo: Serialize objects...
            metaObj = metaclass(obj);
            s = struct();
            for i = 1:numel(metaObj.PropertyList)
                propName = metaObj.PropertyList(i).Name;
                if ~metaObj.PropertyList(i).Constant && ~metaObj.PropertyList(i).Transient
                    s.(propName) = obj.(propName);
                end
            end
        end

        function fromStruct(obj, s)
        % Populate object properties from a struct

            numInstances = numel(s);
            
            if numInstances > 1
                obj(numInstances) = feval( class(obj) );
                [obj(:).DateCreated] = deal(obj(1).DateCreated);
            end

            propertyNames = string( fieldnames(s)' );
            for iInstance = 1:numInstances
                for jPropertyName = propertyNames
                    jPropertyValue = s(iInstance).(jPropertyName);
                    
                    if isa(jPropertyValue, 'struct')
                        % Create object if property has a type
                        if isobject( obj(iInstance).(jPropertyName) )
                            propertyType = class( obj(iInstance).(jPropertyName) );
                            jPropertyValue = obj.deserializeObjectArray(jPropertyValue, propertyType);
                        end
                    end

                    try
                        obj(iInstance).(jPropertyName) = jPropertyValue;
                    catch ME
                        rethrow(ME)
                    end
                end 
            end
        end
    end

    methods (Access = private)
        function objectArray = deserializeObjectArray(~, structArray, className)
            numObjects = numel(structArray);
            objectArray = cell(1, numObjects);
            
            for i = 1:numObjects
                nvPairs = namedargs2cell(structArray(i));
                objectArray{i} = feval(className, nvPairs{:});
            end
            objectArray = [objectArray{:}];
        end

        function isTransient(obj, propertyName)


        end
    end

    methods (Static)
        function newObject = fromJson(jsonStr, className)
        % fromJson - Populate class properties from json string
            
            if isfile(jsonStr)
                jsonStr = fileread(jsonStr);
            end

            S = jsondecode(jsonStr);
            
            assert(strcmp(S.ClassName, className), ...
                'JSON must be of type %s', className)
            
            if S.Version ~= eval([className, '.VERSION'])
                % Pass
            end

            newObject = feval(className);
            newObject.DateCreated = S.DateCreated;
            newObject.fromStruct(S.Properties)
        end
    end
end
