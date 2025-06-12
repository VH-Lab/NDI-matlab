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

        function obj = fromStruct(className, S_in, options)
            arguments
                className (1,1) string
                S_in (1,1) struct
                options.errorIfFieldNotPresent (1,1) logical = false
            end

            if exist(className, 'class') ~= 8
                error('StructSerializable:ClassNotFound', 'Class "%s" not found.', className);
            end

            obj = feval(className); 
            objProps = properties(obj);

            ndi.util.StructSerializable.validateStructArrayFields(S_in, objProps, options.errorIfFieldNotPresent);
            
            fieldNames_S_in = fieldnames(S_in);
            for i = 1:numel(fieldNames_S_in)
                fn = fieldNames_S_in{i};
                if isprop(obj, fn)
                    try
                        propMeta = findprop(obj, fn);
                        
                        % CORRECTED: Check if the property is constant or dependent.
                        % If so, skip it, as it cannot be set directly.
                        if propMeta.Constant || propMeta.Dependent
                            continue;
                        end

                        propTypeStr = '';
                        isSSubclass = false;
                        
                        if ~isempty(propMeta.Validation) && ~isempty(propMeta.Validation.Class)
                            propMetaClass = propMeta.Validation.Class;
                            propTypeStr = propMetaClass.Name;
                            if propMetaClass <= ?ndi.util.StructSerializable
                                isSSubclass = true;
                            end
                        end
                        
                        if isstruct(S_in.(fn)) && isSSubclass
                            if isscalar(S_in.(fn))
                                % Recursive call for a scalar nested object
                                obj.(fn) = ndi.util.StructSerializable.fromStruct(propTypeStr, S_in.(fn), 'errorIfFieldNotPresent',options.errorIfFieldNotPresent);
                            else
                                % Loop through the struct array for a nested object array
                                struct_array_in = S_in.(fn);
                                obj_array = feval(propTypeStr).empty(0,0); % Create typed empty array
                                for k = 1:numel(struct_array_in)
                                    obj_array(k) = ndi.util.StructSerializable.fromStruct(propTypeStr, struct_array_in(k), 'errorIfFieldNotPresent',options.errorIfFieldNotPresent);
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
                options.dispatch (1,1) logical = true % Your recursion guard
            end

            % If dispatch is disabled, just run the default behavior. This is
            % called by the custom override in a subclass.
            if ~options.dispatch
                S_in = alphaS_in;
                obj = ndi.util.StructSerializable.fromStruct(className, S_in, 'errorIfFieldNotPresent', options.errorIfFieldNotPresent);
                return;
            end

            % Use metaclass to inspect the target class definition
            mc = meta.class.fromName(char(className));
            methodMeta = findobj(mc.MethodList, 'Name', 'fromAlphaNumericStruct', '-depth', 0);
            
            isOverridden = ~isempty(methodMeta);
            
            if isOverridden
                % The subclass has a custom implementation. Delegate the call to it,
                % but turn off dispatching to prevent infinite recursion.
                customMethodHandle = str2func([char(className) '.fromAlphaNumericStruct']);
                obj = customMethodHandle(className, alphaS_in, ...
                    'errorIfFieldNotPresent', options.errorIfFieldNotPresent, ...
                    'dispatch', false);
            else
                % The subclass does NOT have a custom override. Use the default behavior.
                S_in = alphaS_in;
                obj = ndi.util.StructSerializable.fromStruct(className, S_in, 'errorIfFieldNotPresent', options.errorIfFieldNotPresent);
            end
        end
    end
end
