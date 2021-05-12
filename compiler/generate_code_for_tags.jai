#import "Basic";
#import "Compiler";
#import "String";
#import "Hash_Table";


#run {
    filepath := "../examples/foo.jai";
    executable := "foo";

    output_path : string;

    build_options := get_build_options();
    build_options.output_type = .NO_OUTPUT;
    set_build_options(build_options);

    build_options.output_type = .EXECUTABLE;
    build_options.output_executable_name = executable;
    build_options.output_path = output_path;

    workspace = compiler_create_workspace();
    set_build_options(build_options, workspace);

    compiler_begin_intercept(workspace);
    add_build_file(filepath, workspace);

    while true {
        message := compiler_wait_for_message();
        if !message continue;
        if message.workspace != workspace continue;
        if message.kind == .COMPLETE break;

        build_steps(message);
    }

    compiler_end_intercept(workspace);
}


tagged_variables : Table(string, Type_Info_Tag);
workspace : Workspace;
inserted_generated_code := false;


build_steps :: (message : *Message) {
    if message.kind == {
        case .TYPECHECKED;
        // Record all global variables tagged with @my_tag
        type_checked := cast(*Message_Typechecked) message;
        for decl : type_checked.declarations {
            if decl.kind == .DECLARATION {
                if has_note(decl, "my_tag") {
                    declaration := cast(*Code_Declaration) decl;
                    table_set(*tagged_variables, declaration.name, declaration.type.type);
                }
            }
        }

        case .COMPILATION_PHASE;
        phase_message := cast (*Message_Phase) message;
        phase := phase_message.phase;
        if phase == .TYPECHECKED_ALL_WE_CAN && !inserted_generated_code {
            // All code has been parsed, so generate what we want from the tags.
            // We'll add it all to a string called `tag_code`, which should be
            // inserted into the source at the desired point by adding
            //      #insert tag_code;

            builder: String_Builder;
            init_string_builder(*builder);
            defer reset(*builder);

            // In this example we'll just make a proc to dump all the tagged variables to stdout,
            // which will look like this:
            /*
            dump_vars :: () {
                print("foo (bool) = %\n", foo);
                print("bar (int)  = %\n", bar);
            }
            */

            append(*builder, "tag_code :: #string ___JAI\n");
            append(*builder, "dump_vars :: () {\n");
            for type, variable: tagged_variables {
                type_string : string;
                if      type == .BOOL     type_string = "bool";
                else if type == .INTEGER  type_string = "int";
                else if type == .FLOAT    type_string = "float";
                else compiler_report("You may only dump a bool, int, or float");

                print_to_builder(*builder, "    print(\"% (%) = %%\\n\", %1);\n", variable, type_string);
            }
            append(*builder, "}\n");
            append(*builder, "___JAI;\n");

            add_build_string(builder_to_string(*builder), workspace);

            inserted_generated_code = true;
        }
    }
}


has_note :: (declaration: *Code_Declaration, note: string) -> bool {
    for declaration.notes  if it.text == note  return true;
    return false;
}
