% file: +ndi/+setup/+conv/+birren/createSayaTreatments.m
classdef createSayaTreatments < ndi.setup.NDIMaker.TreatmentCreator
% CREATESAYATREATMENTS - Creates an NDI treatment table for the Birren/Saya project.
%
% This class implements the 'create' method to generate a treatment table
% from a dataset information table specific to the "Saya" project in the
% Birren Lab. It produces a table that can describe simple treatments,
% drug treatments, and virus treatments.
%
    methods
        function treatmentTable = create(obj, datasetInfoTable)
        % CREATE - Generates a treatment table from the Saya project's dataset info.
        %
        %   TREATMENTTABLE = CREATE(OBJ, DATASETINFOTABLE)
        %
        %   This method processes the input table to identify treatments for each
        %   subject. It extracts information based on values in the 'subject' and
        %   'treatment' columns of the input table.
        %
        %   Inputs:
        %       obj (ndi.setup.conv.birren.createSayaTreatments) - The instance of this creator class.
        %       datasetInfoTable (table) - A MATLAB table containing metadata.
        %
        %   Outputs:
        %       treatmentTable (table) - A MATLAB table formatted for creating NDI treatment documents.
        %
        %   See also: ndi.setup.NDIMaker.TreatmentCreator
        %
            
            arguments
                obj (1,1) ndi.setup.conv.birren.createSayaTreatments
                datasetInfoTable (1,:) table {ndi.validators.mustHaveRequiredColumns(datasetInfoTable, ...
                    {'subjectIdentifier', 'subject', 'treatment', 'filename', 'sessionPath'})}
            end

            uniqueSubjects = unique(datasetInfoTable.subjectIdentifier);

            % Initialize the output table with all possible columns using the superclass method
            treatmentTable = obj.initialize_treatment_table();

            % Iterate over each unique subject
            for i = 1:numel(uniqueSubjects)
                subjectId = uniqueSubjects{i};
                
                % Find the first row for this subject to get representative info
                subjectRows = find(strcmp(datasetInfoTable.subjectIdentifier, subjectId));
                if isempty(subjectRows), continue; end
                firstRow = datasetInfoTable(subjectRows(1), :);
                
                % --- Process different treatment types ---
                
                % 1. Cell Culture Treatments
                cultureRows = obj.create_culture_treatment_rows(firstRow);
                treatmentTable = [treatmentTable; cultureRows];

                % 2. Drug Treatments
                drugRows = obj.create_drug_treatment_rows(firstRow);
                treatmentTable = [treatmentTable; drugRows];

                % 3. Virus Treatments
                virusRows = obj.create_virus_treatment_rows(firstRow);
                treatmentTable = [treatmentTable; virusRows];

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

        function rows = create_culture_treatment_rows(infoRow)
            % Creates rows for 'treatment' type based on cell culture info
            rows = [];
            subjectId = infoRow.subjectIdentifier;
            sessionPath = string(infoRow.sessionPath);
            treatmentString = char(infoRow.subject);
            
            if startsWith(treatmentString, 'N', 'IgnoreCase', true)
                newRow = ndi.setup.conv.birren.createSayaTreatments.create_empty_row(subjectId, sessionPath);
                newRow{1} = "treatment";
                newRow{2} = "EMPTY:Treatment: Culture from cell type";
                newRow{3} = "CL:0011103"; % Neuron
                rows = [rows; newRow];
            end
            if contains(treatmentString, 'glia', 'IgnoreCase', true)
                newRow = ndi.setup.conv.birren.createSayaTreatments.create_empty_row(subjectId, sessionPath);
                newRow{1} = "treatment";
                newRow{2} = "EMPTY:Treatment: Culture from cell type";
                newRow{3} = "CL:0000516"; % Glial Cell
                rows = [rows; newRow];
            end
        end

        function rows = create_drug_treatment_rows(infoRow)
            % Creates rows for 'treatment_drug' type
            rows = [];
            subjectId = infoRow.subjectIdentifier;
            sessionPath = string(infoRow.sessionPath);
            expDate = datetime(infoRow.filename(1:10), 'InputFormat', 'yyyy_MM_dd');
            secondTreatmentString = char(infoRow.treatment);

            if contains(secondTreatmentString, "48hCNO", 'IgnoreCase', true)
                newRow = ndi.setup.conv.birren.createSayaTreatments.create_empty_row(subjectId, sessionPath);
                newRow{1} = "treatment_drug";
                newRow{7} = 'NCIm:C0179246'; % location_ontologyNode
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

            if contains(secondTreatmentString, "48hHexamethonium", 'IgnoreCase', true)
                newRow = ndi.setup.conv.birren.createSayaTreatments.create_empty_row(subjectId, sessionPath);
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
        end

        function rows = create_virus_treatment_rows(infoRow)
            % Creates rows for 'treatment_virus' type
            rows = [];
            subjectId = infoRow.subjectIdentifier;
            sessionPath = string(infoRow.sessionPath);
            treatmentString = char(infoRow.subject);

            if contains(treatmentString, 'dread', 'IgnoreCase', true)
                newRow = ndi.setup.conv.birren.createSayaTreatments.create_empty_row(subjectId, sessionPath);
                newRow{1} = "treatment_virus";
                newRow{13} = 'AddGene:AAV9-hSyn-hM3D(Gq)-mCherry';
                newRow{14} = 'AAV9-hSyn-hM3D(Gq)-mCherry';
                newRow{15} = 'NCIm:C0179246';
                newRow{16} = 'bath';
                newRow{17} = ""; % AdministrationDate not specified
                newRow{18} = "3"; % AdministrationPND
                newRow{19} = 0; % dilution
                newRow{20} = 'NCIm:C0043047';
                newRow{21} = 'Water';
                rows = [rows; newRow];
            end
        end

    end % private static methods
end % classdef
