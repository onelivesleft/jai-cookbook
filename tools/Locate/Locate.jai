#import "Basic";
#import "Compiler";
#import "Hash_Table";
#import "String";

#load "../../compiler/compiler_utils.jai";
#load "../../compiler/nodes.jai";


help_text :: "Usage: jai -import_dir <Locate Folder> -meta Locate <project.jai> -- <file.jai> <row> <col>\n";


set_options :: (using options: *Build_Options) {
    emit_debug_info = .NONE;
    output_path = "c:/temp";
    intermediate_path = "c:/temp";
}


test_path :: "c:/repos/jaitest/foo.jai";


target_path : string;
target_line : int;
target_char : int;
finished := false;


#run {
    args := compiler_get_command_line_arguments();
    if args.count != 3 {
        print(help_text);
        exit(1);
    }

    line_ok : bool;
    char_ok : bool;

    target_path = args[0];
    target_line, line_ok = parse_int(*args[1]);
    target_char, char_ok = parse_int(*args[2]);
    //target_path = test_path;
    //target_line = 67;
    //target_char = 5;

    if !(line_ok && char_ok) {
        print(help_text);
        exit(1);
    }

    workspace := compiler_create_workspace("Target Program");
    if !workspace {
        print("Workspace creation failed.\n");
        return;
    }

    files, run_strings := compiler_get_source_files();
    if files {
        basename, path := get_basename_and_path(files[0]);
        if path {
            old_wd := get_working_directory();
            set_working_directory(path);

            for * files {
                print("%\n", it);
                old_filename := <<it;
                if is_absolute_path(old_filename) continue;
                <<it = sprint("%/%", old_wd, old_filename);
            }
        }
    }

    build_options := get_build_options(workspace);
    build_options.output_type = .NO_OUTPUT;
    build_options.emit_debug_info = .NONE;
    build_options.output_path = "c:/temp/"; // @TODO make correct
    build_options.intermediate_path = "c:/temp/";
    build_options.user_data_u64 = xx *check_message;
    set_build_options(build_options, workspace);

    init(*locations);

    compiler_begin_intercept(workspace);

    for files        add_build_file(it, workspace);
    for run_strings  add_build_string(tprint("#run %;\n", it), workspace);

    while !finished {
        message := compiler_wait_for_message();
        valid, complete := my_check_message(message);
        if complete  break;
    }

    compiler_end_intercept(workspace);

    exit(0);

    check_message :: (message: *Message) -> valid: bool, complete: bool {
        if !message return false, false;
        if message.kind == .COMPLETE return false, true;

        get_idents(message, true);

        return true, false;
    }

    my_check_message :: (message: *Message) -> valid: bool, complete: bool {
        if !message return false, false;
        if message.kind == .COMPLETE return false, true;

        get_idents(message);

        return true, false;
    }


    is_absolute_path :: (path: string) -> bool { // This routine is probably not as correct as we'd like. We'd like to put in a better one! But maybe we will stop doing the cwd thing, or do it differently; hard to say.
        if !path return false;

        if path[0] == #char "/" return true;  // Backslashes have already been converted to forward slashes by this point.
        if path.count >= 3 {
            // @Robustness: Check for a drive letter in character 0?  Anything else?
            if path[1] == #char ":" return true;
        }

        return false;
    }
}



identifier : string;

Location_List  :: [..] Source_Code_Range;
locations : Table(*Code_Declaration, Location_List);


