classdef ndi_app_stimulus_decoder < ndi_app

	properties (SetAccess=protected,GetAccess=public)

	end % properties

	methods

		function ndi_app_stimulus_decoder_obj = ndi_app_stimulus_decoder(varargin)
			% NDI_APP_STIMULUS_DECODER - an app to decode stimulus information from NDI_PROBE_STIMULUS objects
			%
			% NDI_APP_STIMULUS_DECODER_OBJ = NDI_APP_STIMULUS_DECODER(EXPERIMENT)
			%
			% Creates a new NDI_APP_STIMULUS_DECODER object that can operate on
			% NDI_EXPERIMENTS. The app is named 'ndi_app_stimulus_response'.
			%
				experiment = [];
				name = 'ndi_app_stimulus_decoder';
				if numel(varargin)>0,
					experiment = varargin{1};
				end
				ndi_app_stimulus_decoder_obj = ndi_app_stimulus_decoder_obj@ndi_app(experiment, name);

		end % ndi_app_stimulus_decoder() creator

		function [newdocs, existingdocs] = parse_stimuli(ndi_app_stimulus_decoder_obj, ndi_element_stim, reset)
			% PARSE_STIMULI - write stimulus records for all stimulus epochs of an NDI_ELEMENT stimulus probe
			%
			% [NEWDOCS, EXISITINGDOCS] = PARSE_STIMULI(NDI_APP_STIMULUS_DECODER_OBJ, NDI_ELEMENT_STIM, [RESET])
			%
			% Examines a the NDI_EXPERIMENT associated with NDI_APP_STIMULUS_DECODER_OBJ and the stimulus
			% probe NDI_STIM_PROBE, and creates documents of type NDI_DOCUMENT_STIMULUS and NDI_DOCUMENT_STIMULUS_TUNINGCURVE
			% for all stimulus epochs.
			%
			% If NDI_DOCUMENT_STIMULUS and NDI_DOCUMENT_STIMULUS_TUNINGCURVE documents already exist for a given
			% stimulus run, then they are returned in EXISTINGDOCS. Any new documents are returned in NEWDOCS.
			%
			% If the input argument RESET is given and is 1, then all existing documents for this probe are
			% removed and all documents are recalculated. The default for RESET is 0 (if it is not provided).
			%
			% Note that this function DOES add the new documents to the database.
			%
				if nargin<3,
					reset = 0;
				end;
				newdocs = {};
				existingdocs = {};

				E = ndi_app_stimulus_decoder_obj.experiment;

				sq_probe = ndi_query('','depends_on','stimulus_element_id',ndi_element_stim.id());
				sq_e = ndi_query(E.searchquery());
				sq_stim = ndi_query('','isa','stimulus_presentation.json',''); % presentation

				existing_doc_stim = E.database_search(sq_probe&sq_e&sq_stim);

				if reset,
					% delete existing documents
					E.database_rm(existing_doc_stim);
					existing_doc_stim = {};
				end;

				existingdocs = cat(1,existing_doc_stim(:));

				% determine epochs that are finished 
				epoch_finished = {};

				for i=1:numel(existing_doc_stim),
					epoch_finished = unique(cat(2,epoch_finished,existing_doc_stim{i}.document_properties.epochid));
				end;

				et = ndi_element_stim.epochtable();

				epochsremaining = setdiff({et.epoch_id}, epoch_finished);

				for j=1:numel(epochsremaining),
					% decode stimuli
					[data,t,timeref] = ndi_element_stim.readtimeseriesepoch(epochsremaining{j},-Inf,Inf);
					% stimulus
					mystim = emptystruct('parameters');
					for k=1:numel(data.parameters),
						mystim(k) = struct('parameters',data.parameters{k});
					end;
					presentation_time = emptystruct('clocktype', 'stimopen', 'onset', 'offset', 'stimclose');
					for z=1:numel(t.stimon),
						timestruct = struct('clocktype', timeref.clocktype.ndi_clocktype2char(), ...
							'stimopen', t.stimopenclose(z, 1), 'onset', t.stimon(z), 'offset', t.stimoff(z), ...
							'stimclose', t.stimopenclose(z,2) );
						presentation_time(end+1) = timestruct;
					end;

					nd = E.newdocument('stimulus/stimulus_presentation.json',...
						'presentation_order', data.stimid, 'presentation_time', presentation_time, ...
						'stimuli',mystim,'epochid',epochsremaining{j}) + ndi_app_stimulus_decoder_obj.newdocument();
					nd = set_dependency_value(nd,'stimulus_element_id',ndi_element_stim.id());
					newdocs{end+1} = nd;
				end;
				E.database_add(newdocs);
		end % 
	end; % methods
end % ndi_app_stimulus_decoder

