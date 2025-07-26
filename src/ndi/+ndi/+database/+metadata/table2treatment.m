function d = table2treatment(S, tableFileOrTable, subjectID, options)
% TABLE2TREATMENT - read in treatments for a session from a table
%
% D = TABLE2TREATMENT(S, TABLEFILE, SUBJECTID, ...)
%    or
% D = TABLE2TREATMENT(S, TABLE, SUBJECTID ...)
%
% Reads in table of treatment types and creates ndi.document objects of type
% 'treatment'. 
% 
% The table should have the following columns:
%    ontologyName - the ontology name for the manipulation
%            name - the name of the manipulation (from the ontology)
%   numeric_value - a numeric value 
%    string_value - a string value 
%           group - a group number for the manipulation
%
% All manipulations of the same group will have 'manipulation_id' set
% to the first manipulation listed. The first manipulation in each group
% will have 'manipulation_id' unset.
%
% This function takes name/value pairs:
% ---------------------------------------------------------------------------
% | Parameter (default)     | Description                                   |
% |-------------------------|-----------------------------------------------|
% | delimiter (',')         | Delmiter for the table file                   |
% | doNotAdd (false)        | If true, do not add documents to database     |
% ---------------------------------------------------------------------------
%

arguments
    S (1,1) ndi.session
    tableFileOrTable {mustBeA(tableFileOrTable,{'table','char','string'})}
    subjectID (1,:) char
    options.delimiter (1,1) char = ','
    options.doNotAdd (1,1) logical = false
end

if any(ismember(class(tableFileOrTable),{'char','string'}))
    mustBeFile(tableFileOrTable);
    t = readtable(tableFileOrTable,'delimiter',options.delimiter);
else
    t = tableFileOrTable;
end

groupLabels = {};
groupIDs = {};
d = {};

for i=1:size(t,1)
    treatS.ontologyName = t{i,"ontologyName"}{1};
    treatS.name = t{i,"name"}{1};
    treatS.numeric_value = t{i,"numeric_value"};
    treatS.string_value = string(t{i,"string_value"});
    if ismissing(treatS.string_value)
        treatS.string_value = '';
    end
    treatS.string_value = char(treatS.string_value);

    groupLabel = t{i,"group"};
    if isnumeric(groupLabel)
        groupLabel = num2str(groupLabel);
    end
    d{end+1} = ndi.document('treatment','treatment',treatS) + S.newdocument();
    index = find(cellfun(@(x) eq(groupLabel,x), groupLabels));
    if isempty(index) % new group,
        groupLabels{end+1} = groupLabel;
        groupIDs{end+1} = d{end}.id();
    else
        d{end} = d{end}.set_dependency_value('manipulation_id',groupIDs{index});
    end
    d{end} = d{end}.set_dependency_value('subject_id',subjectID);
end

if ~options.doNotAdd
    S.database_add(d);
end
