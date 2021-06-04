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

            for code_struct, type_name: struct_declarations {
                signature: String_Builder;
                body : String_Builder;
                done_a_member := false;
                proc_name := sprint("make_%", type_name);
                to_lower(proc_name);

                if code_struct && code_struct.block {
                    for member: code_struct.block.members {
                        if member.kind != .DECLARATION  continue;

                        decl := cast(*Code_Declaration) member;
                        if decl.flags & (type_of(decl.flags).IS_CONSTANT | .IS_IMPORTED) continue;

                        if !done_a_member {
                            print_to_builder(*signature, "% :: (", proc_name);
                            print_to_builder(*body, "    result : % = ---;\n", type_name);
                        }
                        else
                            append(*signature, ", ");

                        member_type := "";
                        member_default_value := "";
                        for expr: decl.expressions {
                            if expr.kind == {
                                case .TYPE_INSTANTIATION;
                                t := cast(*Code_Type_Instantiation)expr;
                                i := cast(*Code_Ident)t.type_valued_expression;
                                if member_type == "" {
                                    member_type = i.name;
                                    if member_type == "string"
                                        member_default_value = "\"\"";
                                    else
                                        member_default_value = "0";
                                }

                                case .LITERAL;
                                literal := cast(*Code_Literal)expr;

                                if literal.value_type == {
                                    case .NUMBER;
                                    if literal.numeric_flags & .FLOAT64
                                        member_default_value = sprint("%", literal._float64);
                                    else if literal.numeric_flags & .FLOAT
                                        member_default_value = sprint("%", literal._float32);
                                    else
                                        member_default_value = sprint("%", literal._s64);

                                    case .STRING;
                                    member_default_value = sprint("\"%\"", literal._string);

                                    case .TRUE;
                                    member_default_value = "true";

                                    case .FALSE;
                                    member_default_value = "false";

                                    case .ARRAY;
                                    case .STRUCT;
                                    case .POINTER;
                                }
                            }
                        }

                        if member_default_value != "" {
                            if member_type == "" || member_type == "string"
                                print_to_builder(*signature, "% := %", member.name, member_default_value);
                            else
                                print_to_builder(*signature, "% : % = %", member.name, member_type, member_default_value);
                            print_to_builder(*body, "    result.%1 = %1;\n", member.name, member.name);
                            done_a_member = true;
                        }
                    }
                }

                if done_a_member {
                    print_to_builder(*signature, ") -> % #must {\n", type_name);
                    append(*signature, builder_to_string(*body));
                    append(*signature, "    return result;\n}\n\n");
                    add_build_string(builder_to_string(*signature), message.workspace);
                }
            }

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
