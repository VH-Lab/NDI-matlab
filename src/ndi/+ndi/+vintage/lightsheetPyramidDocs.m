function docs = lightsheetPyramidDocs(session)
%LIGHTSHEETPYRAMIDDOCS Every lightsheet pyramid in a session, in both vintages.
%
%   DOCS = ndi.vintage.lightsheetPyramidDocs(SESSION)
%
%   v1 pyramids first, found exactly as before (isa lightsheetZarrPyramid),
%   then migrated ones.
%
%   HOW A MIGRATED PYRAMID IS RECOGNISED. DID-matlab
%   +migrators_j/lightsheet_zarr_pyramid.m makes each v1 pyramid an intensity
%   `observation` (its id kept) whose software_id names an `entity` of type
%   software called ndi.vintage.lightsheetBuilderName() -- 'NDI lightsheet
%   pyramid builder (ndi.fun.doc.lightsheet.makePyramid)' (Jess
%   2026-10-14, lightsheet point 5). Nothing else on the observation says
%   "lightsheet": its class is `observation`, its value kind `intensity` and
%   its variable NCIT:C184706 'Fluorescence Intensity', all of which any
%   fluorescence measurement shares. So a migrated pyramid is an observation
%   whose software is THAT entity, found in two steps (the entity by name,
%   then the observations pointing at it) because a query sees one document
%   at a time.
%
%   This is why lightsheet has no ndi.vintage.map row. ndi.vintage.entryFor
%   keys on the class name alone, and `observation` / `sampled_body` are every
%   V_eta statement and array: a row would reroute the edge and field reads
%   ndi.vintage.edge / field do for EVERY observation in a session (e.g. the
%   time-reference reads in ndi.file.navigator.bodies), not just pyramids.
%
%   The software entity is matched in both shapes did-schema has used: an
%   `entity` with name (current) or a `software` document with name (before
%   2026-10-08).
%
%   See also: ndi.vintage.lightsheetLevelDocs, ndi.vintage.lightsheetPyramid.

BUILDER = ndi.vintage.lightsheetBuilderName();

docs = session.database_search(ndi.query('', 'isa', 'lightsheetZarrPyramid'));
docs = reshape(docs, 1, []);

sw = session.database_search(ndi.query('entity.name', 'exact_string', BUILDER, '') | ...
    ndi.query('software.name', 'exact_string', BUILDER, ''));
seen = {};
for i = 1:numel(sw)
    obs = session.database_search(ndi.v2.isaQuery('observation') & ...
        ndi.query('', 'depends_on', 'software_id', sw{i}.id()));
    for j = 1:numel(obs)
        id = obs{j}.id();
        if any(strcmp(seen, id)), continue; end
        seen{end+1} = id; %#ok<AGROW>
        docs{end+1} = obs{j}; %#ok<AGROW>
    end
end
end
