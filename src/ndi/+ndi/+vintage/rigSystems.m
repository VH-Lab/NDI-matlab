function M = rigSystems(S, ids)
%RIGSYSTEMS The acquisition systems a rig's wiring or clock may name, by id.
%
%   M = ndi.vintage.rigSystems(SESSION, IDS). IDS is a cellstr of the ids a
%   `connected to` (RO:0002170) wiring relation names as its `parent_id` (or
%   a rig's time reference as its referent). M is a containers.Map, ID -> the
%   id of the `acquisition_system` whose `device_id` is ID, for every ID that
%   is a rig's device entity named by exactly one acquisition system; an ID
%   that is an acquisition_system itself, or that no (or more than one)
%   system names, has no key.
%
%   Decided by Jess Haley, 2026-11-19, did-schema
%   docs/plans/did_v2_standing_wiring_plan.md [acquisition system is a device
%   entity]: the digitizer is an `entity` of type device and a probe's
%   wiring names it; the `acquisition_system` is the configuration that points
%   at it by `device_id` ([a rig's clock belongs to its device] likewise for
%   the rig's clocks). DID-matlab's migration writes that shape; a session
%   migrated before names the acquisition_system. The readers file a wiring
%   relation under the system either way (ndi.vintage.wiringIndex), so the
%   probe map and the epoch tables read the same from both shapes.
%
%   One search: the acquisition systems whose `device_id` is any of IDS.
%
%   See also ndi.vintage.wiringIndex, ndi.vintage.wiredDeviceString,
%            ndi.vintage.ingestedEpochs.

arguments
    S
    ids
end

M = containers.Map('KeyType', 'char', 'ValueType', 'char');
if isempty(ids)
    return;
end
ids = unique(reshape(cellstr(ids), 1, []));
ids = ids(~cellfun(@isempty, ids));
if isempty(ids)
    return;
end
systems = S.database_search(ndi.vintage.acquisitionConfigurationQuery() & ...
    ndi.vintage.edgeIn('device_id', ids));
count = containers.Map('KeyType', 'char', 'ValueType', 'double');
for k = 1:numel(systems)
    for d = ndi.vintage.edgeTargets(systems{k}, 'device_id')
        if ~any(strcmp(ids, d{1})); continue; end
        if isKey(count, d{1})
            count(d{1}) = count(d{1}) + 1;
        else
            count(d{1}) = 1;
            M(d{1}) = char(systems{k}.id());
        end
    end
end
for d = count.keys
    if count(d{1}) > 1
        remove(M, d{1});   % several systems name one device: not one rig
    end
end
end
