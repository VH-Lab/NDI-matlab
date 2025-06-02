classdef AuthorData < ndi.database.metadata_app.class.MDAData
    %AuthorData A utility class for storing and retrieving information about authors.
    %   Manages a list of author information, where each author is represented
    %   as a structure. Inherits from MDAData.

    properties
        % AuthorList - A column struct array holding information for each author. 
        %   Each struct element conforms to the structure defined by 
        %   AuthorData.getDefaultAuthorItem().
        AuthorList (:,1) struct
    end

    methods % Constructor
        function obj = AuthorData()
            %AuthorData Construct an instance of this class
            %   Initializes AuthorList to an empty, correctly-structured struct array.
            obj.ClearAll(); 
        end
    end

    methods % Implementation of Abstract MDAData methods
        function ClearAll(obj)
            %CLEARALL Clears all authors from the AuthorList.
            obj.AuthorList = repmat(ndi.database.metadata_app.class.AuthorData.getDefaultAuthorItem(), 0, 1);
        end

        function outputStructArray = toStructs(obj)
            %TOSTRUCTS Converts the internal AuthorList to an array of plain structs.
            if isempty(obj.AuthorList)
                outputStructArray = repmat(ndi.database.metadata_app.class.AuthorData.getDefaultAuthorItem(), 0, 1);
            else
                outputStructArray = obj.AuthorList;
            end
        end

        function fromStructs(obj, inputStructArray)
            %FROMSTRUCTS Populates AuthorList from an array of plain author structs.
            %   Clears existing authors before populating.
            obj.ClearAll(); % Clear existing authors
            
            if ~isempty(inputStructArray)
                if ~isstruct(inputStructArray)
                    warning('AuthorData:InvalidInputFromStructs', 'Input to fromStructs must be a struct array. Author list not populated.');
                    return;
                end
                
                % Ensure all structs in the input array have the default fields
                % This step is crucial if inputStructArray might come from various sources
                % and ensures concatenation into AuthorList doesn't fail due to mismatched fields.
                defaultItem = ndi.database.metadata_app.class.AuthorData.getDefaultAuthorItem();
                defaultFields = fieldnames(defaultItem);
                
                validatedStructArray = repmat(defaultItem, numel(inputStructArray), 1);
                if numel(inputStructArray) == 0 % handle 0x0 input becoming 0x1
                    validatedStructArray = repmat(defaultItem, 0, 1);
                end

                for i = 1:numel(inputStructArray)
                    currentInStruct = inputStructArray(i);
                    currentOutStruct = defaultItem; % Start with a clean default struct
                    for k = 1:numel(defaultFields)
                        fieldName = defaultFields{k};
                        if isfield(currentInStruct, fieldName)
                            % Copy value if field exists in input
                            currentOutStruct.(fieldName) = currentInStruct.(fieldName);
                        else
                            % Field missing in input, already has default from defaultItem
                        end
                    end
                    validatedStructArray(i) = currentOutStruct;
                end
                
                if isempty(obj.AuthorList) && ~isempty(validatedStructArray)
                    obj.AuthorList = validatedStructArray;
                elseif ~isempty(validatedStructArray)
                    obj.AuthorList = validatedStructArray; % Assign the whole validated array
                end

                % Ensure AuthorList is a column vector if not empty
                if ~isempty(obj.AuthorList) && ~iscolumn(obj.AuthorList)
                    obj.AuthorList = obj.AuthorList(:);
                end
            end
            % If inputStructArray was empty, AuthorList remains an empty 0x1 struct.
        end
    end
    
    methods % Public methods specific to AuthorData (Simplified versions)

        function addDefaultAuthorEntry(obj)
            %addDefaultAuthorEntry Adds a new author entry using default values
            %   by directly appending to AuthorList.
            defaultAuthor = ndi.database.metadata_app.class.AuthorData.getDefaultAuthorItem();
            if isempty(obj.AuthorList)
                obj.AuthorList = defaultAuthor; % Initialize if it was 0x1 empty struct
            else
                obj.AuthorList(end+1,1) = defaultAuthor; % Append new default struct
            end
        end

        function S = getItem(obj, authorIndex)
            %getItem Get a struct with author details for the given index (simplified).
            if numel(obj.AuthorList) < authorIndex || authorIndex < 1
                S = obj.getDefaultAuthorItem(); 
            else
                S = obj.AuthorList(authorIndex);
            end
        end

        function removeItem(obj, authorIndex)
            %removeItem Remove the specified author from the list (simplified).
            obj.AuthorList(authorIndex) = [];
            if isempty(obj.AuthorList)
                obj.ClearAll();
            end
        end

        function reorderItems(obj, newIndex, oldIndex)
            %reorderItems Reorders items in the AuthorList (simplified).
            obj.AuthorList([newIndex, oldIndex]) = obj.AuthorList([oldIndex, newIndex]);
        end
        
        function S = getAuthorList(obj)
            %getAuthorList Returns the AuthorList struct array. (Same as toStructs)
            S = obj.toStructs();
        end

        function setAuthorList(obj, S_array)
            %setAuthorList Sets the AuthorList using the fromStructs method.
            obj.fromStructs(S_array);
        end

        function success = updateProperty(obj, propertyName, value, authorIndex)
            %updateProperty Update the value in a field for the given authorIndex (simplified).
            success = false;
            if authorIndex <= 0 
                return; % Silently ignore invalid index for simplicity here
            end
            
            numAuthors = numel( obj.AuthorList );
            if numAuthors < authorIndex
                if numAuthors == 0 && authorIndex == 1
                    obj.AuthorList = obj.getDefaultAuthorItem();
                elseif numAuthors == 0 && authorIndex > 1
                    obj.AuthorList = repmat(obj.getDefaultAuthorItem(), authorIndex, 1);
                else 
                    obj.AuthorList(end+1:authorIndex, 1) = deal(obj.getDefaultAuthorItem());
                end
            end

            try
                if strcmp(propertyName, 'digitalIdentifier')
                    obj.AuthorList(authorIndex).digitalIdentifier.identifier = char(value);
                elseif strcmp(propertyName, 'contactInformation')
                    obj.AuthorList(authorIndex).contactInformation.email = char(value);
                else 
                    obj.AuthorList(authorIndex).(propertyName) = value;
                end
                success = true;
            catch ME
                 % warning('AuthorData:UpdatePropertyError', 'Error updating property "%s": %s', propertyName, ME.message);
            end
        end

        function fullName = getAuthorName(obj, authorIndex)
            %getAuthorName Get the full name for the given author (simplified).
            if authorIndex < 1 || authorIndex > numel(obj.AuthorList)
                fullName = sprintf('Author %d (Invalid)', authorIndex);
                return;
            end
            authorItem = obj.AuthorList(authorIndex);
            givenName = authorItem.givenName;
            familyName = authorItem.familyName;
            fullName = strtrim(strjoin({givenName, familyName}, ' '));
            if isempty(fullName)
                fullName = sprintf('Author %d', authorIndex);
            end
        end

        function addAffiliation(obj, organizationName, authorIndex)
            %addAffiliation Adds an affiliation to the specified author (simplified).
            if authorIndex < 1 || authorIndex > numel(obj.AuthorList)
                 if authorIndex == numel(obj.AuthorList) + 1 % If trying to add to next new author
                    obj.addDefaultAuthorEntry();
                 else
                    return; % Silently ignore invalid index
                 end
            end
            
            affiliationStruct = struct('memberOf', struct('fullName', organizationName));
            if isempty(obj.AuthorList(authorIndex).affiliation) || ~isstruct(obj.AuthorList(authorIndex).affiliation)
                obj.AuthorList(authorIndex).affiliation = affiliationStruct;
            else
                obj.AuthorList(authorIndex).affiliation(end+1) = affiliationStruct;
            end
        end

        function removeAffiliation(obj, authorIndex, affiliationIndex)
            %removeAffiliation Removes an affiliation (simplified).
            if authorIndex > 0 && authorIndex <= numel(obj.AuthorList) && ...
               isfield(obj.AuthorList(authorIndex), 'affiliation') && ...
               isstruct(obj.AuthorList(authorIndex).affiliation) && ...
               affiliationIndex > 0 && affiliationIndex <= numel(obj.AuthorList(authorIndex).affiliation)
                
                obj.AuthorList(authorIndex).affiliation(affiliationIndex) = [];
                if isempty(obj.AuthorList(authorIndex).affiliation) 
                     obj.AuthorList(authorIndex).affiliation = repmat(struct('memberOf',struct('fullName','')),0,1);
                end
            end
        end
    end

    methods (Static)
        function S = getDefaultAuthorItem()
            %getDefaultAuthorItem Returns a struct with all default fields for an author.
            S = struct();
            S.givenName = '';
            S.familyName = '';
            S.authorRole = {}; % Cell array for multiple roles
            S.contactInformation = struct('email', '');
            S.digitalIdentifier = struct('identifier', ''); % ORCID, etc.
            S.affiliation = repmat(struct('memberOf',struct('fullName','')),0,1); 
        end
    end
end
