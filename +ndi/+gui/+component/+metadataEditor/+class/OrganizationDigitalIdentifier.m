% OrganizationDigitalIdentifier.m (in +ndi/+gui/+component/+metadataEditor/+class/)
classdef OrganizationDigitalIdentifier < ndi.util.StructSerializable
    %ORGANIZATIONDIGITALIDENTIFIER Stores a specific type of digital identifier for an organization.
    %   Inherits from ndi.util.StructSerializable for common conversion methods.

    properties
        identifier (1,:) char = ''
        type (1,:) char {mustBeMember(type, {'', 'GRIDID', 'RORID', 'RRID'})} = ''
    end

    methods (Static)
        function obj = fromAlphaNumericStruct(alphaS_in, errorIfFieldNotPresent)
            %FROMALPHANUMERICSTRUCT Creates OrganizationDigitalIdentifier object(s) from an AlphaNumericStruct array.
            arguments
                alphaS_in struct {ndi.validators.mustBeAlphaNumericStruct(alphaS_in)}
                errorIfFieldNotPresent (1,1) logical = false
            end
            
            % If the input array is empty, return an empty object array.
            if isempty(alphaS_in)
                % Create an empty object of this class with the correct size
                obj = feval(mfilename('class')).empty(size(alphaS_in));
                return;
            end
            
            % Centralized validation call (checks fields on first element)
            allowedFields = {'identifier', 'type'};
            ndi.util.StructSerializable.validateStructArrayFields(alphaS_in, allowedFields, errorIfFieldNotPresent);

            % --- Corrected Pre-allocation and Population Loop for Handle Class ---
            
            % Pre-allocate cell array to hold new objects
            obj_cell = cell(size(alphaS_in));
            
            for i = 1:numel(alphaS_in)
                % Create a new, distinct object in each iteration
                newObj = feval(mfilename('class'));
                currentAlphaStruct = alphaS_in(i);

                if isfield(currentAlphaStruct, 'identifier')
                    newObj.identifier = currentAlphaStruct.identifier;
                end

                if isfield(currentAlphaStruct, 'type')
                    newObj.type = upper(currentAlphaStruct.type);
                end
                
                obj_cell{i} = newObj;
            end
            % Convert cell array of objects to an object array
            obj = [obj_cell{:}];
            obj = reshape(obj, size(alphaS_in));
        end
    end
end