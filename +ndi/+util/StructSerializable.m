% StructSerializable.m (in +ndi/+util/)
classdef StructSerializable < handle
%STRUCTSERIALIZABLE A base class for data objects that can be converted to/from structs.
%   Provides common functionality for converting objects to and from
%   plain MATLAB structures, including AlphaNumericStructs suitable for NDI.
%
%   Subclasses are expected to define their own properties and must override
%   the fromAlphaNumericStruct method for full functionality.
%
%   Key Methods:
%   - toStruct: Converts object properties to a plain MATLAB struct.
%   - fromStruct (static): Creates an object from a plain MATLAB struct.
%   - toAlphaNumericStruct: Converts object to an AlphaNumericStruct
%     (uses toStruct then ndi.util.Struct2AlphaNumericStruct).
%   - fromAlphaNumericStruct (static): Placeholder for creating an object
%     from an AlphaNumericStruct; subclasses must override.
%   - validateStructArrayFields (static): Helper to validate field names of a struct array.

    methods
        function obj = StructSerializable()
            %STRUCTSERIALIZABLE Construct an instance of this class.
            %   The base class constructor currently performs no specific actions
            %   beyond default object initialization.
        end

        function S = toStruct(obj)
            %TOSTRUCT Converts the object's public properties to a plain MATLAB struct.
            %   S = TOSTRUCT(OBJ)
            %
            %   This method recursively converts properties that are themselves
            %   StructSerializable objects by calling their toStruct method.
            
            propNames = properties(obj);
            S = struct();
            for i = 1:numel(propNames)
                propName = propNames{i};
                propValue = obj.(propName);

                if isa(propValue, 'ndi.util.StructSerializable')
                    if isscalar(propValue)
                        S.(propName) = propValue.toStruct(); % Call toStruct on it
                    else % It's an array of StructSerializable objects
                        if isempty(propValue)
                            % To preserve field type, try to create empty struct with same fields
                            if numel(propValue) > 0 && ismethod(propValue(1), 'toStruct')
                                S.(propName) = repmat(propValue(1).toStruct(), size(propValue));
                            else
                                S.(propName) = struct();
                            end
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
            %   ALPHAS = TOALPHANUMERICSTRUCT(OBJ)
            %
            %   This method first calls obj.toStruct() to get a plain MATLAB
            %   structure of the object, and then passes this structure to
            %   ndi.util.Struct2AlphaNumericStruct for final conversion.
            
            S = obj.toStruct();
            if isempty(fieldnames(S)) && isstruct(S) 
                alphaS = S; 
                return;
            end
            
            try
                alphaS = ndi.util.Struct2AlphaNumericStruct(S);
            catch ME
                if strcmp(ME.identifier, 'MATLAB:UndefinedFunction') && contains(ME.message, 'ndi.util.Struct2AlphaNumericStruct')
                    error('StructSerializable:UtilityNotFound', ...
                          'The utility function ndi.util.Struct2AlphaNumericStruct was not found. Please ensure it is on the MATLAB path.');
                elseif (strcmp(ME.identifier, 'MATLAB:minrhs') || strcmp(ME.identifier, 'MATLAB:InputParser:ArgumentFailedValidation')) && contains(ME.message, 'Struct2AlphaNumericStruct')
                     error('StructSerializable:InvalidInputToUtility', ...
                          'Input to ndi.util.Struct2AlphaNumericStruct must be a scalar struct. obj.toStruct() returned type: %s. Value: %s', class(S), jsonencode(S));
                else
                    rethrow(ME);
                end
            end
        end
    end

    methods (Static)
        function validateStructArrayFields(structArray, allowedFields, errorIfFieldNotPresent)
            %VALIDATESTRUCTARRAYFIELDS Validates field names for an entire struct array.
            %   VALIDATESTRUCTARRAYFIELDS(STRUCTARRAY, ALLOWEDFIELDS, ERRORIFFIELDNOTPRESENT)
            %   This method centralizes validation for fromStruct/fromAlphaNumericStruct methods.
            %
            %   1. It ensures no struct in STRUCTARRAY has fields not in ALLOWEDFIELDS.
            %   2. If ERRORIFFIELDNOTPRESENT is true, it ensures the structs have all fields
            %      listed in ALLOWEDFIELDS.
            %
            %   Since all elements of a struct array have the same fields, these checks
            %   are performed only once on the first element for efficiency.
            arguments
                structArray struct
                allowedFields (1,:) cell
                errorIfFieldNotPresent (1,1) logical = false
            end
            
            % If the input array is empty, there is nothing to validate.
            if isempty(structArray)
                return;
            end
            
            % Step 1: Ensure the struct does not contain any extra fields.
            ndi.validators.mustHaveOnlyFields(structArray(1), allowedFields);

            % Step 2: If errorIfFieldNotPresent is true, ensure all allowed fields are present.
            if errorIfFieldNotPresent
                ndi.validators.mustHaveFields(structArray(1), allowedFields);
            end
        end

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
                error('StructSerializable:ClassNotFound', 'Class "%s" not found.', className);
            end

            obj = feval(className); 
            objProps = properties(obj);

            ndi.util.StructSerializable.validateStructArrayFields(S_in, objProps, errorIfFieldNotPresent);
            
            fieldNames_S_in = fieldnames(S_in);
            for i = 1:numel(fieldNames_S_in)
                fn = fieldNames_S_in{i};
                if isprop(obj, fn)
                    try
                        propMeta = findprop(obj, fn);
                        propTypeStr = '';
                        isSSubclass = false;
                        
                        % Use meta.class for robust subclass check
                        if ~isempty(propMeta.Validation) && ~isempty(propMeta.Validation.Class)
                            propMetaClass = propMeta.Validation.Class;
                            propTypeStr = propMetaClass.Name;
                            if propMetaClass <= ?ndi.util.StructSerializable
                                isSSubclass = true;
                            end
                        end
                        
                        if isstruct(S_in.(fn)) && isSSubclass
                            % If the property expects a StructSerializable subclass and the input is a struct, recurse.
                            obj.(fn) = ndi.util.StructSerializable.fromStruct(propTypeStr, S_in.(fn), errorIfFieldNotPresent);
                        else
                            % Otherwise, perform direct assignment.
                            obj.(fn) = S_in.(fn); 
                        end
                    catch ME
                        newEx = MException('StructSerializable:fromStruct:PropertySetError', ...
                            sprintf('Could not set property "%s" on class "%s". Original error: %s', fn, className, ME.message));
                        newEx = addCause(newEx, ME);
                        throw(newEx);
                    end
                end
            end
        end

        function obj = fromAlphaNumericStruct(className, alphaS_in, errorIfFieldNotPresent)
            %FROMALPHANUMERICSTRUCT Creates an object from an AlphaNumericStruct (Base Placeholder).
            %   Subclasses MUST override this method to provide specific parsing logic.
            arguments
                className (1,1) string
                alphaS_in (1,1) struct
                errorIfFieldNotPresent (1,1) logical = false 
            end
            if exist(className, 'class') ~= 8
                error('StructSerializable:ClassNotFound', 'Class "%s" not found.', className);
            end
            obj = feval(className);
            warning('StructSerializable:fromAlphaNumericStruct:BaseImplementation', ...
                    ['Base StructSerializable.fromAlphaNumericStruct called for class "%s". ' ...
                     'Object returned with default values. errorIfFieldNotPresent was %s. ' ...
                     'Subclasses must override this method.'], ...
                     className, mat2str(errorIfFieldNotPresent));
        end
    end
end