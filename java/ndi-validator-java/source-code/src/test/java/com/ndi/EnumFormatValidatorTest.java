package com.ndi;

import org.everit.json.schema.FormatValidator;
import org.json.JSONObject;
import org.junit.jupiter.api.Test;

import java.io.IOException;
import java.util.Arrays;
import java.util.List;
import java.util.Optional;

import static org.junit.jupiter.api.Assertions.*;

class EnumFormatValidatorTest {

    @Test
    void buildFromJSON() throws IOException {
        JSONObject test = new JSONObject("{\n" +
                "\t\"string_format\": [\n" +
                "\t\t{\n" +
                "\t\t\t\"formatTag\": \"test_gzip\",\n" +
                "\t\t\t\"filePath\": \"src/main/resources/test.txt.gz\",\n" +
                "\t\t\t\"tableFormat\": {\n" +
                "\t\t\t\t\"format\": [\n" +
                "\t\t\t\t\t\", \",\n" +
                "\t\t\t\t\t\", \",\n" +
                "\t\t\t\t\t\", \"\n" +
                "\t\t\t\t],\n" +
                "\t\t\t\t\"entryFormat\": [\n" +
                "\t\t\t\t\tnull,\n" +
                "\t\t\t\t\tnull,\n" +
                "\t\t\t\t\t\":\",\n" +
                "\t\t\t\t\tnull\n" +
                "\t\t\t\t]\n" +
                "\t\t\t},\n" +
                "\t\t\t\"rules\": {\n" +
                "\t\t\t\t\"correct\": [\n" +
                "\t\t\t\t\t\"col1\"\n" +
                "\t\t\t\t],\n" +
                "\t\t\t\t\"suggestions\": [\n" +
                "\t\t\t\t\t\"col3\",\n" +
                "\t\t\t\t\t\"col4\"\n" +
                "\t\t\t\t]\n" +
                "\t\t\t},\n" +
                "\t\t\t\"loadTableIntoMemory\": true\n" +
                "\t\t},\n" +
                "\t\t{\n" +
                "\t\t\t\"formatTag\": \"text_txt\",\n" +
                "\t\t\t\"filePath\": \"src/main/resources/test.txt\",\n" +
                "\t\t\t\"tableFormat\": {\n" +
                "\t\t\t\t\"format\": [\n" +
                "\t\t\t\t\t\", \",\n" +
                "\t\t\t\t\t\", \",\n" +
                "\t\t\t\t\t\", \"\n" +
                "\t\t\t\t],\n" +
                "\t\t\t\t\"entryFormat\": [\n" +
                "\t\t\t\t\tnull,\n" +
                "\t\t\t\t\tnull,\n" +
                "\t\t\t\t\t\":\",\n" +
                "\t\t\t\t\tnull\n" +
                "\t\t\t\t]\n" +
                "\t\t\t},\n" +
                "\t\t\t\"rules\": {\n" +
                "\t\t\t\t\"correct\": [\n" +
                "\t\t\t\t\t\"col1\"\n" +
                "\t\t\t\t],\n" +
                "\t\t\t\t\"suggestions\": [\n" +
                "\t\t\t\t\t\"col3\",\n" +
                "\t\t\t\t\t\"col4\"\n" +
                "\t\t\t\t]\n" +
                "\t\t\t},\n" +
                "\t\t\t\"loadTableIntoMemory\": true\n" +
                "\t\t}\n" +
                "\t]\n" +
                "}");
        List<FormatValidator> testValidator = EnumFormatValidator.buildFromJSON(test);
        for (FormatValidator validator_curr : testValidator){
            assertEquals(validator_curr.validate("entry1"), Optional.empty());
            assertEquals(validator_curr.validate("entry5"), Optional.empty());
            assertEquals(validator_curr.validate("entry6"), Optional.empty());
            assertEquals(validator_curr.validate("entry2"), Optional.of("Entered: " + "entry2" + ". Expected: an entry from the columns " + "[col1]"));
            assertEquals(validator_curr.validate("entry7"), Optional.of("Entered: " + "entry7" + ". Expected: an entry from the columns " + "[col1]"));
            assertEquals(validator_curr.validate("entry3"), Optional.of("Entered: " + "entry3" + ". Expected: any one of " + "[entry5]"));
            assertEquals(validator_curr.validate("entry8"), Optional.of("Entered: " + "entry8" + ". Expected: any one of " + "[entry6]"));
            assertEquals(validator_curr.validate("entry9"), Optional.of("Entered: " + "entry9" + ". Expected: any one of " + "[entry6]"));
            assertEquals(validator_curr.validate("entry10"), Optional.of("Entered: " + "entry10" + ". Expected: any one of " + "[entry6]"));
            assertEquals(validator_curr.validate("entry4"), Optional.of("Entered: " + "entry4" + ". Expected: any one of " + "[entry1]"));
            assertEquals(validator_curr.validate("entry12"), Optional.of("Entered: " + "entry12" + ". Expected: any one of " + "[entry5]"));
            assertEquals(validator_curr.validate("entry11"), Optional.of("Entered: " + "entry11" + ". Expected: any one of " + "[entry6]"));
        }

        test = new JSONObject("{\n" +
                "\t\"string_format\": [\n" +
                "\t\t{\n" +
                "\t\t\t\"formatTag\": \"test_gzip\",\n" +
                "\t\t\t\"filePath\": \"src/main/resources/test.txt.gz\",\n" +
                "\t\t\t\"tableFormat\": {\n" +
                "\t\t\t\t\"format\": [\n" +
                "\t\t\t\t\t\", \",\n" +
                "\t\t\t\t\t\", \",\n" +
                "\t\t\t\t\t\", \"\n" +
                "\t\t\t\t],\n" +
                "\t\t\t\t\"entryFormat\": [\n" +
                "\t\t\t\t\tnull,\n" +
                "\t\t\t\t\tnull,\n" +
                "\t\t\t\t\t\":\",\n" +
                "\t\t\t\t\tnull\n" +
                "\t\t\t\t]\n" +
                "\t\t\t},\n" +
                "\t\t\t\"rules\": {\n" +
                "\t\t\t\t\"correct\": [\n" +
                "\t\t\t\t\t\"col1\"\n" +
                "\t\t\t\t],\n" +
                "\t\t\t\t\"suggestions\": [\n" +
                "\t\t\t\t\t\"col3\",\n" +
                "\t\t\t\t\t\"col4\"\n" +
                "\t\t\t\t]\n" +
                "\t\t\t},\n" +
                "\t\t\t\"loadTableIntoMemory\": true\n" +
                "\t\t},\n" +
                "\t\t{\n" +
                "\t\t\t\"formatTag\": \"text_txt\",\n" +
                "\t\t\t\"filePath\": \"src/main/resources/test.txt\",\n" +
                "\t\t\t\"tableFormat\": {\n" +
                "\t\t\t\t\"format\": [\n" +
                "\t\t\t\t\t\", \",\n" +
                "\t\t\t\t\t\", \",\n" +
                "\t\t\t\t\t\", \"\n" +
                "\t\t\t\t],\n" +
                "\t\t\t\t\"entryFormat\": [\n" +
                "\t\t\t\t\tnull,\n" +
                "\t\t\t\t\tnull,\n" +
                "\t\t\t\t\t\":\",\n" +
                "\t\t\t\t\tnull\n" +
                "\t\t\t\t]\n" +
                "\t\t\t},\n" +
                "\t\t\t\"rules\": {\n" +
                "\t\t\t\t\"correct\": [\n" +
                "\t\t\t\t\t\"col1\"\n" +
                "\t\t\t\t],\n" +
                "\t\t\t\t\"suggestions\": [\n" +
                "\t\t\t\t\t\"col3\",\n" +
                "\t\t\t\t\t\"col4\"\n" +
                "\t\t\t\t]\n" +
                "\t\t\t},\n" +
                "\t\t\t\"loadTableIntoMemory\": false\n" +
                "\t\t}\n" +
                "\t]\n" +
                "}");
        testValidator = EnumFormatValidator.buildFromJSON(test);
        for (FormatValidator validator_curr : testValidator){
            assertEquals(validator_curr.validate("entry1"), Optional.empty());
            assertEquals(validator_curr.validate("entry5"), Optional.empty());
            assertEquals(validator_curr.validate("entry6"), Optional.empty());
            assertEquals(validator_curr.validate("entry2"), Optional.of("Entered: " + "entry2" + ". Expected: an entry from the columns " + "[col1]"));
            assertEquals(validator_curr.validate("entry7"), Optional.of("Entered: " + "entry7" + ". Expected: an entry from the columns " + "[col1]"));
            assertEquals(validator_curr.validate("entry3"), Optional.of("Entered: " + "entry3" + ". Expected: any one of " + "[entry5]"));
            assertEquals(validator_curr.validate("entry8"), Optional.of("Entered: " + "entry8" + ". Expected: any one of " + "[entry6]"));
            assertEquals(validator_curr.validate("entry9"), Optional.of("Entered: " + "entry9" + ". Expected: any one of " + "[entry6]"));
            assertEquals(validator_curr.validate("entry10"), Optional.of("Entered: " + "entry10" + ". Expected: any one of " + "[entry6]"));
            assertEquals(validator_curr.validate("entry4"), Optional.of("Entered: " + "entry4" + ". Expected: any one of " + "[entry1]"));
            assertEquals(validator_curr.validate("entry12"), Optional.of("Entered: " + "entry12" + ". Expected: any one of " + "[entry5]"));
            assertEquals(validator_curr.validate("entry11"), Optional.of("Entered: " + "entry11" + ". Expected: any one of " + "[entry6]"));
        }

        test = new JSONObject("{\n" +
                "\t\"string_format\": [\n" +
                "\t\t{\n" +
                "\t\t\t\"formatTag\": \"test_gzip\",\n" +
                "\t\t\t\"filePath\": \"src/main/resources/test.txt.gz\",\n" +
                "\t\t\t\"tableFormat\": {\n" +
                "\t\t\t\t\"format\": [\n" +
                "\t\t\t\t\t\", \",\n" +
                "\t\t\t\t\t\", \",\n" +
                "\t\t\t\t\t\", \"\n" +
                "\t\t\t\t],\n" +
                "\t\t\t\t\"entryFormat\": [\n" +
                "\t\t\t\t\tnull,\n" +
                "\t\t\t\t\tnull,\n" +
                "\t\t\t\t\t\":\",\n" +
                "\t\t\t\t\tnull\n" +
                "\t\t\t\t]\n" +
                "\t\t\t},\n" +
                "\t\t\t\"rules\": {\n" +
                "\t\t\t\t\"correct\": [\n" +
                "\t\t\t\t\t\"col1\"\n" +
                "\t\t\t\t],\n" +
                "\t\t\t\t\"suggestions\": [\n" +
                "\t\t\t\t\t\"col3\",\n" +
                "\t\t\t\t\t\"col4\"\n" +
                "\t\t\t\t]\n" +
                "\t\t\t},\n" +
                "\t\t\t\"loadTableIntoMemory\": false\n" +
                "\t\t},\n" +
                "\t\t{\n" +
                "\t\t\t\"formatTag\": \"text_txt\",\n" +
                "\t\t\t\"filePath\": \"src/main/resources/test.txt\",\n" +
                "\t\t\t\"tableFormat\": {\n" +
                "\t\t\t\t\"format\": [\n" +
                "\t\t\t\t\t\", \",\n" +
                "\t\t\t\t\t\", \",\n" +
                "\t\t\t\t\t\", \"\n" +
                "\t\t\t\t],\n" +
                "\t\t\t\t\"entryFormat\": [\n" +
                "\t\t\t\t\tnull,\n" +
                "\t\t\t\t\tnull,\n" +
                "\t\t\t\t\t\":\",\n" +
                "\t\t\t\t\tnull\n" +
                "\t\t\t\t]\n" +
                "\t\t\t},\n" +
                "\t\t\t\"rules\": {\n" +
                "\t\t\t\t\"correct\": [\n" +
                "\t\t\t\t\t\"col1\"\n" +
                "\t\t\t\t],\n" +
                "\t\t\t\t\"suggestions\": [\n" +
                "\t\t\t\t\t\"col3\",\n" +
                "\t\t\t\t\t\"col4\"\n" +
                "\t\t\t\t]\n" +
                "\t\t\t},\n" +
                "\t\t\t\"loadTableIntoMemory\": false\n" +
                "\t\t}\n" +
                "\t]\n" +
                "}");
        testValidator = EnumFormatValidator.buildFromJSON(test);
        for (FormatValidator validator_curr : testValidator){
            assertEquals(validator_curr.validate("entry1"), Optional.empty());
            assertEquals(validator_curr.validate("entry5"), Optional.empty());
            assertEquals(validator_curr.validate("entry6"), Optional.empty());
            assertEquals(validator_curr.validate("entry2"), Optional.of("Entered: " + "entry2" + ". Expected: an entry from the columns " + "[col1]"));
            assertEquals(validator_curr.validate("entry7"), Optional.of("Entered: " + "entry7" + ". Expected: an entry from the columns " + "[col1]"));
            assertEquals(validator_curr.validate("entry3"), Optional.of("Entered: " + "entry3" + ". Expected: any one of " + "[entry5]"));
            assertEquals(validator_curr.validate("entry8"), Optional.of("Entered: " + "entry8" + ". Expected: any one of " + "[entry6]"));
            assertEquals(validator_curr.validate("entry9"), Optional.of("Entered: " + "entry9" + ". Expected: any one of " + "[entry6]"));
            assertEquals(validator_curr.validate("entry10"), Optional.of("Entered: " + "entry10" + ". Expected: any one of " + "[entry6]"));
            assertEquals(validator_curr.validate("entry4"), Optional.of("Entered: " + "entry4" + ". Expected: any one of " + "[entry1]"));
            assertEquals(validator_curr.validate("entry12"), Optional.of("Entered: " + "entry12" + ". Expected: any one of " + "[entry5]"));
            assertEquals(validator_curr.validate("entry11"), Optional.of("Entered: " + "entry11" + ". Expected: any one of " + "[entry6]"));
        }
    }

