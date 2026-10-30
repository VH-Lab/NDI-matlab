function u = sourceUnit(spelling)
%SOURCEUNIT A value's source unit as a registered term.
%
%   U = ndi.setup.V2.sourceUnit(SPELLING) takes a unit as an import spells it
%   ('mm', 'h', 'CFU/mL') and returns what a value's `source_unit` holds, a
%   term (did-schema V_eta_source_unit_plan.md, signed 2026-10-21): the unit's
%   REGISTERED term, its label as the name, looked up in DID-schema's term
%   registry through ndi.setup.V2.registeredTerm.
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
%       uL/mL   NCIT:C69175                         Microliter per Milliliter
%   (the last seven registered in did-schema #88 for this import). A pH has no source
%   unit (the canonical `ph` is its own scale).
%   ANY OTHER SPELLING is looked up in the term registry itself: a spelling
%   that is a registered term's label ('millimetre', 'degree Celsius', any
%   case) or its CURIE ('om:millimetre') gives that term, so a new import can
%   use any registered unit without a line here. The table above is only for
%   the spellings that are NOT a label ('mm', 'C', 'um/s'). The registry
%   carries no synonyms today, so an abbreviation needs a row above (or the
%   label in the spec).
%   A spelling the registry does not hold either becomes a term with an empty
%   node and the spelling as its name -- the plan's rule for a spelling no
%   term matches (item 4): kept, not dropped and not guessed. did2.build's
%   term registry check then refuses it (or, collecting, lists it), so it is
%   reported until its unit is registered ("Adding terms", Using_V2.md).
%
%   SPELLING may be a cellstr / string array, giving one per element (a cell).
%
%   See also ndi.setup.V2.registeredTerm.

arguments
    spelling {mustBeText}
end

if iscellstr(spelling) || (isstring(spelling) && ~isscalar(spelling))
    u = cellfun(@ndi.setup.V2.sourceUnit, cellstr(spelling), 'UniformOutput', false);
    return;
end
spelling = strtrim(char(spelling));
if isempty(spelling)
    u = spelling;
    return;
end
persistent decided
if isempty(decided)
    decided = containers.Map( ...
        {'mm', 'pixel', 'frame', 'h', 'uL', 'um/s', 'um/s^2', 'CFU/mL', 'OD600', 'L', ...
         'C', 'mL', 'g', 'mg', 'g/L', 'ug/mL', 'uL/mL'}, ...
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
         {'NCIT:C64572', 'Microgram per Milliliter'}, ...
         {'NCIT:C69175', 'Microliter per Milliliter'}});
end
if isKey(decided, spelling)
    e = decided(spelling);
    u = ndi.setup.V2.registeredTerm(e{1}, e{2});
    return;
end
u = did2.build.term('', spelling);
ix = did2.schema.termIndex();
if ~ix.present
    return;
end
if contains(spelling, ':') && isKey(ix.byNode, did2.schema.curieKey(spelling))
    e = ix.byNode(did2.schema.curieKey(spelling));        % a CURIE
elseif isKey(ix.byName, did2.schema.termNameKey(spelling))
    e = ix.byName(did2.schema.termNameKey(spelling));                      % a label
else
    return;
end
u = did2.build.term(e.node, e.name);
end
