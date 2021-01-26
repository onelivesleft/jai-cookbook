#import "Basic";
#import "Compiler";
#import "Hash_Table";
#import "String";

#load "../compiler/nodes.jai";
#load "../compiler/compiler_utils.jai";


help_text :: "Usage: jai locate.jai -- <project.jai> <file.jai> <row> <col>\n";


set_options :: (using options: *Build_Options) {
    emit_debug_info = Debug_Info_Type.NONE;
    output_path = "c:/temp";
    intermediate_path = "c:/temp";
}


test_path :: "c:/repos/jaitest/metacheck.jai";


target_path : string;
target_line : int;
target_char : int;


#run {
    args := compiler_get_command_line_arguments();
    if args.count < 4 {
        print(help_text);
        exit(1);
    }

    line_ok : bool;
    char_ok : bool;

    project_path := args[0];
    target_path = args[1];
    target_line, line_ok = parse_int(*args[2]);
    target_char, char_ok = parse_int(*args[3]);
    //project_path := test_path;
    //target_path  = "c:/repos/jaitest/meta.jai";
    //target_line = 4;
    //target_char = 5;

    if !(line_ok && char_ok) {
        print(help_text);
        exit(1);
    }

    output_path : string;

    build_options := get_build_options();
    build_options.output_type = .NO_OUTPUT;
    set_build_options(build_options);

    workspace := compiler_create_workspace();
    set_build_options(build_options, workspace);

    compiler_begin_intercept(workspace);
    add_build_file(project_path, workspace);

    init(*locations);

    while true {
        message := compiler_wait_for_message();
        if !message continue;
        if message.workspace != workspace continue;
        if message.kind == .COMPLETE break;

        get_idents(message);
    }

    compiler_end_intercept(workspace);
}



identifier : string;

Location_List  :: [..] Source_Code_Range;
locations : Table(*Code_Declaration, Location_List);


condition :: (node: *Code_Node) -> bool {
    return node.filename != "" && !contains(node.filename, "modules"); // @TODO @Performance this is terrible
}


to_revisit : [..] *Code_Ident;


action :: (node: *Code_Node) {
    name : string = ---;
    decl : *Code_Declaration = ---;
    range : Source_Code_Range;

    if node.kind == .IDENT {
        ident := cast(*Code_Ident) node;
        name = ident.name;
        decl = ident.resolved_declaration;
        if !decl {
            array_add(*to_revisit, ident);
            revisit_node(ident);
            return;
        }

        range = make_code_range(node);
    }
    else if node.kind == .DECLARATION {
        decl = cast(*Code_Declaration) node;
        name = decl.name;
        range = make_code_range(decl);
        //print("% % %:%:%\n\n", decl.name, decl, decl.filename, decl.l0, decl.c0);
    }
    else
        return;

    if name == "" || decl.filename == ""  return;

    existing_list, found := table_find(locations, decl);
    if !found {
        list : Location_List;
        existing_list = list;
    }
    array_add(*existing_list, range);
    table_set(*locations, decl, existing_list);
}


get_idents :: (message: *Compiler_Message) {
    if message.kind == {
        case .CODE_TYPECHECKED;
        code := cast(*Compiler_Message_Code_Typechecked) message;
        for decl: code.declarations
            walk_all_nodes(decl, condition, action);

        case .COMPILATION_PHASE;
        phase := cast (*Compiler_Message_Compilation_Phase) message;
        if phase.phase == .ALL_TARGET_CODE_BUILT {
            //print("Looking for: %:%:%\n", target_path, target_line, target_char);
            decl := decl_from_location(target_path, target_line, target_char);
            decl_range := format_range(make_code_range(decl));
            print("%\n", decl_range);
            if decl {
                ranges, _ := table_find(locations, decl);
                for ranges {
                    range := format_range(it);
                    if range != decl_range
                        print("%\n", range);
                }
            }
        }
    }
}


decl_from_location :: (filename: string, line: int, char: int) -> *Code_Declaration {
    for ranges, decl: locations {
        if decl.filename != filename  continue;
        for range: ranges {
            if line < range.line_number_start || line > range.line_number_end  continue;
            if line == range.line_number_start && char < range.character_number_start
            || line == range.line_number_end && char >range.character_number_end
                continue;
            return decl;
        }
    }
    return null;
}


#scope_file


format_location :: (node: *Code_Node) -> string {
    location := make_location(node);
    return sprint("%|%|%", location.fully_pathed_filename, location.line_number, location.character_number);
}


format_range :: (range: Source_Code_Range) -> string {
    return sprint("%|%|%|%|%", range.fully_pathed_filename, range.line_number_start, range.character_number_start, range.line_number_end, range.character_number_end);
}
