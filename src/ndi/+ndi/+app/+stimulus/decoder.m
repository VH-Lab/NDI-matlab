classdef decoder < ndi.app

    properties (SetAccess=protected,GetAccess=public)

    end % properties

    methods

        function ndi_app_stimulus_decoder_obj = decoder(varargin)
            % ndi.app.stimulus.decoder - an app to decode stimulus information from NDI_PROBE_STIMULUS objects
            %
            % NDI_APP_STIMULUS_DECODER_OBJ = ndi.app.stimulus.decoder(SESSION)
            %
            % Creates a new ndi_app_stimulus.decoder object that can operate on
            % NDI_SESSIONS. The app is named 'ndi.app.stimulus_decoder'.
            %
            session = [];
            name = 'ndi_app_stimulus_decoder';
            if numel(varargin)>0
                session = varargin{1};
            end
            ndi_app_stimulus_decoder_obj = ndi_app_stimulus_decoder_obj@ndi.app(session, name);

        end % ndi_app_stimulus_decoder() creator

        function [newdocs, existingdocs] = parse_stimuli(ndi_app_stimulus_decoder_obj, ndi_element_stim, reset, epochids)
            % PARSE_STIMULI - write stimulus records for stimulus epochs of an ndi.element stimulus probe
            %
            % [NEWDOCS, EXISITINGDOCS] = PARSE_STIMULI(NDI_APP_STIMULUS_DECODER_OBJ, NDI_ELEMENT_STIM, [RESET], [EPOCHIDS])
            %
            % Examines a the ndi.session associated with NDI_APP_STIMULUS_DECODER_OBJ and the stimulus
            % probe NDI_STIM_PROBE, and creates documents of type NDI_DOCUMENT_STIMULUS and NDI_DOCUMENT_STIMULUS_TUNINGCURVE
            % for all stimulus epochs.
            %
            % If NDI_DOCUMENT_STIMULUS and NDI_DOCUMENT_STIMULUS_TUNINGCURVE documents already exist for a given
            % stimulus run, then they are returned in EXISTINGDOCS. Any new documents are returned in NEWDOCS.
            %
            % If the input argument RESET is given and is 1, then existing documents are removed and
            % recalculated. The default for RESET is 0 (if it is not provided).
            %
            % By default, all stimulus epochs of the probe are examined. If the optional argument EPOCHIDS
            % is given (a char epoch id or a cell array of epoch ids), then only those epochs are examined
            % (and, when RESET is 1, only those epochs' existing documents are removed). An empty EPOCHIDS
            % (the default) means all epochs.
            %
            % Note that this function DOES add the new documents to the database.
            %
            if nargin<3
                reset = 0;
            end
            if nargin<4
                epochids = {};
            end
            if ischar(epochids) || (isstring(epochids) && isscalar(epochids))
                epochids = cellstr(epochids);
            end
            epochids = epochids(:).';   % row cell array (empty means "all epochs")
            newdocs = {};
            existingdocs = {};

            E = ndi_app_stimulus_decoder_obj.session;

            sq_probe = ndi.query('','depends_on','stimulus_element_id',ndi_element_stim.id());
            sq_e = ndi.query(E.searchquery());
            sq_stim = ndi.query('','isa','stimulus_presentation',''); % presentation

            existing_doc_stim = E.database_search(sq_probe&sq_e&sq_stim);

            % the epoch id of each existing stimulus_presentation document
            existing_epoch_ids = cell(1,numel(existing_doc_stim));
            for i=1:numel(existing_doc_stim)
                existing_epoch_ids{i} = existing_doc_stim{i}.document_properties.epochid.epochid;
            end

            % the set of epochs this call operates on (all, or the requested subset)
            et = ndi_element_stim.epochtable();
            target_epochs = {et.epoch_id};
            if ~isempty(epochids)
                target_epochs = intersect(target_epochs, epochids);
            end

            if reset
                % delete only the existing documents belonging to the target epochs
                rmmask = ismember(existing_epoch_ids, target_epochs);
                if any(rmmask)
                    E.database_rm(existing_doc_stim(rmmask));
                end
                existing_doc_stim = existing_doc_stim(~rmmask);
                existing_epoch_ids = existing_epoch_ids(~rmmask);
            end

            existingdocs = cat(1,existing_doc_stim(:));

            % epochs that already have a stimulus_presentation document are finished
            epoch_finished = unique(existing_epoch_ids);

            epochsremaining = setdiff(target_epochs, epoch_finished);

            for j=1:numel(epochsremaining)
                % decode stimuli
                [data,t,timeref] = ndi_element_stim.readtimeseriesepoch(epochsremaining{j},-Inf,Inf);
                % stimulus
                mystim = vlt.data.emptystruct('parameters');
                for k=1:numel(data.parameters)
                    mystim(k) = struct('parameters',data.parameters{k});
                end
                presentation_time = vlt.data.emptystruct('clocktype', 'stimopen', 'onset', 'offset', 'stimclose','stimevents');
                for z=1:numel(t.stimon)
                    timestruct = struct('clocktype', timeref.clocktype.ndi_clocktype2char(), ...
                        'stimopen', t.stimopenclose(z, 1), 'onset', t.stimon(z), 'offset', t.stimoff(z), ...
                        'stimclose', t.stimopenclose(z,2) );
                    stimevents = [];
                    if isfield(t,'stimevents')&~isempty(t.stimevents)
                        for kk=1:numel(t.stimevents)
                            stim_onset = nanmin(timestruct.onset,timestruct.stimopen);
                            stim_offset = nanmax(timestruct.offset,timestruct.stimclose);
                            stimevents_indexes = find(t.stimevents{kk}>=stim_onset & t.stimevents{kk}<=stim_offset);
                            stimevents = cat(1,stimevents,[ vlt.data.colvec(t.stimevents{kk}(stimevents_indexes)) kk*ones(numel(stimevents_indexes),1)]);
                        end
                        [dummy,sortorder] = sort(stimevents(:,1));
                        stimevents = stimevents(sortorder,:);
                    end
                    timestruct.stimevents = stimevents;
                    presentation_time(end+1) = timestruct;
                end

                %  make a file and write the presentation_time structure
                presentation_time_filename = ndi.file.temp_name();
                ndi.database.fun.write_presentation_time_structure(presentation_time_filename,...
                    presentation_time);

                stimulus_presentation = struct('presentation_order', data.stimid(:),...
                    ... % 'presentation_time', presentation_time, ... % we now put this in a file
                    'stimuli', mystim);
                nd = E.newdocument('stimulus_presentation',...
                    'stimulus_presentation', stimulus_presentation, ...
                    'epochid.epochid',epochsremaining{j}) + ndi_app_stimulus_decoder_obj.newdocument();
                nd = set_dependency_value(nd,'stimulus_element_id',ndi_element_stim.id());
                nd = nd.add_file('presentation_time.bin',presentation_time_filename);
                newdocs{end+1} = nd;
            end
            E.database_add(newdocs);
        end %

        function presentation_time = load_presentation_time(ndi_app_stimulus_decoder_obj, stimulus_presentation_doc)
            % LOAD_PRESENTATION_TIME - read the presentation_time structure from binary portion
            %
            % PRESENTATION_TIME = LOAD_PRESENTATION_TIME(NDI_APP_STIMULUS_DECODER_OBJ, ...
            %      STIMULUS_PRESENTATION_DOC)
            %
            % Given a 'stimulus_presentation' type ndi.document, loads the presentation_time data from
            % the binary portion.
            %
            if isfield(stimulus_presentation_doc.document_properties.stimulus_presentation,'presentation_time') % old way
                warning('stimulus presentation document uses deprecated form of presentation_time storage.');
                presentation_time = stimulus_presentation_doc.document_properties.stimulus_presentation.presentation_time;
            else
                fobj = ndi_app_stimulus_decoder_obj.session.database_openbinarydoc(stimulus_presentation_doc,'presentation_time.bin');
                [header,presentation_time] = ndi.database.fun.read_presentation_time_structure(fobj.fullpathfilename);
                fobj.fclose();
            end
        end % load_presentation_time
    end % methods

end % ndi.app.stimulus.decoder
