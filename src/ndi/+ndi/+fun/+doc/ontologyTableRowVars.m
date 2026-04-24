function [names,variableNames,ontologyNodes] = ontologyTableRowVars(S)
% ONTOLOGYTABLEROWVARS - return all ontologyTableRow document variable names in dataset/session
%
% [NAMES,VARIABLENAMES,ONTOLOGYNODES] = ONTOLOGYTABLEROWVARS(S)
%
% Given an ndi.session or ndi.dataset object S, finds all N of the unique
% variable names (that is, column names) for all ontologyTableRow documents.
%
% NAMES        {Nx1}: cell array of ontology names available
% VARIABLENAMES{Nx1}: the short name that appears in the table
% ONTOLOGYNODES{Nx1}: the ontology node names of each variable
%
% Example:
% % if S is an ndi.session or ndi.dataset
% [names,variableNames,ontologyNodes] = ndi.fun.doc.ontologyTableVars(S);
%

if isa(S,'ndi.session.dir') | isa(S,'ndi.dataset.dir')
    docs = S.database_search(ndi.query('','isa','ontologyTableRow'));
elseif iscell(S) & isa(S{1},'ndi.document')
    docs = S;
elseif isa(S,'ndi.document')
    docs = {S};
end

names = {};
variableNames = {};
ontologyNodes = {};

for i=1:numel(docs)
    if ~isempty(docs{i}.document_properties.ontologyTableRow.names)
        nameCellArray = strsplit(docs{i}.document_properties.ontologyTableRow.names,',');
        variableNamesArray = strsplit(docs{i}.document_properties.ontologyTableRow.variableNames,',');
        ontologyNodeArray = strsplit(docs{i}.document_properties.ontologyTableRow.ontologyNodes,',');
    end
    nameList = cat(1,names,nameCellArray(:));
    variableNamesArrayList = cat(1,variableNames,variableNamesArray(:));
    ontologyNodeArrayList = cat(1,ontologyNodes,ontologyNodeArray(:));
    [names,itemIndexes] = unique(nameList);
    variableNames = variableNamesArrayList(itemIndexes);
    ontologyNodes = ontologyNodeArrayList(itemIndexes);
end

