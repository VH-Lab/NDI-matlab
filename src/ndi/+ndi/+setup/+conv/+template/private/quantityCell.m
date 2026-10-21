function v = quantityCell(q, text)
%QUANTITYCELL A statement's value from one source cell, the source kept.
%
%   V = quantityCell(Q, TEXT) reads TEXT (the source cell, after corrections)
%   as a number and returns did2.build.valueCell(Q.data_type, ...):
%
%     canonical     the number times Q.scale (the source unit -> the data
%                   type's canonical unit: 0.001 for mm -> metres; 1 when the
%                   source is already canonical, e.g. degrees Celsius)
%     source_value  the number as the source wrote it, in its own unit
%     source_unit   Q.unit, the unit as the source spells it ('mm', 'C'),
%                   written as its REGISTERED term (ndi.setup.V2.sourceUnit)
%     tolerance     Q.tolerance, [minus plus] in the canonical unit, only
%                   where the source states one (it also marks the value
%                   approximate)
%
%   TEXT that is not a number is an error (ndi:setup:conv:template:notANumber);
%   a blank cell never reaches here -- the stage skips it: missing is not a
%   value.

arguments
    q (1,1) struct
    text {mustBeText}
end
x = str2double(text);
if isnan(x)
    error('ndi:setup:conv:template:notANumber', '"%s" is not a number.', char(text));
end
args = {'SourceValue', x};
if isfield(q, 'unit') && ~isempty(q.unit)
    args = [args, {'SourceUnit', ndi.setup.V2.sourceUnit(char(q.unit))}];
end
if isfield(q, 'tolerance') && ~isempty(q.tolerance)
    args = [args, {'Tolerance', reshape(double(q.tolerance), 1, 2)}];
end
scale = 1;
if isfield(q, 'scale') && ~isempty(q.scale)
    scale = double(q.scale);
end
v = did2.build.valueCell(char(q.data_type), x * scale, args{:});
end
