function [parameters, displayOrder] = extractStimulusParametersFromFile(analyzerFile)
%extractStimulusParametersFromFile Extract stimulus parameters from a .analyzer file.
%
%   SYNTAX:
%   [parameters, displayOrder] = extractStimulusParametersFromFile(analyzerFile)
%
%   DESCRIPTION:
%   Loads the '.analyzer' file ANALYZERFILE and passes its 'Analyzer'
%   structure to ndi.setup.stimulus.kjnielsenlab.extractStimulusParameters.
%
%   Any error raised while reading or interpreting the file is re-thrown with
%   the full path of that file appended to the message. Ingestion walks many
%   epochs, and the underlying functions see only a loaded structure, so
%   without this the failing file cannot be identified from the error alone.
%   The original error's identifier is preserved and the original exception is
%   attached as a cause, so callers that catch specific identifiers, and the
%   original stack, both survive.
%
%   INPUTS:
%   analyzerFile (char): Path to a '.analyzer' file.
%
%   OUTPUTS:
%   parameters (cell array):       See extractStimulusParameters.
%   displayOrder (numeric vector): See extractStimulusParameters.
%
%   See also: ndi.setup.stimulus.kjnielsenlab.extractStimulusParameters

arguments
    analyzerFile (1,:) char
end

resolvedFile = resolveFullPath(analyzerFile);

try
    z = load(analyzerFile, '-mat');
    if ~isfield(z, 'Analyzer')
        error('extractStimulusParametersFromFile:missingAnalyzer', ...
              'The file does not contain an ''Analyzer'' variable.');
    end
    [parameters, displayOrder] = ...
        ndi.setup.stimulus.kjnielsenlab.extractStimulusParameters(z.Analyzer);
catch ME
    % An error thrown without an identifier cannot be used to build an
    % MException, so fall back to one of our own.
    identifier = ME.identifier;
    if isempty(identifier)
        identifier = 'extractStimulusParametersFromFile:analyzerFileError';
    end
    % ME.message is passed as an argument to %s, never as a format string, so
    % any '%' or '\' it contains is not re-interpreted.
    annotatedError = MException(identifier, '%s\nAnalyzer file: %s', ...
                                ME.message, resolvedFile);
    annotatedError = addCause(annotatedError, ME);
    throw(annotatedError);
end

end % extractStimulusParametersFromFile()


% --- Local Helper Function for Resolving the Full Path ---
function fullPath = resolveFullPath(fileName)
    % Returns the full path of FILENAME when it can be resolved on disk, and
    % FILENAME unchanged otherwise (so a missing file still reports the name
    % the caller asked for).

    fileInfo = dir(fileName);
    if isscalar(fileInfo) && ~fileInfo.isdir
        fullPath = fullfile(fileInfo.folder, fileInfo.name);
    else
        fullPath = fileName;
    end
end
