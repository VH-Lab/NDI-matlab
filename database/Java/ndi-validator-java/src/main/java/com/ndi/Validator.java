package com.ndi;

import org.json.JSONObject;
import org.json.JSONTokener;
import java.io.InputStream;
import java.util.HashMap;

public class Validator {
    private static final Validation implementation = ValidatorFactory.build();
    private final HashMap<String, String> report;

    /**
     * read the JSON file from the provided path of the JSON object and
     * the schema. Validate the JSON object and then produce the report
     *
     * @param document  the file path linking to the document
     * @param schema    the file path linking to the schema
     * @param isJSONContent specifying if the string passed in is the actual json file content
     */
    public Validator(String document, String schema, boolean isJSONContent){
        if (document == null || schema == null){
            throw new IllegalArgumentException("Must specify either a path or actual json content");
        }
        JSONObject schema_document;
        JSONObject ndi_document;
        if (isJSONContent){
            schema_document = new JSONObject(schema);
            ndi_document = new JSONObject(document);
        }
        else{
            schema_document = readJSON(schema);
            ndi_document = readJSON(document);
        }
        this.report = implementation.performValidation(ndi_document, schema_document);
    }

    /**
     * A second constructor that takes two HashMap as arguments, each of which represents
     * a JSON file content
     * @param documentProperties    the actual ndi_document content
     * @param schemaProperties      its validation (schema) document content
     */
    public Validator(HashMap<String, String> documentProperties, HashMap<String,String> schemaProperties){
        if (documentProperties == null || schemaProperties == null){
            throw new IllegalArgumentException("Arguments must be java.util.HashMap<String,String>");
        }
        JSONObject schema = new JSONObject(documentProperties);
        JSONObject ndi_document = new JSONObject(schemaProperties);
        this.report = implementation.performValidation(ndi_document, schema);
    }

    /**
     * get a report detailing the error message of the validation
     *
     * @return a key-value pairs, where the key represents the
     * JSON key that has the wrong type, and the value represents
     * a string detailing the error message. If the HashMap is empty,
     * then it means the json document is valid
     */
    public HashMap<String, String> getReport(){
        return this.report;
    }

    /**
     * parse a json file from the given file path and return a
     * JSONObject file
     *
     * @param path the file path of the JSON file
     * @return the JSONObject file representing the json file
     */
    private static JSONObject readJSON(String path){
        InputStream is = Validator.class.getResourceAsStream(path);
        if (is == null){
            throw new RuntimeException("Fail to read the json file");
        }
        return new JSONObject(new JSONTokener(is));
    }

    /**
     * Example usage of the com.ndi.Validator class
     * @param args command-line arguments
     */
    public static void main(String[] args){
        Validator test = new Validator("/test.json", "/schema.json", false);
        System.out.println(test.getReport());
    }
}
