function [gratingBodies, byPresentation, report] = hartleyBasisGratings(bodies, targetVersion)
%HARTLEYBASISGRATINGS The Hartley basis set of a session, as deduped
%   `visual_grating` documents, plus the per-presentation playlist and frame
%   times that reference them.
%
%   [G, BYPRES, REPORT] = hartleyBasisGratings(BODIES, TARGETVERSION) reads a
%   decoded v1 body set and returns
%
%     G        a cell of standalone `visual_grating` document bodies -- the
%              DISTINCT basis functions of the session, MINTED ONCE.
%     BYPRES   a containers.Map from stimulus_presentation id to
%                 .presented_ids  cell of the G ids that presentation uses
%                 .order          [1 x nFrames] index into presented_ids,
%                                 one entry per displayed frame
%                 .frame_times    [1 x nFrames] frame onsets, seconds
%                 .duration       the nominal per-frame duration, 1/fps
%              -- i.e. exactly the override
%              ndi.migrate.internal.stimulusPresentationToTimedSequence takes.
%     REPORT   denominators first, unconditionally (Operating Rule 5).
%
%   ========================================================================
%   WHY THIS EXISTS: THE HARTLEY PRESENTATION IS A GENERATOR RECIPE AND THE
%   ENUMERATION LIVES IN A DIFFERENT DOCUMENT.
%   ========================================================================
%   Measured on the 20211116 corpus (1220 documents read, 21 classes):
%
%       11  stimulus_presentation      1 carries 225 enumerated stimuli;
%                                      10 carry a SINGLE stimulus whose
%                                      parameters are the white-noise
%                                      GENERATOR spec -- M, K_absmax,
%                                      L_absmax, sfmax, fps, contrast,
%                                      randState -- and enumerate nothing.
%      210  hartley_calc               21 per presentation x 10; each carries
%                                      hartley_reverse_correlation.
%                                      hartley_numbers {S, KXV, KYV, ORDER},
%                                      3360 entries, and a frameTimes of 3360.
%
%   hartley_numbers is IDENTICAL across all 210 documents (1 distinct value):
%   one basis set for the whole session. frameTimes has 10 distinct values,
%   one per presentation, each monotonically increasing with mean spacing
%   0.10034 s against a declared fps of 10.
%
%   So the presentation cannot be decomposed from its own contents, and
%   ndi.migrate.internal.stimulusPresentationToTimedSequence correctly REFUSES
%   it on its own (the generator spec carries no angle / sFrequency /
%   tFrequency, and mapping it anyway yields a grating at 0 deg, 0 cyc/deg,
%   0 Hz with every field looking measured). This function supplies the
%   missing half from the calculators, so the refusal becomes an emission.
%
%   THE BASIS, AS READ (all figures re-derived from the corpus, not quoted):
%     3360 entries; 1680 distinct (kx,ky) pairs, EACH appearing exactly twice;
%     3360 distinct (kx,ky,s) triples; s in {-1,+1}, 1680 of each; the DC term
%     (0,0) is ABSENT, and 41*41 - 1 = 1680 exactly (kx,ky in -20..20 for
%     K_absmax = L_absmax = 20).
%
%   ------------------------------------------------------------------------
%   ORDER IS THE CANONICAL INDEX, NOT THE PLAYLIST -- and getting this
%   backwards would mis-assign every one of the 3360 frames silently.
%   ------------------------------------------------------------------------
%   The generator (vhlab `hartleyrange`) is in NO repository this session can
%   read, so the semantics were established from the DATA, by structure rather
%   than by assertion. Sorting the 3360 entries BY THEIR ORDER VALUE recovers
%   the canonical generator output exactly:
%
%       first 12 (kx,ky,s):  (-20,-20,-1) (-20,-19,-1) ... (-20,-9,-1)
%       s: the first 1680 are ALL -1 and the last 1680 are ALL +1
%          -- i.e. s = [-ones(1680,1); ones(1680,1)]
%       entry i and entry i+1680 share their (kx,ky): 1680 of 1680
%
%   while the RAW array order shows none of that structure (first 12 are
%   (4,19,-1) (3,17,-1) (-9,-19,1) ..., and only 1 of the 1680 i/i+1680 pairs
%   matches). So the raw arrays are in PRESENTATION order and ORDER is each
%   frame's index back into the canonical list -- provenance, not playlist.
%   The playlist is therefore the array position itself, matched positionally
%   against frameTimes (also 3360, also monotone). ORDER is a permutation of
%   1..3360, so every basis function is shown exactly once.
%
%   THIS IS AN INFERENCE FROM STRUCTURE, and it is the one claim here that is
%   not read off a writer. If the vhlab generator ever becomes readable,
%   check it. What makes the inference safe to act on rather than merely
%   likely: under the opposite reading the raw arrays WOULD be canonical, and
%   they are measurably not.
%
%   ------------------------------------------------------------------------
%   WHAT EACH BASIS FUNCTION BECOMES, AND WHAT IS DELIBERATELY LEFT UNSET
%   ------------------------------------------------------------------------
%     value.angle            atan2d(ky, kx), wrapped to [0,360). EXACT -- a
%                            direction needs no rig calibration.
%     value.phase            THE FIELD WITHOUT WHICH THE SET COLLAPSES. cas =
%                            cos + sin = sqrt(2)*cos(theta - 45deg), so a
%                            basis function written as a cosine grating has
%                            phase -45 deg, and s = -1 is that +180.
%                            Measured: with phase the 3360 entries give 3360
%                            distinct value tuples; WITHOUT it they give 1680
%                            -- every (kx,ky) pair would become one document
%                            and half the basis would vanish into a dedup.
%     value.source_geometry  spatial_frequency = sqrt(kx^2+ky^2)/M, in
%                            `unit` = 'cycles/pixel'.
%     value.contrast         from the generator spec.
%     value.duration         1/fps -- the nominal frame duration.
%     value.is_blank         false. The DC term is excluded by the generator
%                            (measured above), so no basis entry is a blank.
%
%     value.spatial_frequency / .size / .position   UNSET, ON PURPOSE. They
%       are the DEGREE domain and the conversion factor is rig calibration:
%       NewStim computes it as `pixels_per_cm` x distance x tan(1 deg). A
%       sweep of all 1220 documents of 20211116 over the 229 distinct field
%       names they contain finds `distance` (30, on the generator spec) and
%       NOTHING ELSE from that formula -- no `pixels_per_cm`, no
%       pixels-per-degree, no screen or monitor geometry under any spelling.
%       Half a formula is not a conversion, so cycles-per-pixel written into
%       a cycles-per-degree field would be a 20-to-50x error wearing the
%       right unit. `source_geometry.pixels_per_degree` is left unset for the
%       same reason -- it is the missing factor, not a default.
%     value.temporal_frequency   UNSET. Each frame is a static grating, and
%       the composite's blank value for this field is 0, so writing 0 would
%       be indistinguishable from "not looked at".
%     source_geometry.size / .position   UNSET although `rect` is available
%       in pixels: the block carries ONE `unit` char for all three
%       quantities, and it is already spent on 'cycles/pixel'. Recorded as an
%       open question rather than resolved by writing two units into one
%       field.
%
%   See also: ndi.migrate.internal.stimulusPresentationToTimedSequence,
%   ndi.migrate.internal.gratingValueFromParameters.

