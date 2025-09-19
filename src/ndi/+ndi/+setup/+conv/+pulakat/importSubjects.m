function [subjectTable] = importSubjects(sessions,subjectTable)
%IMPORTSUBJECTS Summary of this function goes here
%   Detailed explanation goes here

% how to process multiple sessions here?

% Identify new subjects
indNew = ~ndi.fun.table.identifyValidRows(subjectTable,'Ingested');
subjectTable_new = subjectTable(indNew,:);

% Create subjectMaker
subjectMaker = ndi.setup.NDIMaker.subjectMaker();
subjectCreator = ndi.setup.conv.pulakat.SubjectInformationCreator();

% Create subject documents (and add to session)
for i = 1:numel(sessions)
    [~,subjectTable_new.subjectName,subjectTable_new.subject_id] = ...
        subjectMaker.addSubjectsFromTable(sessions{i},subjectTable_new,subjectCreator);
end

end

