function docs = lightsheetLevelDocs(session, pyramidDoc)
%LIGHTSHEETLEVELDOCS The level documents of one lightsheet pyramid, in its vintage.
%
%   DOCS = ndi.vintage.lightsheetLevelDocs(SESSION, PYRAMIDDOC)
%
%   PYRAMIDDOC is an ndi.document (either vintage). DOCS is the cell
%   SESSION.database_search returns for:
%
%     v1     isa lightsheetZarrLevel, depends_on lightsheetZarrPyramid_id =
%            the pyramid's id -- EXACTLY the query the lightsheet readers
%            have always run, so a v1 session is searched as before.
%     V_eta  isa sampled_body, depends_on owner_id = the pyramid's id. The
%            migration keeps the pyramid's id on its observation and each
%            level's id on its sampled_body, whose owner_id names the
%            observation (DID-matlab +migrators_j/lightsheet_zarr_level.m).
%            Only the levels are sampled_bodies: the store record the
%            observation also owns is an opaque_body.
%
%   `isa sampled_body` does not bridge onto `isa lightsheetZarrLevel` the way
%   ndi.vintage.isaQuery bridges a renamed class: sampled_body is every V_eta
%   sampled array, so only the owner edge makes one a level. That is also why
%   lightsheet has no ndi.vintage.map row (see ndi.vintage.lightsheetPyramidDocs).
%
%   See also: ndi.vintage.lightsheetLevels, ndi.vintage.lightsheetPyramidDocs.

arguments
    session
    pyramidDoc
end

props = ndi.v2.props(pyramidDoc);
id = props.base.id;
if isfield(props, 'lightsheetZarrPyramid')
    q1 = ndi.query('', 'isa', 'lightsheetZarrLevel');
    q2 = ndi.query('depends_on', 'depends_on', 'lightsheetZarrPyramid_id', id);
else
    q1 = ndi.query('', 'isa', 'sampled_body', '');
    q2 = ndi.query('', 'depends_on', 'owner_id', id);
end
docs = session.database_search(q1 & q2);
end
