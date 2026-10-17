function avi2mp4(inputSource, outputDir, options)
%AVI2MP4 Compress .avi files to .mp4 using FFmpeg.
%   AVI2MP4(INPUTSOURCE) searches recursively for all .avi files in 
%   INPUTSOURCE and compresses them using H.264. The compressed files 
%   are saved in the same directory as the source files.
%
%   AVI2MP4(INPUTSOURCE, OUTPUTDIR) saves all compressed files to the 
%   specified OUTPUTDIR. If OUTPUTDIR is empty (''), it defaults to the 
%   source file's directory.
%
%   AVI2MP4(..., 'Name', Value) specifies additional options using one 
%   or more name-value pair arguments.
%
%   Syntax:
%       avi2mp4(inputSource)
%       avi2mp4(inputSource, outputDir)
%       avi2mp4(___, 'crf', 18)
%       avi2mp4(___, 'preset', 'slow')
%       avi2mp4(___, 'Overwrite', false)
%
%   Input Arguments:
%       inputSource - Source to be compressed. Can be one of the following:
%                     - Path to a single .avi file (char or string).
%                     - Path to a directory (char or string). The function 
%                       will search recursively for all .avi files.
%                     - A cell array of character vectors (cellstr) 
%                       containing specific file paths.
%                     - A string array containing specific file paths.
%
%       outputDir   - (Optional) Destination folder for compressed files. 
%                     If omitted or set to '', compressed files are saved 
%                     in the same directory as their respective source files.
%                     (char vector | string scalar)
%
%   Name-Value Arguments:
%       crf         - Constant Rate Factor (0-51). Lower is higher quality. 
%                     Default is FFmpeg default (usually 23).
%                     (integer)
%
%       preset      - Encoding speed/efficiency tradeoff. Options include:
%                     'ultrafast', 'superfast', 'veryfast', 'faster', 
%                     'fast', 'medium', 'slow', 'slower', 'veryslow'.
%                     (char vector | string scalar)
%
%       Overwrite   - Whether to overwrite existing .mp4 files. If false, 
%                     existing files are skipped.
%                     (logical scalar, default: true)
%
%       ffmpegPath  - Full path of the ffmpeg program to run. An explicit
%                     path always wins. Default '' finds it with
%                     ndi.fun.findExecutable: the preference
%                     Tools.FFmpegPath, the FFMPEG_BINARY environment
%                     variable, the usual install folders, then your
%                     shell's PATH.
%                     (char vector | string scalar)
%
%   Examples:
%       % Compress all files in a folder and save locally
%       avi2mp4('/Users/jhaley/Data/Experiment1');
%
%       % Compress with high quality and skip existing files
%       avi2mp4(dataPath, 'Overwrite', false, 'crf', 18);
%
%   See also: ndi.fun.findExecutable, ndi.fun.systemCommandLine,
%             SYSTEM, DIR, FULLFILE.

% Input argument validation
arguments
    inputSource {mustBeText, mustBeNonempty}
    outputDir {mustBeTextScalar} = ""
    options.crf {mustBeScalarOrEmpty, mustBeInteger, mustBeInRange(options.crf, 0, 51)} = []
    options.preset (1,:) char {mustBeMember(options.preset, {'', 'ultrafast', ...
        'superfast', 'veryfast', 'faster', 'fast', 'medium', 'slow', ...
        'slower', 'veryslow'})} = ''
    options.Overwrite logical = true
    options.ffmpegPath (1,:) char = ''
end
    
% 1. Unify inputSource into a struct array of files
filesToProcess = struct('name', {}, 'folder', {});

if iscell(inputSource) || (isstring(inputSource) && ~isscalar(inputSource))
    % Handle cell array or string array of paths
    inputSource = cellstr(inputSource);
    for i = 1:length(inputSource)
        if isfile(inputSource{i})
            [p, n, e] = fileparts(inputSource{i});
            filesToProcess(end+1) = struct('name', [n, e], 'folder', p); %#ok<AGROW>
        end
    end
