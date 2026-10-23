function [series, bodyFor] = epochSeriesOf(session, elementId)
%EPOCHSERIESOF The per-epoch series of a derived element in a MIGRATED session.
%
%   [SERIES, BODYFOR] = ndi.vintage.epochSeriesOf(SESSION, ELEMENTID)
%
%   SERIES is what ndi.vintage.epochSeries returns for the observations of
%   the element ELEMENTID in SESSION (an ndi.session, or anything with
%   database_search). BODYFOR is a function handle, OBSERVATION -> the data
%   body (an ndi.document) that holds that observation's bytes, or [] when
%   it has none: a `sampled_body` when the NDI second pass could read the
%   .vhsb (ndi.migrate.internal.epochSeriesBodies), else the `opaque_body`
%   carrying it as attached (did2.convert.resolveEpochProbemap). Either way
%   the bytes are the body's member `body_data_0`, in the .vhsb format NDI
%   wrote (vlt.file.custom_file_formats.vhsb_read reads it).
%
%   A v1 or un-dissolved session has no such observations and SERIES is
%   empty; callers try the v1 / acquisition_epoch shape first
%   (ndi.vintage.addedEpoch) and come here only for what it did not find.
%
%   See also ndi.vintage.epochSeries, ndi.element/loadaddedepochs,
%            ndi.element.timeseries/readtimeseries.

arguments
    session
    elementId (1,:) char
end

q = ndi.query('', 'depends_on', 'entity_id', elementId) & ...
    ndi.query('', 'isa', 'observation', '');
obs = session.database_search(q);
% JH (Decided by Jess Haley, 2026-10-22 [JH position and distance]): a
% position / distance element's series are calculations ABOUT ITS WORM with
% the element as instrument; the first of a distance epoch's two keeps the
% epoch's id. One series row per epoch: the epoch is read off each and a
% repeat is skipped by ndi.element/loadaddedepochs.
q2 = ndi.query('', 'depends_on', 'instrument_id', elementId) & ...
    ndi.query('', 'isa', 'calculation', '');
obs = [obs(:); session.database_search(q2)];
series = ndi.vintage.epochSeries(obs, @(id) propsById(session, id));
bodyFor = @(o) bodyOf(session, o);
end

function p = propsById(session, id)
p = [];
if isempty(id)
    return;
end
d = session.database_search(ndi.query('base.id', 'exact_string', id, ''));
if ~isempty(d)
    p = d{1}.document_properties;
end
end

function b = bodyOf(session, observation)
b = [];
if isa(observation, 'ndi.document') || isa(observation, 'did.document')
    oid = observation.id();
else
    oid = char(observation.base.id);
end
q = ndi.query('', 'depends_on', 'owner_id', oid) & ...
    (ndi.query('', 'isa', 'sampled_body', '') | ndi.query('', 'isa', 'opaque_body', ''));
docs = session.database_search(q);
if isempty(docs)
    return;
end
% a sampled_body (the bytes described) before an opaque_body (carried)
for k = 1:numel(docs)
    if isfield(docs{k}.document_properties, 'sampled_body')
        b = docs{k};
        return;
    end
end
b = docs{1};
end