arguments
    bodies cell
    targetVersion (1,:) char = 'V_eta'
end

report = newReport();
report.bodies_read = numel(bodies);

gratingBodies = {};
byPresentation = containers.Map('KeyType', 'char', 'ValueType', 'any');

% --- index the two halves ----------------------------------------------------
presentations = containers.Map('KeyType', 'char', 'ValueType', 'any');
calcsByPresentation = containers.Map('KeyType', 'char', 'ValueType', 'any');
for k = 1:numel(bodies)
    b = bodies{k};
    if ~isstruct(b) || ~isscalar(b)
        continue;
    end
    switch classNameOf(b)
        case 'stimulus_presentation'
            report.presentations_read = report.presentations_read + 1;
            spec = generatorSpec(b);
            % An empty base.id cannot key the map, and a presentation with no
            % id could not be referenced by a calculator either -- `base`
            % declares id mustBeNonEmpty, so such a document is already
            % un-migratable and is not this function's to repair.
            if ~isempty(spec) && ~isempty(baseField(b, 'id', ''))
                report.generator_presentations = report.generator_presentations + 1;
                presentations(baseField(b, 'id', '')) = b;
            end
        case 'hartley_calc'
            report.hartley_calcs_read = report.hartley_calcs_read + 1;
            pid = depValue(b, 'stimulus_presentation_id');
            if isempty(pid)
                report.calcs_without_presentation = ...
                    report.calcs_without_presentation + 1;
                continue;
            end
            if isKey(calcsByPresentation, pid)
                acc = calcsByPresentation(pid);
            else
                acc = {};
            end
            acc{end+1} = b; %#ok<AGROW>
            calcsByPresentation(pid) = acc;
    end
