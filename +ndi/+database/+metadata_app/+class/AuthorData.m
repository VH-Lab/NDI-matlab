classdef AuthorData < handle
    %AuthorData A utility class for storing and retrieving information about authors.

    properties
        % A struct array holding information for each author. See
        % AuthorData.getDefaultAuthorItem for the fields contained in the
        % struct
        AuthorList (:,1) struct
    end

    methods % Public methods for interacting with author items

        function S = getItem(obj, authorIndex)
            %getAuthorName Get a struct with author details for the given index
            if numel( obj.AuthorList ) < authorIndex
                S = obj.getDefaultAuthorItem();
            else
                S = obj.AuthorList(authorIndex);
            end
        end

        function removeItem(obj, authorIndex)
            %removeItem Remove the specified author from the list.
            %
            %   Usage:
            %   authorData.removeItem(authorIndex) removes the author from the
            %   list where authorIndex is the index in the struct.

            obj.AuthorList(authorIndex) = [];
        end

        function reorderItems(obj, newIndex, oldIndex)
            obj.AuthorList([newIndex, oldIndex]) = ...
                obj.AuthorList([oldIndex, newIndex]);
        end

        function S = getAuthorList(obj)
            %getAuthorList Same as S = authorData.AuthorList
            S = obj.AuthorList;
        end

        function setAuthorList(obj, S)
            %setAuthorList Same as authorData.AuthorList = S
            obj.AuthorList = S;
        end

    end

    methods % Public methods for setting or getting author details

        function updateProperty(obj, name, value, authorIndex)
            %updateProperty Update the value in a field for the given
            % authorIndex

            % Expand the AuthorList with the default struct if necessary
            numAuthors = numel( obj.AuthorList );
            if numAuthors < authorIndex
                if numAuthors == 0
                    obj.AuthorList = obj.getDefaultAuthorItem();
                    if authorIndex > 1
                        obj.AuthorList(end+1:authorIndex) = deal(obj.getDefaultAuthorItem());
                    end
                else
                    obj.AuthorList(end+1:authorIndex) = deal(obj.getDefaultAuthorItem());
                end
            end

            if strcmp(name, 'digitalIdentifier')
                value = struct('identifier', value);
            elseif strcmp(name, 'contactInformation')
                value = struct('email', value);
            end

            obj.AuthorList(authorIndex).(name) = value;
        end

        function fullName = getAuthorName(obj, authorIndex)
            %getAuthorName Get the full name for the given author

            givenName = obj.AuthorList(authorIndex).givenName;
            familyName = obj.AuthorList(authorIndex).familyName;

            fullName = strjoin({givenName, familyName}, ' ');
            fullName = strtrim(fullName);

            if isempty(fullName)
                fullName = sprintf('Author %d', authorIndex);
            end
        end

        function addAffiliation(obj, organizationName, authorIndex)

            affiliationStruct = struct('memberOf', struct('fullName', organizationName));

            numAuthors = numel( obj.AuthorList );
            if numAuthors < authorIndex
                obj.updateProperty('affiliation', affiliationStruct, authorIndex)
            else
                if isempty(obj.AuthorList(authorIndex).affiliation)
                    obj.AuthorList(authorIndex).affiliation = affiliationStruct;
                else
                    obj.AuthorList(authorIndex).affiliation(end+1) = affiliationStruct;
                end
            end
        end

        function removeAffiliation(obj, authorIndex, affiliationIndex)
            obj.AuthorList(authorIndex).affiliation(affiliationIndex)=[];
        end


        % % %         function addAffiliation(obj, authorIndex, name, identifier)
        % % %             if isempty(obj.AuthorList(authorIndex).affiliation)
        % % %                 obj.AuthorList(authorIndex).affiliation = ndi.database.metadata_app.class.AffiliationData();
        % % %             else
        % % %                 size = obj.AuthorList(authorIndex).affiliation.getSize();
        % % %                 af = ndi.database.metadata_app.class.Affiliation();
        % % %                 af.memberOf.fullName = name;
        % % %                 af.memberOf.digitalIdentifier.identifier = identifier;
        % % %                 obj.AuthorList(authorIndex).affiliation.addItem(af);
        % % %             end
        % % %         end
        % % %
        % % %         function removeAffiliation(obj, authorIndex, affiliationIndex)
        % % %             obj.AuthorList(authorIndex).affiliation.removeItem(affiliationIndex);
        % % %         end

    end


    methods (Static)

        function S = getDefaultAuthorItem()
            % Todo: Consider using camelcase (i.e givenName) to conform
            % with openMINDS
            S = struct;
            S.affiliation = struct.empty;
            S.contactInformation.email = '';
            S.digitalIdentifier.identifier = '';
            S.familyName = '';
            S.givenName = '';
            S.authorRole = '';
        end

    end

end