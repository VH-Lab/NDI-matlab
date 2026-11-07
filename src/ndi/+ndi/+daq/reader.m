classdef reader < ndi.ido & ndi.documentservice
    % NDI_DAQREADER - A class for objects that read samples for NDI_DAQSYSTEM objects
    %
    %
    properties (GetAccess=public, SetAccess=protected)
    end

    methods

        function obj = reader(varargin)
            % ndi.daq.reader - create a new ndi.daq.reader object
            %
            %  OBJ = ndi.daq.reader()
            %
            %  Creates an ndi.daq.reader.
            %
            %  OBJ = ndi.daq.reader(NDI_SESSION_OBJ, NDI_DOCUMENT_OBJ)
            %
            %  Creates an ndi.daq.reader from an NDI_DOCUMENT_OBJ.
            %
            %  ndi.daq.reader has mostly abstract methods, it is made to be overridden.
            %
            obj = obj@ndi.ido();

            loadfromfile = 0;

            if nargin==2 & isa(varargin{1},'ndi.session') & isa(varargin{2},'ndi.document')
                obj.identifier = varargin{2}.document_properties.base.id;
            elseif nargin>=2
                if ischar(varargin{2}) % it is a command
                    loadfromfile = 1;
                    filename = varargin{1};
                    if ~strcmp(lower(varargin{2}), lower('OpenFile'))
                        error(['Unknown command.']);
                    end
                end
            end

            if loadfromfile
                error(['Load from file no longer supported.']);
            end
        end % ndi.daq.reader

        function d = getingesteddocument(ndi_daqreader_mfdaq_obj, epochfiles, S)
            % GETINGESTEDDOCUMENT - return the ndi.document with the data for an ingested epoch
            %
            % D = GETINGESTEDDOCUMENT(NDI_DAQREADER_MFDAQ_OBJ, EPOCHFILES, S)
            %
            % Returns the document D that contains the ingested ndi.daq.reader.mfdaq data for
            % the epoch described by EPOCHFILES. EPOCHFILES should be an ingested epoch.
            % S is the ndi.session for the dataset.
            %
            epochid = ndi.file.navigator.ingestedfiles_epochid(epochfiles);
            q = ndi.query('','isa','daqreader_epochdata_ingested') & ...
                ndi.query('','depends_on','daqreader_id', ndi_daqreader_mfdaq_obj.id()) & ...
                ndi.query('epochid.epochid','exact_string',epochid);
            d = S.database_search(q);
            assert(numel(d)==1,['Found ' int2str(numel(d)) ' documents for ' epochid ', needed exactly 1.']);
            d = d{1};

        end % getingesteddocument();

        function A = getingestedarchive(ndi_daqreader_obj, epochfiles, S, varargin)
            % GETINGESTEDARCHIVE - the ingested data of an epoch, from a v1 document or v2 bodies
            %
            % A = GETINGESTEDARCHIVE(NDI_DAQREADER_OBJ, EPOCHFILES, S)
            %
            % Returns a structure A describing where the ingested data of the
            % epoch EPOCHFILES (an ingested epoch) is. A.vintage says which:
            %
            %   'v1'  the v1 `daqreader_epochdata_ingested` document is in S
            %         (any v1 database, or a v2 database that kept it); A.doc
            %         is that document, as GETINGESTEDDOCUMENT returns it, and
            %         every reader reads it exactly as before.
            %   'v2'  S's database is v2 and holds no such document: the epoch's
            %         data are v2 data bodies (ndi.vintage.ingestedArchive
            %         describes the fields). Decided by Jess Haley, 2026-10-29
            %         [V2 ingest is one sampled body per channel group]
            %         (did-schema did_v2_go_forward_class_audit.md): "a reader
            %         finds an epoch's data through those bodies, not through
            %         the v1 `daqreader_mfdaq_epochdata_ingested` document";
            %         2026-11-03 [v2 line reads and writes both].
            %
            % A v1 database with no such document raises the error
            % GETINGESTEDDOCUMENT raises.
            %
            % A = GETINGESTEDARCHIVE(..., 'Channels', false) passes the
            % option to ndi.vintage.ingestedArchive: a v2 epoch's channel
            % list is not read (the epoch table needs only its clock and
            % extent, which are documents).
            %
            % See also: ndi.vintage.ingestedArchive, GETINGESTEDDOCUMENT
            %
            epochid = ndi.file.navigator.ingestedfiles_epochid(epochfiles);
            q = ndi.query('','isa','daqreader_epochdata_ingested') & ...
                ndi.query('','depends_on','daqreader_id', ndi_daqreader_obj.id()) & ...
                ndi.query('epochid.epochid','exact_string',epochid);
            d = S.database_search(q);
            if numel(d)==1
                A = struct('vintage', 'v1', 'doc', d{1}, 'epoch_id', epochid);
                return;
            end
            if isempty(d) && ndi.daq.reader.isv2database(S)
                A = ndi.vintage.ingestedArchive(S, ndi_daqreader_obj.id(), epochid, varargin{:});
                return;
            end
            assert(numel(d)==1,['Found ' int2str(numel(d)) ' documents for ' epochid ', needed exactly 1.']);
        end % getingestedarchive()

        function m = ingested2epochs_t0t1_epochclock(ndi_daqreader_mfdaq_obj, S, v2EpochIds)
           % INGESTED2EPOCHS_T0T1_EPOCHCLOCK - make a map of all ingested epochs to t0t1 and epochclock
           %
           % M = ingested2epochs_epochprobemaps_t0t1_epochclock(NDI_DAQREADER_OBJ, S)
           %
           % Examines the ingested epochfiles and returns a structure of maps:
           %   M.t0t1 maps epochid to t0t1
           %   M.epochclock maps epochid to epochclock
           %
           % They hold the v1 `daqreader_epochdata_ingested` documents only.
           %
           % M = ingested2epochs_t0t1_epochclock(NDI_DAQREADER_OBJ, S, V2EPOCHIDS)
           % also fills
           %   M.v2t0t1      epochid -> T0_T1_INGESTED of that epoch
           %   M.v2epochclock epochid -> EPOCHCLOCK_INGESTED of that epoch
           % for each id in V2EPOCHIDS (a cellstr of ingested epoch ids) that
           % has no v1 document here and whose ingested data are v2 bodies
           % (GETINGESTEDARCHIVE), read for all of them at once by
           % ndi.vintage.ingestedArchives: the same values, without the
           % six searches per epoch and per call. An epoch those calls
           % would refuse (no clock, no recording) is left out, and
           % ndi.daq.system/buildepochtable asks the system for it, which
           % raises the error. Without V2EPOCHIDS (or on a v1 database)
           % both maps are empty.

            q = ndi.query('','isa','daqreader_epochdata_ingested') & ...
                ndi.query('','depends_on','daqreader_id', ndi_daqreader_mfdaq_obj.id());

           d_ingested = S.database_search(q);

           epochid = {};
           t0t1 = {};
           epochclock = {};
           
           for i=1:numel(d_ingested)
                epochid{i} = d_ingested{i}.document_properties.epochid.epochid;
                et = d_ingested{i}.document_properties.daqreader_epochdata_ingested.epochtable;
                ec_here = {};
                for j=1:numel(et.epochclock)
                   ec_here{j} = ndi.time.clocktype(et.epochclock{j});
                end
                epochclock{i} = ec_here;

                t0t1_here = et.t0_t1;
                if ~iscell(t0t1_here)
                    t = {};
                    if isvector(t0t1_here) % this fixes a to-json, from-json, to-json conversion problem
                        t{1} = t0t1_here(:)';
                    else
                        for k=1:size(et.t0_t1,2)
                            t{k} = t0t1_here(:,k)';
                        end
                    end
                    t0t1_here = t;
                end;
                t0t1{i} = t0t1_here;
           end

           if ~isempty(epochid)
               m.t0t1 = containers.Map(epochid,t0t1);
               m.epochclock = containers.Map(epochid,epochclock);
           else
               m.t0t1 = containers.Map;
               m.epochclock = containers.Map;
           end

           % the v2 ingested epochs, read at once (see above)
           m.v2t0t1 = containers.Map('KeyType','char','ValueType','any');
           m.v2epochclock = containers.Map('KeyType','char','ValueType','any');
           if nargin > 2 && ~isempty(v2EpochIds) && ndi.daq.reader.isv2database(S)
               v2EpochIds = setdiff(cellstr(v2EpochIds), m.t0t1.keys, 'stable');
               A = ndi.vintage.ingestedArchives(S, ndi_daqreader_mfdaq_obj.id(), v2EpochIds);
               ids = A.keys;
               for i=1:numel(ids)
                   a = A(ids{i});
                   if isempty(a.epochclock) || isempty(a.t0_t1)
                       continue; % EPOCHCLOCK_INGESTED raises ingestedEpochNoClock
                   end
                   ec_here = {};
                   for j=1:numel(a.epochclock)
                       ec_here{j} = ndi.time.clocktype(a.epochclock{j});
                   end
                   m.v2epochclock(ids{i}) = ec_here;
                   m.v2t0t1(ids{i}) = a.t0_t1;
               end
           end

        end


        % EPOCHSET functions, although this object is NOT an EPOCHSET object

        function ec = epochclock(ndi_daqreader_obj, epochfiles)
            % EPOCHCLOCK - return the ndi.time.clocktype objects for an epoch
            %
            % EC = EPOCHCLOCK(NDI_DAQREADER_OBJ, EPOCHFILES)
            %
            % Return the clock types available for this epoch as a cell array
            % of ndi.time.clocktype objects (or sub-class members).
            %
            % For the generic ndi.daq.reader, this returns a single clock
            % type 'no_time';
            %
            % See also: ndi.time.clocktype
            %
            ec = {ndi.time.clocktype('no_time')};
        end % epochclock

        function ec = epochclock_ingested(ndi_daqreader_obj, epochfiles, S)
            % EPOCHCLOCK_INGESTED - return the ndi.time.clocktype objects for an ingested epoch
            %
            % EC = EPOCHCLOCK_INGESTED(NDI_DAQREADER_OBJ, EPOCHFILES, S)
            %
            % Return the clock types available for this epoch as a cell array
            % of ndi.time.clocktype objects (or sub-class members).
            %
            % See also: ndi.time.clocktype
            %
            ec = {};
            A = ndi_daqreader_obj.getingestedarchive(epochfiles, S, 'Channels', false);
            if strcmp(A.vintage,'v2')
                if isempty(A.epochclock)
                    error('NDI:daq:reader:ingestedEpochNoClock', '%s', A.clock_problem);
                end
                for i=1:numel(A.epochclock)
                    ec{i} = ndi.time.clocktype(A.epochclock{i});
                end
                return;
            end
            et = A.doc.document_properties.daqreader_epochdata_ingested.epochtable;
            for i=1:numel(et.epochclock)
                ec{i} = ndi.time.clocktype(et.epochclock{i});
            end
        end % epochclock_ingested

        function t0t1 = t0_t1(ndi_daqreader_obj, epochfiles)
            % T0_T1 - return the t0_t1 (beginning and end) epoch times for an epoch
            %
            % T0T1 = T0_T1(NDI_DAQREADER_OBJ, EPOCH_NUMBER)
            %
            % Return the beginning (t0) and end (t1) times of the epoch EPOCH_NUMBER
            % in the same units as the ndi.time.clocktype objects returned by EPOCHCLOCK.
            %
            % The abstract class always returns {[NaN NaN]}.
            %
            % See also: ndi.time.clocktype, EPOCHCLOCK
            %
            t0t1 = {[NaN NaN]};
        end % t0t1

        function t0t1 = t0_t1_ingested(ndi_daqreader_obj, epochfiles, S)
            % T0_T1_INGESTED - return the t0_t1 (beginning and end) epoch times for an ingested epoch
            %
            % T0T1 = T0_T1_INGESTED(NDI_DAQREADER_OBJ, EPOCH_NUMBER, S)
            %
            % Return the beginning (t0) and end (t1) times of the epoch EPOCH_NUMBER
            % in the same units as the ndi.time.clocktype objects returned by EPOCHCLOCK.
            %
            % The abstract class always returns {[NaN NaN]}.
            %
            % See also: ndi.time.clocktype, EPOCHCLOCK
            %
            A = ndi_daqreader_obj.getingestedarchive(epochfiles, S, 'Channels', false);
            if strcmp(A.vintage,'v2')
                if isempty(A.t0_t1)
                    error('NDI:daq:reader:ingestedEpochNoClock', '%s', A.clock_problem);
                end
                t0t1 = A.t0_t1;
                return;
            end
            et = A.doc.document_properties.daqreader_epochdata_ingested.epochtable;
            t0t1 = et.t0_t1;
            if ~iscell(t0t1)
                t = {};
                if isvector(t0t1) % this fixes a to-json, from-json, to-json conversion problem
                    t{1} = t0t1(:)';
                else
                    for i=1:size(et.t0_t1,2)
                        t{i} = t0t1(:,i)';
                    end
                end
                t0t1 = t;
            end
        end % t0t1

        function [b,msg] = verifyepochprobemap(ndi_daqreader_obj, epochprobemap, epochfiles)
            % VERIFYEPOCHPROBEMAP - Verifies EPOCHPROBEMAP is compatible with device and data on disk
            %
            % B = VERIFYEPOCHPROBEMAP(NDI_DAQREADER_OBJ, EPOCHPROBEMAP, NUMBER)
            %
            % Examines the ndi.epoch.epochprobemap_daqsystem EPOCHPROBEMAP and determines if it is
            % valid for the given device epoch NUMBER.
            %
            % For the abstract class ndi.daq.reader, EPOCHPROBEMAP is always valid as long as
            % EPOCHPROBEMAP is an ndi.epoch.epochprobemap_daqsystem object.
            %
            % See also: ndi.daq.reader, ndi.epoch.epochprobemap_daqsystem
            msg = '';
            b = isa(epochprobemap, 'ndi.epoch.epochprobemap_daqsystem');
            if ~b
                msg = 'epochprobemap is not a member of the class ndi.epoch.epochprobemap_daqsystem; it must be.';
                return;
            end

            for i=1:numel(epochprobemap)
                try
                    thedevicestring = ndi_daqreaderstring(epochprobemap(i).devicestring);
                catch
                    b = 0;
                    msg = ['Error evaluating devicestring ' epochprobemap(i).devicestring '.'];
                end
            end
        end % verifyepochprobemap

        function d = ingest_epochfiles(ndi_daqreader_obj, epochfiles)
            % INGEST_EPOCHFILES - create a document that describes data read by an ndi.daq.reader
            %
            % D = INGEST_EPOCHFILES(NDI_DAQREADER_OBJ, EPOCHFILES)
            %
            % Creates an ndi.document of type 'daqreader_epochdata_ingested' that contains the data
            % for an ndi.daq.reader object. The document D is not added to any database.
            %
            % Example:
            %    D = mydaqreader.ingest_epochfiles(epochfiles);

            daqreader_epochdata_ingested.epochtable.epochclock = ndi_daqreader_mfdaq_obj.epockclock(epochfiles);
            daqreader_epochdata_ingested.epochtable.t0_t1 = ndi.fun.doc.t0_t1cell2array(ndi_daqreader_mfdaq_obj.t0_t1(epochfiles));

            d = ndi.document('daqreader_epochdata_ingested',...
                'daqreader_epochdata_ingested', daqreader_epochdata_ingested);
            d = d.set_dependency_value('daqreader_id',ndi_daqreader_obj.id());

        end % ingest_epochfiles()

        function b = eq(ndi_daqreader_obj1, ndi_daqreader_obj2)
            % EQ - tests whether 2 ndi.daq.reader objects are equal
            %
            % B = EQ(NDI_DAQREADER_OBJ1, NDI_DAQREADER_OBJ2)
            %
            % Examines whether or not the ndi.daq.reader objects are equal.
            %
            b = strcmp(class(ndi_daqreader_obj1),class(ndi_daqreader_obj2));
            b = b & strcmp(ndi_daqreader_obj1.id(), ndi_daqreader_obj2.id());
        end % eq()

        %% functions that override ndi.documentservice

        function ndi_document_obj = newdocument(ndi_daqreader_obj, ndi_session_obj)
            % NEWDOCUMENT - create a new ndi.document for an ndi.daq.reader object
            %
            % DOC = NEWDOCUMENT(NDI_DAQREADER_OBJ)
            %
            % Creates an ndi.document object DOC that represents the
            %    ndi.daq.reader object.
            %
            % DOC = NEWDOCUMENT(NDI_DAQREADER_OBJ, NDI_SESSION_OBJ)
            %
            % Writes for the database of NDI_SESSION_OBJ (a reader holds no
            % session; ndi.daq.system/newdocument passes its own). When that
            % database is v2 (ndi.session/writesV2), DOC is a cell array of the
            % v2 record (see NEWDOCUMENTV2); otherwise the v1 document.
            %
            if nargin>1 && ~isempty(ndi_session_obj) && ndi_session_obj.writesV2()
                ndi_document_obj = ndi_daqreader_obj.newdocumentV2(ndi_session_obj, '');
                return;
            end
            ndi_document_obj = ndi.document('daqreader',...
                'daqreader.ndi_daqreader_class',class(ndi_daqreader_obj),...
                'base.id', ndi_daqreader_obj.id(),...
                'base.session_id',ndi.session.empty_id());
        end % newdocument()

        function docs = newdocumentV2(ndi_daqreader_obj, ndi_session_obj, reader_string)
            % NEWDOCUMENTV2 - the v2 record of this reader
            %
            % DOCS = NEWDOCUMENTV2(NDI_DAQREADER_OBJ, NDI_SESSION_OBJ, READER_STRING)
            %
            % Returns, as ndi.document objects, an `acquisition_reader` whose
            % id is the reader's id (`reader_string` READER_STRING when it is
            % not empty) and the `software` entity its `software_id` names,
            % whose `name` is the reader's class, in NDI_SESSION_OBJ -- the
            % shape DID-matlab's +migrators_j/daqreader.m and daqreader_ndr.m
            % write for a v1 `daqreader` / `daqreader_ndr`, and the one the
            % reader constructors and ndi.vintage.objectClass already read.
            % Decided by Jess Haley, 2026-10-29 [v1 writes into a V2 session]
            % (did-schema did_v2_go_forward_class_audit.md): "the end state is
            % that every NDI writer writes V2 documents".
            %
            sid = ndi_session_obj.id();
            cls = class(ndi_daqreader_obj);
            sw = ndi.setup.V2.entityDocuments('software', ...
                struct('name', cls, 'local_identifier', cls), struct(), 'SessionId', sid);
            f = struct();
            if ~isempty(reader_string)
                f.reader_string = char(reader_string);
            end
            r = did2.build.document('acquisition_reader', f, ...
                'Edges', struct('software_id', sw{1}.base.id), ...
                'Id', ndi_daqreader_obj.id(), 'SessionId', sid);
            docs = [{ndi.document(r)}, ...
                cellfun(@(x) ndi.document(x), sw, 'UniformOutput', false)];
        end % newdocumentV2()

        function sq = searchquery(ndi_daqreader_obj)
            % SEARCHQUERY - create a search for this ndi.daq.reader object
            %
            % SQ = SEARCHQUERY(NDI_DAQREADER_OBJ)
            %
            % Creates a search query for the ndi.daq.reader object.
            %
            sq = ndi.query('base.id','exact_string', ndi_daqreader_obj.id(), '');
        end % searchquery()

    end % methods

    methods (Static)
        function tf = isv2database(S)
            % ISV2DATABASE - is the database of session or dataset S a v2 (did2) database?
            %
            % TF = ndi.daq.reader.isv2database(S)
            %
            tf = false;
            try
                if ismethod(S, 'writesV2')
                    tf = logical(S.writesV2());
                else
                    tf = isa(S.database, 'ndi.database.implementations.database.did2sqlite');
                end
            catch
                tf = false;
            end
        end % isv2database()
    end % methods (Static)

end % ndi.daq.reader classdef
