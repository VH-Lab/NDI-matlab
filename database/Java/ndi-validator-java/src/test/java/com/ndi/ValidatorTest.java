package com.ndi;

import org.junit.jupiter.api.Test;

import static org.junit.jupiter.api.Assertions.*;

class ValidatorTest {

    @Test
    void getReportMultipleError() {
        String schema = "{\n" +
                "  \"$schema\": \"http://json-schema.org/schema#\",\n" +
                "  \"id\" : \"my_example_validator\",\n" +
                "  \"title\": \"Student information\",\n" +
                "  \"type\" : \"object\",\n" +
                "  \"properties\" : {\n" +
                "    \"name\" : {\n" +
                "      \"type\": \"string\"\n" +
                "    },\n" +
                "    \"ID\" : {\n" +
                "      \"type\" : \"string\",\n" +
                "      \"format\" : \"date-time\"\n" +
                "    },\n" +
                "    \"Grade\" : {\n" +
                "      \"type\" : \"string\"\n" +
                "    }\n" +
                "  }\n" +
                "}";
        String json = "{\n  \"name\": \"Joe\",\n  \"ID\" : 39,\n  \"Grade\" : 3,\n  \"Friend\" : {\"name\" :  \"Tom\", \"favourite-number\" :  \"8\"}\n}";
        Validator test = new Validator(json, schema, true);
        assertEquals(2, test.getReport().size());
    }

    @Test
    void getReportOneError() {
        String schema = "{\n" +
                "  \"$schema\": \"http://json-schema.org/schema#\",\n" +
                "  \"id\" : \"my_example_validator\",\n" +
                "  \"title\": \"Student information\",\n" +
                "  \"type\" : \"object\",\n" +
                "  \"properties\" : {\n" +
                "    \"name\" : {\n" +
                "      \"type\": \"string\"\n" +
                "    },\n" +
                "    \"ID\" : {\n" +
                "      \"type\" : \"integer\"\n" +
                "    },\n" +
                "    \"Grade\" : {\n" +
                "      \"type\" : \"string\"\n" +
                "    }\n" +
                "  }\n" +
                "}";
        String json = "{\n" +
                "  \"name\": \"Joe\",\n" +
                "  \"ID\" : \"39\",\n" +
                "  \"Grade\" : \"A\"\n" +
                "}";
        Validator test = new Validator(json, schema, true);
        assertEquals(1, test.getReport().size());
    }
}