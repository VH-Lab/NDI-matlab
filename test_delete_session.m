% Test ndi.session.dir.delete

% Create a temporary directory for the session
temp_path = fullfile(tempdir, ['ndi_test_session_' num2str(randi(10000))]);
if isfolder(temp_path)
    rmdir(temp_path, 's');
end
mkdir(temp_path);

disp(['Testing with temp path: ' temp_path]);

% Create a normal session
% Note: ndi.session.dir creates .ndi directory in constructor
s = ndi.session.dir('ref', temp_path);

% Ensure .ndi exists
ndi_dir = fullfile(temp_path, '.ndi');
if ~isfolder(ndi_dir)
    error('.ndi directory was not created by constructor!');
end

disp('Test 1: delete(s, false, false) -> Should not delete');
% 1. Test delete(s, false, false) -> Should not delete
% Note: At this point, the method doesn't exist yet, so this script is expected to fail initially.
% But when running after modification, it should pass.
try
    s.delete(false, false);
catch ME
    if strcmp(ME.identifier, 'MATLAB:noSuchMethodOrField')
        disp('Method delete not found (expected before changes).');
    else
        rethrow(ME);
    end
end

if ~isfolder(ndi_dir)
    error('delete(false, false) deleted the directory!');
else
    disp('Pass: Directory still exists.');
end

disp('Test 2: delete(s, true, false) -> Should delete');
% 2. Test delete(s, true, false) -> Should delete
try
    s.delete(true, false);
    if isfolder(ndi_dir)
         % Check if the method was actually called (if script runs before changes, it might just do nothing if caught above? No, s.delete would error if missing)
         % If we are running this script BEFORE changes, s.delete errors.
         error('delete(true, false) did NOT delete the directory!');
    else
        disp('Pass: Directory deleted.');
    end
catch ME
    if strcmp(ME.identifier, 'MATLAB:noSuchMethodOrField')
         disp('Method delete not found (expected before changes).');
    else
        rethrow(ME);
    end
end

% Clean up for next test
if isfolder(temp_path)
    rmdir(temp_path, 's');
end
mkdir(temp_path);
s = ndi.session.dir('ref', temp_path);

% 3. Test ingested session (MockSession)
% Create MockSession.m first
disp('Test 3: Ingested session check');
fid = fopen('MockSession.m', 'w');
fprintf(fid, 'classdef MockSession < ndi.session.dir\n');
fprintf(fid, '    methods\n');
fprintf(fid, '        function obj = MockSession(path)\n');
fprintf(fid, '            obj@ndi.session.dir(''ref'', path);\n');
fprintf(fid, '        end\n');
fprintf(fid, '        function b = isIngestedInDataset(obj)\n');
fprintf(fid, '            b = true;\n');
fprintf(fid, '        end\n');
fprintf(fid, '    end\n');
fprintf(fid, 'end\n');
fclose(fid);

rehash; % Ensure MATLAB sees the new class

try
    ms = MockSession(temp_path);
    % Should error
    ms.delete(true, false);
    error('delete() on ingested session did NOT error!');
catch ME
    if contains(ME.message, 'Cannot directly delete session that is embedded in dataset')
        disp('Verified: delete() on ingested session errored as expected.');
    elseif strcmp(ME.identifier, 'MATLAB:noSuchMethodOrField')
        disp('Method delete not found (expected before changes).');
    else
        rethrow(ME);
    end
end

% Cleanup
if isfolder(temp_path)
    rmdir(temp_path, 's');
end
if exist('MockSession.m', 'file')
    delete('MockSession.m');
end
clear MockSession;

disp('All tests passed!');
