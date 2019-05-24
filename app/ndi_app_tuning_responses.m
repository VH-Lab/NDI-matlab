classdef ndi_app_tuning_response < ndi_app

	properties (SetAccess=protected,GetAccess=public)

	end % properties

	methods

		function ndi_app_tuning_response_obj = ndi_app_tuning_response(varargin)
			% NDI_APP_TUNING_RESPONSE - an app to decode stimulus information from NDI_PROBE_STIMULUS objects
			%
			% NDI_APP_TUNING_RESPONSE_OBJ = NDI_APP_TUNING_RESPONSE(EXPERIMENT)
			%
			% Creates a new NDI_APP_TUNING_RESPONSE object that can operate on
			% NDI_EXPERIMENTS. The app is named 'ndi_app_stimulus_response'.
			%
				experiment = [];
				name = 'ndi_app_tuning_response';
				if numel(varargin)>0,
					experiment = varargin{1};
				end
				ndi_app_tuning_response_obj = ndi_app_tuning_response_obj@ndi_app(experiment, name);

		end % ndi_app_tuning_response() creator


		function [newdocs, existingdocs] = parse_stimuli(ndi_app_tuning_response_obj, ndi_probe_stim, ndi_timeseries_obj, reset)
			% PARSE_STIMULI - write stimulus records for all stimulus epochs of an NDI_PROBE stimulus probe
			%
			% [NEWDOCS, EXISITINGDOCS] = PARSE_STIMULI(NDI_APP_TUNING_RESPONSE_OBJ, NDI_PROBE_STIM, NDI_TIMESERIES_OBJ, [RESET])
			%
			% Examines a the NDI_EXPERIMENT associated with NDI_APP_TUNING_RESPONSE_OBJ and the stimulus
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
				if nargin<4,
					reset = 0;
				end;

				% find stimulus records

				sq_probe = ndi_probe_stim.searchquery();
				sq_e = ndi_app_tuning_response_obj.app.experiment.searchquery();
				sq_stim =  {'ndi_document.class_name','ndi_document_stimulus' };
				sq_tune = {'ndi_document.class_name','ndi_document_tuningcurve'};
				doc_stim = ndi_app_tuning_response_obj.experiment.database_search( cat(2,sq_e,sq_probe,sq_stim) );
				doc_tune   = ndi_app_tuning_response_obj.experiment.database_search( cat(2,sq_e,sq_probe,sq_tune) );

				

				if reset,
					% delete existing documents
					ndi_app_tuning_response_obj.experiment.database_rm(existing_doc_stim);
					ndi_app_tuning_response_obj.experiment.database_rm(existing_doc_tune);
					existing_doc_stim = {};
					existing_doc_tune = {};
				end;

				existingdocs = cat(1,existing_doc_stim(:),existing_doc_tune(:));

				% determine epochs that are finished 
				epoch_finished = {};

				for i=1:numel(existing_doc_stim),
					epoch_finished = unique(cat(2,epoch_finished,existing_doc_stim{i}.document_properties.epochid));
				end;

				et = ndi_probe_stim.epochtable;

				epochsremaining = setdiff({et.epoch_id}, epoch_finished);

				for j=1:numel(epochsremaining),
					% decode stimuli
					[data,t,timeref] = ndi_probe_stim.readtimeseriesepoch(epochsremaining{j},-Inf,Inf);
					% stimulus
					mystim = emptystruct('parameters');
					for k=1:numel(data.parameters),
						mystim(k) = struct('parameters',data.parameters{k});
					end;
					nd = ndi_app_tuning_response_obj.newdocument('stimulus/ndi_document_stimulus.json','presentation_order',data.stimid,'stimulus',mystim) + ...
						ndi_probe_stim.newdocument(epochsremaining{j});
					newdoc{end+1} = nd;

					% tuning curve

					isblank = structfindfield(ds.parameters,'isblank',1);
					notblank = setdiff(1:numel(ds.parameters),isblank);

					whatvaries = structwhatvaries(data.parameters(notblank));

					tuning_curve.whatvaries = whatvaries;
					tuning_curve.control_stimulus_id = isblank;

					nd2 = ndi_document('stimulus/ndi_document_stimulus_tuningcurve.json','tuning_curve',tuning_curve) + ndi_probe_stim.newdocument(epochsremaining{j});
					newdoc{end+1} = nd2;
				end;

				ndi_app_tuning_response_obj.experiment.database_add(newdoc);
		end % 

	end; % methods

end % ndi_app_stimulus_response


