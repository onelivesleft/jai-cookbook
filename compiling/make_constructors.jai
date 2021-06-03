// This file allows you to tag structs with `@Constructable`; if you do then a `make_` procedure
// will be automatically generated, which has parameters identical to the struct members.

// To use, `#load` this file in your equivalent of `build.jai`, and in your message loop
// call `make_constuctors` with each message.


make_constructors :: (message: *Message) {
    if message.kind == {
        case .TYPECHECKED;
        code := cast(*Message_Typechecked) message;
        for decl: code.declarations {
            if decl.enclosing_load && decl.enclosing_load.enclosing_import.module_type != .MAIN_PROGRAM
                continue;

            for expr: decl.expressions {
                if expr.kind == {
                    case .STRUCT;
                    store_struct_declaration(decl.name, cast(*Code_Struct)expr);
                }
            }
        }

        case .COMPILATION_PHASE;
        phase := cast (*Message_Phase) message;
        if phase.phase == .TYPECHECKED_ALL_WE_CAN {
            if added_constructors  return;
            added_constructors = true;

            builder: String_Builder;

            for code_struct, type_name: struct_declarations {
                proc_name := sprint("make_%", type_name);
                to_lower(proc_name);
                if code_struct && code_struct.defined_type {
                    type_info_struct := code_struct.defined_type;
                    // @TODO check type_info_struct.status_flags / .struct_flags?
                    print_to_builder(*builder, "% :: (", proc_name);
                    for member: type_info_struct.members {
                        if it_index  append(*builder, ", ");
                        print_to_builder(*builder, "%: %", member.name, name_from_type_info(member.type));
                    }
                    print_to_builder(*builder, ") -> % {\n", type_name);
                    print_to_builder(*builder, "    result : % = ---;\n", type_name);
                    for member: type_info_struct.members {
                        print_to_builder(*builder, "    result.%1 = %1;\n", member.name);
                    }
                    append(*builder, "    return result;\n");
                    append(*builder, "}\n\n");
                }
            }

            add_build_string(builder_to_string(*builder), message.workspace);
        }
    }
}



#scope_file



format_location :: (node: *Code_Node) -> string {
    location := make_location(node);
    return sprint("%:%,%", location.fully_pathed_filename, location.line_number, location.character_number);
}


store_struct_declaration :: (name: string, code_struct: *Code_Struct) {
    if name == ""  return;

    table_set(*struct_declarations, name, code_struct);
}


added_constructors := false;
struct_declarations : Table(string, *Code_Struct);


#import "Hash_Table";
#load "compiler_utils.jai";
