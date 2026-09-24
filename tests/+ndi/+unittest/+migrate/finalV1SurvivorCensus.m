function survivors = finalV1SurvivorCensus(sourceBodies, destBodies)
%FINALV1SURVIVORCENSUS Which v1 SOURCE class names survive in the FINAL migrated DB.
%   SURVIVORS = finalV1SurvivorCensus(SOURCEBODIES, DESTBODIES) is the Bar-2
%   instrument: the pass-1 conversion census (verifyDeferralsAreDeclared) counts
%   what the SINGLE-DOCUMENT migrators did, and says nothing about the SECOND
%   PASSES that run afterward -- epochMint's armed folds, resolveResponseParameters,
%   resolveStimulusPresentations. A document can be a pass-1 passthrough and still
%   reach its decided shape in the final DB (stimulus_presentation -> timed_sequence
%   is exactly that). So "is this corpus fully at decided shape" is a question about
%   the FINAL output, and this function answers it by the only sound method: a v1
%   SOURCE class name that still labels a document in the destination is a document
%   that did not fold.
%
%   SOURCEBODIES  cell array of raw v1 JSON text (what readCorpusBodies returns).
%   DESTBODIES    cell array of destination doc STRUCTS (what destinationBodies
%                 returns).
%   SURVIVORS     struct array, one row per surviving v1 class name, fields
%                 `class_name` and `count`, sorted by count descending. Empty
%                 struct array when nothing v1-shaped survives.
%
%   ---------------------------------------------------------------------
%   IT IS FULLY DATA-DRIVEN, ON PURPOSE
%   ---------------------------------------------------------------------
%   No hardcoded list of v1 classes: the SOURCE set is read from this run's own
%   input, so it cannot drift from the corpus, and the intersection with the
%   destination is the survivor set. A class that legitimately PERSISTS (`subject`,
%   `session`) appears in both source and destination and so is reported here --
%   correctly, because "survives as itself" is exactly what persist means. The
%   CALLER declares which survivors are persist-legitimate and which are an unfolded
%   deferral, the same division the pass-1 census uses. This function measures; it
%   does not judge.
%
%   DENOMINATOR FIRST, always (Operating Rule 5): a census that read zero source
%   or zero destination documents reports a clean-looking empty survivor set for
%   the wrong reason, and that is the silentLoss failure this whole project exists
%   to stop. The caller prints the denominators this returns alongside the rows.

arguments
    sourceBodies (1,:) cell
    destBodies   (1,:) cell
end

sourceNames = containers.Map('KeyType', 'char', 'ValueType', 'logical');
for k = 1:numel(sourceBodies)
    name = classNameOfText(sourceBodies{k});
    if ~isempty(name)
        sourceNames(name) = true;
    end
end

destCounts = containers.Map('KeyType', 'char', 'ValueType', 'double');
for k = 1:numel(destBodies)
    name = classNameOfStruct(destBodies{k});
    if isempty(name) || ~isKey(sourceNames, name)
        continue;   % not a v1 source class -> a minted V_eta document, not a survivor
    end
    if isKey(destCounts, name)
        destCounts(name) = destCounts(name) + 1;
    else
        destCounts(name) = 1;
    end
end

names = destCounts.keys();
survivors = struct('class_name', {}, 'count', {});
for k = 1:numel(names)
    survivors(end+1) = struct('class_name', names{k}, ...
        'count', destCounts(names{k})); %#ok<AGROW>
end
if ~isempty(survivors)
    [~, order] = sort([survivors.count], 'descend');
    survivors = survivors(order);
end
end

% ===================== helpers =============================================

function name = classNameOfText(jsonText)
%CLASSNAMEOFTEXT class_name from raw v1 JSON, without decoding the whole body.
%   The document_class block is small and at the top; a full jsondecode of a
%   large body (a hartley_calc carries a 200x200x36x2 volume) just to read one
%   string is wasteful over 1220 documents. A targeted regex is enough and the
%   format is machine-written, so the key is always present verbatim.
name = '';
tok = regexp(char(jsonText), '"class_name"\s*:\s*"([^"]+)"', 'tokens', 'once');
if ~isempty(tok)
    name = tok{1};
end
end

function name = classNameOfStruct(body)
name = '';
if isstruct(body) && isfield(body, 'document_class') ...
        && isstruct(body.document_class) ...
        && isfield(body.document_class, 'class_name')
    name = char(body.document_class.class_name);
end
end
