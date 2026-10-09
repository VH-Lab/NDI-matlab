function name = objectName(ndi_document_obj)
%OBJECTNAME The name an NDI object document carries, either vintage.
%
%   NAME = ndi.vintage.objectName(NDI_DOCUMENT_OBJ)
%
%   v1 keeps an object's name in `base.name` (a daq system's 'intan1').
%   did-schema #73 item 54 moved names onto the classes that have one, so a
%   document built to the current V_eta schema carries it in its own block
%   (`acquisition_system.name`), and `base.name` is did_v1-only. Documents
%   migrated before that change still carry `base.name`. This returns the
%   block's `name` when the document has a non-empty one, else `base.name`,
%   else ''.
%
%   See also: ndi.vintage.field, ndi.vintage.map.

name = '';
props = ndi_document_obj.document_properties;
blockName = props.document_class.class_name;
if isfield(props, blockName) && isstruct(props.(blockName)) && isscalar(props.(blockName)) ...
        && isfield(props.(blockName), 'name') && ~isempty(props.(blockName).name)
    name = props.(blockName).name;
    return;
end
if isfield(props, 'base') && isfield(props.base, 'name') && ~isempty(props.base.name)
    name = props.base.name;
end
end
