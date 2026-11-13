function [v, ok] = bathPrefixedValue(value, spelling, base)
%BATHPREFIXEDVALUE A bath amount converted to molar or osmolar when its unit is that unit with a known SI prefix.
%
%   [V, OK] = ndi.migrate.internal.bathPrefixedValue(VALUE, SPELLING, BASE)
%   converts VALUE, stated in the unit spelled SPELLING, to the unit BASE
%   ('molar': moles per litre; 'osmolar': osmoles per litre) when SPELLING is
%   BASE with a known SI prefix, arithmetic only. OK is false, and V [], for
%   any other spelling. A symbol is read case-sensitively (mM is millimolar;
%   MM is not), a word ignoring case:
%     molar    M, mol/L, mol/l, molar, Molar; with a prefix: mM, uM (or the
%              micro sign or mu), nM, pM, fM, kM, mmol/L, millimolar,
%              micromolar, ...
%     osmolar  Osm/L, Osm/l, osmol/L, osmol/l, OsM, osmolar; with a prefix:
%              mOsm/L, mOsM, milliosmolar, ... (a bare Osm or mOsm states no
%              volume, and is not read)
%   The number is divided by 10^n for a prefix below one (mM: /1e3), so the
%   result is the double nearest the exact quotient.
%
%   Jess Haley, 2026-11-12 [bath concentration prefixes convert to molar]
%   (did-schema docs/plans/did_v2_go_forward_class_audit.md): a bath
%   concentration in a molar unit with a known SI prefix gets its canonical in
%   M; an unparsable spelling is carried for mapping.
%
%   A COPY of the local function prefixedValue in DID-matlab
%   +did2/+convert/resolveDeferredBaths.m (VH-Lab/DID-matlab PR #456, branch
%   claude/bath-molar-prefixes), which DID-matlab does not expose; the two
%   must read the same spellings. When DID-matlab exposes it, call that
%   instead and delete this file.
%
%   See also ndi.migrate.internal.stimulusBathToBath,
%            ndi.migrate.internal.bathUnreadUnitRows.

v = [];
ok = false;
s = strtrim(char(string(spelling)));
if isempty(s) || ~isnumeric(value) || ~isscalar(value)
    return;
end
% symbol prefix, word prefix, power of ten
P = { ...
    '',             '',       0; ...
    'k',            'kilo',   3; ...
    'm',            'milli', -3; ...
    'u',            'micro', -6; ...
    char(181),      '',      -6; ...   % micro sign
    char(956),      '',      -6; ...   % Greek small mu
    'n',            'nano',  -9; ...
    'p',            'pico', -12; ...
    'f',            'femto', -15; ...
    'a',            'atto', -18};
switch base
    case 'molar'
        symbols = {'M', 'mol/L', 'mol/l'};
        word = 'molar';
    case 'osmolar'
        symbols = {'Osm/L', 'Osm/l', 'osmol/L', 'osmol/l', 'OsM'};
        word = 'osmolar';
    otherwise
        return;
end
e = [];
for k = 1:size(P, 1)
    if any(strcmp(s, strcat(P{k, 1}, symbols))) ...
            || ((k == 1 || ~isempty(P{k, 2})) && strcmpi(s, [P{k, 2} word]))
        e = P{k, 3};
        break;
    end
end
if isempty(e)
    return;
end
value = double(value);
if e < 0
    v = value / 10^(-e);
else
    v = value * 10^e;
end
ok = true;
end
