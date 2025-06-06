% Strain.m (in +ndi/+gui/+component/+metadataEditor/+class/)
classdef Strain < ndi.util.StructSerializable
    %STRAIN Represents a biological strain with a name.
    %   Inherits from ndi.util.StructSerializable for common conversion methods.

    properties
        Name (1,:) char = '' % The name of the strain
    end

    % Constructor is implicitly inherited. Properties are initialized directly.
    % Instance methods toStruct and toAlphaNumericStruct are inherited from StructSerializable.
    % The static fromStruct method is also inherited.

    methods (Static)
        function obj = fromAlphaNumericStruct(alphaS_in, options)
            %FROMALPHANUMERICSTRUCT Creates Strain object(s) from an AlphaNumericStruct array.
            %
            %   Name-Value Pairs:
            %       errorIfFieldNotPresent (logical): If true, errors if alphaS_in
            %           is missing any fields. Defaults to false.
            arguments
                alphaS_in struct {ndi.validators.mustBeAlphaNumericStruct(alphaS_in)}
                options.errorIfFieldNotPresent (1,1) logical = false
            end
            
            if isempty(alphaS_in)
                obj = feval(mfilename('class')).empty(size(alphaS_in));
                return;
            end
            
            % The allowedFields should include all properties of this class plus inherited ones.
            allowedFields = {'Name', 'CellStrDelimiter'};
            ndi.util.StructSerializable.validateStructArrayFields(alphaS_in, allowedFields, options.errorIfFieldNotPresent);

            obj_cell = cell(size(alphaS_in));
            
            for i = 1:numel(alphaS_in)
                newObj = feval(mfilename('class'));
                currentAlphaStruct = alphaS_in(i);

                if isfield(currentAlphaStruct, 'Name')
                    newObj.Name = currentAlphaStruct.Name;
                end
                
                if isfield(currentAlphaStruct, 'CellStrDelimiter')
                    newObj.CellStrDelimiter = currentAlphaStruct.CellStrDelimiter;
                end
                
                obj_cell{i} = newObj;
            end
            
            obj = [obj_cell{:}];
            obj = reshape(obj, size(alphaS_in));
        end
    end
end