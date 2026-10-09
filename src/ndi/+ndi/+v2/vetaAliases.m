function names = vetaAliases(name)
%VETAALIASES A V_eta class, block or edge name and the spelling it had before 2026-10-08.
%
%   NAMES = ndi.v2.vetaAliases(NAME) is {NAME} for a name that was not
%   renamed, and {NAME, OLD} for one that was: 'statement' gives
%   {'statement', 'subject_statement'}, 'value' gives {'value', 'data_type'},
%   'entity_id' gives {'entity_id', 'subject_id'}. Readers search both, so a
%   dataset written before the rename still reads (ndi.v2.vetaName).
%
%   See also ndi.v2.vetaName, ndi.v2.isaQuery.

name = char(ndi.v2.vetaName(name));
switch name
    case 'statement',    names = {name, 'subject_statement'};
    case 'assertion',    names = {name, 'subject_assertion'};
    case 'interaction',  names = {name, 'subject_interaction'};
    case 'observation',  names = {name, 'subject_observation'};
    case 'manipulation', names = {name, 'subject_manipulation'};
    case 'calculation',  names = {name, 'subject_calculation'};
    case 'value',        names = {name, 'data_type'};
    case 'entity_id',    names = {name, 'subject_id'};
    otherwise,           names = {name};
end
end
