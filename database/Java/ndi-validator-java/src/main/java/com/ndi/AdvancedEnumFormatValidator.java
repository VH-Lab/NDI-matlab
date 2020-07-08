package com.ndi;

import org.everit.json.schema.FormatValidator;

import java.io.IOException;
import java.util.Optional;
import java.util.List;
import java.util.ArrayList;

/**
 * A very flexible customized format option validator. It allows user to creates
 * format tag that is not present in the Json Schema Official Specification. This validator
 * can be used when we want to restrict an entry to a set of predefined values, but at the same
 * time, when the user has entered another set of value, we want to create suggestions for the user
 * to enter the correct values. It extends the FormatValidator class, which is called by the Everit
 * Validator when it encounters the this user's defined format tag in the schema document
 */
public class AdvancedEnumFormatValidator implements FormatValidator {
    final ParserFormat formats;
    final String formatName;
    final Table table;
    final Rules rules;
    final String filePath;


    /**
     * Constructor for the AdvancedEnumFormatValidator class. It takes the an instance of
     * FormatValidatorBuilder. FormatValidatorBuilder must contain all field, except the
     * table field. If table is not initialized, it will validate by calling the gzipSearch
     * methods instead of using the methods in the Table class
     *
     */
    public AdvancedEnumFormatValidator(FormatValidatorBuilder builder){
        if (builder.formatName == null){
            throw new IllegalArgumentException("require format name");
        }
        if (builder.rules == null || builder.filePath == null){
            if (builder.table == null){
                throw new IllegalArgumentException("require rules, filePath");
            }
        }
        if (builder.table != null) {
            assert builder.rules != null;
            for (String correctColumn : builder.rules.correct){
                if (!builder.table.isColKey(correctColumn)){
                    throw new IllegalArgumentException("Correct columns must come from a real column from the provided table");
                }
            }
            for (String suggestion : builder.rules.suggestions){
                if (!builder.table.isColKey(suggestion)){
                    throw new IllegalArgumentException("Columns that lead to error messages with suggestions must come" +
                            "from one of the columns in the provided table");
                }
            }
        }
        this.formatName = builder.formatName;
        this.table = builder.table;
        this.rules = builder.rules;
        this.formats = builder.parserformat;
        this.filePath = builder.filePath;
    }

    /**
     * Perform the validation step
     *
     * @param subject   the user input in that json entry
     * @return          List of error messages. The List would be empty if the user's entry
     *                  is valid.
     */
    @Override
    public Optional<String> validate(String subject) {
        if (this.table == null){
            FormatValidatorBuilder fb = new FormatValidatorBuilder(this);
            try {
                String result = fb.gzipSearch(subject);
                if (result == null){
                    return Optional.empty();
                }
                return Optional.of(result);
            } catch (IOException e) {
                e.printStackTrace();
                throw new IllegalArgumentException("check your path");
            }
        }
        List<String> correctOptions = new ArrayList<>();
        for (String correctColumn : rules.correct) {
            try {
                this.table.getEntry(correctColumn, subject);
                return Optional.empty();
            }
            catch (IllegalArgumentException ignored) {}
        }

        for (String suggestion : this.rules.suggestions) {
            try{
                this.table.getEntry(suggestion, subject, suggestion);
                for (String correctColumn : this.rules.correct){
                    correctOptions.addAll(this.table.getEntry(correctColumn, subject, suggestion));
                }
                return Optional.of("Entered: " + subject + ". Expected: any one of " + correctOptions);
            }
            catch (IllegalArgumentException ignored){
            }
        }

        return Optional.of("Entered: " + subject + ". Expected: an entry from the columns " + rules.correct);
    }

    /**
     * The name of the user-defined format tag
     *
     * @return  the name of this format tag
     */
    @Override
    public String formatName() {
        return this.formatName;
    }
}
