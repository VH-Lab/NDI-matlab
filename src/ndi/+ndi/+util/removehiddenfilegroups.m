function epochfiles_disk = removehiddenfilegroups(epochfiles_disk)
% ndi.util.removehiddenfilegroups - remove file groups that contain hidden/shadow files
%
% EPOCHFILES_DISK = ndi.util.removehiddenfilegroups(EPOCHFILES_DISK)
%
% Given a cell array of file groups (as returned by FINDFILEGROUPS, where
% EPOCHFILES_DISK{i} is a cell array of the file names in group i), removes any
% group that contains a file whose name begins with '.'.
%
% This drops hidden files and, in particular, macOS AppleDouble shadow files
% (e.g. '._Epoch6_g0_t0.imec0.ap.bin'), which can otherwise be matched by
% '#'-style filematch patterns and produce spurious duplicate epochs that share
% the same epoch_id as the genuine epoch.
%
% Example:
%   groups = { {'/d/data.bin'}, {'/d/._data.bin'} };
%   groups = ndi.util.removehiddenfilegroups(groups); % -> { {'/d/data.bin'} }
%
% See also: ndi.file.navigator

    hidden = [];
    for i=1:numel(epochfiles_disk)
        for j=1:numel(epochfiles_disk{i})
            % Check the full basename (name + extension), not just the fileparts
            % 'name': for a dotfile such as '.DS_Store', fileparts returns an empty
            % name and ext='.DS_Store', so the name alone would miss it.
            [~,fname,fext] = fileparts(epochfiles_disk{i}{j});
            basename = [fname fext];
            if ~isempty(basename) && basename(1)=='.'
                hidden(end+1) = i; %#ok<AGROW>
            end
        end
    end
    incl = setdiff(1:numel(epochfiles_disk),hidden);
    epochfiles_disk = epochfiles_disk(incl);

end
