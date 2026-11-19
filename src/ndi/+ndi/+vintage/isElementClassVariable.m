function tf = isElementClassVariable(variable)
%ISELEMENTCLASSVARIABLE True when VARIABLE is a migrated element's class variable.
%
%   TF = ndi.vintage.isElementClassVariable(VARIABLE) for a term struct
%   {node, name}: true when its node is EMPTY:0000401 "software class"
%   (ndi.vintage.elementClassVariable; prefix case aside), whatever its name,
%   or when its name is the old phrase 'ndi element class'
%   (ndi.vintage.elementLabel('class')), which databases migrated before
%   [variable terms batch 1] (Decided by Jess Haley, 2026-11-19, did-schema
%   docs/plans/did_v2_go_forward_class_audit.md) already hold. The node is
%   compared first; a statement carrying only the node (no name) is read.
%
%   See also ndi.vintage.elementClassVariable, ndi.vintage.elementClassQuery.

arguments
    variable
end

tf = false;
if ~isstruct(variable) || isempty(variable)
    return;
end
variable = variable(1);
node = '';
name = '';
if isfield(variable, 'node') && ~isempty(variable.node); node = strtrim(char(variable.node)); end
if isfield(variable, 'name') && ~isempty(variable.name); name = strtrim(char(variable.name)); end
want = ndi.vintage.elementClassVariable();
if ~isempty(node) && strcmpi(node, want.node)
    tf = true;
    return;
end
tf = strcmp(name, ndi.vintage.elementLabel('class'));
end
