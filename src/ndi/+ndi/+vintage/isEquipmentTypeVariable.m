function tf = isEquipmentTypeVariable(variable)
%ISEQUIPMENTTYPEVARIABLE True when VARIABLE is a device's kind variable.
%
%   TF = ndi.vintage.isEquipmentTypeVariable(VARIABLE) for a term struct
%   {node, name}: NCIT:C178920 "Equipment Type", the variable DID-matlab's
%   did2.convert.elementDeviceKind asserts a device's kind under (did-schema
%   binding_registry_meta.json subject_statement_bindings). Compared by node
%   (prefix case aside) when the term has one, else by the label.
%
%   See also ndi.vintage.elementTypeOf, ndi.vintage.equipmentTypeVariable.

arguments
    variable
end

want = ndi.vintage.equipmentTypeVariable();
tf = false;
if ~isstruct(variable) || isempty(variable)
    return;
end
variable = variable(1);
node = '';
name = '';
if isfield(variable, 'node'); node = strtrim(char(variable.node)); end
if isfield(variable, 'name'); name = strtrim(char(variable.name)); end
if ~isempty(node)
    tf = strcmpi(node, want.node);
else
    tf = strcmp(name, want.name);
end
end
