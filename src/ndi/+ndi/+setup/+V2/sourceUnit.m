function u = sourceUnit(spelling)
%SOURCEUNIT A value's source unit in the shape the V2 schema in use declares.
%
%   U = ndi.setup.V2.sourceUnit(SPELLING) takes a unit as an import spells it
%   ('mm', 'h', 'CFU/mL') and returns what a value's `source_unit` holds:
%     - on did-schema main (`source_unit` is char): SPELLING, unchanged;
%     - where `source_unit` is a term (did-schema V_eta_source_unit_plan.md,
%       signed 2026-10-21; ndi.v2.sourceUnitIsTerm): the unit's REGISTERED
%       term, its label as the name, looked up in DID-schema's term registry
%       through ndi.setup.V2.registeredTerm.
%   An empty SPELLING gives '' (no source unit: the field is left out).
%
%   The spellings with a decided term (Jess Haley, 2026-10-21):
%       mm      om:millimetre                       millimetre
%       pixel   om:pixel                            pixel
%       frame   EMPTY:0000260                       frame
%       h       om:hour                             hour
%       uL      om:microlitre                       microlitre
%       um/s    om:micrometrePerSecond-Time         micrometre per second
%       um/s^2  om:micrometrePerSecond-TimeSquared  micrometre per second squared
%       CFU/mL  NCIT:C68902                         Colony Forming Unit per Milliliter
%       OD600   NCIT:C73686                         Absorbance Unit (plan amendment 1)
%       L       om:litre                            litre
%       C       om:degreeCelsius                    degree Celsius
%       mL      om:millilitre                       millilitre
%       g       om:gram                             gram
%       mg      om:milligram                        milligram
%       g/L     om:gramPerLitre                     gram per litre
%       ug/mL   NCIT:C64572                         Microgram per Milliliter
%   (the last six registered in did-schema #88, a14d2a9). A pH has no source
%   unit (the canonical `ph` is its own scale).
%   A spelling with no decided term becomes a term with an empty node and the
%   spelling as its name -- the plan's rule for a spelling no term matches
%   (item 4): kept, not dropped and not guessed. did2.build's term registry
%   check then refuses it (or, collecting, lists it), so it is reported until
%   its unit is registered and added here.
%
%   SPELLING may be a cellstr / string array, giving one per element (a cell).
%
%   See also ndi.v2.sourceUnitIsTerm, ndi.setup.V2.registeredTerm.

arguments
    spelling {mustBeText}
end

if iscellstr(spelling) || (isstring(spelling) && ~isscalar(spelling))
    u = cellfun(@ndi.setup.V2.sourceUnit, cellstr(spelling), 'UniformOutput', false);
    return;
end
spelling = strtrim(char(spelling));
if isempty(spelling) || ~ndi.v2.sourceUnitIsTerm()
    u = spelling;
    return;
end
persistent decided
if isempty(decided)
    decided = containers.Map( ...
        {'mm', 'pixel', 'frame', 'h', 'uL', 'um/s', 'um/s^2', 'CFU/mL', 'OD600', 'L', ...
         'C', 'mL', 'g', 'mg', 'g/L', 'ug/mL'}, ...
        {{'om:millimetre', 'millimetre'}, ...
         {'om:pixel', 'pixel'}, ...
         {'EMPTY:0000260', 'frame'}, ...
         {'om:hour', 'hour'}, ...
         {'om:microlitre', 'microlitre'}, ...
         {'om:micrometrePerSecond-Time', 'micrometre per second'}, ...
         {'om:micrometrePerSecond-TimeSquared', 'micrometre per second squared'}, ...
         {'NCIT:C68902', 'Colony Forming Unit per Milliliter'}, ...
         {'NCIT:C73686', 'Absorbance Unit'}, ...
         {'om:litre', 'litre'}, ...
         {'om:degreeCelsius', 'degree Celsius'}, ...
         {'om:millilitre', 'millilitre'}, ...
         {'om:gram', 'gram'}, ...
         {'om:milligram', 'milligram'}, ...
         {'om:gramPerLitre', 'gram per litre'}, ...
         {'NCIT:C64572', 'Microgram per Milliliter'}});
end
if isKey(decided, spelling)
    e = decided(spelling);
    u = ndi.setup.V2.registeredTerm(e{1}, e{2});
else
    u = did2.build.term('', spelling);
end
end
