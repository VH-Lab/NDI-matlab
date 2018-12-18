function db = nsd_opendatabase(experiment_path)
% NSD_OPENDATABASE - open the database associated with an experiment
%
% DB = NSD_OPENDATABASE(EXPERIMENT_PATH)
%
% Searches the file path EXPERIMENT_PATH for any known databases
% in NSD_DATABASEHIERACHY. If it finds a datbase of subtype NSD_DATABASE,
% then it is opened and returned in DB.
%
% If it finds no databases, then it tries to create a new database following
% the order in the hierarchy.
%
% Otherwise, DB is empty.
%

nsd_globals;

db = [];

for i=1:numel(nsd_databasehierarchy),
	d = dir([experiment_path filesep '*' nsd_databasehierarchy(i).extension]);
	if ~isempty(d), % found one
		if numel(d)>1,
			error(['Too many matching files.']);
		end;
		fname = [experiment_path filesep d(1).name];
		evalstr = strrep(nsd_databasehierarchy(i).code,'FILENAME',fname);
		eval(evalstr);
		break;
	end;
end;

if isempty(db),
	for i=1:numel(nsd_databasehierarchy),
		if ~isempty(nsd_databasehierarchy(i).newcode),
			evalstr = strrep(nsd_databasehierarchy(i).newcode,'FILEPATH',[experiment_path filesep]);
			eval(evalstr);
		end;
		break;
	end
end