end

if presentations.Count == 0
    report.reason = 'no stimulus_presentation carries a Hartley generator spec';
    return;
end

% --- the session-wide distinct basis -----------------------------------------
% Keyed by (session_id, value) rather than by value alone: a document's
% session_id is part of its identity, so two sessions in one body set must not
% share a grating document. Keyed through a containers.Map rather than an
% isequal scan because the scan is O(n^2) and n is 3360 per presentation.
seen = containers.Map('KeyType', 'char', 'ValueType', 'any');
ids = {};           % parallel to gratingBodies

presIds = presentations.keys();
for p = 1:numel(presIds)
    pid = presIds{p};
    pres = presentations(pid);
    spec = generatorSpec(pres);

    if ~isKey(calcsByPresentation, pid)
        report.presentations_without_calc = report.presentations_without_calc + 1;
        continue;
    end
    calcs = calcsByPresentation(pid);

    [enumeration, frameTimes, agreed, nCalcs] = agreedEnumeration(calcs);
    report.calcs_matched = report.calcs_matched + nCalcs;
    if ~agreed
        report.presentations_with_disagreeing_calcs = ...
            report.presentations_with_disagreeing_calcs + 1;
        continue;
    end
    if isempty(enumeration.kx)
        report.presentations_without_enumeration = ...
            report.presentations_without_enumeration + 1;
        continue;
    end

    nFrames = numel(enumeration.kx);
    if numel(enumeration.ky) ~= nFrames || numel(enumeration.s) ~= nFrames
        report.presentations_with_ragged_enumeration = ...
            report.presentations_with_ragged_enumeration + 1;
        continue;
    end
    % frameTimes is the ONLY surviving stimulus timing in this corpus: the
    % writer moved presentation_time into presentation_time.bin (declared by
    % 11 of 11 documents, present in 0 of them), and a struct-level batch pass
    % does not open attached binaries. A length disagreement means the two
    % halves describe different runs, so refuse rather than truncate.
    if numel(frameTimes) ~= nFrames
        report.presentations_with_mismatched_frame_times = ...
            report.presentations_with_mismatched_frame_times + 1;
        continue;
    end

    % M and fps are stated TWICE -- on the presentation's generator spec and
    % on the calculator's `stimulus_properties`. The presentation is the
    % source document for the stimulus, so it wins; a disagreement is counted
    % and reported rather than silently resolved.
    props = stimulusProperties(calcs{1});
    if ~agreesOn(props, spec, 'M', 'M') || ~agreesOn(props, spec, 'fps', 'fps')
        report.presentations_with_disagreeing_properties = ...
            report.presentations_with_disagreeing_properties + 1;
    end

    if ~(spec.M > 0)
        report.presentations_without_M = report.presentations_without_M + 1;
        continue;
    end
    duration = 0;
    if spec.fps > 0
        duration = 1 / spec.fps;
    end

    sessionId = baseField(pres, 'session_id', '');
    datestamp = baseField(pres, 'datestamp', '');

    localIndex = containers.Map('KeyType', 'double', 'ValueType', 'double');
    presentedIds = {};
    order = zeros(1, nFrames);
    for f = 1:nFrames
        value = basisValue(enumeration.kx(f), enumeration.ky(f), ...
            enumeration.s(f), spec.M, spec.contrast, duration);
        key = [sessionId '|' valueKey(value)];
        if isKey(seen, key)
            g = seen(key);
        else
            g = numel(gratingBodies) + 1;
            seen(key) = g;
            ids{g} = did.ido.unique_id();  %#ok<AGROW>
            gratingBodies{g} = gratingDocument(ids{g}, sessionId, datestamp, ...
                g, value, targetVersion); %#ok<AGROW>
        end
        if isKey(localIndex, g)
            local = localIndex(g);
        else
            presentedIds{end+1} = ids{g};   %#ok<AGROW>
            local = numel(presentedIds);
            localIndex(g) = local;
        end
        order(f) = local;
    end

    entry = struct();
    entry.presented_ids = presentedIds;
    entry.order         = order;
    entry.frame_times   = frameTimes(:)';
    entry.duration      = duration;
    byPresentation(pid) = entry;

    report.presentations_assembled = report.presentations_assembled + 1;
    report.frames_assembled = report.frames_assembled + nFrames;
end

report.distinct_gratings_minted = numel(gratingBodies);
end

% ===================== the basis value ====================================

