% AuthorData.m (in +ndi/+database/+metadata_app/+class)
classdef AuthorData < ndi.database.metadata_app.class.MDEDataUnits
    %AUTHORDATA Represents data for a single author.
    %   This class now represents a single author's details, inheriting
    %   from MDEDataUnits.

    properties
        givenName {mustBeCharRowVector(givenName)} = ''
        familyName {mustBeCharRowVector(familyName)} = ''
        authorRole cell {mustBeCellArrayOfChars(authorRole)} = {} % Cell array of char arrays
        contactInformation (1,1) ndi.database.metadata_app.class.ContactInformation
        digitalIdentifier (1,1) ndi.database.metadata_app.class.DigitalIdentifier
        % Assuming Organization class will also be an MDEDataUnits subclass
        % or have appropriate fromAlphaNumericStruct static method.
        affiliation (1,1) ndi.database.metadata_app.class.Organization
    end

    methods
        function obj = AuthorData()
            %AUTHORDATA Construct an instance of AuthorData with default values.
            %   Initializes contactInformation, digitalIdentifier, and affiliation
            %   with default instances of their respective classes.

            obj.contactInformation = ndi.database.metadata_app.class.ContactInformation();
            obj.digitalIdentifier = ndi.database.metadata_app.class.DigitalIdentifier();
            
            % Initialize affiliation with a default Organization object.
            % This assumes ndi.database.metadata_app.class.Organization exists and has a default constructor.
            % If Organization needs specific construction or is not yet an MDEDataUnit,
            % this might need adjustment or try-catch.
            try
                obj.affiliation = ndi.database.metadata_app.class.Organization();
            catch ME_Org
                 warning('AuthorData:Constructor:OrganizationInitFailed', ...
                        'Failed to initialize affiliation with default Organization object: %s. Affiliation might be uninitialized or set to empty.', ME_Org.message);
                 % Fallback if Organization() errors or doesn't exist as expected.
                 % This might leave obj.affiliation uninitialized if Organization class is problematic.
                 % For safety, one might assign a placeholder if Organization() fails:
                 % obj.affiliation = []; % Or a default/empty struct if appropriate
            end
        end

        % toStruct and toAlphaNumericStruct are inherited from MDEDataUnits.
        % The revised MDEDataUnits.toStruct will handle calling .toStruct()
        % on contactInformation, digitalIdentifier, and affiliation if they are MDEDataUnits
        % or have a toStruct method.
    end

    methods (Static)
        function obj = fromAlphaNumericStruct(className, alphaS_in)
            %FROMALPHANUMERICSTRUCT Creates and populates an AuthorData object from an AlphaNumericStruct.
            arguments
                className (1,1) string {mustEqual(className, "ndi.database.metadata_app.class.AuthorData")}
                alphaS_in (1,1) struct
            end

            obj = ndi.database.metadata_app.class.AuthorData(); % Calls constructor, which sets defaults

            if isfield(alphaS_in, 'givenName')
                obj.givenName = alphaS_in.givenName;
            end
            if isfield(alphaS_in, 'familyName')
                obj.familyName = alphaS_in.familyName;
            end
            if isfield(alphaS_in, 'authorRole')
                if ischar(alphaS_in.authorRole) && ~isempty(alphaS_in.authorRole)
                    obj.authorRole = strsplit(alphaS_in.authorRole, ',');
                elseif ischar(alphaS_in.authorRole) && isempty(alphaS_in.authorRole)
                    obj.authorRole = {}; % Empty char becomes empty cell
                else
                    obj.authorRole = alphaS_in.authorRole; % Assume already cell if not char
                end
            end

            if isfield(alphaS_in, 'contactInformation') && isstruct(alphaS_in.contactInformation)
                obj.contactInformation = ndi.database.metadata_app.class.ContactInformation.fromAlphaNumericStruct(...
                    "ndi.database.metadata_app.class.ContactInformation", alphaS_in.contactInformation);
            end

            if isfield(alphaS_in, 'digitalIdentifier') && isstruct(alphaS_in.digitalIdentifier)
                obj.digitalIdentifier = ndi.database.metadata_app.class.DigitalIdentifier.fromAlphaNumericStruct(...
                    "ndi.database.metadata_app.class.DigitalIdentifier", alphaS_in.digitalIdentifier);
            end

            if isfield(alphaS_in, 'affiliation') && isstruct(alphaS_in.affiliation)
                % This assumes ndi.database.metadata_app.class.Organization will have
                % a static fromAlphaNumericStruct method. If not, this will error,
                % or Organization needs to be made an MDEDataUnits subclass.
                try
                    obj.affiliation = ndi.database.metadata_app.class.Organization.fromAlphaNumericStruct(...
                        "ndi.database.metadata_app.class.Organization", alphaS_in.affiliation);
                catch ME_Org_fromAlpha
                     warning('AuthorData:fromAlphaNumericStruct:OrganizationConversionFailed', ...
                        'Failed to convert affiliation from AlphaNumericStruct: %s. Affiliation might remain default.', ME_Org_fromAlpha.message);
                end
            end
        end
    end
end