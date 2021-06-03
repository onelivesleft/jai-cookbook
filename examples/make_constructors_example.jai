#import "Basic";
#import "Compiler";
#import "String";

#load "../compiling/make_constructors.jai";


#run {
    filepath := "quux.jai";
    executable := "quux";

    output_path : string;

    build_options := get_build_options();
    build_options.output_type = .NO_OUTPUT;
    set_build_options(build_options);

    build_options.output_type = .EXECUTABLE;
    build_options.output_executable_name = executable;
    build_options.output_path = output_path;
    workspace := compiler_create_workspace();
    set_build_options(build_options, workspace);

    compiler_begin_intercept(workspace);
    add_build_file(filepath, workspace);

    while true {
        message := compiler_wait_for_message();
        if !message continue;
        if message.workspace != workspace continue;
        if message.kind == .COMPLETE break;

        make_constructors(message);
    }

    compiler_end_intercept(workspace);
}
