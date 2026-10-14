function out = vetaName(name)
%VETANAME A V_eta class or block name in its current spelling.
%
%   OUT = ndi.v2.vetaName(NAME) maps the names V_eta used until 2026-10-08 to
%   the ones it uses since (did-schema V_eta_tenets.md, T2 amendment): the
%   statement family drops its `subject_` prefix and `data_type` becomes
%   `value`. Any other name comes back unchanged. NAME may be a cellstr.
%
%     subject_statement    -> statement
%     subject_assertion    -> assertion
%     subject_interaction  -> interaction
%     subject_observation  -> observation
%     subject_manipulation -> manipulation
%     subject_calculation  -> calculation
%     data_type            -> value
%
%   Documents written before the rename keep the old names (and the edge
%   `subject_id` for `entity_id`), so the readers here accept both.
%
%   See also ndi.v2.vetaAliases.

if iscell(name)
    out = cellfun(@ndi.v2.vetaName, name, 'UniformOutput', false);
    return;
end
name = char(name);
[old, new] = pairs();
k = find(strcmp(old, name), 1);
if isempty(k)
    out = name;
else
    out = new{k};
end
end

function [old, new] = pairs()
old = {'subject_statement', 'subject_assertion', 'subject_interaction', ...
    'subject_observation', 'subject_manipulation', 'subject_calculation', 'data_type'};
new = {'statement', 'assertion', 'interaction', ...
    'observation', 'manipulation', 'calculation', 'value'};
end
