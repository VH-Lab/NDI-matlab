dataParentDir = fullfile(userpath,'data');
dataPath = fullfile(dataParentDir,'Dabrowska');
S = ndi.session.dir(dataPath);

%% 

behaviorVariables = ndi.fun.doc.ontologyTableRowVars(S);
behaviorDocuments = S.database_search(ndi.query('','isa','ontologyTableRow'));

% Convert behavior docs to EPM and FPS tables