    @Test
    void testInvalidBuilder(){
        EnumFormatValidator.Builder builder = new EnumFormatValidator.Builder();
        try{
            builder.setFormatTag(null);
            fail();
        }
        catch(IllegalArgumentException ex){
            assertEquals("EnumFormatValidator Initialization Error: formatName cannot be null", ex.getMessage());
        }
        try{
            builder.setRules(null);
            fail();
        }
        catch(IllegalArgumentException ex){
            assertEquals("EnumFormatValidator Initialization Error: Rules cannot be null", ex.getMessage());
        }
        try{
            builder.setRules(new Rules());
            fail();
        }
        catch(IllegalArgumentException ex){
            assertEquals("EnumFormatValidator Initialization Error: You must have at least one column, whose entry will be accepted by the validator", ex.getMessage());
        }
        try{
            builder.setFilePath(null);
            fail();
        }
        catch(IllegalArgumentException ex){
            assertEquals("EnumFormatValidator Initialization Error: filePath cannot be null", ex.getMessage());
        }
        try{
            builder.setFilePath("src/test/java/com/ndi/invalid_test.json");
            fail();
        }
        catch(IllegalArgumentException ex){
            assertEquals("EnumFormatValidator Initialization Error: file does not exists", ex.getMessage());
            builder.setFilePath("src/main/resources/test.json");
        }
    }

