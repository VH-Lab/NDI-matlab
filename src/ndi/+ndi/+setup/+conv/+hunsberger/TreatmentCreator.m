% file: +ndi/+setup/+conv/+hunsberger/TreatmentCreator.m
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
        function treatmentTable = create(obj, subjectTable, session, columnName)
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
                columnName (1,:) char
            end

            % Initialize the output table with all possible columns using the superclass method
            treatmentTable = renamevars(obj.initialize_treatment_table(),...
                'location_ontologyNode','location_ontologyName');

            % Initialize mixture structs
            alprazolam = struct2table(struct('ontologyName','NCIT:C227',...
                                'name','alprazolam', 'value',1, ...
                                'ontologyUnit','SNOMED:396163008', ...
                                'unitName','mg/kg'));
            saline = struct2table(struct('ontologyName','EFO:0002677',...
                                'name','saline', 'value',1, ...
                                'ontologyUnit','SNOMED:396163008', ...
                                'unitName','mg/kg'));

            tempTable = table();
            indRemove = [];
            switch columnName
                case 'DOB'
                    tempTable.stringValue = cellstr(string(subjectTable.DOB, 'yyyy-MM-dd'));
                    tempTable(:,'treatmentType') = {'measurement'};
                    tempTable(:,'treatment') = {'NCIT:C94173'};
                    indRemove = ndi.fun.table.identifyMatchingRows(tempTable,'stringValue','');
                case 'InitialWeight_g_'
                    tempTable.numericValue = subjectTable.InitialWeight_g_;
                    tempTable(:,'treatmentType') = {'measurement'};
                    tempTable(:,'treatment') = {'NCIT:C81328'};
                case 'InjectionTime'
                    for i = 1:height(subjectTable)
                        if isnan(subjectTable.InjectionTime(i))
                            tempTable.administration_onset_time(i) = ...
                                cellstr(string(subjectTable.Today(i),'yyyy-MM-dd'));
                        else
                            tempTable.administration_onset_time(i) = ...
                                cellstr(string(subjectTable.Today(i),'yyyy-MM-dd') + "T" + ...
                                string(days(subjectTable.InjectionTime(i)),'hh:mm:ss'));
                        end
                        if strcmp(subjectTable.Timeline{i}(1),'A') 
                            mixtureTable = alprazolam;
                        elseif strcmp(subjectTable.Condition{i},'Treatment')
                            mixtureTable = alprazolam;
                        else
                            mixtureTable = saline;
                        end
                        tempTable.mixture_table(i) = {ndi.database.fun.writetablechar(mixtureTable)};
                    end
                    tempTable(:,'location_ontologyName') = {'SNOMED:783351009'};
                    tempTable(:,'location_name') = {'Intraperitoneal'};
                    tempTable(:,'treatmentType') = {'treatment_drug'};
                case 'injectionTimeDay2'
                    indRemove = isnan(subjectTable.injectionTimeDay2);
                    for i = 1:height(subjectTable)
                        tempTable.administration_onset_time(i) = ...
                            cellstr(string(days(5) + subjectTable.Today(i),'yyyy-MM-dd') + "T" + ...
                            string(days(subjectTable.injectionTimeDay2(i)),'hh:mm:ss'));
                        if contains(subjectTable.Timeline{i},'-A')
                            mixtureTable = alprazolam;
                        else
                            mixtureTable = saline;
                        end
                        if contains(subjectTable.Timeline{i},'(0.25)')
                            mixtureTable.value = 0.25;
                        end
                        tempTable.mixture_table(i) = {ndi.database.fun.writetablechar(mixtureTable)};
                    end
                    tempTable(:,'location_ontologyName') = {'SNOMED:783351009'};
                    tempTable(:,'location_name') = {'Intraperitoneal'};
                    tempTable(:,'treatmentType') = {'treatment_drug'};
            end
            tempTable.subjectIdentifier = subjectTable.SubjectLocalIdentifier;
            tempTable(:,'sessionPath') = {session.path};
            tempTable(indRemove,:) = [];
            treatmentTable = outerjoin(treatmentTable,tempTable,'MergeKeys',true);
            
            % Apply fillmissing to all variables that are strings or cells
            isText = varfun(@(x) isstring(x) || iscell(x), treatmentTable, 'OutputFormat', 'uniform');
            treatmentTable = fillmissing(treatmentTable, 'constant', "", 'DataVariables', isText);
        end
    end

end % classdef
