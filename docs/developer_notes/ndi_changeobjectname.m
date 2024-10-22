function ndi_changeobjectname(ndi_distribution_path, oldname, newname, varargin)
% NDI_CHANGEOBJECTNAME - change the name of an NDI object in the code distribution
%
% NDI_CHANGEOBJECTNAME(NDI_DISTRIBUTION_PATH, OLDNAME, NEWNAME, ...)
%
% This function attempts to change the name of an NDI object from OLDNAME to NEWNAME.
% 
% It does this by:
%    a) Using vlt.file.searchreplacefiles_shell to change the occurrence of OLDNAME to NEWNAME for both
%       the case-matched occurrences of OLDNAME and upper case-matched occurrences of OLDNAME
%       (which are changed to upper case of NEWNAME) for files of type *.m, *.txt, and *object*.
%    b) Using vlt.file.filenamesearchreplace to change any case-matched occurrences of OLDNAME to NEWNAME 
%       in the files and directory names.
%
%
% IMPORTANT: Remeber to run NDI_TESTSUITE on a FRESH install (fresh github clone) to test your changes.
%
% This behavior of this function is also modifyable by including name/value pairs:
% Parameter (default)              | Description
% -------------------------------------------------------------------------------
% noOp (1)                         | Should we perform no operation but just test what
%                                  |    would have been changed? (1 means don't do anything,
%                                  |    0 means to do it).
% filestoedit ({'*.m','*.txt',...  | File types to examine for changes
%       '*object*'})               |
%


noOp = 1;

filestoedit = {'*.m','*.txt','*object*'};

vlt.data.assign(varargin{:});

currentpath = pwd; % save our current path for restoration later

cd(ndi_distribution_path);

 % first edit text in the files
for i=1:numel(filestoedit),
    if ~noOp,
        vlt.file.searchreplacefiles_shell(filestoedit{i},oldname,newname);
        vlt.file.searchreplacefiles_shell(filestoedit{i},upper(oldname),upper(newname));
    end;
end;

cd(currentpath); % restore path

 % next change file names

vlt.file.filenamesearchreplace(ndi_distribution_path, {oldname}, {newname}, 'deleteOriginals',1,...
    'noOp', noOp, 'recursive', 1);



