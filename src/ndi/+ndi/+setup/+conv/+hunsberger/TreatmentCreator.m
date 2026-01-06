% file: +ndi/+setup/+conv/+birren/TreatmentCreator.m
classdef TreatmentCreator < ndi.setup.NDIMaker.TreatmentCreator
% TREATMENTCREATOR - Creates an NDI treatment table for the Birren lab project.
%
% This class implements the 'create' method to generate a treatment table
% from the main epochs table. It produces a table that can describe simple
% treatments (cell culture), drug treatments, and virus treatments based on
% binary indicators in the table. It also corrects for outdated column names
% from its superclass to ensure compatibility with the NDI schema.
%
    methods
        function treatmentTable = create(obj, subjectTable, session, columnName)
        % CREATE - Generates a treatment table from the project's epochs table.
        %
        %   TREATMENTTABLE = CREATE(OBJ, EPOCHSTABLE, ALLSUBJECTNAMES, SESSION)
        %
        %   This method processes the input epochsTable to identify treatments for each
        %   subject. It extracts information based on values in several columns that
        %   indicate the presence or absence of a treatment.
        %
        %   Inputs:
        %       obj (ndi.setup.conv.birren.TreatmentCreator) - The instance of this creator class.
        %       epochsTable (table) - A MATLAB table containing all epoch metadata.
        %       allSubjectNames (cell) - A cell array of subject identifiers for each row of epochsTable.
        %       session (ndi.session.dir) - The NDI session object.
        %
        %   Outputs:
        %       treatmentTable (table) - A MATLAB table formatted for creating NDI treatment documents.
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
                                'unitName','Milligram/kilogram'));
            saline = struct2table(struct('ontologyName','EFO:0002677',...
                                'name','saline', 'value',1, ...
                                'ontologyUnit','SNOMED:396163008', ...
                                'unitName','Milligram/kilogram'));

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
