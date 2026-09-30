function preflight(options)
%PREFLIGHT Check that a V2 import can run, and say how to fix it if not.
%
%   ndi.setup.V2.preflight() errors (ndi:setup:V2:preflight) with ONE message
%   listing every missing requirement, before any stage runs:
%
%     * DID-matlab's did2.build is on the MATLAB path (DID-matlab `V2`, since
%       DID-matlab PR #210);
%     * DID_SCHEMA_PATH names a folder holding the V2 (V_eta) schema, assembled
%       flat from did-schema main's schemas/V_eta/{stable,draft,deprecated};
%     * that schema carries each class listed in 'Classes'.
%
%   A missing requirement otherwise surfaces deep inside a stage as "Unable
%   to resolve the name 'did2.build.label'" or a schema error, which says
%   nothing about the fix.
%
%   Options:
%     'Classes'  cellstr of schema classes the import needs
%                (default {'study', 'session'})

arguments
    options.Classes cell = {'study', 'session'}
end

problems = {};
if isempty(which('did2.build.document'))
    problems{end+1} = sprintf(['did2.build is not on the MATLAB path. Update DID-matlab to its ' ...
        '`V2` branch (git checkout V2; git pull) and add it to the path.']);
end
sp = getenv('DID_SCHEMA_PATH');
if isempty(sp) || ~isfolder(sp)
    problems{end+1} = sprintf(['DID_SCHEMA_PATH is not set to a folder (it is "%s"). Copy did-schema ' ...
        'main''s schemas/V_eta/{stable,draft,deprecated}/*.json into one folder and ' ...
        'setenv(''DID_SCHEMA_PATH'', <that folder>), then did2.schema.cache.resetSingleton().'], sp);
else
    missing = options.Classes(~cellfun(@(c) isfile(fullfile(sp, [c '.json'])), options.Classes));
    if ~isempty(missing)
        problems{end+1} = sprintf(['The schema in DID_SCHEMA_PATH (%s) has no %s. It predates ' ...
            'the V2 classes this import uses: re-copy it from did-schema main.'], ...
            sp, strjoin(strcat('`', missing, '`'), ', '));
    elseif any(strcmp(options.Classes, 'session'))
        s = jsondecode(fileread(fullfile(sp, 'session.json')));
        f = s.fields;
        if iscell(f), names = cellfun(@(x) x.name, f, 'UniformOutput', false); else, names = {f.name}; end
        if ~any(strcmp(names, 'name'))
            problems{end+1} = sprintf(['The schema in DID_SCHEMA_PATH (%s) has no session.name ' ...
                '(did-schema PR #79): re-copy it from did-schema main.'], sp);
        end
    end
end
if ~isempty(problems)
    error('ndi:setup:V2:preflight', 'The V2 import cannot run yet:\n  - %s', ...
        strjoin(problems, sprintf('\n  - ')));
end
end
