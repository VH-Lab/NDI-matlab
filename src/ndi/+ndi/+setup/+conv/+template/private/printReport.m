function printReport(r)
%PRINTREPORT Print a stage report, its denominator first.

arguments
    r (1,1) struct
end
fprintf(['DENOMINATOR (%s): %d read, %d written, %d skipped, %d error(s); ' ...
    '%d document(s) built\n'], r.stage, r.read, r.written, r.skipped, r.errors, r.documents);
if r.read ~= r.written + r.skipped + r.errors
    fprintf('  ** the counts do not add up: read %d ~= %d written + %d skipped + %d errors\n', ...
        r.read, r.written, r.skipped, r.errors);
end
for k = 1:numel(r.skippedList)
    fprintf('  skipped: %s\n', r.skippedList{k});
end
for k = 1:numel(r.errorList)
    fprintf('  ERROR: %s\n', r.errorList{k});
end
for k = 1:numel(r.corrected)
    fprintf('  corrected: %s\n', r.corrected{k});
end
for k = 1:numel(r.notCorrected)
    fprintf('  correction not applied: %s\n', r.notCorrected{k});
end
end
