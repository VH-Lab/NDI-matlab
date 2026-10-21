function out = seedingDocuments(S, ids, sessionId, options)
%SEEDINGDOCUMENTS Stage 8 part B (Haley): each seeding solution as an entity.
%
%   OUT = ndi.setup.conv.haley.seedingDocuments(S, IDS, SESSIONID) builds the
%   dataset-level documents of the seeding solutions in S.solutions
%   (ndi.setup.conv.haley.seedingSuspensions), decision #114 (tenet T19, "a
%   planned value is said by its term"; T14, "missing is not a value"). IDS
%   maps the dataset-level keys (stage 2: the formulations, the strains, the
%   instruments) to their document ids; SESSIONID is the dataset's session.
%   Per solution actually pipetted (the OD600 10 stock of a seeding day, each
%   dilution made from it, and an unmeasured day's solution):
%
%     entity             type material, local_identifier its formulation's
%                        key, a name and description (and the note of a
%                        correction applied to it, decision #111)
%     dose_manipulation  how it was made: variable the strain's term (as a
%                        seeding dose names it, decision #105),
%                        formulation_id its formulation -- its PLAN (the
%                        strain at target OD600 10; a dilution's target
%                        fraction of the stock) -- with no amount (the source
%                        gives none) and no method (none is recorded); when:
%                        the seeding day
%     concentration_observation  the stock's MEASURED OD600 (`OD600Real`),
%                        variable OD600 (MCO:0000059), in the `od600` canonical
%                        with the source pair where the schema has it, method
%                        NCIT:C85776 Optical Density Measurement (decision
%                        #129); instrument the spectrophotometer (the spec's
%                        `spectrophotometer_1`); when: the seeding day.
%     concentration_observation  the stock's MEASURED colony count (`CFU`,
%                        where the day has one), variable NCIT:C120538 Cell
%                        Density, method NCIT:C130166 Viable Cell Count
%                        (decision #129): `particles_per_liter` CFU x 2e10,
%                        the source pair CFU x 2e7 'CFU/mL' (the lab code's
%                        conversion, decision #57; NCIT:C68902 Colony Forming
%                        Unit per Milliliter is the registered unit). No
%                        instrument: the colonies were counted on a plate,
%                        not with the spectrophotometer; when: the seeding
%                        day.
%                        A dilution was not measured and an unmeasured day's
%                        solution was not either: no observation (T14).
%     absolute_time_reference  the seeding day, as an instant written to the
%                        day (tolerance minus 0, plus 86399 s; tenet T14's
%                        T-7: a coarser granularity is a tolerance), one per
%                        day
%
%   The seeding doses of the patches keep pointing at the formulation they
%   used (dose.formulation_id): a formulation and its solution are one to
%   one, and a dose has no edge for the material it was pipetted from.
%
%   Options:
%     'Names'       containers.Map, strain key -> the term a dose of it reads
%                   as (import_V2's namesOf)
%     'Instrument'  the spec key of the spectrophotometer (default
%                   'spectrophotometer_1')
%
%   OUT fields: documents (cell), ids (containers.Map, solution key -> entity
%   id), counts (solutions, preparations, od600_observations,
%   cfu_observations, days), skipped
%   (cellstr).
%
%   See also ndi.setup.conv.haley.seedingSuspensions, ndi.setup.conv.haley.import_V2.

arguments
    S (1,1) struct
    ids
    sessionId (1,:) char
    options.Names = containers.Map()
    options.Instrument (1,:) char = 'spectrophotometer_1'
end

tz = 'America/Los_Angeles';
out = struct('documents', {{}}, 'ids', containers.Map(), 'counts', struct('solutions', 0, ...
    'preparations', 0, 'od600_observations', 0, 'cfu_observations', 0, 'days', 0), ...
    'skipped', {{}});
if ~isfield(S, 'solutions') || isempty(S.solutions)
    return;
end
hasObservation = ndi.setup.V2.schemaHasLeaf('concentration_observation');
hasOD = ndi.setup.V2.schemaHasField('concentration', 'value.od600');
instrument = '';
if isKey(ids, options.Instrument)
    instrument = ids(options.Instrument);
else
    out.skipped{end+1} = sprintf(['no instrument %s: the OD600 observations name no ' ...
        'instrument'], options.Instrument);
end
dayRefs = containers.Map();

for k = 1:numel(S.solutions)
    x = S.solutions(k);
    if ~isKey(ids, x.formulation)
        out.skipped{end+1} = sprintf('%s: formulation %s was not built; no solution', ...
            x.key, x.formulation);
        continue;
    end
    when = dayRef(x.day);

    % the solution
    f = struct('local_identifier', x.formulation, 'name', nameOf(x), ...
        'description', descriptionOf(x));
    if ndi.setup.V2.schemaHasField('subject', 'type')
        f.type = did2.build.term('', 'material');
    end
    ent = ndi.setup.V2.entityDocuments('subject', f, struct(), 'SessionId', sessionId, ...
        'Type', 'material');
    out.documents = [out.documents, reshape(ent, 1, [])];
    eid = ent{1}.base.id;
    out.ids(x.key) = eid;
    out.counts.solutions = out.counts.solutions + 1;

    % how it was made: to its formulation, its plan
    out.documents{end+1} = did2.build.statement('dose_manipulation', eid, strainTerm(x.strain), [], ...
        'Edges', struct('formulation_id', ids(x.formulation)), ...
        'TimeReferenceIds', {when}, 'SessionId', sessionId);
    out.counts.preparations = out.counts.preparations + 1;

    % what was measured of it: the stock's OD600 and, on most days, its CFU
    if isnan(x.od)
        continue;
    end
    if ~hasObservation
        out.skipped{end+1} = sprintf(['%s: the schema in use has no concentration_observation; ' ...
            'its measured OD600 %g is not recorded'], x.key, x.od);
        continue;
    end
    if hasOD
        v = did2.build.valueCell('concentration', x.od, 'Canonical', 'od600', 'SourceValue', x.od, ...
            'SourceUnit', 'OD600');
    else
        v = did2.build.valueCell('concentration', x.od, 'Canonical', 'source_value', 'SourceUnit', 'OD600');
    end
    args = {};
    if ~isempty(instrument), args = {'InstrumentId', instrument}; end
    out.documents{end+1} = did2.build.statement('concentration_observation', eid, ...
        haleyTerm('OD600'), v, 'Method', haleyTerm('optical density measurement'), args{:}, ...
        'TimeReferenceIds', {when}, 'SessionId', sessionId);
    out.counts.od600_observations = out.counts.od600_observations + 1;
    if ~isnan(x.cfu)
        % the lab code's conversion: CFU x 2e7 per mL (decision #57)
        c = did2.build.valueCell('concentration', x.cfu * 2e10, 'Canonical', 'particles_per_liter', ...
            'SourceValue', x.cfu * 2e7, 'SourceUnit', 'CFU/mL');
        out.documents{end+1} = did2.build.statement('concentration_observation', eid, ...
            haleyTerm('cell density'), c, 'Method', haleyTerm('viable cell count'), ...
            'TimeReferenceIds', {when}, 'SessionId', sessionId);
        out.counts.cfu_observations = out.counts.cfu_observations + 1;
    end
end
out.counts.days = double(dayRefs.Count);
fprintf(['DENOMINATOR: %d seeding solution(s) -> %d entity(ies), %d preparation(s), %d measured ' ...
    'OD600 and %d CFU observation(s), over %d seeding day(s)\n'], numel(S.solutions), ...
    out.counts.solutions, out.counts.preparations, out.counts.od600_observations, ...
    out.counts.cfu_observations, out.counts.days);
for j = 1:numel(out.skipped)
    fprintf('  skipped: %s\n', out.skipped{j});
end

    function id = dayRef(day)
        % the seeding day, an instant written to the day: one per day
        d = dateshift(wallClock(day, tz), 'start', 'day');
        key = char(d, 'yyyy-MM-dd');
        if isKey(dayRefs, key)
            id = dayRefs(key);
            return;
        end
        r = utcReference(d, [0 86399], 'yyyy-MM-dd', NaT, [], 'yyyy-MM-dd', false, tz, sessionId);
        out.documents{end+1} = r;
        id = r.base.id;
        dayRefs(key) = id;
    end

    function t = strainTerm(key)
        % the term a dose of the strain reads as (decision #105)
        if isKey(options.Names, key)
            t = options.Names(key);
        else
            t = did2.build.term('', key);
        end
        if ~isstruct(t), t = did2.build.term('', t); end
    end
end

function n = nameOf(x)
% e.g. "OP50 suspension, target OD600 10, 2023-03-27"
arguments
    x (1,1) struct
end
n = sprintf('%s suspension, target OD600 %g, %s', x.strain, x.target, char(x.day, 'yyyy-MM-dd'));
end

function d = descriptionOf(x)
arguments
    x (1,1) struct
end
diluent = 'its diluent';
if ~isempty(x.diluent), diluent = x.diluent; end
day = char(x.day, 'yyyy-MM-dd');
switch x.kind
    case 'stock'
        d = sprintf(['The %s suspension made to OD600 10 in %s on %s, from a pelleted culture, ' ...
            'for that day''s seeding; its OD600 was measured (an observation of it).'], ...
            x.strain, diluent, day);
    case 'dilution'
        d = sprintf('The %s stock of %s diluted in %s to OD600 %g, for that day''s seeding.', ...
            x.strain, day, diluent, x.target);
    otherwise
        d = sprintf('The %s suspension at OD600 %g in %s seeded on %s.', ...
            x.strain, x.target, diluent, day);
end
if ~isempty(x.note)
    d = sprintf('%s %s', d, x.note);
end
end
