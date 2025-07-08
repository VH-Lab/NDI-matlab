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

for i=1:numel(u)
    % any example should be fine, take the first
    index = find(T_in.subjectIdentifier==u{i});
    index1 = index(1); % first, should not be empty
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
    if contains(secondTreatmentString,"48hCNO")
        t_here.treatment = 'EMPTY:Treatment: Chronic chemical application onset';
        t_here.stringValue = 

    end
    if contains(secondTreatmentString,"8hHexamethonium")

    end
end
