function T_out = sayaTreatmentTable(T_in)
   % T_in needs SubjectIdentifier


 % makes a table with the following columns:
 %
 %       'treatment'         - The name of the treatment, prefixed with its ontology (e.g., 'NDIC:Treatment Name').
 %       'stringValue'       - A string value for the treatment.
 %       'numericValue'      - A numeric value for the treatment.
 %       'subjectIdentifier' - The local identifier for the subject.
 %       'sessionPath'       - The path for the session (not used here but
 %                             part of the standard table).


u = unique(T_in.subjectIdentifier);


T_out = table();

for i=1:numel(u)

    % any example should be fine, take the first
    index = find(T_in.subjectIdentifier==u{i});
    index1 = index(1); % first, should not be empty
    expDate = datetime(T_in{i,"filename"}(1:10),'InputFormat','yyyy_MM_dd');

    treatmentString = T_in{index,"subject"};
    t_here = table();
    if startsWith(treatmentString,"N",'IgnoreCase',true)
        t_here.treatment = 'EMPTY:Treatment: Culture from cell type';
        t_here.stringValue = 'CL:0011103';
        t_here.numericValue = NaN;
        t_here.subjectIdentifier = u{i};
    end
    if contains(treatmentString,"glia",'IgnoreCase',true)
        t_here.treatment = 'EMPTY:Treatment: Culture from cell type';
        t_here.stringValue = 'CL:0000516';
        t_here.numericValue = NaN;
        t_here.subjectIdentifier = u{i};
    end

    secondTreatmentString = T_in{index,"treatment"};
    if contains(secondTreatmentString,"48hCNO",'IgnoreCase',true)
        t_here.location_ontologyNode = 'NCIm:C0179246';
        t_here.location_name = 'bath';
        mixStruct = struct('ontologyName','NCIm:C0212364',...
            'name', 'clozapine N-oxide',...
            'value', 10e-6,...
            'ontologyUnit', 'OM:MolarVolumeUnit',
            'unitName', 'Molar');
        t_here.mixture_table = ndi.database.fun.writetablechar(struct2table(mixStruct));
        onset_time = expDat - days(2);
        offset_time = expDat;
        t_here.administration_onset_time = string(onset_time,'yyyy-MM-dd') + "T" + string(onset_time,'HH:mm:ss');
        t_here.administration_offset_time = string(offset_time,'yyyy-MM-dd') + "T" + string(offset_time,'HH:mm:ss');
        t_here.administration_duration = 2;
    end

    if contains(secondTreatmentString,"48hHexamethonium")
        t_here.location_ontologyNode = 'NCIm:C0179246';
        t_here.location_name = 'bath';
        mixStruct = struct('ontologyName','NCIm:C0062637',...
            'name', 'Hexamethonium',...
            'value', 100e-6,...
            'ontologyUnit', 'OM:MolarVolumeUnit',
            'unitName', 'Molar');
        t_here.mixture_table = ndi.database.fun.writetablechar(struct2table(mixStruct));
        onset_time = expDat - days(2);
        offset_time = expDat;
        t_here.administration_onset_time = string(onset_time,'yyyy-MM-dd') + "T" + string(onset_time,'HH:mm:ss');
        t_here.administration_offset_time = string(offset_time,'yyyy-MM-dd') + "T" + string(offset_time,'HH:mm:ss');
        t_here.administration_duration = 2;
    end

    if contains(treatmentString,'dread','IgnoreCase',true)
        t_here.virus_OntologyName = 'AddGene:AAV9-hSyn-hM3D(Gq)-mCherry';
        t_here.virus_name = 'AAV9-hSyn-hM3D(Gq)-mCherry';
        t_here.virusLocation_OntologyName = 'NCIm:C0179246';
        t_here.virusLocation_name = 'bath';
        t_here.virus_AdministrationDate = '';
        t_here.virus_AdministrationPND = '3';
        t_here.dilution= 0;
        t_here.diluent_OntologyName = 'NCIm:C0043047';
        t_here.diluent_name = 'Water';
    end

    T_out = ndi.fun.table.vstack(T_out,struct2table(t_here));
end