elseif isfile(inputSource)
    % Handle single file
    [p, n, e] = fileparts(char(inputSource));
    filesToProcess = struct('name', [n, e], 'folder', p);
elseif isfolder(inputSource)
    % Handle directory (recursive)
    filesToProcess = dir(fullfile(char(inputSource), '**', '*.avi'));
else
    error('inputSource must be a valid file, directory, or cell array of paths.');
end

if isempty(filesToProcess)
    fprintf('No valid .avi files found to process.\n'); return;
end

% 2. Find FFmpeg (Cross-Platform)
ffmpegPath = findFFmpeg(options.ffmpegPath);

% 3. Prepare Flags (each element is passed as one quoted argument)
codecArgs = {'-vcodec', 'libx264'};
if ~isempty(options.crf), codecArgs = [codecArgs, {'-crf', sprintf('%d', options.crf)}]; end
if ~isempty(options.preset), codecArgs = [codecArgs, {'-preset', options.preset}]; end

ovrFlag = '-n';
if options.Overwrite, ovrFlag = '-y'; end

% 4. Execution Loop
outputDir = char(outputDir);
fprintf('Using FFmpeg: %s\n', ffmpegPath);

for i = 1:length(filesToProcess)
    [~, fileName, ~] = fileparts(filesToProcess(i).name);

    % Determine destination
    if isempty(outputDir)
        thisOutputDir = filesToProcess(i).folder;
    else
        thisOutputDir = outputDir;
        if ~exist(thisOutputDir, 'dir'), mkdir(thisOutputDir); end
    end

    fullInput  = fullfile(filesToProcess(i).folder, filesToProcess(i).name);
    fullOutput = fullfile(thisOutputDir, [fileName, '_compressed.mp4']);

    if ~options.Overwrite && exist(fullOutput, 'file')
        fprintf('Skipping (%d/%d): %s\n', i, length(filesToProcess), fileName);
        continue;
    end

    fprintf('Processing (%d/%d): %s\n', i, length(filesToProcess), fileName);

    cmd = ndi.fun.systemCommandLine(ffmpegPath, ...
        [{'-i', fullInput}, codecArgs, {ovrFlag, fullOutput}]);

    [status, cmdOut] = system(cmd);
    if status ~= 0, warning('Error on %s: %s', fileName, cmdOut); end
end
fprintf('Batch complete.\n');
end

function path = findFFmpeg(explicitPath)
% Internal helper: find ffmpeg across platforms (see ndi.fun.findExecutable)
folders = string.empty;
if ispc
    folders = [folders, "C:\ffmpeg\bin"];
    if ~isempty(getenv('ProgramFiles'))
        folders = [folders, string(fullfile(getenv('ProgramFiles'), 'ffmpeg', 'bin'))];
    end
    if ~isempty(getenv('LOCALAPPDATA'))
        % winget puts a link to ffmpeg here
        folders = [folders, string(fullfile(getenv('LOCALAPPDATA'), 'Microsoft', 'WinGet', 'Links'))];
    end
    if ~isempty(getenv('ProgramData'))
        folders = [folders, string(fullfile(getenv('ProgramData'), 'chocolatey', 'bin'))];
    end
end
path = ndi.fun.findExecutable('ffmpeg', 'Path', explicitPath, ...
    'Preference', 'Tools.FFmpegPath', ...
    'EnvironmentVariables', "FFMPEG_BINARY", ...
    'Folders', folders, ...
    'InstallHint', ['Install FFmpeg (https://ffmpeg.org/download.html; ' ...
        'e.g. "brew install ffmpeg" on macOS, "sudo apt install ffmpeg" ' ...
        'on Ubuntu, "winget install ffmpeg" on Windows), or set the ' ...
        'preference Tools.FFmpegPath or pass ''ffmpegPath''.']);
end
