function q = isaQuery(concept)
%ISAQUERY An `isa` query that finds a concept in EVERY vintage.
%
%   Q = ndi.vintage.isaQuery(CONCEPT)
%
%   Replaces `ndi.query('','isa',CONCEPT)` at the sites that load NDI
%   objects. For a concept V_eta renamed, Q is the OR of both class names;
%   for anything else Q is exactly the query the caller would have written,
%   so passing an unrenamed concept is safe and changes nothing.
%
%   WHY OR AND NOT A TRANSLATION. `isa` walks the class chain, and V_eta
%   does not put the v1 name in it -- `clock_alignment_policy`'s chain is
%   [base], `acquisition_system`'s is [entity]. So there is no single name
%   that finds both, and translating v1 -> V_eta would lose the ability to
%   read a database NDI itself has just written (NDI still writes v1; see
%   ndi.vintage.map). Both, always, is the only shape that reads a
%   migrated session AND a fresh one.
%
%   Example:
%       dev_doc = session.database_search(ndi.vintage.isaQuery('daqsystem'));
%
%   See also: ndi.vintage.map, ndi.vintage.entryFor.

arguments
    concept (1,:) char
end

q = ndi.query('', 'isa', concept, '');

entry = ndi.vintage.entryFor(concept);
if isempty(entry)
    return;
end

% Both names, so neither vintage is privileged. `|` is did.query/or.
if ~strcmp(entry.v1_class, entry.eta_class)
    q = q | ndi.query('', 'isa', entry.eta_class, '');
end
end
