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
%   `observation` (its id kept) whose `interaction.method` is
%   ndi.vintage.lightsheetMethod() -- FBbi:00000369 'selective plane
%   illumination fluorescence microscopy' (Jess 2026-10-15). Its class
%   (`observation`), value kind (`intensity`) and variable (NCIT:C184706
%   'Fluorescence Intensity') are shared by any fluorescence measurement; the
%   method is what says light-sheet. So a migrated pyramid is an observation
%   whose method node is that term, found in ONE query on the field path
%   `interaction.method.node` (`interaction` declares `method`, an
%   ontology_term {node, name}; ndi.v2.fieldQuery also asks the block's name
%   before 2026-10-08, `subject_interaction`).
%
%   (Until 2026-10-15 it was found through the builder `software` entity's
%   name. The entity is still written; it no longer marks the pyramid.)
%
%   This is why lightsheet has no ndi.vintage.map row. ndi.vintage.entryFor
%   keys on the class name alone, and `observation` / `sampled_body` are every
%   V_eta statement and array: a row would reroute the edge and field reads
%   ndi.vintage.edge / field do for EVERY observation in a session (e.g. the
%   time-reference reads in ndi.file.navigator.bodies), not just pyramids.
%
%   See also: ndi.vintage.lightsheetMethod, ndi.vintage.lightsheetLevelDocs,
%             ndi.vintage.lightsheetPyramid.

M = ndi.vintage.lightsheetMethod();

docs = session.database_search(ndi.query('', 'isa', 'lightsheetZarrPyramid'));
docs = reshape(docs, 1, []);

obs = session.database_search(ndi.v2.isaQuery('observation') & ...
    ndi.v2.fieldQuery('interaction.method.node', 'exact_string', M.node));
seen = cellfun(@(d) d.id(), docs, 'UniformOutput', false);
for j = 1:numel(obs)
    id = obs{j}.id();
    if any(strcmp(seen, id)), continue; end
    seen{end+1} = id; %#ok<AGROW>
    docs{end+1} = obs{j}; %#ok<AGROW>
end
end
