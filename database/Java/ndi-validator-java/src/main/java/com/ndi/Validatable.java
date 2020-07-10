package com.ndi;

import java.util.HashMap;

/**
 * An interface for all objects that is capable of validating a JSON Instance against
 * a JSON Schema. This is created in case that we want to switch to a different open-source
 * JSON Validator implementation. All we need is to implement this interface and implement
 * performValidation method as well as the getReport method.
 */
public interface Validatable {

    /**
     * This method should perform the actual validation of JSON Object
     *
     * @return a key-value pairs, where the key represents the
     *         JSON key that has the wrong type, and the value represents
     *         a string detailing the error message. If the HashMap is empty,
     *         then it means the json document is valid
     */
    HashMap<String, String> performValidation();

    /**
     * Acquire an report of validation. This should be called after performValidation()
     * method has been called. If perform Validation has not been called, this should
     * call the performValidation method for the user
     *
     * @return again a key-value pairs, where the key represents the
     *         JSON key that has the wrong type, and the value represents
     *         a string detailing the error message. If the HashMap is empty,
     *         then it means the json document is valid (exactly what performValidation()
     *         returns)
     */
    HashMap<String, String> getReport();

}

