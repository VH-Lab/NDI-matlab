function verifyDeferralsAreDeclared(testCase, byClass, declared)
%VERIFYDEFERRALSAREDECLARED Every unconverted class must carry a written reason.
%   verifyDeferralsAreDeclared(TESTCASE, BYCLASS, DECLARED) fails TESTCASE when
%   BYCLASS -- a `summary.unconverted_by_class` table from
%   did2.convert.v1_to_v2 -- names a class that DECLARED does not.
%
%   BYCLASS   struct, one field per class, value = document count. Built by
%             v1_to_v2's buildByClassTable via matlab.lang.makeValidName, so
%             for every class name in this migration the field name IS the
%             class name.
%   DECLARED  Nx2 cell, {class_name, reason}. The reason is not decoration:
%             v1_to_v2.m:244-250 records that a deliberate deferral and an
%             accidental fall-through are indistinguishable downstream, and
%             that the count separates them "by expectation rather than by
%             code". A row with no reason supplies no expectation.
%
%   ---------------------------------------------------------------------
%   WHY THIS IS ONE FUNCTION AND NOT A COPY PER TEST FILE
%   ---------------------------------------------------------------------
%   The corpus test files already duplicate five small helpers verbatim
%   (findAllByClass, destinationBodies, quarantineDiag, resultDiag,
%   readCorpusBodies), which is harmless for a diagnostic string. This one
%   decides a PASS, and two copies of a rule that decide passes are how the
%   two halves drift until a corpus is gated by the laxer one. The reason it
%   is a package function rather than a sixth local copy is that: same
%   argument the migration itself uses for corpus_proven.py calling
%   coverage.py across a repository boundary instead of reimplementing the
%   verdict.
%
%   BOTH DIRECTIONS ARE CHECKED, and the second one is the one that rots.
%   An UNDECLARED class fails, because it is a document nobody expected to
%   pass through. A DECLARED class that no longer appears also fails, because
%   the deferral it describes has been built and the row is now a claim about
%   the past -- exactly the staleness this project keeps paying for, and the
%   only moment at which anyone would notice is a run where it stops firing.

arguments
    testCase (1,1) matlab.unittest.TestCase
    byClass  (1,1) struct
    declared (:,2) cell
end

seen = fieldnames(byClass);
declaredNames = declared(:, 1);

% BOTH verifications RUN UNCONDITIONALLY, including on the green path. A
% helper that only calls verify* when it has something to complain about
% contributes nothing to the test's verification count when it passes, so
% "checked and clean" and "never reached" become indistinguishable in the
% result -- the same defect one layer up.

% ---- direction 1: a class passed through that nobody declared -------------
undeclared = seen(~ismember(seen, declaredNames));
detail = '';
for k = 1:numel(undeclared)
    detail = sprintf('%s\n      %s: %d document(s)', detail, ...
        undeclared{k}, byClass.(undeclared{k}));
end
verifyEmpty(testCase, undeclared, sprintf( ...
    ['%d of %d class(es) passed through pass 1 with no declared reason. An ' ...
     'undeclared passthrough is the ACCIDENTAL kind until someone says ' ...
     'otherwise: the migrator looked for a field the source document does ' ...
     'not have and fell through to its fallback, and nothing else in the ' ...
     'pipeline can see that -- the document is valid, nothing dangles, and ' ...
     'it counts as migrated. Either fix the migrator or add a row saying ' ...
     'why it defers and what closes it.%s'], ...
    numel(undeclared), numel(seen), detail));

% ---- direction 2: a declared reason that no longer describes anything -----
vanished = declaredNames(~ismember(declaredNames, seen));
detail = '';
for k = 1:numel(vanished)
    detail = sprintf('%s\n      %s', detail, vanished{k});
end
verifyEmpty(testCase, vanished, sprintf( ...
    ['%d of %d declared deferral(s) no longer fire. That is GOOD NEWS and a ' ...
     'stale record at the same time: the class now converts, and the row ' ...
     'still says it does not. Delete the row.%s'], ...
    numel(vanished), numel(declaredNames), detail));
end
