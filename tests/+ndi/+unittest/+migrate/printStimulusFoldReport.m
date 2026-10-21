function printStimulusFoldReport(r, corpusName)
%PRINTSTIMULUSFOLDREPORT Print the second pass's stimulus_presentation report.
%   ndi.unittest.migrate.printStimulusFoldReport(R, CORPUSNAME) prints
%   R = Result.secondPass.stimulusSequence: the denominator, how each
%   decomposed presentation's animal was resolved, the per-kind stimulus
%   counts (NewStim class recogniser), presentations by their set of kinds
%   split decomposed / refused, and the histogram of refusal reasons.
%   REPORT-ONLY: it asserts nothing. Shared by the B and Soph e2e tests.

field = @(name) getOr(r, name, 0);
fprintf(['\n  STIMULUS-PRESENTATION FOLD (%s, did-schema #88) -- report-only\n' ...
         '    DENOMINATOR: %d presentation(s) read\n' ...
         '    folded with a subject (manipulation, value kind item): %d\n' ...
         '        animal via stimulus_response:      %d\n' ...
         '        animal via epoch, own session (FORK 1): %d\n' ...
         '        animal via stimulator element (no epoch element): %d\n' ...
         '    standalone item, no subject (Jess Haley 2026-10-21 "a"): %d\n' ...
         '    refused (left as v1):                       %d\n' ...
         '    method documents minted (one per distinct stimulus): %d  (+%d shared Hartley basis)\n' ...
         '    SEVERAL ANIMALS in the session:             %d presentation(s)\n' ...
         '        folded onto the session cohort (distributive): %d\n' ...
         '        refused (conflicting stimulator links):        %d\n' ...
         '    session cohorts minted: %d, member_of edges: %d\n' ...
         '    quarantined at validation: %d\n'], ...
    corpusName, field('presentations_read'), field('presentations_decomposed'), ...
    field('decomposed_via_response'), field('decomposed_via_epoch'), ...
    field('decomposed_via_stimulator'), field('standalone_items'), ...
    field('presentations_refused'), field('methods_minted'), ...
    field('shared_methods_minted'), ...
    field('several_animal_presentations'), field('distributive_manipulations'), ...
    field('several_animal_refused'), field('cohorts_minted'), ...
    field('cohort_members'), field('quarantined'));
t = getOr(r, 'time_references', []);
if isstruct(t)
    fprintf(['    time references: %d marked, %d minted during the session, ' ...
             '%d without a session document, %d ambiguous\n'], ...
        getOr(t, 'session_references_marked', 0), ...
        getOr(t, 'session_references_minted', 0), ...
        getOr(t, 'observations_without_session', 0), ...
        getOr(t, 'session_references_ambiguous', 0));
end

k = getOr(r, 'stimulus_kinds', []);
fprintf('    STIMULI BY KIND (NewStim class recogniser), over all presentations read:\n');
if isstruct(k) && ~isempty(k)
    fns = fieldnames(k);
    total = 0;
    for f = 1:numel(fns); total = total + k.(fns{f}); end
    fprintf('        DENOMINATOR: %d stimuli classified\n', total);
    for f = 1:numel(fns)
        fprintf('        %8d  %s\n', k.(fns{f}), fns{f});
    end
else
    fprintf('        (no per-kind counts in the report)\n');
end

rows = getOr(r, 'presentations_by_kind', []);
fprintf('    PRESENTATIONS BY KIND SET:  decomposed  refused  kinds\n');
if isstruct(rows) && ~isempty(rows)
    for i = 1:numel(rows)
        fprintf('                              %10d  %7d  %s\n', ...
            rows(i).decomposed, rows(i).refused, rows(i).kinds);
    end
else
    fprintf('        (none)\n');
end

fprintf('    REFUSAL REASONS:\n');
refusals = getOr(r, 'refusals', {});
counts = containers.Map('KeyType', 'char', 'ValueType', 'double');
for i = 1:numel(refusals)
    why = refusals{i}.reason;
    if isempty(why); why = '(empty reason)'; end
    if isKey(counts, why)
        counts(why) = counts(why) + 1;
    else
        counts(why) = 1;
    end
end
ks = keys(counts);
if isempty(ks)
    fprintf('        (no refusals recorded)\n');
end
for i = 1:numel(ks)
    fprintf('        %6d  %s\n', counts(ks{i}), ks{i});
end
end

function v = getOr(s, name, default)
v = default;
if isstruct(s) && isfield(s, name) && ~isempty(s.(name))
    v = s.(name);
end
end
