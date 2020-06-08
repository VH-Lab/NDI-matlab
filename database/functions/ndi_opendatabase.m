function db = ndi_opendatabase(database_path, session_unique_reference)
% NDI_OPENDATABASE - open the database associated with an session
%
% DB = NDI_OPENDATABASE(DATABASE_PATH, SESSION_UNIQUE_REFERENCE)
%
% Searches the file path DATABASE_PATH for any known databases
% in NDI_DATABASEHIERACHY. If it finds a datbase of subtype NDI_DATABASE,
% then it is opened and returned in DB.
%
% If it finds no databases, then it tries to create a new database following
% the order in the hierarchy.
%
% Otherwise, DB is empty.
%

ndi_globals;

db = [];

for i=1:numel(ndi.databasehierarchy),
	d = dir([database_path filesep '*' ndi.databasehierarchy(i).extension]);
	if ~isempty(d), % found one
		if numel(d)>1,
			error(['Too many matching files.']);
		end;
		fname = [database_path filesep d(1).name];
		evalstr = strrep(ndi.databasehierarchy(i).code,'FILENAME',fname);
		evalstr = strrep(evalstr,'FILEPATH',[database_path filesep]);
		evalstr = strrep(evalstr,'SESSION_REFERENCE',session_unique_reference);
		eval(evalstr);
		break;
	end;
end;

if isempty(db),
	for i=1:numel(ndi.databasehierarchy),
		if ~isempty(ndi.databasehierarchy(i).newcode),
			evalstr = strrep(ndi.databasehierarchy(i).newcode,'FILEPATH',[database_path filesep]);
			evalstr = strrep(evalstr,'SESSION_REFERENCE',session_unique_reference);
			eval(evalstr);
		end;
		break;
	end
end


