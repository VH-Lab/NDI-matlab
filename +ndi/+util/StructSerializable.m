% StructSerializable.m (in +ndi/+util/)
classdef StructSerializable < handle
%STRUCTSERIALIZABLE A base class for data objects that can be converted to/from structs.
%   Provides common functionality for converting objects to and from
%   plain MATLAB structures, including AlphaNumericStructs suitable for NDI.
%
%   Key Methods:
%   - toStruct: Converts object properties to a plain MATLAB struct.
%   - fromStruct (static): Creates an object from a plain MATLAB struct.
%   - toAlphaNumericStruct: Converts object to an AlphaNumericStruct.
%   - fromAlphaNumericStruct (static): Placeholder; subclasses must override.
%   - validateStructArrayFields (static): Helper to validate field names.

    properties
        CellStrDelimiter (1,:) char = ', ' 
    end

    methods
        function obj = StructSerializable()
        end

        function S = toStruct(obj)
            propNames = properties(obj);
            S = struct();
            for i = 1:numel(propNames)
                propName = propNames{i};
                propValue = obj.(propName);

                if isa(propValue, 'ndi.util.StructSerializable')
                    if isscalar(propValue)
                        S.(propName) = propValue.toStruct();
                    else 
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
                        catch
                            S.(propName) = tempCell;
                        end
                    end
                else
                    S.(propName) = propValue; 
                end
            end
        end

        function alphaS = toAlphaNumericStruct(obj)
            S = obj.toStruct();
            if isempty(fieldnames(S)) && isstruct(S) 
                alphaS = S; 
                return;
            end
            
            try
                alphaS = ndi.util.Struct2AlphaNumericStruct(S, 'Delimiter', obj.CellStrDelimiter);
            catch ME
                if strcmp(ME.identifier, 'MATLAB:UndefinedFunction') && contains(ME.message, 'ndi.util.Struct2AlphaNumericStruct')
                    error('StructSerializable:UtilityNotFound', 'The utility function ndi.util.Struct2AlphaNumericStruct was not found.');
                else
                    rethrow(ME);
                end
            end
        end
    end

    methods (Static)
        function validateStructArrayFields(structArray, allowedFields, errorIfFieldNotPresent)
            arguments
                structArray struct
                allowedFields (1,:) cell
                errorIfFieldNotPresent (1,1) logical = false
            end
            
            if isempty(structArray)
                return;
            end
            
            ndi.validators.mustHaveOnlyFields(structArray(1), allowedFields);

            if errorIfFieldNotPresent
                ndi.validators.mustHaveFields(structArray(1), allowedFields);
            end
        end

        function obj = fromStruct(className, S_in, errorIfFieldNotPresent)
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
                        
                        if ~isempty(propMeta.Validation) && ~isempty(propMeta.Validation.Class)
                            propMetaClass = propMeta.Validation.Class;
                            propTypeStr = propMetaClass.Name;
                            if propMetaClass <= ?ndi.util.StructSerializable
                                isSSubclass = true;
                            end
                        end
                        
                        % --- CORRECTED LOGIC ---
                        if isstruct(S_in.(fn)) && isSSubclass
                            if isscalar(S_in.(fn))
                                % Recursive call for a scalar nested object
                                obj.(fn) = ndi.util.StructSerializable.fromStruct(propTypeStr, S_in.(fn), errorIfFieldNotPresent);
                            else
                                % Loop through the struct array for a nested object array
                                struct_array_in = S_in.(fn);
                                obj_array = feval(propTypeStr).empty(0,0); % Create typed empty array
                                for k = 1:numel(struct_array_in)
                                    obj_array(k) = ndi.util.StructSerializable.fromStruct(propTypeStr, struct_array_in(k), errorIfFieldNotPresent);
                                end
                                obj.(fn) = reshape(obj_array, size(struct_array_in));
                            end
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

        function obj = fromAlphaNumericStruct(className, alphaS_in, options)
            arguments
                className (1,1) string
                alphaS_in struct
                options.errorIfFieldNotPresent (1,1) logical = false 
            end
            if exist(className, 'class') ~= 8
                error('StructSerializable:ClassNotFound', 'Class "%s" not found.', className);
            end
            obj = feval(className);

            warning('StructSerializable:fromAlphaNumericStruct:BaseImplementation', ...
                    ['Base StructSerializable.fromAlphaNumericStruct called for class "%s". ' ...
                     'Object returned with default values. Subclasses must override this method.'], ...
                     className);
        end
    end
end