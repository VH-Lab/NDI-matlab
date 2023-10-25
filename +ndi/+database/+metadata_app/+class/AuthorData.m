classdef AuthorData < handle
%AuthorData A utility class for storing and retrieving information about authors.
    
    properties 
        % A struct array holding information for each author. See
        % AuthorData.getDefaultAuthorItem for the fields contained in the 
        % struct
        AuthorList (:,1) struct
    end

    methods
        
        function removeItem(obj, authorIndex)
        %removeItem Remove the specified author form the list.
        %
        %   Usage: 
        %   authorData.removeItem(authorIndex) removes the author from the
        %   list where authorIndex is the index in the struct.

            obj.AuthorList(authorIndex) = [];
        end
        
        function updateProperty(obj, name, value, authorIndex)
        %updateProperty Update the value in a field for the given
        %authorIndex

            % Expand the AuthorList with the default struct if necessary
            if numel( obj.AuthorList ) < authorIndex
                if numel(obj.AuthorList) == 0
                    obj.AuthorList = obj.getDefaultAuthorItem();
                else
                    obj.AuthorList(end+1:authorIndex) = deal(obj.getDefaultAuthorItem());
                end
            end
            obj.AuthorList(authorIndex).(name)=value;
        end

        function fullName = getAuthorName(obj, authorIndex)
        %getAuthorName Get the full name for the given author

            givenName = obj.AuthorList(authorIndex).GivenName;
            familyName = obj.AuthorList(authorIndex).FamilyName;

            fullName = strjoin({givenName, familyName}, ' ');
            fullName = strtrim(fullName);

            if isempty(fullName)
                fullName = sprintf('Author %d', authorIndex);
            end
        end

        function S = getItem(obj, authorIndex)
        %getAuthorName Get a struct with author details for the given index
            if numel( obj.AuthorList ) < authorIndex
                S = obj.getDefaultAuthorItem();
            else
                S = obj.AuthorList(authorIndex);
            end
        end

        function S = getAuthorList(obj)
        %getAuthorList Same as S = authorData.AuthorList
            S = obj.AuthorList;
        end

        function setAuthorList(obj, S)
        %setAuthorList Same as authorData.AuthorList = S
            obj.AuthorList = S;
        end

        function addAffiliation(obj, authorIndex,S)
            if isempty(obj.AuthorList(authorIndex).Affiliation)
                obj.AuthorList(authorIndex).Affiliation = S;
            else
                size = numel(obj.AuthorList(authorIndex).Affiliation);
                obj.AuthorList(authorIndex).Affiliation(size + 1) = S;         
            end
        end

        function removeAffiliation(obj, authorIndex, affiliationIndex)
            obj.AuthorList(authorIndex).Affiliation(affiliationIndex) = [];  
        end
    end

    
    methods (Static)

        function S = getDefaultAuthorItem()
            % Todo: Consider using camelcase (i.e givenName) to conform
            % with openMINDS
            S = struct;
            S.GivenName = '';
            S.FamilyName = '';
            S.ContactInformation = '';
            S.DigitalIdentifier = '';
            S.Role = '';
            S.Affiliation = '';
            S.Additional = '';
            
        end

    end

end