% MDEDataUnits.m
classdef MDEDataUnits < handle
    %MDEDATAUNITS A base class for metadata editor data units.
    %   Provides common functionality for converting objects to and from
    %   structures, including AlphaNumericStructs suitable for NDI.
    %
    %   Subclasses are expected to define their own properties.
    %
    %   Key Methods:
    %   - toStruct: Converts object properties to a plain MATLAB struct.
    %   - fromStruct (static): Creates an object from a plain MATLAB struct.
    %   - toAlphaNumericStruct: Converts object to an AlphaNumericStruct
    %     (uses toStruct then ndi.util.Struct2AlphaNumericStruct).
    %   - fromAlphaNumericStruct (static): Placeholder for creating an object
    %     from an AlphaNumericStruct; subclasses must override for full functionality.

    methods
        function obj = MDEDataUnits()
            %MDEDATAUNITS Construct an instance of this class.
            % No specific initialization in the base constructor.
        end

        function S = toStruct(obj)
            %TOSTRUCT Converts the object's public properties to a plain MATLAB struct.
            %   If a property is an MDEDataUnits instance (or an array of them),
            %   its toStruct method is called recursively.

            propNames = properties(obj);
            S = struct();
            for i = 1:numel(propNames)
                propName = propNames{i};
                propValue = obj.(propName);

                if isa(propValue, 'ndi.database.metadata_app.class.MDEDataUnits')
                    if isscalar(propValue)
                        S.(propName) = propValue.toStruct(); % Call toStruct on it
                    else % It's an array of MDEDataUnits objects
                        if isempty(propValue)
                            S.(propName) = struct(); 
                        else
                            tempCell = cell(size(propValue));
                            for k_pv = 1:numel(propValue)
                                if isvalid(propValue(k_pv)) 
                                    tempCell{k_pv} = propValue(k_pv).toStruct();
                                else
                                    tempCell{k_pv} = struct(); 
                                end
                            end
                            try
                                S.(propName) = [tempCell{:}];
                                if isempty(S.(propName)) && ~isempty(tempCell) 
                                   S.(propName) = struct(); 
                                end
                            catch
                                S.(propName) = tempCell; 
                            end
                        end
                    end
                elseif isobject(propValue) && ~isa(propValue, 'string') && ismethod(propValue, 'toStruct') && ...
                       ~isa(propValue, 'matlab.ui.control.UIControl') 
                     if isscalar(propValue)
                        S.(propName) = propValue.toStruct();
                    else 
                        tempCell = cell(size(propValue));
                        for k_pv = 1:numel(propValue)
                             if isvalid(propValue(k_pv))
                                tempCell{k_pv} = propValue(k_pv).toStruct();
                             else
                                tempCell{k_pv} = struct();
                             end
                        end
                        try
                            S.(propName) = [tempCell{:}];
                             if isempty(S.(propName)) && ~isempty(tempCell)
                               S.(propName) = struct();
                            end
                        catch
                            S.(propName) = tempCell;
                        end
                    end
                else
                    S.(propName) = propValue; % Assign directly for primitive types
                end
            end
        end

        function alphaS = toAlphaNumericStruct(obj)
            %TOALPHANUMERICSTRUCT Converts the object to an AlphaNumericStruct.
            S = obj.toStruct();
            if isempty(fieldnames(S)) && isstruct(S) 
                alphaS = S; 
                return;
            end
            
            try
                alphaS = ndi.util.Struct2AlphaNumericStruct(S);
            catch ME
                if strcmp(ME.identifier, 'MATLAB:UndefinedFunction') && contains(ME.message, 'ndi.util.Struct2AlphaNumericStruct')
                    error('MDEDataUnits:UtilityNotFound', ...
                          'The utility function ndi.util.Struct2AlphaNumericStruct was not found. Please ensure it is on the MATLAB path.');
                elseif (strcmp(ME.identifier, 'MATLAB:minrhs') || strcmp(ME.identifier, 'MATLAB:InputParser:ArgumentFailedValidation')) && contains(ME.message, 'Struct2AlphaNumericStruct')
                     error('MDEDataUnits:InvalidInputToUtility', ...
                          'Input to ndi.util.Struct2AlphaNumericStruct must be a scalar struct. obj.toStruct() returned type: %s. Value: %s', class(S), jsonencode(S));
                else
                    rethrow(ME);
                end
            end
        end
    end

    methods (Static)
        function obj = fromStruct(className, S_in, errorIfFieldNotPresent)
            %FROMSTRUCT Creates/populates an object from a struct.
            %   S_in must not contain fields that are not properties of className.
            %   If errorIfFieldNotPresent is true, S_in must contain all properties of className.
            arguments
                className (1,1) string
                S_in (1,1) struct
                errorIfFieldNotPresent (1,1) logical = false
            end

            if exist(className, 'class') ~= 8
                error('MDEDataUnits:ClassNotFound', 'Class "%s" not found.', className);
            end

            obj = feval(className); % Create new instance (properties will have defaults)
            objProps = properties(obj);

            % Ensure S_in does not have fields not present in the class
            ndi.validators.mustHaveOnlyFields(S_in, objProps);

            % If required, ensure S_in has all fields that are properties of the class
            if errorIfFieldNotPresent
                ndi.validators.mustHaveFields(S_in, objProps);
            end

            % Populate properties from S_in
            % All fields in S_in are now known to be valid properties of obj.
            % If errorIfFieldNotPresent was false, S_in might be missing some objProps,
            % in which case those properties in obj will retain their default values.
            fieldNames_S_in = fieldnames(S_in);
            for i = 1:numel(fieldNames_S_in)
                fn = fieldNames_S_in{i};
                % isprop check is technically redundant here due to mustHaveOnlyFields,
                % but kept for safety/explicitness.
                if isprop(obj, fn)
                    try
                        propMeta = findprop(obj, fn);
                        propType = propMeta.Type.Name; 
                        
                        if isstruct(S_in.(fn)) && ~isempty(propType) && exist(propType, 'class') == 8
                            % If the property is an object type and S_in provides a struct for it
                            if ismethod(propType, 'fromStruct') && ~strcmp(propType, 'ndi.database.metadata_app.class.MDEDataUnits')
                                % Call specific subclass's static fromStruct, passing the flag
                                obj.(fn) = feval([propType '.fromStruct'], S_in.(fn), errorIfFieldNotPresent);
                            elseif any(strcmp(superclasses(propType), 'ndi.database.metadata_app.class.MDEDataUnits'))
                                % Call base MDEDataUnits static fromStruct if it's an MDEDataUnit without its own fromStruct override
                                obj.(fn) = ndi.database.metadata_app.class.MDEDataUnits.fromStruct(propType, S_in.(fn), errorIfFieldNotPresent);
                            else
                                obj.(fn) = S_in.(fn); % Fallback direct assignment
                            end
                        else
                            obj.(fn) = S_in.(fn); % Direct assignment for primitives or non-struct inputs
                        end
                    catch ME_SetProp
                        warning('MDEDataUnits:fromStruct:PropertySetError', ...
                                'Could not set property "%s" on class "%s": %s', fn, className, ME_SetProp.message);
                    end
                % This 'else' should ideally not be reached if mustHaveOnlyFields works correctly.
                % else
                %     warning('MDEDataUnits:fromStruct:UnknownPropertySkipped', ...
                %             'Property "%s" from input struct S_in was unexpectedly not a property of class "%s". This should have been caught by mustHaveOnlyFields.', fn, className);
                end
            end
        end

        function obj = fromAlphaNumericStruct(className, alphaS_in, errorIfFieldNotPresent)
            %FROMALPHANUMERICSTRUCT (Base Placeholder - Subclasses MUST override)
            %   Subclasses should implement logic including conditional mustHaveFields
            %   and unconditional mustHaveOnlyFields for their expected structure.
            arguments
                className (1,1) string
                alphaS_in (1,1) struct
                errorIfFieldNotPresent (1,1) logical = false % Flag reinstated
            end
            if exist(className, 'class') ~= 8
                error('MDEDataUnits:ClassNotFound', 'Class "%s" not found.', className);
            end
            obj = feval(className); % Create default object
            warning('MDEDataUnits:fromAlphaNumericStruct:BaseImplementation', ...
                    ['Base MDEDataUnits.fromAlphaNumericStruct called for class "%s". ' ...
                     'Object returned with default values. errorIfFieldNotPresent was %s. ' ...
                     'Subclasses must override this method to properly parse the AlphaNumericStruct, '...
                     'including calling ndi.validators.mustHaveOnlyFields and conditionally ndi.validators.mustHaveFields.'], ...
                     className, mat2str(errorIfFieldNotPresent));
        end
    end
end