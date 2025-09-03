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
        function treatmentTable = create(obj, epochsTable, allSubjectNames, session)
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
                obj (1,1) ndi.setup.conv.birren.TreatmentCreator
                epochsTable (:,:) table {ndi.validators.mustHaveRequiredColumns(epochsTable, ...
                    {'Neurons', 'Glia', 'Chronic_48h_Dreads', 'Chronic_48hexamethonium', ...
                     'Chronic_24ORLESShexamethonium', 'glial_dreadds', 'neuronal_dreadds', 'ExperimentDateString'})}
                allSubjectNames (:,1) cell
                session (1,1) ndi.session.dir
            end

            uniqueSubjects = unique(allSubjectNames);
            % Initialize the output table with all possible columns using the superclass method
            treatmentTable = obj.initialize_treatment_table();

            % Iterate over each unique subject
            for i = 1:numel(uniqueSubjects)
                subjectId = uniqueSubjects{i};
                
                % Find the first row for this subject to get representative info
                subjectRows = find(strcmp(allSubjectNames, subjectId));
                if isempty(subjectRows), continue; end
                firstRow = epochsTable(subjectRows(1), :);
                
                % --- Process different treatment types based on column values ---
                
                % 1. Cell Culture Treatments
                cultureRows = obj.create_culture_treatment_rows(firstRow, subjectId, session.path);
                treatmentTable = [treatmentTable; cultureRows];
                
                % 2. Drug Treatments
                drugRows = obj.create_drug_treatment_rows(firstRow, subjectId, session.path);
                treatmentTable = [treatmentTable; drugRows];
                
                % 3. Virus Treatments
                virusRows = obj.create_virus_treatment_rows(firstRow, subjectId, session.path);
                treatmentTable = [treatmentTable; virusRows];
            end

            % FIX: Rename the outdated column name from the superclass to match the current NDI schema
            if ismember('location_ontologyNode', treatmentTable.Properties.VariableNames)
                disp('Fixing outdated treatment table column name within TreatmentCreator...');
                treatmentTable = renamevars(treatmentTable, 'location_ontologyNode', 'location_ontologyName');
            end
        end
    end

    methods (Access = private, Static)
        function row = create_empty_row(subjectId, sessionPath)
            % Creates a single row with default empty/NaN values
            row = { ...
                "", "", "", NaN, string(subjectId), string(sessionPath), ... % standard fields
                "", "", "", "", "", NaN, ... % drug fields
                "", "", "", "", "", "", NaN, "", "" ... % virus fields
            };
        end

        function rows = create_culture_treatment_rows(infoRow, subjectId, sessionPath)
            % Creates rows for 'treatment' type based on cell culture info
            rows = [];
            
            if infoRow.Neurons == 1
                newRow = ndi.setup.conv.birren.TreatmentCreator.create_empty_row(subjectId, sessionPath);
                newRow{1} = "treatment";
                newRow{2} = "EMPTY:Treatment: Culture from cell type";
                newRow{3} = "CL:0011103"; % Neuron
                rows = [rows; newRow];
            end
            if infoRow.Glia == 1
                newRow = ndi.setup.conv.birren.TreatmentCreator.create_empty_row(subjectId, sessionPath);
                newRow{1} = "treatment";
                newRow{2} = "EMPTY:Treatment: Culture from cell type";
                newRow{3} = "CL:0000516"; % Glial Cell
                rows = [rows; newRow];
            end
        end

        function rows = create_drug_treatment_rows(infoRow, subjectId, sessionPath)
            % Creates rows for 'treatment_drug' type
            rows = [];
            expDate = datetime(infoRow.ExperimentDateString, 'InputFormat', 'yyyy_MM_dd');
            
            if infoRow.Chronic_48h_Dreads == 1
                newRow = ndi.setup.conv.birren.TreatmentCreator.create_empty_row(subjectId, sessionPath);
                newRow{1} = "treatment_drug";
                newRow{7} = 'NCIm:C0179246'; % location_ontologyNode: Bath
                newRow{8} = 'bath'; % location_name
                mixStruct = struct('ontologyName','NCIm:C0212364', 'name','clozapine N-oxide', 'value',10e-6, 'ontologyUnit','OM:MolarVolumeUnit', 'unitName','Molar');
                newRow{9} = ndi.database.fun.writetablechar(struct2table(mixStruct));
                onset_time = expDate - days(2);
                offset_time = expDate;
                newRow{10} = string(onset_time,'yyyy-MM-dd') + "T" + string(onset_time,'HH:mm:ss');
                newRow{11} = string(offset_time,'yyyy-MM-dd') + "T" + string(offset_time,'HH:mm:ss');
                newRow{12} = 2; % duration in days
                rows = [rows; newRow];
            end
            if infoRow.Chronic_48hexamethonium == 1
                newRow = ndi.setup.conv.birren.TreatmentCreator.create_empty_row(subjectId, sessionPath);
                newRow{1} = "treatment_drug";
                newRow{7} = 'NCIm:C0179246';
                newRow{8} = 'bath';
                mixStruct = struct('ontologyName','NCIm:C0062637', 'name','Hexamethonium', 'value',100e-6, 'ontologyUnit','OM:MolarVolumeUnit', 'unitName','Molar');
                newRow{9} = ndi.database.fun.writetablechar(struct2table(mixStruct));
                onset_time = expDate - days(2);
                offset_time = expDate;
                newRow{10} = string(onset_time,'yyyy-MM-dd') + "T" + string(onset_time,'HH:mm:ss');
                newRow{11} = string(offset_time,'yyyy-MM-dd') + "T" + string(offset_time,'HH:mm:ss');
                newRow{12} = 2;
                rows = [rows; newRow];
            end
            if infoRow.Chronic_24ORLESShexamethonium == 1
                newRow = ndi.setup.conv.birren.TreatmentCreator.create_empty_row(subjectId, sessionPath);
                newRow{1} = "treatment_drug";
                newRow{7} = 'NCIm:C0179246';
                newRow{8} = 'bath';
                mixStruct = struct('ontologyName','NCIm:C0062637', 'name','Hexamonium', 'value',100e-6, 'ontologyUnit','OM:MolarVolumeUnit', 'unitName','Molar');
                newRow{9} = ndi.database.fun.writetablechar(struct2table(mixStruct));
                onset_time = expDate - hours(6); % Assume 6 hours
                offset_time = expDate;
                newRow{10} = string(onset_time,'yyyy-MM-dd') + "T" + string(onset_time,'HH:mm:ss');
                newRow{11} = string(offset_time,'yyyy-MM-dd') + "T" + string(offset_time,'HH:mm:ss');
                newRow{12} = 6/24; % duration in days
                rows = [rows; newRow];
            end
        end

        function rows = create_virus_treatment_rows(infoRow, subjectId, sessionPath)
            % Creates rows for 'virus_injection' type
            rows = [];
            
            if infoRow.neuronal_dreadds == 1
                newRow = ndi.setup.conv.birren.TreatmentCreator.create_empty_row(subjectId, sessionPath);
                newRow{1} = "virus_injection";
                newRow{13} = 'AddGene:AAV9-hSyn-hM3D(Gq)-mCherry';
                newRow{14} = 'AAV9-hSyn-hM3D(Gq)-mCherry';
                newRow{15} = 'NCIm:C0179246'; % Location: Bath
                newRow{16} = 'bath';
                newRow{17} = ""; % AdministrationDate not specified
                newRow{18} = "3"; % AdministrationPND
                newRow{19} = 0; % dilution
                newRow{20} = 'NCIm:C0043047'; % Vehicle: Water
                newRow{21} = 'Water';
                rows = [rows; newRow];
            end
            if infoRow.glial_dreadds == 1
                newRow = ndi.setup.conv.birren.TreatmentCreator.create_empty_row(subjectId, sessionPath);
                newRow{1} = "virus_injection";
                newRow{13} = 'AddGene:AAV-GFAP-hM3D(Gq)-mCherry'; % Using name as placeholder ID
                newRow{14} = 'AAV-GFAP-hM3D(Gq)-mCherry';
                newRow{15} = 'NCIm:C0179246'; % Location: Bath
                newRow{16} = 'bath';
                newRow{17} = ""; % AdministrationDate not specified
                newRow{18} = "3"; % AdministrationPND
                newRow{19} = 0; % dilution
                newRow{20} = 'NCIm:C0043047'; % Vehicle: Water
                newRow{21} = 'Water';
                rows = [rows; newRow];
            end
        end
    end % private static methods
end % classdef
