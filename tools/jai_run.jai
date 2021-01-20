#import "Basic";
#import "Compiler";
#import "String";

set_options :: (options: *Build_Options) {
    using options;
    emit_debug_info = Debug_Info_Type.NONE;
}


#run {
    args := compiler_get_command_line_arguments();
    if args.count == 0 || !ends_with_nocase(args[0], ".jai") {
        print("Must specify a .jai src file!");
        exit(1);
    }

    filepath := args[0];
    output_path := path_strip_filename(filepath);
    #if OS == .WINDOWS
        executable := concatenate(path_strip_extension(basename(filepath)), ".exe");
    else
        executable := path_strip_extension(basename(filepath));

    set_working_directory(output_path);

    build_options := get_build_options();
    build_options.output_type = .NO_OUTPUT;
    set_build_options(build_options);

    build_options.output_type = .NO_OUTPUT;
    build_options.output_executable_name = executable;
    build_options.output_path = output_path;
    set_options(*build_options);
    workspace := compiler_create_workspace("Main");
    set_build_options(build_options, workspace);
    add_build_file(filepath, workspace);

    builder : String_Builder;
    init_string_builder(*builder);

    if args.count > 0 {
        print_to_builder(*builder, "__new_command_line_strings : [%] string : .[\n", args.count);
        for arg: args  print_to_builder(*builder, "    \"%\",\n", replace(arg, "\\", "\\\\"));
        append(*builder, "];\n");
        print_to_builder(*builder, "__new_command_line_arguments : [%] *u8;\n", args.count);
        append(*builder, "#run {\n");
        for arg, index: args
            print_to_builder(*builder, "    __new_command_line_arguments[%1] = __new_command_line_strings[%1].data;\n", index);
        append(*builder, "    __command_line_arguments.data = __new_command_line_arguments.data;\n");
        append(*builder, "    __command_line_arguments.count = __new_command_line_arguments.count;\n");
        append(*builder, "}\n");
    }

    append(*builder, "#run main();\n");
    add_build_string(builder_to_string(*builder), workspace);
}
