% file: +ndi/+setup/+conv/+babu/TreatmentCreator.m
classdef TreatmentCreator < ndi.setup.NDIMaker.TreatmentCreator
% TREATMENTCREATOR - Creates an NDI treatment table for the Hunsberger lab project.
%
% This class implements the 'create' method to generate NDI-compliant treatment 
% and measurement tables from a subject metadata table. It handles the logic 
% for drug administrations (Alprazolam/Saline), dose calculations, and 
% biometric measurements like weight and date of birth.
%
% It automatically corrects for legacy column names in the superclass, specifically
% mapping 'location_ontologyNode' to 'location_ontologyName'.
%
% See also: ndi.setup.NDIMaker.TreatmentCreator, ndi.ontology.EMPTY
%

    methods
        function treatmentTable = create(obj, subjectTable, session, treatmentName)
        % CREATE - Generates a treatment or measurement table based on specific columns.
        %
        %   TREATMENTTABLE = CREATE(OBJ, SUBJECTTABLE, SESSION, COLUMNNAME)
        %
        %   This method processes a specific column from the SUBJECTTABLE to generate
        %   NDI documents. It handles four primary cases:
        %
        %   1. 'DOB': Extracts Date of Birth as a 'measurement' (NCIT:C94173).
        %   2. 'InitialWeight_g_': Extracts weight as a 'measurement' (NCIT:C81328).
        %   3. 'InjectionTime': Processes the first drug administration. Logic:
        %      - Identifies mixture (Alprazolam/Saline) based on Timeline/Condition.
        %      - Sets location to Intraperitoneal (SNOMED:783351009).
        %      - Formats ISO 8601 onset times.
        %   4. 'injectionTimeDay2': Processes second drug administration (Day 2).
        %      - Handles specific dose logic (e.g., 0.25 mg/kg if indicated).
        %
        %   Inputs:
        %       obj (ndi.setup.conv.hunsberger.TreatmentCreator) - The instance of this creator class.
        %       subjectTable (table) - A MATLAB table containing subject metadata.
        %           Must contain 'SubjectLocalIdentifier'.
        %       session (ndi.session.dir) - The NDI session object where data is stored.
        %       columnName (char) - The specific column in subjectTable to process.
        %
        %   Outputs:
        %       treatmentTable (table) - A table containing formatted NDI treatment/measurement fields:
        %           'treatmentType', 'treatment', 'administration_onset_time', 'mixture_table',
        %           'location_ontologyName', 'stringValue' or 'numericValue'.
        %
        %   See also: ndi.setup.NDIMaker.TreatmentCreator
        %
            
            arguments
                obj (1,1) ndi.setup.conv.hunsberger.TreatmentCreator
                subjectTable (:,:) table {ndi.validators.mustHaveRequiredColumns(subjectTable, ...
                    {'SubjectLocalIdentifier'})}
                session (1,1) ndi.session.dir
                treatmentName (1,:) char
            end

            % Initialize the output table with all possible columns using the superclass method
            treatmentTable = renamevars(obj.initialize_treatment_table(),...
                'location_ontologyNode','location_ontologyName');

            treatmentFile = which(fullfile('+ndi','+setup','+conv','+babu','treatments.json'));
            treatments = jsondecode(fileread(treatmentFile));
            
            % Create heat treatment table rows
            heatTable = struct2table(treatments.agar);
            heatTable.mixture_table = {ndi.database.fun.writetablechar(struct2table(treatments.heat))};
            heatTable.TreatmentType = 'treatment_drug';
            heatTable.sessionPath = session.path;
            indHeat = subjectTable.Heat | subjectTable.Trained;
            heatTable = repmat(heatTable,sum(indHeat),1);
            heatTable.subjectIdentifier = subjectTable.SubjectLocalIdentifier(indHeat);
            heatTable.administration_onset_time = subjectTable.HeatOnset(indHeat);
            heatTable.administration_offset_time = heatTable.administration_onset_time + minutes(2);
            heatTable.administration_duration = string(days(heatTable.administration_offset_time - ...
                heatTable.administration_onset_time));
            heatTable = repmat(heatTable,5,1);
            delay = reshape(subjectTable.HeatInterval(indHeat)*(0:4),[],1);
            heatTable.administration_onset_time = string(heatTable.administration_onset_time + delay,'hh:mm:ss');
            heatTable.administration_offset_time = string(heatTable.administration_offset_time + delay,'hh:mm:ss');
            
            

            treatmentTable = outerjoin(treatmentTable,tempTable,'MergeKeys',true);
            
            % Apply fillmissing to all variables that are strings or cells
            isText = varfun(@(x) isstring(x) || iscell(x), treatmentTable, 'OutputFormat', 'uniform');
            treatmentTable = fillmissing(treatmentTable, 'constant', "", 'DataVariables', isText);
        end
    end

end % classdef