    @Test
    void testLoadData(){
        EnumFormatValidator test = new EnumFormatValidator.Builder()
                    .setFilePath("src/main/resources/test.txt")
                    .setRules(new Rules().addExpectedColumn("col1").addSuggestedColumn(Arrays.asList("col3", "col4")))
                    .setFormatTag("test")
                    .setTableFormat(new TableFormat().addFormat(new String[]{", ", ", ", ", "}).addEntryPattern(2, ":"))
                    .loadData().build();
        assertEquals(test.validate("entry1"), Optional.empty());
        assertEquals(test.validate("entry5"), Optional.empty());
        assertEquals(test.validate("entry6"), Optional.empty());
        assertEquals(test.validate("entry2"), Optional.of("Entered: " + "entry2" + ". Expected: an entry from the columns " + "[col1]"));
        assertEquals(test.validate("entry7"), Optional.of("Entered: " + "entry7" + ". Expected: an entry from the columns " + "[col1]"));
        assertEquals(test.validate("entry3"), Optional.of("Entered: " + "entry3" + ". Expected: any one of " + "[entry5]"));
        assertEquals(test.validate("entry8"), Optional.of("Entered: " + "entry8" + ". Expected: any one of " + "[entry6]"));
        assertEquals(test.validate("entry9"), Optional.of("Entered: " + "entry9" + ". Expected: any one of " + "[entry6]"));
        assertEquals(test.validate("entry10"), Optional.of("Entered: " + "entry10" + ". Expected: any one of " + "[entry6]"));
        assertEquals(test.validate("entry4"), Optional.of("Entered: " + "entry4" + ". Expected: any one of " + "[entry1]"));
        assertEquals(test.validate("entry12"), Optional.of("Entered: " + "entry12" + ". Expected: any one of " + "[entry5]"));
        assertEquals(test.validate("entry11"), Optional.of("Entered: " + "entry11" + ". Expected: any one of " + "[entry6]"));

        test = new EnumFormatValidator.Builder()
                .setFilePath("src/main/resources/test.txt.gz")
                .setRules(new Rules().addExpectedColumn("col1").addSuggestedColumn(Arrays.asList("col3", "col4")))
                .setFormatTag("test")
                .setTableFormat(new TableFormat().addFormat(new String[]{", ", ", ", ", "}).addEntryPattern(2, ":"))
                .loadDataGzip().build();
        assertEquals(test.validate("entry1"), Optional.empty());
        assertEquals(test.validate("entry5"), Optional.empty());
        assertEquals(test.validate("entry6"), Optional.empty());
        assertEquals(test.validate("entry2"), Optional.of("Entered: " + "entry2" + ". Expected: an entry from the columns " + "[col1]"));
        assertEquals(test.validate("entry7"), Optional.of("Entered: " + "entry7" + ". Expected: an entry from the columns " + "[col1]"));
        assertEquals(test.validate("entry3"), Optional.of("Entered: " + "entry3" + ". Expected: any one of " + "[entry5]"));
        assertEquals(test.validate("entry8"), Optional.of("Entered: " + "entry8" + ". Expected: any one of " + "[entry6]"));
        assertEquals(test.validate("entry9"), Optional.of("Entered: " + "entry9" + ". Expected: any one of " + "[entry6]"));
        assertEquals(test.validate("entry10"), Optional.of("Entered: " + "entry10" + ". Expected: any one of " + "[entry6]"));
        assertEquals(test.validate("entry4"), Optional.of("Entered: " + "entry4" + ". Expected: any one of " + "[entry1]"));
        assertEquals(test.validate("entry12"), Optional.of("Entered: " + "entry12" + ". Expected: any one of " + "[entry5]"));
        assertEquals(test.validate("entry11"), Optional.of("Entered: " + "entry11" + ". Expected: any one of " + "[entry6]"));

        test = new EnumFormatValidator.Builder()
                .setFilePath("src/main/resources/test.txt.gz")
                .setRules(new Rules().addExpectedColumn("col1").addSuggestedColumn(Arrays.asList("col3", "col4")))
                .setFormatTag("test")
                .setTableFormat(new TableFormat().addFormat(new String[]{", ", ", ", ", "}).addEntryPattern(2, ":"))
                .build();
        assertEquals(test.validate("entry1"), Optional.empty());
        assertEquals(test.validate("entry5"), Optional.empty());
        assertEquals(test.validate("entry6"), Optional.empty());
        assertEquals(test.validate("entry2"), Optional.of("Entered: " + "entry2" + ". Expected: an entry from the columns " + "[col1]"));
        assertEquals(test.validate("entry7"), Optional.of("Entered: " + "entry7" + ". Expected: an entry from the columns " + "[col1]"));
        assertEquals(test.validate("entry3"), Optional.of("Entered: " + "entry3" + ". Expected: any one of " + "[entry5]"));
        assertEquals(test.validate("entry8"), Optional.of("Entered: " + "entry8" + ". Expected: any one of " + "[entry6]"));
        assertEquals(test.validate("entry9"), Optional.of("Entered: " + "entry9" + ". Expected: any one of " + "[entry6]"));
        assertEquals(test.validate("entry10"), Optional.of("Entered: " + "entry10" + ". Expected: any one of " + "[entry6]"));
        assertEquals(test.validate("entry4"), Optional.of("Entered: " + "entry4" + ". Expected: any one of " + "[entry1]"));
        assertEquals(test.validate("entry12"), Optional.of("Entered: " + "entry12" + ". Expected: any one of " + "[entry5]"));
        assertEquals(test.validate("entry11"), Optional.of("Entered: " + "entry11" + ". Expected: any one of " + "[entry6]"));
    }
}