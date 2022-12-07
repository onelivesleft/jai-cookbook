// Utilize `@notes` on declarations without the need for your own metaprogram
// @Incomplete Currently only handles `Code_Declaration` (not `Code_Compound_Declaration`)


#import "Basic";
#import "Compiler";
#import "Hash_Table";
#import "String";


Note_Data :: struct {
    declaration : *Code_Declaration = ---;
    parameters : [..] string;
}


check_for_notes :: (message: *Message_Typechecked) {
    if processed_notes  return;

    for message.declarations {
        declaration := cast(*Code_Declaration) it;
        for note: declaration.notes
            if declaration.name
                add_note(note.text, declaration);
    }
}


process_notes :: (workspace: Workspace) {
    if note_procs.count == 0 || processed_notes  return;

    processed_notes = true;

    builder : String_Builder;
    append(*builder, #string ___jai
#run {
    notes : *[..] Note_Data = ---;
___jai);

    for _, label: note_procs {
        notes, found := table_find(*notes_by_label, label);
        if found
            print_to_builder(*builder, #string ___jai
    notes = cast(*[..] Note_Data)0x%1;
    %2(<<notes);
___jai, *notes, label);
    }
    append(*builder, "}");

    add_build_string(builder_to_string(*builder), workspace);

}



#scope_file



processed_notes := false;

notes_by_label : Table(string, [..] Note_Data);
note_procs : Table(string, *Code_Node);


add_note :: (note_text: string, declaration: *Code_Declaration) {
    label : string = ---;
    note : Note_Data;
    note.declaration = declaration;

    if contains(note_text, "(") {
        label_and_parameters := split(note_text, "(");
        if index_of_string(note_text, ")") != note_text.count - 1 || label_and_parameters.count != 2
            compiler_report(sprint("Ill-formed note: \"%\"", note_text), make_location(declaration), .ERROR);

        if label_and_parameters[0] == "Note"
            compiler_report(sprint("@Note does not take parameters: \"@%\"", note_text), make_location(declaration), .ERROR);

        label = label_and_parameters[0];
        label_and_parameters[1].count -= 1;
        for parameter: split(label_and_parameters[1], ",")
            array_add(*note.parameters, parameter);
    }
    else {
        if note_text == "Note" {
            if declaration.root_expression.kind == .PROCEDURE_HEADER {
                header := cast(*Code_Procedure_Header) declaration.root_expression;
                if header.arguments.count == 1 && header.returns.count == 0  {
                    // @Incomplete We should really check the parameter types, but that means waiting on the PROCEDURE_BODY,
                    //             so for now we'll make do with this; it'll error out later if the types are wrong anyway.
                    node, found := table_find(*note_procs, declaration.name);
                    if found {
                        compiler_report(sprint("Found more than one definition for @Note proc: \"%\"", declaration.name), make_location(declaration), .WARNING);
                        compiler_report("This is the other definition", make_location(node), .ERROR);
                    }
                    table_set(*note_procs, declaration.name, cast(*Code_Node) declaration);
                    return;
                }
            }

            compiler_report("\"@Note\" should only be attached to procedures of the form\n\n    <NoteLabel> :: (notes: [] Note_Data) {",
                            make_location(declaration), .WARNING);
            return;
        }

        label = note_text;
    }

    existing_notes, found := table_find(*notes_by_label, label);

    notes : [..] Note_Data = ---;
    if found {
        notes = existing_notes;
    }
    else {
        new_notes : [..] Note_Data;
        notes = new_notes;
    }

    array_add(*notes, note);
    table_set(*notes_by_label, label, notes);
}
