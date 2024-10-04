function [name, ontology_identifier, synonym] = getSpeciesInfo(uuid)
    
    database = "taxonomy";
    base_url = "https://eutils.ncbi.nlm.nih.gov/entrez/eutils";
    doc_url = sprintf("efetch.fcgi?db=%s&id=%d", database, uuid);
    search_result = webread(base_url+"/"+doc_url);
    
    global ndi_globals;
    temp_dir = ndi.common.PathConstants.TempFolder;
    ido_ = ndi.ido;
    rand_num = ido_.identifier;
    temp_filename = sprintf("search_result_%s.xml", rand_num);
    file_path = fullfile(temp_dir,temp_filename);
    
    fid = fopen(file_path,'w');
    fprintf(fid,'%s',search_result);
    fclose(fid);

    C = onCleanup( @(fp) deleteTempFile(file_path));
    
    species_info = readstruct(file_path);
    if isfield(species_info.Taxon, 'ScientificName')
        name = species_info.Taxon.ScientificName;
    else
        name = "";
    end

    synonym = "";
    if isfield(species_info.Taxon, 'OtherNames')
        if isfield(species_info.Taxon.OtherNames, 'Synonym')
            synonym = species_info.Taxon.OtherNames.Synonym;
        end
    end

    if isfield(species_info.Taxon, 'TaxId')
        ontology_identifier = sprintf("http://purl.obolibrary.org/obo/NCBITaxon_%d", species_info.Taxon.TaxId);
    else
        ontology_identifier = "";
    end
end

function deleteTempFile(file_path)
    if isfile(file_path)
        delete(file_path)
    end
end
