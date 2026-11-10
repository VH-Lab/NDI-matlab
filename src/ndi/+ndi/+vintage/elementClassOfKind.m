function objClass = elementClassOfKind(kind, elementType)
%ELEMENTCLASSOFKIND The v1 `ndi_element_class` of an element, rebuilt from what it is.
%
%   OBJCLASS = ndi.vintage.elementClassOfKind(KIND, ELEMENTTYPE) rebuilds the
%   MATLAB class NDI constructs for an element from its link kind
%   (ndi.vintage.elementLinkKind) and its v1 element type (read from its
%   entity type and device kind, ndi.vintage.elementTypeOf):
%
%     'probe'     the class NDI's probe type table names for ELEMENTTYPE
%                 (ndi_common/probe/probetype2object.json, read through
%                 ndi.probe.fun.getProbeTypeMap): 'n-trode' ->
%                 'ndi.probe.timeseries.mfdaq', 'stimulator' ->
%                 'ndi.probe.timeseries.stimulator', ...; '' when the table
%                 has no row for it
%     'unit'      'ndi.neuron' (a single unit, `cell`, or one multi-unit,
%                 a `Group` with no members; v1 type `spikes`)
%     'ensemble'  'ndi.element.ensemble' (a `Group` with members)
%     ''          ''
%
%   Decided by Jess Haley, 2026-10-27 [ndi element class not kept] ("the
%   round trip rebuilds `element.ndi_element_class` from the entity type and
%   device kind (for a probe type, NDI's `probetype2object.json`), and an
%   element whose class cannot be rebuilt that way is brought to the team"),
%   2026-11-10 [element recognised by its links] and [ensemble has members]
%   (did-schema docs/plans/did_v2_go_forward_class_audit.md). '' is the
%   "cannot be rebuilt" answer: the caller falls back to the "ndi element
%   class" assertion where one is present.
%
%   See also ndi.vintage.elementFields, ndi.vintage.objectClass.

arguments
    kind (1,:) char
    elementType = ''
end

objClass = '';
switch kind
    case 'probe'
        elementType = char(elementType);
        if isempty(elementType)
            return;
        end
        m = ndi.probe.fun.getProbeTypeMap();
        if isa(m, 'containers.Map')
            if isKey(m, elementType)
                objClass = char(m(elementType));
            end
        elseif isKey(m, string(elementType))
            objClass = char(m(string(elementType)));
        end
    case 'unit'
        objClass = 'ndi.neuron';
    case 'ensemble'
        objClass = 'ndi.element.ensemble';
end
end