function value = basisValue(kx, ky, s, M, contrast, duration)
%BASISVALUE One Hartley basis function as a V_eta `visual_grating` value.
%   Only the fields this can state are set; see the header for every field
%   that is deliberately absent and why. `angle` is wrapped to [0,360) to
%   match the domain v1 `angle` uses (NewStim writes 0-360), and the wrap is a
%   bijection on distinct directions, so it collapses nothing: measured, the
%   3360 entries still give 3360 distinct value tuples after wrapping.
value = struct();
value.angle    = mod(atan2d(double(ky), double(kx)), 360);
value.contrast = contrast;
value.duration = duration;
value.is_blank = false;
% cas(theta) = cos(theta) + sin(theta) = sqrt(2)*cos(theta - 45deg), so as a
% cosine grating the s = +1 basis function sits at -45 deg; s = -1 is the same
% grating +180, which is what the schema's own documentation states. Only the
% 180 SEPARATION is established by the data; the -45 anchor is the cas->cos
% conversion under the phase convention cos(2*pi*f.r + phase).
if s < 0
    value.phase = 135;
else
    value.phase = -45;
end
value.source_geometry = struct( ...
    'spatial_frequency', hypot(double(kx), double(ky)) / double(M), ...
    'unit',              'cycles/pixel');
end

function k = valueKey(value)
%VALUEKEY A char key identical exactly when the value struct is.
%   %.17g round-trips a double, so two keys match only when the numbers do.
k = sprintf('%.17g;%.17g;%.17g;%.17g;%d;%.17g;%s', ...
    value.angle, value.phase, value.contrast, value.duration, ...
    double(value.is_blank), value.source_geometry.spatial_frequency, ...
    value.source_geometry.unit);
end

function g = gratingDocument(id, sessionId, datestamp, index, value, targetVersion)
g = struct();
g.document_class = struct('class_name', 'visual_grating', ...
    'class_version', '1.0.0', ...
    'superclasses', struct('class_name', 'data_type', 'class_version', '1.0.0'), ...
    'schema_version', targetVersion);
g.base = struct('id', id, 'session_id', sessionId, ...
    'name', sprintf('migrated_hartley_basis_%d', index), ...
    'creation_timestamp', datestamp);
% Assigned separately: struct(...) with a struct value distributes.
g.visual_grating = struct();
g.visual_grating.value = value;
end

% ===================== v1 readers =========================================

function spec = generatorSpec(body)
%GENERATORSPEC The white-noise generator parameters of a presentation whose
%   SINGLE stimulus is a Hartley recipe, or [] when it is not one.
%   A POSITIVE test: M plus both half-widths must be there. Listing shapes to
%   exclude would sweep in every stimulus kind nobody has met yet, and this
%   function's misses would be silent.
spec = [];
if ~isfield(body, 'stimulus_presentation') || ~isstruct(body.stimulus_presentation)
    return;
end
stimuli = stimulusArray(body.stimulus_presentation);
if numel(stimuli) ~= 1
    return;
end
p = struct();
if isfield(stimuli(1), 'parameters') && isstruct(stimuli(1).parameters) ...
        && isscalar(stimuli(1).parameters)
    p = stimuli(1).parameters;
end
needed = {'M', 'K_absmax', 'L_absmax'};
for k = 1:numel(needed)
    if ~isfield(p, needed{k}) || isempty(p.(needed{k}))
        return;
    end
end
spec = struct( ...
    'M',        getNum(p, 'M'), ...
    'fps',      getNum(p, 'fps'), ...
    'contrast', getNum(p, 'contrast'), ...
    'sfmax',    getNum(p, 'sfmax'));
end

function stimuli = stimulusArray(block)
%STIMULUSARRAY The `stimuli` list as a struct ARRAY.
%   jsondecode collapses a one-element JSON array of objects to a scalar
%   struct, which is exactly the shape every Hartley presentation has.
stimuli = struct([]);
if ~isfield(block, 'stimuli')
    return;
end
raw = block.stimuli;
if isstruct(raw)
    stimuli = raw(:)';
elseif iscell(raw)
    keep = struct('parameters', {});
    for k = 1:numel(raw)
        if isstruct(raw{k}) && isscalar(raw{k}) && isfield(raw{k}, 'parameters')
            keep(end+1) = struct('parameters', raw{k}.parameters); %#ok<AGROW>
        end
    end
    stimuli = keep;
end
end

