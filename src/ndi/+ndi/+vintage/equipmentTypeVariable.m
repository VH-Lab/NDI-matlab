function t = equipmentTypeVariable()
%EQUIPMENTTYPEVARIABLE The variable a device's kind is asserted under.
%
%   T = ndi.vintage.equipmentTypeVariable() is the term {node, name}
%   NCIT:C178920 "Equipment Type": DID-matlab did2.convert.elementDeviceKind's
%   second output, the binding registry's subject-defining variable for a
%   device's finer kind.
%
%   See also ndi.vintage.isEquipmentTypeVariable, ndi.vintage.elementTypeOf.

t = struct('node', 'NCIT:C178920', 'name', 'Equipment Type');
end
