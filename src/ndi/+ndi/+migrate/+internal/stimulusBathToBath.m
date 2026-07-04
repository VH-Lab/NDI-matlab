function [bathBody, timeRefBody] = stimulusBathToBath(v1Body, resolver)
%STIMULUSBATHTOBATH Assemble a V_epsilon `bath` (+ epoch time reference) from a
%   legacy stimulus_bath, using session/element context.  *** SCAFFOLD ***
%
%   The per-document converter (did2.convert.migrators_e.stimulus_bath) defers
%   stimulus_bath with did2:convert:needsSessionContext, because a `bath`
%   (pharmacological_manipulation) must be emitted complete and two of its
%   required parts can only be obtained by following the stimulator element:
%
%     - subject_id      : the stimulator element's subject, and
%     - time_reference  : an epoch_bounded_reference on the stimulator's epoch.
%
%   The stimulator is used ONLY as the time referent and the subject source; no
%   other connection is kept (the result is a plain `bath`, not a
%   `stimulus_bath`). This function does that session-aware assembly; it is
%   intended to be called by ndi.migrate.local on each body that v1_to_v2
%   deferred with reason did2:convert:needsSessionContext.
%
%   Inputs:
%     v1Body   - the legacy stimulus_bath document body (struct), carrying:
%                  depends_on            : stimulus_element_id (the stimulator)
%                  epochid.epochid       : the stimulator's epoch id
%                  stimulus_bath.location, stimulus_bath.mixture_table
%                  base.{id, session_id, datestamp}
%     resolver - struct of session-aware lookups (provided by ndi.migrate.local
%                from the open session's element graph):
%                  .subjectOfElement(elementId)            -> subject_id (char)
%                  .epochClockOfElement(elementId, epochId)-> clocktype (char)
%
%   Outputs:
%     bathBody     - the V_epsilon `bath` document body.
%     timeRefBody  - the epoch_bounded_reference document the bath depends_on.
%
%   STATUS: scaffold. Authored without local MATLAB; the assembly shape is
%   complete but the resolver wiring + ndi.migrate.local second pass are TODO,
%   and it is verified only in NDI CI. See ndi-matlab issue #782.

arguments
    v1Body   (1,1) struct
    resolver (1,1) struct
end

stimulatorId = dependencyValue(v1Body, 'stimulus_element_id');
epochId      = epochIdOf(v1Body);
sessionId    = baseField(v1Body, 'session_id', '');
datestamp    = baseField(v1Body, 'datestamp', '');

% --- resolve the session/element context (the reason this is NDI-layer) -----
subjectId  = resolver.subjectOfElement(stimulatorId);
epochClock = resolver.epochClockOfElement(stimulatorId, epochId);

% --- time reference: epoch_bounded_reference on the stimulator's epoch ------
timeRefId = did.ido.unique_id();
timeRefBody = struct();
timeRefBody.document_class = struct( ...
    'class_name', 'epoch_bounded_reference', 'class_version', '1.0.0', ...
    'superclasses', [ ...
        struct('class_name', 'time_reference', 'class_version', '1.0.0'), ...
        struct('class_name', 'epochid',        'class_version', '1.0.0')], ...
    'schema_version', 'V_epsilon');
timeRefBody.depends_on = struct('name', 'element_id', 'value', stimulatorId);
timeRefBody.base = struct('id', timeRefId, 'session_id', sessionId, ...
    'name', 'migrated_stimulator_epoch_anchor', 'datestamp', datestamp);
timeRefBody.time_reference = struct('is_approximate', false);
timeRefBody.epochid = struct('epochid', epochId);
timeRefBody.epoch_bounded_reference = struct('epoch_clock', epochClock);

% --- the bath --------------------------------------------------------------
bathBody = struct();
bathBody.document_class = struct( ...
    'class_name', 'bath', 'class_version', '1.0.0', ...
    'superclasses', struct('class_name', 'pharmacological_manipulation', ...
        'class_version', '1.0.0'), ...
    'schema_version', 'V_epsilon');
bathBody.depends_on = [ ...
    struct('name', 'subject_id',       'value', subjectId), ...
    struct('name', 'time_reference_1', 'value', timeRefId)];
bathBody.base = struct('id', did.ido.unique_id(), 'session_id', sessionId, ...
    'name', 'migrated_bath', 'datestamp', datestamp);
% mixture is declared on pharmacological_manipulation -> its block.
bathBody.pharmacological_manipulation = struct();
bathBody.pharmacological_manipulation.mixture = parseMixture(v1Body);
% location/kind are declared on bath -> the bath block.
bathBody.bath = struct('kind', 'drug', 'location', locationTerm(v1Body));
end

% ===================== helpers =============================================

function v = dependencyValue(body, name)
v = '';
if isfield(body, 'depends_on') && isstruct(body.depends_on)
    for k = 1:numel(body.depends_on)
        d = body.depends_on(k);
        if isfield(d, 'name') && strcmp(d.name, name)
            if isfield(d, 'value');       v = d.value;
            elseif isfield(d, 'document_id'); v = d.document_id; end
        end
    end
end
end

function e = epochIdOf(body)
e = '';
if isfield(body, 'epochid') && isstruct(body.epochid) ...
        && isfield(body.epochid, 'epochid')
    e = body.epochid.epochid;
end
end

function v = baseField(body, name, default)
v = default;
if isfield(body, 'base') && isstruct(body.base) && isfield(body.base, name)
    v = body.base.(name);
end
end

function term = locationTerm(body)
term = struct('node', '', 'name', '');
if isfield(body, 'stimulus_bath') && isstruct(body.stimulus_bath) ...
        && isfield(body.stimulus_bath, 'location') ...
        && isstruct(body.stimulus_bath.location)
    loc = body.stimulus_bath.location;
    if isfield(loc, 'node');             term.node = loc.node;
    elseif isfield(loc, 'ontologyNode'); term.node = loc.ontologyNode; end
    if isfield(loc, 'name');             term.name = loc.name; end
end
end

function mixture = parseMixture(body)
%PARSEMIXTURE Build the array-of-records mixture from the legacy fields.
%   Mirrors the per-chemical record shape pharmacological_manipulation.mixture
%   wants: { chemical: ontology_term, amount: concentration }. Handles the
%   CSV mixture_table form; the V_gamma solution_name/concentration form is a
%   TODO extension. pharmacological_manipulation.mixture is mustBeNonEmpty,
%   so this always returns >= 1 record -- a blank one when nothing parses,
%   which is the curator's signal rather than a validation failure.
mixture = struct('chemical', {}, 'amount', {});
if isfield(body, 'stimulus_bath') && isstruct(body.stimulus_bath) ...
        && isfield(body.stimulus_bath, 'mixture_table')
    raw = body.stimulus_bath.mixture_table;
    if ischar(raw) || (isstring(raw) && isscalar(raw))
        lines = strsplit(char(raw), newline);
        for i = 1:numel(lines)
            cols = strsplit(strtrim(lines{i}), ',');
            if numel(cols) < 5 || isempty(strtrim(cols{1}))
                continue;   % header / blank / malformed row
            end
            chemical = struct('node', strtrim(cols{1}), 'name', strtrim(cols{2}));
            amount = struct('source_value', str2double(cols{3}), ...
                'source_unit', strtrim(cols{5}), 'approximate', false);
            mixture(end+1) = struct('chemical', chemical, 'amount', amount); %#ok<AGROW>
        end
    end
end
if isempty(mixture)
    mixture(1) = struct( ...
        'chemical', struct('node', '', 'name', ''), ...
        'amount', struct('source_value', 0.0, 'source_unit', '', ...
            'approximate', false));
end
end
