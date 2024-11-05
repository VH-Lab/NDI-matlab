function docList = makeVoltageOffsets(S)
% MAKEVOLTAGEOFFSETS - Make documents from a table of voltage offset values
%
% DOCLIST = MAKEVOLTAGEOFFSETS(S)
%
% Read in a table called "MEoffset.txt" that is comma separated value and has 
% columns "probeName", "offsetV", and "T" (for temperature). The function then
% checks to see if the offset data has been added to the database, and, if not
% adds it.
%
% If there is no file, then no action is taken and a warning is given.
%
% Any newly created documents are returned in DOCLIST. They will already be added
% to the database of session S.
%

argument
   S (1,1) ndi.session
end

docList = {};

filenameNoPath = "MEoffset.txt";

filename = fullfile(S.pathname(),filenameNoPath);

if isfile(filename),
    t = readtable(filename);
else,
    warning(['No file ' filename ' found -- no action taken.']);
end;

for i=1:size(t,1), % for each row
    p = S.getprobe('probe.name',t{i,"probeName"});
    assert(~isempty(p),['Unable to find probe ' t{i,"probeName"} '.']);
    v = t{i,"offsetV"};
    temp = t{i,"T"};
    % see if we already have this document
    q1 = ndi.query('','isa','electrode_offset_voltage');
    q2 = ndi.query('','depends_on','probe_id',p.id());
    q3 = ndi.query('electrode_offset_voltage.offset','exact_number',v);
    q = q1 & q2 & q3;
    if ~isnan(temp),
        q4 = ndi.query('electrode_offset_voltage.temperature','exact_number','temp);
        q = q & q4;
    end;

    d = S.database_search(q);
    if isempty(d), % if we don't have one, make one
       electrode_offset_voltage = [];
       electrode_offset_voltage.offset = v;
       electrode_offset_voltage.temperature = temp;
       docList{end+1} = ndi.document('electrode_offset_voltage','electrode_offset_voltage',electrode_offset_voltage) +...
          S.newdocument();
    end

end

if ~isempty(docList)
    S.database_add(docList);
end



