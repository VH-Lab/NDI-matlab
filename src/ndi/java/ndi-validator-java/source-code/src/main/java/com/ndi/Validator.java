package com.ndi;

import org.everit.json.schema.FormatValidator;
import org.everit.json.schema.Schema;
import org.everit.json.schema.ValidationException;
import org.everit.json.schema.loader.SchemaLoader;
import org.json.JSONObject;

import java.io.IOException;
import java.util.ArrayList;
import java.util.List;
import java.util.HashMap;

/**
 * A wrapper class around com.ndi.Everit's json-schema validator implementation:
 * 'https://github.com/everit-org/json-schema', which follows the Draft v7 specification
 */
public class Validator implements Validatable {
    private final List<FormatValidator> validators = new ArrayList<>();
    private final JSONObject document;
    private final JSONObject schema;
    private HashMap<String, String> report;

    /**
     * Initialize an instance of Validator by passing in string which is
     * the content of the JSON document and JSON schema document
     *
     * @param document  the JSON document which will be validated
     * @param schema    the schema that the JSON file will be validated against
     */
    public Validator(String document, String schema){
        this.document = new JSONObject(document);
        this.schema = new JSONObject(schema);
    }

    /**
     * Initialize an instance of Validator by passing in instance of JSONObject
     *
     * @param document  the JSON document which will be validated
     * @param schema    the schema that the JSON file will be validated against
     */
    public Validator(JSONObject document, JSONObject schema){
        this.document = document;
        this.schema = schema;
    }

    /**
     * Add a list of format validators such that the validator recognizes the costume
     * format keyword for string
     *
     * @param validators an List of org.everit.json.schema.FormatValidator
     * @return  a new instance of Validator with a new formatValidator added
     */
    public Validator addValidators(List<FormatValidator> validators){
        if (validators == null){
            return this;
        }
        this.validators.addAll(validators);
        return this;
    }

    /**
     * Add a format validators such that the validator recognizes costume
     * format keyword for string
     *
     * @param validator an instance of org.everit.json.schema.FormatValidator
     * @return  a new instance of Validator with a new formatValidator added
     */
    public Validator addValidator(FormatValidator validator){
        if (validator == null){
            return this;
        }
        this.validators.add(validator);
        return this;
    }

    /**
     * get a report detailing the error message of the validation. If the report
     * is empty, performValidation() will be called, otherwise it will just return
     * the report
     *
     * @return a key-value pairs, where the key represents the
     * JSON key that has the wrong type, and the value represents
     * a string detailing the error message. If the HashMap is empty,
     * then it means the json document is valid
     */
    @Override
    public HashMap<String, String> getReport() {
        if (this.report == null){
            return this.performValidation();
        }
        else{
            return this.report;
        }
    }

    /**
     * Perform JSON Validation using org.everit JSON validator
     *
     * @return a key-value pairs, where the key represents the
     *         JSON key that has the wrong type, and the value represents
     *         a string detailing the error message. If the HashMap is empty,
     *         then it means the json document is valid
     */
    private HashMap<String, String> performValidation() {
        HashMap<String, String> output = new HashMap<>();
        SchemaLoader.SchemaLoaderBuilder loader = SchemaLoader.builder()
                .draftV7Support()
                .schemaJson(schema);
        for (FormatValidator validator : validators){
            loader = loader.addFormatValidator(validator);
        }
        Schema validation = loader.build().load().build();
        try{
            validation.validate(document);
            return output;
        }
        catch(ValidationException e){
            List<ValidationException> exceptionList = e.getCausingExceptions();
            if (exceptionList.isEmpty()){
                output.put(e.getPointerToViolation(), e.getMessage());
                return output;
            }
            for (ValidationException individual : exceptionList){
                output.put(individual.getPointerToViolation(), individual.getMessage());
            }
        }
        this.report = output;
        return output;
    }

    /**
     * A helper method that can used to read a JSON File from an absolute path, and
     * then convert it into an instance of JSONObject
     * @param filepath  the absolute path to the JSON file
     * @return  an instance of JSONObject
     * @throws IOException  when file path is invalid or any error occurred while
     * reading the file
     */
    public static JSONObject readJSONFile(String filepath) throws IOException {
        return Util.readJSONFile(filepath);
    }
}