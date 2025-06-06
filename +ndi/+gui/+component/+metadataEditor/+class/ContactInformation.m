% ContactInformation.m (in +ndi/+gui/+component/+metadataEditor/+class/)
classdef ContactInformation < ndi.util.StructSerializable
    %CONTACTINFORMATION Stores contact information, specifically an email address.
    %   Inherits from ndi.util.StructSerializable for common conversion methods.

    properties
        email (1,:) char = '' % Email address, initialized to empty char
    end

    % Constructor is implicitly inherited. Properties are initialized directly.
    % Instance methods toStruct and toAlphaNumericStruct are inherited from StructSerializable.
    % The static fromStruct method is also inherited. To create an object from a struct:
    %   obj = ndi.util.StructSerializable.fromStruct('ndi.gui.component.metadataEditor.class.ContactInformation', S_in, flag);

    methods (Static)
        function obj = fromAlphaNumericStruct(alphaS_in, errorIfFieldNotPresent)
            %FROMALPHANUMERICSTRUCT Creates ContactInformation object(s) from an AlphaNumericStruct array.
            %   This method can accept a struct array of any size and will return an
            %   object array of the same dimensions.
            %
            %   It validates that the input is a valid AlphaNumericStruct. If errorIfFieldNotPresent
            %   is true, it also validates that all elements have the required 'email' field.
            arguments
                alphaS_in struct {ndi.validators.mustBeAlphaNumericStruct(alphaS_in)}
                errorIfFieldNotPresent (1,1) logical = false
            end
            
            % Preallocate output object array with the same size as the input
            obj = repmat(ndi.gui.component.metadataEditor.class.ContactInformation(), size(alphaS_in));
            
            % Iterate through each element of the input struct array
            for i = 1:numel(alphaS_in)
                currentAlphaStruct = alphaS_in(i);

                if errorIfFieldNotPresent
                    ndi.validators.mustHaveFields(currentAlphaStruct, {'email'});
                end
                
                if isfield(currentAlphaStruct, 'email')
                    obj(i).email = currentAlphaStruct.email;
                end
                % If field is not present and errorIfFieldNotPresent is false, obj(i).email retains its default
            end
        end
    end
end