function found = systemStatements(S, systemId, inSession)
%SYSTEMSTATEMENTS The recording statements of one acquisition system, from either shape.
%
%   FOUND = ndi.vintage.systemStatements(SESSION, SYSTEMID, INSESSION) returns
%   a cell of cell arrays of ndi.document: first the statements that name
%   the system by `acquisition_system_id` (did-schema, Jess Haley 2026-11-01
%   [probe wiring is a relation]: a recording points straight at its
%   system), then, for a session written before that, the statements that
%   name one of the system's `acquisition_channels` documents. A statement
%   is listed once. INSESSION is the query restricting the search to the
%   session (ndi.query('base.session_id', 'exact_string', ...)).
%
%   See also ndi.file.navigator.bodies.

found = {S.database_search(ndi.v2.isaQuery('statement') & ...
    ndi.query('', 'depends_on', 'acquisition_system_id', systemId) & inSession)};
seen = cellfun(@(d) d.id(), found{1}, 'UniformOutput', false);
channels = S.database_search(ndi.query('', 'isa', 'acquisition_channels', '') & ...
    ndi.query('', 'depends_on', 'acquisition_system_id', systemId) & inSession);
for c = 1:numel(channels)
    st = S.database_search(ndi.v2.isaQuery('statement') & ...
        ndi.query('', 'depends_on', 'acquisition_channels_id', channels{c}.id()) & inSession);
    keep = true(1, numel(st));
    for t = 1:numel(st)
        keep(t) = ~any(strcmp(seen, st{t}.id()));
        seen{end+1} = st{t}.id(); %#ok<AGROW>
    end
    found{end+1} = st(keep); %#ok<AGROW>
end
end
