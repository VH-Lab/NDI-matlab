classdef AffiliationData < handle
    %AffiliationData A utility class for storing and retrieving information about affiliations.

    properties
        % A struct array holding affiliation information for each author. See
        % AffiliationData.getDefaultAffiliationItem for the fields contained in the
        % struct
        AffiliationList (1,:) ndi.database.metadata_app.class.Affiliation
    end

    methods

        function removeItem(obj, affiliationIndex)
            %removeItem Remove the specified author form the list.
            %
            %   Usage:
            %   AffiliationData.removeItem(affiliationIndex) removes the affiliation from the
            %   list where affiliationIndex is the index in the struct.

            obj.AffiliationList(affiliationIndex) = [];
        end

        function addItem(obj, af)
            obj.AffiliationList(end + 1) = af;
        end

        function updateProperty(obj, name, value, affiliationIndex)
            %updateProperty Update the value in a field for the given
            %affiliationIndex

            % Expand the AffiliationList with the default struct if necessary
            if numel( obj.AffiliationList ) < affiliationIndex
                if numel(obj.AffiliationList) == 0
                    obj.AffiliationList = obj.getDefaultAffiliationItem();
                else
                    obj.AffiliationList(end+1:affiliationIndex) = deal(obj.getDefaultAffiliationItem());
                end
            end
            obj.AffiliationList(affiliationIndex).(name)=value;
        end

        function obj = updateName(obj, value, affiliationIndex)
            %updateProperty Update the value in a field
            if numel( obj.AffiliationList ) < affiliationIndex
                if numel(obj.AffiliationList) == 0
                    obj.AffiliationList = obj.getDefaultAffiliationItem();
                else
                    obj.AffiliationList(end+1:affiliationIndex) = deal(obj.getDefaultAffiliationItem());
                end
            end
            obj.AffiliationList(affiliationIndex).updateName(value);
        end

        function obj = updateIdentifier(obj, value, affiliationIndex)
            %updateProperty Update the value in a field
            if numel( obj.AffiliationList ) < affiliationIndex
                if numel(obj.AffiliationList) == 0
                    obj.AffiliationList = obj.getDefaultAffiliationItem();
                else
                    obj.AffiliationList(end+1:affiliationIndex) = deal(obj.getDefaultAffiliationItem());
                end
            end
            obj.AffiliationList(affiliationIndex).updateIdentifier(value);
        end

        function affiliationName = getAffiliationName(obj, affiliationIndex)
            %getAffiliationName Get the full name for the given affiliation

            affiliationName = obj.AffiliationList(affiliationIndex).getName();

        end

        function S = getItem(obj, affiliationIndex)
            %getAffiliationName Get a struct with affiliation details for the given index
            if numel( obj.AffiliationList ) < affiliationIndex
                S = obj.getDefaultAffiliationItem();
            else
                S = obj.AffiliationList(affiliationIndex);
            end
        end

        function S = getAffiliationList(obj)
            %getAffiliationList Same as S = AffiliationData.AffiliationList
            S = obj.AffiliationList;
        end

        function setAffiliationList(obj, S)
            %setAffiliationList Same as AffiliationData.AffiliationList = S
            obj.AffiliationList = S;
        end

        function checkName(obj, ror, affiliationIndex)
            [name, ~] = ndi.database.metadata_app.fun.checkValidRORID(ror);
            obj.updateName(name, affiliationIndex);
        end

        function size = getSize(obj)
            size = numel(obj.AffiliationList);
        end
    end


    methods (Static)

        function S = getDefaultAffiliationItem()
            % Todo: Consider using camelcase (i.e givenName) to conform
            % with openMINDS
            S = ndi.database.metadata_app.class.Affiliation();
        end

    end

end