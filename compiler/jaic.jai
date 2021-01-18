// Simple wrapper to compile any Jai program with different options.
// Example use: jai jaic.jai -- -short -vs foo.jai


#import "Basic";
#import "Compiler";
#import "String";


short : bool;
vs : bool;
lazy : bool;
inline : bool;
trace : bool;
memdbg : bool;
x64 : bool;


set_options :: (using options: *Build_Options) {
    if short   shorten_filenames_in_error_messages = !shorten_filenames_in_error_messages;
    if vs      use_visual_studio_message_format    = !use_visual_studio_message_format;
    if lazy    lazy_foreign_function_lookups       = !lazy_foreign_function_lookups;
    if inline  enable_bytecode_inliner             = !enable_bytecode_inliner;
    if trace   stack_trace                         = !stack_trace;
    if memdbg  memory_debugger                     = !memory_debugger;

    if x64  backend = .X64;
}


#run {
    args := compiler_get_command_line_arguments();
    filepath : string;

    for arg: args {
        if starts_with(arg, "-") {
            if arg == {
                case "-short";
                short = true;

                case "-vs";
                vs = true;

                case "-lazy";
                lazy = true;

                case "-inline";
                inline = true;

                case "-trace";
                trace = true;

                case "-memdbg";
                memdbg = true;

                case;
                print("Unknown option: %\n", arg);
                exit(1);
            }
        }
        else if ends_with_nocase(args[0], ".jai") {
            filepath = arg;
        }
        else {
            print("Unknown option: %\n", arg);
            exit(1);
        }
    }

    if filepath = "" {
        print("Must specify a .jai src file!");
        exit(1);
    }

    output_path := path_strip_filename(filepath);
    #if OS == .WINDOWS
        executable := concatenate(path_strip_extension(basename(filepath)), ".exe");
    else
        executable := path_strip_extension(basename(filepath));

    set_working_directory(output_path);

    build_options := get_build_options();
    build_options.output_type = .NO_OUTPUT;
    set_build_options(build_options);

    build_options.output_type = .EXECUTABLE;
    build_options.output_executable_name = executable;
    build_options.output_path = output_path;
    set_options(*build_options);
    workspace := compiler_create_workspace("Main");
    set_build_options(build_options, workspace);
    add_build_file(filepath, workspace);
}
