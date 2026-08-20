classdef TestElementSpecimenSurvivesRetiredObserves < matlab.unittest.TestCase
%TESTELEMENTSPECIMENSURVIVESRETIREDOBSERVES The specimen moves; the reader must follow.
%
%   FOUND ON A REAL SESSION, 2026-08-14, and it is the failure this whole
%   package exists to prevent, reintroduced inside the package itself. A
%   migrated session rebuilt two probes and only one of them was right:
%
%       [1] electrode16   type: n-trode      direct: 0   subject_id: <none>
%       [2] rayostim      type: stimulator   direct: 1   subject_id: 41269628e2a0...
%
%   Nothing errored. `electrode16` came back as a derived element with no
%   specimen, which is a coherent-looking answer and a wrong one.
%
%   THE MIGRATION WAS CORRECT BOTH TIMES. #30's signed model replaces the
%   loose `probe observes specimen` relation with a typed
%   `<modality>_observation` -- `subject_id` = the specimen, `instrument_id`
%   = the element (T7: patient vs agent) -- and the migrator then RETIRES
%   the now-redundant relation. A stimulator assembles no recording
%   observation, so its `observes` survives. Two probes, two shapes, one
%   reader that only knew the second.
%
%   WHY A TEST AND NOT JUST A FIX. The invariant spans two repositories:
%   DID-matlab decides when `observes` is retired, NDI decides where to
%   look for the specimen, and no compiler, schema or validator compares
%   them. When they drift the symptom is a probe that reads back as
%   non-direct -- and `ndi.element.epochtable` gives a non-direct element
%   `epochprobemap = []` (element.m:342), so the probe silently cannot
%   resolve its channels. Silent, wrong, and shaped exactly like a dataset
%   that genuinely has a derived element.
%
%   These are STRING COMPARISONS AGAINST SOURCE, in the same spirit as
%   TestElementLabelMatchesMigrator and for the same reason: there is no
%   shared constant to assert on across a repository boundary, and
%   pretending there is would be the thing the test is here to prevent.
%
%   See also: ndi.vintage.elementFields,
%             ndi.unittest.vintage.TestElementLabelMatchesMigrator.

    methods (Test)

        function testTheMigratorStillRetiresObserves(testCase)
            % If this ever stops being true, the reader's instrument-edge
            % lookup becomes dead code rather than a bug -- so it is
            % asserted rather than assumed. The failure direction matters:
            % a reader that checks BOTH shapes is correct either way, but
            % a silent change here would leave nobody able to explain why
            % the extra query exists.
            src = testCase.sourceOf('did2.convert.migrators_j.element');
            testCase.log(sprintf( ...
                'DENOMINATOR: element migrator source is %d char(s)', numel(src)));

            testCase.verifySubstring(src, 'retireObserves', ...
                ['The element migrator no longer mentions `retireObserves`. ' ...
                 'ndi.vintage.elementFields recovers the specimen from the ' ...
                 'observation''s instrument_id BECAUSE the migrator ' ...
                 'suppresses `observes` when that observation exists.']);

            testCase.verifySubstring(src, '''observes''', ...
                ['The element migrator no longer writes an `observes` ' ...
                 'relation at all. elementFields still falls back to it ' ...
                 'for the stimulator case, which would now find nothing.']);
        end

        function testTheAssemblerIsWhatSetsTheFlag(testCase)
            % The retirement is decided inside jRecordingObservation, not
            % in the migrator, and only on the path that actually emitted
            % an observation. That is the property which makes the
            % instrument edge a SOUND signal for `direct`: no observation
            % is assembled unless the element was direct.
            src = testCase.sourceOf('did2.convert.migrators_j.private.jRecordingObservation');
            if isempty(src)
                src = testCase.sourceNear('did2.convert.migrators_j.element', ...
                    fullfile('private', 'jRecordingObservation.m'));
            end
            testCase.assumeNotEmpty(src, ...
                'jRecordingObservation is not reachable from this checkout.');
            testCase.log(sprintf( ...
                'DENOMINATOR: jRecordingObservation source is %d char(s)', numel(src)));

            testCase.verifySubstring(src, 'retireObserves = true', ...
                ['jRecordingObservation no longer sets `retireObserves`, so ' ...
                 'the migrator''s suppression of `observes` is driven by ' ...
                 'something else now. Re-derive which shape a direct ' ...
                 'recording element ends up with before trusting ' ...
                 'elementFields.']);

            testCase.verifySubstring(src, 'instrument_id', ...
                ['jRecordingObservation no longer names `instrument_id`. ' ...
                 'That edge is the ONLY route from a recording element ' ...
                 'back to its specimen once `observes` is retired.']);
        end

        function testTheReaderAsksAboutTheInstrumentEdge(testCase)
            % The regression, pinned. This function used to read the
            % specimen from `observes` alone and then infer `direct` from
            % the same absence -- two facts destroyed by one missing
            % query.
            src = fileread(which('ndi.vintage.elementFields'));
            testCase.log(sprintf( ...
                'DENOMINATOR: elementFields source is %d char(s)', numel(src)));

            testCase.verifySubstring(src, 'instrument_id', ...
                ['ndi.vintage.elementFields does not query `instrument_id`. ' ...
                 'Every direct recording element will report subject_id ' ...
                 '<none> and direct = 0, silently.']);

            testCase.verifySubstring(src, 'subject_observation', ...
                ['elementFields no longer queries `subject_observation`. ' ...
                 'The concrete class is a per-modality name chosen by ' ...
                 'jRecordingModality; the abstract parent is what lets ' ...
                 'this repository avoid a second copy of that table.']);
        end

        function testDirectIsNotInferredFromTheSpecimenAlone(testCase)
            % The precise shape of the bug: `f.direct = ~isempty(specimen)`.
            % It is not enough to add the new query -- if `direct` is still
            % derived from the specimen being non-empty, then an
            % observation with a blank subject edge reports a direct probe
            % as derived. Presence of the OBSERVATION is the signal;
            % presence of the specimen is not.
            src = fileread(which('ndi.vintage.elementFields'));
            testCase.verifyEmpty(strfind(src, 'f.direct = ~isempty(specimen)'), ...
                ['`direct` is being inferred from the specimen alone again. ' ...
                 'An observation exists only for a direct element, so its ' ...
                 'PRESENCE is what settles `direct`; the specimen it names ' ...
                 'is a separate fact and conflating them is the original ' ...
                 'defect.']);
        end

    end

    methods (Access = private)

        function src = sourceOf(testCase, fname)
            p = which(fname);
            if isempty(p) || ~isfile(p)
                % ASSUMPTION FAILURE, NOT A TEST FAILURE. "DID-matlab is
                % absent" and "the two repositories disagree" are
                % different findings and must not print alike.
                assumeFail(testCase, sprintf( ...
                    '%s is not on the path, so the cross-repo invariant cannot be checked here.', ...
                    fname));
            end
            src = fileread(p);
        end

        function src = sourceNear(~, siblingFunction, relPath)
            % `private/` functions are not visible to `which`, so the one
            % public sibling in the same package is used to locate the
            % package directory.
            src = '';
            p = which(siblingFunction);
            if isempty(p) || ~isfile(p)
                return;
            end
            candidate = fullfile(fileparts(p), relPath);
            if isfile(candidate)
                src = fileread(candidate);
            end
        end

    end

end
