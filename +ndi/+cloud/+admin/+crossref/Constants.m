classdef Constants
    properties (Constant)
        DOIPrefix = "10.63884"
        DatabaseURL = "https://ndi-cloud.com"
        DatabaseDOI = sprintf("%s/ndic.00000", ndi.cloud.admin.crossref.Constants.DOIPrefix)
        DatabaseTitle = "NDI Cloud Open Datasets"
        DatabaseDescription = "Searchable scientific datasets from neuroscience and other disciplines";
        DatabaseOrganization = "Waltham Data Science LLC"
        DatabaseCreationDate = ["2024", "04", "08"] % year, month, day
        NDIDatasetBaseURL = "https://www.ndi-cloud.com/datasets/"
    end
end
