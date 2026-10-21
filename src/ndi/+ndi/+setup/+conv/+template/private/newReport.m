function r = newReport(stage)
%NEWREPORT An empty stage report: the denominators every stage returns.
%
%   R = newReport(STAGE) starts the report a stage of the template import
%   fills in. Operating rule: a count without its denominator is not
%   evidence, so every stage says how many source items it READ, how many
%   became documents (WRITTEN), how many it SKIPPED (each with its reason in
%   skippedList) and how many ERRORS it met (each in errorList), plus the
%   number of DOCUMENTS it built. read = written + skipped + errors.
%
%   corrected / notCorrected list the spec's named corrections the stage
%   applied or refused (applyCorrection).
%
%   See also skipRow, rowError, printReport.

arguments
    stage {mustBeText}
end
r = struct('stage', char(stage), 'read', 0, 'written', 0, 'skipped', 0, 'errors', 0, ...
    'documents', 0, 'skippedList', {{}}, 'errorList', {{}}, ...
    'corrected', {{}}, 'notCorrected', {{}});
end