function [enumeration, frameTimes, agreed, n] = agreedEnumeration(calcs)
%AGREEDENUMERATION The basis + frame times a presentation's calculators AGREE
%   on. Measured on 20211116: the 21 calculators of a presentation always
%   agree, and all 210 agree on the basis. Disagreement is reported rather
%   than resolved by taking the first -- two calculators describing different
%   runs is an instrument fault, not a result.
enumeration = struct('kx', [], 'ky', [], 's', []);
frameTimes = [];
agreed = true;
n = numel(calcs);
for k = 1:n
    blk = struct();
    if isfield(calcs{k}, 'hartley_reverse_correlation') ...
            && isstruct(calcs{k}.hartley_reverse_correlation)
        blk = calcs{k}.hartley_reverse_correlation;
    end
    hn = struct();
    if isfield(blk, 'hartley_numbers') && isstruct(blk.hartley_numbers)
        hn = blk.hartley_numbers;
    end
    thisEnum = struct( ...
        'kx', numVector(hn, 'KXV'), ...
        'ky', numVector(hn, 'KYV'), ...
        's',  numVector(hn, 'S'));
    thisTimes = numVector(blk, 'frameTimes');
    if k == 1
        enumeration = thisEnum;
        frameTimes = thisTimes;
        % Compared with isequal rather than through a rendered key: on real
        % data each vector is 3360 long and there are 21 calculators per
        % presentation, so a %.17g rendering would build ~300 KB of transient
        % string per document to answer a question isequal answers directly.
    elseif ~isequal(thisEnum, enumeration) || ~isequal(thisTimes, frameTimes)
        agreed = false;
        return;
    end
end
end

function props = stimulusProperties(calc)
props = struct();
if isfield(calc, 'hartley_reverse_correlation') ...
        && isstruct(calc.hartley_reverse_correlation) ...
        && isfield(calc.hartley_reverse_correlation, 'stimulus_properties') ...
        && isstruct(calc.hartley_reverse_correlation.stimulus_properties)
    props = calc.hartley_reverse_correlation.stimulus_properties;
end
end

function tf = agreesOn(props, spec, propName, specName)
%AGREESON True when the calculator restates a generator quantity identically,
%   or does not restate it at all. Absence is not a disagreement.
tf = true;
if ~isfield(props, propName) || isempty(props.(propName)) ...
        || ~isnumeric(props.(propName))
    return;
end
tf = isequal(double(props.(propName)(1)), spec.(specName));
end

function v = numVector(s, name)
v = [];
if isstruct(s) && isfield(s, name) && isnumeric(s.(name)) && ~isempty(s.(name))
    v = double(s.(name)(:)');
end
end

function v = getNum(s, name)
v = 0;
if isfield(s, name) && isnumeric(s.(name)) && ~isempty(s.(name))
    v = double(s.(name)(1));
end
end

function v = baseField(body, name, default)
v = default;
if isfield(body, 'base') && isstruct(body.base) && isfield(body.base, name) ...
        && ~isempty(body.base.(name))
    v = body.base.(name);
end
end

function name = classNameOf(body)
name = '';
if isfield(body, 'document_class') && isstruct(body.document_class) ...
        && isfield(body.document_class, 'class_name')
    name = char(body.document_class.class_name);
end
end

function v = depValue(body, name)
v = '';
if ~isfield(body, 'depends_on')
    return;
end
deps = body.depends_on;
if isstruct(deps)
    items = num2cell(deps(:)');
elseif iscell(deps)
    items = deps(:)';
else
    return;
end
for k = 1:numel(items)
    d = items{k};
    if isstruct(d) && isfield(d, 'name') && strcmp(char(d.name), name) ...
            && isfield(d, 'value') && ~isempty(d.value)
        v = char(d.value);
        return;
    end
end
end

function r = newReport()
%NEWREPORT Every denominator exists before any early return, so a refusal
%   prints the same SHAPE as a success (Operating Rule 5).
r = struct( ...
    'bodies_read',                             0, ...
    'presentations_read',                      0, ...
    'generator_presentations',                 0, ...
    'hartley_calcs_read',                      0, ...
    'calcs_without_presentation',              0, ...
    'calcs_matched',                           0, ...
    'presentations_without_calc',              0, ...
    'presentations_with_disagreeing_calcs',    0, ...
    'presentations_without_enumeration',       0, ...
    'presentations_with_ragged_enumeration',   0, ...
    'presentations_with_mismatched_frame_times', 0, ...
    'presentations_with_disagreeing_properties', 0, ...
    'presentations_without_M',                 0, ...
    'presentations_assembled',                 0, ...
    'frames_assembled',                        0, ...
    'distinct_gratings_minted',                0, ...
    'reason',                                  '');
end
