classdef SimpleTestCreator < ndi.setup.NDIMaker.SubjectInformationCreator
% A simple creator for testing that mimics the old simpleSubjectInfoFun.

    methods
        function [subjectIdentifier, strain, species, biologicalSex] = create(~, tableRow)
            % CREATE - Extracts the 'subjectName' for testing purposes.
            %
            %   This method simulates the extraction of subject information,
            %   returning NaNs for strain, species, and biologicalSex, as
            %   they are not needed for these specific tests.

            subjectIdentifier = NaN;
            strain = NaN;
            species = NaN;
            biologicalSex = NaN;

            if ismember('subjectName', tableRow.Properties.VariableNames)
                val = tableRow.subjectName;
                if iscell(val) 
                    if ~isempty(val)
                        subjectIdentifier = val{1};
                    end
                else
                    subjectIdentifier = val;
                end
                
                if isstring(subjectIdentifier) 
                    subjectIdentifier = char(subjectIdentifier);
                end % if
                if isnumeric(subjectIdentifier) && all(isnan(subjectIdentifier(:))) 
                    subjectIdentifier = NaN;
                end % if
            end % if
        end % create()
    end % methods
end % SimpleTestCreator