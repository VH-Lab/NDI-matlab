classdef sessiontable
    % NDI_SESSIONTABLE - a table for managing the file paths of NDI sessions
    %
    %

    properties

    end;

    methods

        function thepath = getsessionpath(ndi_sessiontable_obj, session_id)
            % GETSESSIONPATH - look up the path of an ndi.session by its ID
            %
            % THEPATH = GETSESIONPATH(SESSION_ID)
            %
            % Examines the ndi.session.sessiontable object to see if a path is known for a session
            % with an ID of SESSION_ID. Otherwise, empty ([]) is returned;
            %
            thepath = [];
            t = ndi_sessiontable_obj.getsessiontable();
            i = find(strcmp(session_id,{t.session_id}));
            if ~isempty(i),
                thepath = t(i(1)).path; % pick first match, should be only match
            end;
        end; % getsessionpath()

        function t = getsessiontable(ndi_sessiontable_obj)
            % GETSESSIONTABLE - return the session table
            %
            % T = GETSESSIONTABLE(NDI_SESSIONTABLE_OBJ)
            %
            % Returns the session table, a structure with fields 'SESSION_ID' and 'PATH'. Each entry
            % in the table corresponds to a recently-opened or added path of ndi.session.dir.
            %
            t = vlt.data.emptystruct('session_id','path');
            fname = ndi.session.sessiontable.localtablefilename();
            if isfile(fname),
                try,
                    t = vlt.file.loadStructArray(fname);
                    if ~isfield(t,'path'),
                        error(['path is a required field.']);
                    end;
                    if ~isfield(t,'session_id'),
                        error(['session_id is a required field.']);
                    end;
                catch,
                    warning(['Local session table file ' fname ' appears corrupted, ignoring.']);
                end;
                for i=1:numel(t),
                    if ~ischar(t(i).session_id),
                        t(i).session_id = int2str(t(i).session_id);
                    end;
                end;
            end;
        end; % getsessiontable()

        function addtableentry(ndi_sessiontable_obj, session_id, path);
            % ADDTABLEENTRY - add an entry to an ndi.session.sessiontable
            %
            % ADDTABLEENTRY(NDI_SESSIONTABLE_OBJ, SESSION_ID, PATH)
            %
            % Adds SESSION_ID and PATH as an entry to the session table.
            % If SESSION_ID is already in the table, then the entry is replaced.
            %
            if ~ischar(session_id),
                error(['Session_id must be a character array.']);
            end;
            if ~ischar(path),
                error(['PATH must be a character array.']);
            end;
            ndi_sessiontable_obj.removetableentry(session_id);
            t = ndi_sessiontable_obj.getsessiontable();
            t(end+1) = struct('session_id',session_id,'path',path);
            ndi_sessiontable_obj.writesessiontable(t);

        end; % addtableentry()

        function removetableentry(ndi_sessiontable_obj, session_id)
            % REMOVETABLEENTRY - remove an entry of an ndi.session.sessiontable
            %
            % REMOVETABLEENTRY(NDI_SESSIONTABLE_OBJ, SESSION_ID)
            %
            % Removes the entry of an ndi.session.sessiontable with the given SESSION_ID.
            %
            %
            t = ndi_sessiontable_obj.getsessiontable();
            i = find(strcmp(session_id,{t.session_id}));
            if ~isempty(i), % only act if we need to
                t = t(setdiff(1:numel(t),i));
                ndi_sessiontable_obj.writesessiontable(t);
            end;

        end; % removetableentry()

        function [b,results] = checktable(ndi_sessiontable_obj)
            %CHECKTABLE - check the session table for proper form, accessibility
            %
            % [B, RESULTS] = CHECKTABLE(NDI_SESSIONTABLE_OBJ)
            %
            % Check the ndi.session.sessiontable object's session table to see if it has the right
            % form (B is 1 if it does, B is 0 otherwise). (It has the right form if it is a structure with fieldnames
            % 'path' and 'sesion_id'.
            %
            % If the table has the right form RESULTS is a structure array with one entry per entry in the table.
            % It has a field 'exists' which is 1 if the path currently exists on the user's machine. If the table does not
            % have the right form, then RESULTS is empty.
            %
            b = 0;
            results = vlt.data.emptystruct('exists');
            t = ndi_sessiontable_obj.getsessiontable();
            [b,msg] = ndi_sessiontable_obj.isvalidtable(t);
            if b,
                for i=1:numel(t),
                    resultshere.exists = isfolder(t(i).path);
                    results(i) = resultshere;
                end;
            end;

        end; % checktable()

        function [b,msg] = isvalidtable(ndi_sessiontable_obj, t)
            % ISVALIDTABLE - Does the session table have the correct fields?
            %
            % [B,MSG] = ISVALIDTABLE(NDI_SESSIONTABLE_OBJ, [T])
            %
            % B is 1 if the NDI SESSION TABLE is a structure array with fields
            % 'path' and 'session_id', all text fields. B is 0 otherwise. If T
            % is not provided, then the session table is read.
            %
            % If B is 0, then an error description is provided in MSG. MSG is '' otherwise.
            %
            b = 1;
            msg = '';

            if nargin<2,
                t = ndi_sessiontable_obj.getsessiontable();
            end;
            if ~isfield(t,'path'),
                b = 0;
                msg = ['path is a required field.'];
                return;
            end;
            if ~isfield(t,'session_id'),
                b = 0;
                msg = ['session_id is a required field.'];
                return;
            end;
            for i=1:numel(t),
                if ~ischar(t(i).path),
                    b = 0;
                    msg = ['Entry ' int2str(i) ' of session table path is not a character array.'];
                    return;
                end;
                if ~ischar(t(i).session_id),
                    b = 0;
                    msg = ['Entry ' int2str(i) ' of session table session_id is not a character array.'];
                    return;
                end;
            end;
        end; % isvalidtable()

        function backupsessiontable(ndi_sessiontable_obj)
            % BACKUP_SESSION_TABLE - create a backup file for an ndi.session.sessiontable
            %
            % BACKUP_SESSION_TABLE(NDI_SESSIONTABLE_OBJ)
            %
            % Perform a backup of the session table file.
            % The session table file is backed up in the [USERPATH]/Preferences/NDI directory
            % and be named 'local_sessiontableNNN.txt', where NNN is a number.
            %
            fname = ndi.session.sessiontable.localtablefilename();
            if isfile(fname), % nothing to do if there's no file
                backupname = vlt.file.filebackup(fname);
                [success,message]=copyfile(fname,backupname);
                if ~success,
                    error(['Could not make backup file: ' message]);
                end;
            end;
        end; % backup_sessiontable()

        function f = backupfilelist(NDI_SESSIONTABLE_OBJ)
            % BACKUPFILELIST - a list of backup files that are present on disk
            %
            % F = BACKUPFILELIST(NDI_SESSIONTABLE_OBJ)
            %
            % Returns a list of backup files that are available. Backup files have
            % the name [USERPATH]/Preferences/NDI/local_sessiontable_bkupNNN.txt.
            %
            fname = ndi.session.sessiontable.localtablefilename();
            [parentdir,fn,ext] = fileparts(fname);
            d = dir([parentdir filesep fn '_*' ext]);
            f = {};
            for i=1:numel(d),
                f{i} = [parentdir filesep d(i).name];
            end;
        end; % backupfilelist()

        function clearsessiontable(ndi_sessiontable_obj, makebackup)
            % CLEARSESSIONTABLE - clear an ndi.session.sessiontable object's data
            %
            % CLEARSESSIONTABLE(NDI_SESSIONTABLE_OBJ, [MAKEBACKUP])
            %
            % Removes all entries from the ndi.session.sessiontable's file.
            % If MAKEBACKUP is present and is 1, then the session table file
            % is backed up first (in the Preferences/NDI directory).
            %
            if nargin<2,
                makebackup = 0;
            end;
            t = vlt.data.emptystruct('session_id','path');
            if makebackup,
                ndi_sessiontable_obj.backupsessiontable();
            end;
            ndi_sessiontable_obj.writesessiontable(t);
        end; % clearsessiontable()
    end; % methods

    methods (Access=protected)
        function writesessiontable(ndi_sessiontable_obj, t)
            % WRITESESSIONTABLE - write the session table to disk
            %
            % WRITESESSIONTABLE(NDI_SESSIONTABLE_OBJ, T)
            %
            % Save the table T to disk as the session table.
            % The table is first checked for validity.
            % An error is triggered if the table is invalid or cannot be written.
            %
            [b,msg] = ndi_sessiontable_obj.isvalidtable(t);
            if ~b,
                error(['Session table not valid: ' msg ]);
            end;
            fname = ndi.session.sessiontable.localtablefilename();
            lockfilename = [fname '-lockfile'];
            lockfid = vlt.file.checkout_lock_file(lockfilename);
            if lockfid > 0,
                vlt.file.saveStructArray(fname,t);
                fclose(lockfid);
                delete(lockfilename);
            else
                error(['Could not check out lock file to gain exclusive write access; ' ...
                    'delete file if you think it exists in error: ' lockfilename]);
            end;
        end; % writesessiontable()

    end % methods (Protected)

    methods (Static)

        function f = localtablefilename()
            % LOCALTABLEFILENAME - return the session table filename
            %
            % F = LOCALTABLEFILENAME()
            %
            f = [ndi.common.PathConstants.Preferences filesep 'local_sessiontable.txt'];
        end; % tablefilename()

    end; % static methods

end % class