condition :: (node: *Code_Node) -> bool {
    return decl.enclosing_load && decl.enclosing_load.enclosing_import.module_type == .MAIN_PROGRAM
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
            //print("Missing declaration for: %\n%\n\n", name, format_location(ident));
            return;
        }
        else {
            //print("Found declaration for: %\n%\n%\n\n", name, format_location(ident), format_location(decl));
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


check_ident :: (node: *Code_Node) {
    if node.kind == .DECLARATION {
        decl := cast(*Code_Declaration) node;
        location, found := table_find(locations, decl);
        if !found {
            location_list : Location_List;
            table_set(*locations, decl, location_list);
            for expression: decl.expressions
                if condition(expression)
                    check_ident(expression);
        }
        return;
    }

    if node.kind != .IDENT  return;

    ident := cast(*Code_Ident) node;

    decl := ident.resolved_declaration;
    if !decl {
        array_add(*to_revisit, ident);
        //print("Missing declaration for: %\n%\n\n", name, format_location(ident));
        return;
    }
    //else {
    //    print("Found declaration for: %\n%\n%\n\n", name, format_location(ident), format_location(decl));
    //}

    name := ident.name;
    if name == "" || decl.filename == ""  return;

    range := make_code_range(node);

    existing_list, found := table_find(locations, decl);
    if !found {
        list : Location_List;
        existing_list = list;
        //free(*list);
    }
    array_add(*existing_list, range);
    table_set(*locations, decl, existing_list);
}


get_idents :: (message: *Message, debug := false) {
    if message.kind == {
        case .TYPECHECKED;
        code := cast(*Message_Typechecked) message;
        for decl: code.declarations {
            if debug  print("%\n", <<decl);
            if decl.enclosing_load && decl.enclosing_load.enclosing_import.module_type != .MAIN_PROGRAM
                continue;
            if decl.filename != "" && !contains(decl.filename, "modules") { // @TODO @Performance this is terrible
                _, found := table_find(locations, decl);
                if !found {
                    location_list : Location_List;
                    table_set(*locations, decl, location_list);
                }
            }
        }

        case .COMPILATION_PHASE;
        phase := cast (*Message_Phase) message;
        if phase.phase == .TYPECHECKED_ALL_WE_CAN && phase.num_items_waiting_to_typecheck == 0 {
            finished = true;

            // aggregate locations
            location_list : [..] *Code_Declaration;
            for _, decl: locations
                array_add(*location_list, decl);

            for decl: location_list {
                for expression: decl.expressions
                    if condition(expression)
                        check_ident(expression);
            }
            //walk_all_nodes(decl, condition, action);

            //for location_list, decl: locations {
            //    print("%\n", format_location(decl));
            //    for location_list
            //        print("%\n", format_range(it));
            //    print("\n");
            //}

            // look for ident
            needle := decl_from_location(target_path, target_line, target_char);
            //print("Looking for: %:%:% = %\n", target_path, target_line, target_char, needle);
            if needle {
                needle_range := format_range(make_code_range(needle));
                print("%\n", needle_range);
                ranges, _ := table_find(locations, needle);
                for ranges {
                    range := format_range(it);
                    if range != needle_range
                        print("%\n", range);
                }
            }

            //print("Revisit count: %\n", to_revisit.count);
            ////for to_revisit  print("%\n", format_location(it));
            //for to_revisit  print("%\n", <<it);
        }
    }
}




decl_from_location :: (filename: string, line: int, char: int) -> *Code_Declaration {
    for ranges, decl: locations {
        if decl.filename != filename  continue;
        for range: ranges {
            if line < range.line_number_start || line > range.line_number_end
                continue;

            if line == range.line_number_start && char < range.character_number_start
            || line == range.line_number_end   && char > range.character_number_end
                continue;

            return decl;
        }
    }
    return null;
}


#scope_file


format_location :: (node: *Code_Node) -> string {
    location := make_location(node);
    return sprint("%:%:%", location.fully_pathed_filename, location.line_number, location.character_number);
}

format_range :: (range: Source_Code_Range) -> string {
    return sprint("%:%:%|%|%", range.fully_pathed_filename, range.line_number_start, range.character_number_start, range.line_number_end, range.character_number_end);
}


//format_range :: (range: Source_Code_Range) -> string {
//    return sprint("%|%|%|%|%", range.fully_pathed_filename, range.line_number_start, range.character_number_start, range.line_number_end, range.character_number_end);
//}
