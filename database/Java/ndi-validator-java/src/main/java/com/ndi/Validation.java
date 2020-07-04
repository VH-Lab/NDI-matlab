package com.ndi;

import org.json.JSONObject;
import java.util.HashMap;

public interface Validation {
    HashMap<String, String>
        performValidation(JSONObject input, JSONObject schema);
}

