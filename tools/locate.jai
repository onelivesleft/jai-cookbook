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


#run {
    args := compiler_get_command_line_arguments();
    //if args.count != 5 {
    //    print(help_text);
    //    exit(1);
    //}

    //project_path := args[1];
    //file_path := args[2];
    //row, row_ok := parse_int(args[3]);
    //col, col_ok := parse_int(args[4]);
    project_path := "../examples/qux.jai";
    file_path    := "../examples/qux.jai";
    row, row_ok  := 8, true;
    col, col_ok  := 8, true;

    if !(row_ok && col_ok) {
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


action :: (node: *Code_Node) {
    name : string = ---;
    decl : *Code_Declaration = ---;
    range : Source_Code_Range;

    if node.kind == .IDENT {
        ident := cast(*Code_Ident) node;
        name = ident.name;
        decl = ident.resolved_declaration;
        range = make_code_range(node);
    }
    else if node.kind == .DECLARATION {
        decl = cast(*Code_Declaration) node;
        name = decl.name;
        range = make_code_range(decl);
        range.character_number_end = range.character_number_start + name.count;
    }
    else
        return;

    if name == ""  return;

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
            print("---\n");
            for list, decl: locations {
                print("%:\n", decl.name);
                for range: list  print("%,% -> %,%\n",
                    range.line_number_start,
                    range.character_number_start,
                    range.line_number_end,
                    range.character_number_end);
                print("\n");
            }
        }
    }
}

#scope_file


format_location :: (node: *Code_Node) -> string {
    location := make_location(node);
    return sprint("%:%,%", location.fully_pathed_filename, location.line_number, location.character_number);
}


store_local_variable :: (index: int, name: string, node: *Code_Node) {
    local : Local_Variable = ---;
    local.name = name;
    local.node = node;
    if local_variables.count <= index {
        while local_variables.count <= index
            array_add(*local_variables, local);
    }
    else {
        local_variables[index] = local;
    }
}


Local_Variable :: struct {
    name : string;
    node : *Code_Node;
}

local_variables : [..] Local_Variable;
last_parameter_index := -1;

global_variables : Table(string, *Code_Node);
headers : Table(*Code_Procedure_Header, bool);
