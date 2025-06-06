% OrganizationDigitalIdentifier.m (in +ndi/+gui/+component/+metadataEditor/+class/)
classdef OrganizationDigitalIdentifier < ndi.util.StructSerializable
    %ORGANIZATIONDIGITALIDENTIFIER Stores a specific type of digital identifier for an organization.
    %   Inherits from ndi.util.StructSerializable for common conversion methods.

    properties
        identifier (1,:) char = ''
        % The 'type' property must be a member of the specified set.
        % The set includes an empty char '' as a valid default/unspecified value.
        type (1,:) char {mustBeMember(type, {'', 'GRIDID', 'RORID', 'RRID'})} = ''
    end

    % Constructor is implicitly inherited. Properties are initialized directly.
    % Instance methods toStruct and toAlphaNumericStruct are inherited from StructSerializable.
    % The static fromStruct method is also inherited.

    methods (Static)
        function obj = fromAlphaNumericStruct(alphaS_in, options)
            %FROMALPHANUMERICSTRUCT Creates OrganizationDigitalIdentifier object(s) from an AlphaNumericStruct array.
            %   This method can accept a struct array of any size and will return an
            %   object array of the same dimensions.
            %
            %   Name-Value Pairs:
            %       errorIfFieldNotPresent (logical): If true, errors if alphaS_in
            %           is missing any fields. Defaults to false.
            arguments
                alphaS_in struct {ndi.validators.mustBeAlphaNumericStruct(alphaS_in)}
                options.errorIfFieldNotPresent (1,1) logical = false
            end
            
            % If the input array is empty, return an empty object array.
            if isempty(alphaS_in)
                obj = feval(mfilename('class')).empty(size(alphaS_in));
                return;
            end
            
            % The allowedFields should include all properties of this class plus the inherited ones.
            % The base class property 'CellStrDelimiter' is expected to be in the struct.
            allowedFields = {'identifier', 'type', 'CellStrDelimiter'};
            ndi.util.StructSerializable.validateStructArrayFields(alphaS_in, allowedFields, options.errorIfFieldNotPresent);

            % Pre-allocate a cell array to hold new, distinct handle objects
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
                
                if isfield(currentAlphaStruct, 'CellStrDelimiter')
                    newObj.CellStrDelimiter = currentAlphaStruct.CellStrDelimiter;
                end
                
                obj_cell{i} = newObj;
            end
            % Convert cell array of objects to a standard object array
            obj = [obj_cell{:}];
            obj = reshape(obj, size(alphaS_in));
        end
    end
end