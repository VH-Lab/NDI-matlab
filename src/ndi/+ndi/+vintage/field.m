function [value, found] = field(ndi_document_obj, v1_field_name)
%FIELD Read a block field by its v1 name, whatever vintage the document is.
%
%   [VALUE, FOUND] = ndi.vintage.field(NDI_DOCUMENT_OBJ, V1_FIELD_NAME)
%
%   Both the BLOCK name and the FIELD name move: a v1 `filenavigator`
%   document carries `filenavigator.fileparameters`, and its V_eta
%   successor carries `epoch_file_pattern.data_file_pattern`. Callers name
%   the v1 field and get the right one either way.
%
%   FOUND IS RETURNED RATHER THAN ERRORING, and that is deliberate: several
%   of these fields are legitimately absent (v1 leaves `fileparameters`
%   empty for a navigator with no pattern), so absence is data, not a
%   fault. VALUE is [] when FOUND is false. A caller that needs the field
%   raises its own error with its own context.
%
%   ONE SHAPE CHANGE IS NOT A RENAME AND IS NOT HANDLED HERE. v1 stores
%   `fileparameters` as a MATLAB expression the reader `eval`s
%   (+ndi/+file/navigator.m:44-45); V_eta declares `data_file_pattern` as a
%   string list, already the value the eval produced. So the caller must
%   eval the v1 form and NOT eval the V_eta form. `ndi.vintage.entryFor`
%   tells it which it has; doing it here would hide an eval inside a
%   getter.
%
%   See also: ndi.vintage.map, ndi.vintage.entryFor.

arguments
    ndi_document_obj
    v1_field_name (1,:) char
end

value = [];
found = false;

props = ndi_document_obj.document_properties;
[entry, vintage] = ndi.vintage.entryFor(ndi_document_obj);

if isempty(entry)
    blockName = props.document_class.class_name;
    fieldName = v1_field_name;
elseif strcmp(vintage, 'v1')
    blockName = entry.v1_class;
    fieldName = v1_field_name;
else
    blockName = entry.eta_class;
    fieldName = v1_field_name;
    rows = entry.fields;
    for i = 1:size(rows, 1)
        if strcmp(v1_field_name, rows{i,1})
            fieldName = rows{i,2};
            break;
        end
    end
end

if ~isfield(props, blockName)
    return;
end
blk = props.(blockName);
if ~isstruct(blk) || ~isscalar(blk) || ~isfield(blk, fieldName)
    return;
end
value = blk.(fieldName);
found = true;
end
