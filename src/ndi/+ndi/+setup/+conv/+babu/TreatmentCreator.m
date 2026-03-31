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
        function treatmentTable = create(obj, subjectTable, session)
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
                obj (1,1) ndi.setup.conv.babu.TreatmentCreator
                subjectTable (:,:) table {ndi.validators.mustHaveRequiredColumns(subjectTable, ...
                    {'SubjectLocalIdentifier'})}
                session (1,1) ndi.session.dir
            end

            treatmentFile = which(fullfile('+ndi','+setup','+conv','+babu','treatments.json'));
            treatments = jsondecode(fileread(treatmentFile));
            
            % Create heat treatment table rows
            heatTable = convertvars(struct2table(treatments.agar),{'location_ontologyName','location_name'},'string');
            heatTable.mixture_table = {ndi.database.fun.writetablechar(struct2table(treatments.heat))};
            indHeat = subjectTable.Heat | subjectTable.Trained;
            heatTable = repmat(heatTable,sum(indHeat),1);
            heatTable.subjectIdentifier = subjectTable.SubjectLocalIdentifier(indHeat);
            heatTable.administration_onset_time = subjectTable.HeatOnset(indHeat);
            heatTable.administration_offset_time = heatTable.administration_onset_time + minutes(2);
            heatTable.administration_duration = string(days(heatTable.administration_offset_time - ...
                heatTable.administration_onset_time));
            heatTable = repmat(heatTable,5,1);
            delay = reshape(subjectTable.TrainInterval(indHeat)*(0:4),[],1);
            heatTable.administration_onset_time = string(heatTable.administration_onset_time + delay,'hh:mm:ss');
            heatTable.administration_offset_time = string(heatTable.administration_offset_time + delay,'hh:mm:ss');
            
            % Create odor treatment table rows
            odorTable = convertvars(struct2table(treatments.air),{'location_ontologyName','location_name'},'string');
            indOdor = subjectTable.Odor;
            odorTable = repmat(odorTable,sum(indOdor),1);
            odorTable.subjectIdentifier = subjectTable.SubjectLocalIdentifier(indOdor);
            odorTable.mixture_table = cellfun(@(o) ndi.database.fun.writetablechar(struct2table(treatments.(o))),...
                subjectTable.TrainOdor(indOdor),'UniformOutput',false);
            odorTable.administration_onset_time = subjectTable.OdorOnset(indOdor);
            odorTable.administration_offset_time = subjectTable.OdorOnset(indOdor) + subjectTable.OdorDuration(indOdor);
            odorTable.administration_duration = string(days(subjectTable.OdorDuration(indOdor)));
            odorTable = repmat(odorTable,5,1);
            delay = reshape(subjectTable.TrainInterval(indOdor)*(0:4),[],1);
            odorTable.administration_onset_time = string(odorTable.administration_onset_time + delay,'hh:mm:ss');
            odorTable.administration_offset_time = string(odorTable.administration_offset_time + delay,'hh:mm:ss');
           
            % Create chemical treatment table rows
            chemicalTable = convertvars(struct2table(treatments.agar),{'location_ontologyName','location_name'},'string');
            indChemical = subjectTable.Chemical;
            chemicalTable = repmat(chemicalTable,sum(indChemical),1);
            chemicalTable.subjectIdentifier = subjectTable.SubjectLocalIdentifier(indChemical);
            chemicalTable.mixture_table = cellfun(@(o) ndi.database.fun.writetablechar(struct2table(...
                cellfun(@(c) treatments.(c),strsplit(o,',')))),...
                subjectTable.TrainOdor(indChemical),'UniformOutput',false);
            chemicalTable.administration_onset_time = subjectTable.OdorOnset(indChemical);
            chemicalTable.administration_offset_time = subjectTable.OdorOnset(indChemical) + subjectTable.OdorDuration(indChemical);
            chemicalTable.administration_duration = string(days(subjectTable.OdorDuration(indChemical)));
            chemicalTable = repmat(chemicalTable,5,1);
            delay = reshape(subjectTable.TrainInterval(indChemical)*(0:4),[],1);
            chemicalTable.administration_onset_time = string(chemicalTable.administration_onset_time + delay,'hh:mm:ss');
            chemicalTable.administration_offset_time = string(chemicalTable.administration_offset_time + delay,'hh:mm:ss');

            % Create OP50 treatment table rows
            OP50Table = convertvars(struct2table(treatments.agar),{'location_ontologyName','location_name'},'string');
            OP50Table = repmat(OP50Table,height(subjectTable),1);
            OP50Table.subjectIdentifier = subjectTable.SubjectLocalIdentifier;
            OP50Table{:,'mixture_table'} = {ndi.database.fun.writetablechar(struct2table(treatments.OP50))};
            OP50Table{subjectTable.HeatKilledOP50,'mixture_table'} = {ndi.database.fun.writetablechar(struct2table(treatments.OP50HK))};
            OP50Table.administration_onset_time = string(subjectTable.FoodOnset,'hh:mm:ss');
            OP50Table{:,'administration_offset_time'} = string(hours(0),'hh:mm:ss');
            OP50Table.administration_duration = string(days(-subjectTable.FoodOnset));

            % Combine treatment_drug tables
            drugTable = ndi.fun.table.vstack({heatTable,odorTable,chemicalTable,OP50Table});
            drugTable{:,'treatmentType'} = {'treatment_drug'};
            
            % Create treatment_transfer table rows
            transferTable = convertvars(struct2table(treatments.transfer_entity),{'entity_name','entity_ontologyNode'},'string');
            transferTable.treatmentType = {'treatment_transfer'};
            transferTable.clockType = {'local'};
            indM9 = subjectTable.M9;
            indPick = subjectTable.Pick | subjectTable.Transfer;
            indTransfer = indM9 | indPick;
            transferTable = repmat(transferTable,sum(indTransfer),1);
            transferTable.subjectIdentifier = subjectTable.SubjectLocalIdentifier(indTransfer);
            transferTable.timestamp = string(seconds(hours(-subjectTable.TransferTime(indTransfer))));
            transferTable(indM9(indTransfer),{'method_name','method_ontologyNode'}) = ...
                repmat(convertvars(struct2table(treatments.transfer_M9),...
                {'method_name','method_ontologyNode'},'string'),sum(indM9),1);
            transferTable(indPick(indTransfer),{'method_name','method_ontologyNode'}) = ...
                repmat(convertvars(struct2table(treatments.transfer_pick),...
                {'method_name','method_ontologyNode'},'string'),sum(indPick),1);
            transferTable.donor_id = subjectTable.donor_id(indTransfer);

            % Combine all tables
            treatmentTable = ndi.fun.table.vstack({drugTable,transferTable});
            treatmentTable{:,'sessionPath'} = {session.path};
        end
    end

end % classdef
