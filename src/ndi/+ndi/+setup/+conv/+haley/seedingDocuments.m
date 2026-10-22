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
%                        correction applied to it, decision #111); its own
%                        time_reference_id the seeding day, when it existed
%                        from its preparation (decision #147)
%     formulation assertion  what it was made to (decision #146, Jess
%                        Haley 2026-10-21): an assertion about the solution
%                        whose value is its formulation -- its PLAN (the
%                        strain at target OD600 10; a dilution's target
%                        fraction of the stock) -- through `value_id`, its own
%                        value empty; variable composition (PATO:0000025);
%                        no method (none is recorded); timeless, as every
%                        assertion is (decision #147: the day is on the
%                        entity). Not a dose: nothing was given to the
%                        solution.
%     directed_relation  a dilution derived_from (RO:0001000) the stock
%                        solution it was made from, that day's stock (decision
%                        #147); when: the seeding day
%     concentration observation  the stock's MEASURED OD600 (`OD600Real`),
%                        variable OD600 (MCO:0000059), in the `optical_density` canonical (source unit OD600)
%                        with the source pair where the schema has it, method
%                        NCIT:C85776 Optical Density Measurement (decision
%                        #129); instrument the spectrophotometer (the spec's
%                        `spectrophotometer_1`); when: the seeding day.
%     concentration observation  the stock's MEASURED colony count (`CFU`,
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
%     'Instrument'  the spec key of the spectrophotometer (default
%                   'spectrophotometer_1')
%
%   OUT fields: documents (cell), ids (containers.Map, solution key -> entity
%   id), counts (solutions, preparations, derivations, od600_observations,
%   cfu_observations, days), skipped
%   (cellstr).
%
%   See also ndi.setup.conv.haley.seedingSuspensions, ndi.setup.conv.haley.import_V2.

arguments
    S (1,1) struct
    ids
    sessionId (1,:) char
    options.Instrument (1,:) char = 'spectrophotometer_1'
end

tz = 'America/Los_Angeles';
out = struct('documents', {{}}, 'ids', containers.Map(), 'counts', struct('solutions', 0, ...
    'preparations', 0, 'derivations', 0, 'od600_observations', 0, 'cfu_observations', 0, 'days', 0), ...
    'skipped', {{}});
if ~isfield(S, 'solutions') || isempty(S.solutions)
    return;
end
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
        'description', descriptionOf(x), 'type', did2.build.term('', 'material'));
    ent = ndi.setup.V2.entityDocuments('subject', f, struct('time_reference_id', when), ...
        'SessionId', sessionId, ...
        'Type', 'material');
    out.documents = [out.documents, reshape(ent, 1, [])];
    eid = ent{1}.base.id;
    out.ids(x.key) = eid;
    out.counts.solutions = out.counts.solutions + 1;

    % what it was made to: its formulation, its plan, as the solution's
    % composition (decision #146; an assertion, not a dose)
    out.documents{end+1} = did2.build.statement('assertion', eid, ...
        haleyTerm('composition'), [], 'ValueId', ids(x.formulation), 'SessionId', sessionId, 'ValueKind', 'formulation');
    out.counts.preparations = out.counts.preparations + 1;

    % a dilution was made from that day's stock solution (decision #147)
    if strcmp(x.kind, 'dilution')
        stockKey = [x.stock '#solution'];
        if isKey(out.ids, stockKey)
            out.documents{end+1} = did2.build.directedRelation(eid, out.ids(stockKey), ...
                did2.build.term('RO:0001000', 'derived_from'), ...
                'TimeReferenceIds', {when}, 'SessionId', sessionId);
            out.counts.derivations = out.counts.derivations + 1;
        else
            out.skipped{end+1} = sprintf('%s: its stock %s was not built; no derived_from', ...
                x.key, stockKey);
        end
    end

    % what was measured of it: the stock's OD600 and, on most days, its CFU
    if isnan(x.od)
        continue;
    end
    v = did2.build.valueCell('concentration', x.od, 'Canonical', 'optical_density', 'SourceValue', x.od, ...
        'SourceUnit', ndi.setup.V2.sourceUnit('OD600'));
    args = {};
    if ~isempty(instrument), args = {'InstrumentId', instrument}; end
    out.documents{end+1} = did2.build.statement('observation', eid, ...
        haleyTerm('OD600'), v, 'Method', haleyTerm('optical density measurement'), args{:}, ...
        'TimeReferenceIds', {when}, 'SessionId', sessionId, 'ValueKind', 'concentration');
    out.counts.od600_observations = out.counts.od600_observations + 1;
    if ~isnan(x.cfu)
        % the lab code's conversion: CFU x 2e7 per mL (decision #57)
        c = did2.build.valueCell('concentration', x.cfu * 2e10, 'Canonical', 'particles_per_liter', ...
            'SourceValue', x.cfu * 2e7, 'SourceUnit', ndi.setup.V2.sourceUnit('CFU/mL'));
        out.documents{end+1} = did2.build.statement('observation', eid, ...
            haleyTerm('cell density'), c, 'Method', haleyTerm('viable cell count'), ...
            'TimeReferenceIds', {when}, 'SessionId', sessionId, 'ValueKind', 'concentration');
        out.counts.cfu_observations = out.counts.cfu_observations + 1;
    end
end
out.counts.days = double(dayRefs.Count);
fprintf(['DENOMINATOR: %d seeding solution(s) -> %d entity(ies), %d preparation(s), %d ' ...
    'derived_from, %d measured OD600 and %d CFU observation(s), over %d seeding day(s)\n'], ...
    numel(S.solutions), out.counts.solutions, out.counts.preparations, out.counts.derivations, ...
    out.counts.od600_observations, ...
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
        r = ndi.setup.V2.utcReference(d, tz, sessionId, 'Tolerance', [0 86399], 'Format', 'yyyy-MM-dd');
        out.documents{end+1} = r;
        id = r.base.id;
        dayRefs(key) = id;
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
