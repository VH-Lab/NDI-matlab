function q = elementRelationQuery(handle)
%ELEMENTRELATIONQUERY A search for the directed relations of one relation.
%
%   Q = elementRelationQuery(HANDLE): `isa directed_relation` and its
%   relation term is HANDLE ('connected_to', 'derived_from', 'member_of'),
%   by node or by any of its names (ndi.v2.vocabQuery).
q = ndi.query('', 'isa', 'directed_relation', '') & ...
    ndi.v2.vocabQuery('directed_relation.relation', 'relation', handle);
end
